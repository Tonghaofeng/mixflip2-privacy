package uk.tonytong.permguard;

import android.app.Notification;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.job.JobInfo;
import android.app.job.JobParameters;
import android.app.job.JobScheduler;
import android.app.job.JobService;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkRequest;
import android.os.PersistableBundle;
import android.os.Process;
import android.os.SystemClock;
import android.os.UserManager;
import android.provider.Settings;
import android.util.Log;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Shizuku 守门员：Shizuku 没在跑时，用 ADB-over-TLS 连本机 adbd 跑 Shizuku 的 starter，再拉起守护循环。全程不用人点。
 * 为什么要它：Shizuku 13.6 自己的开机自启只在开机广播那一刻试一次，那时 Wi-Fi 往往还没连上，无线调试被系统关回去，
 *   它就放弃、不重试（OPEN_ITEMS #20，10-03 21:28 实测 Wi-Fi 比它晚 2 秒）。
 * 触发：LOCKED_BOOT_COMPLETED（未解锁就跑，钥匙和状态都在设备加密存储）/ BOOT_COMPLETED / 本 App 更新 / Wi-Fi 连上 /
 *   Shizuku binder 断 / GuardJob 等不到 Shizuku / 每 30 分钟兜底。失败从 30 秒起翻倍、封顶 15 分钟重试；
 *   连续两轮失败发通知，点一下打开 Shizuku 手动启动。
 * 一轮：等 binder 5 秒 → 无线调试没开就开（WRITE_SECURE_SETTINGS，shell `pm grant`）→ 找 TLS 端口 → 连 adbd →
 *   没有 shizuku_server 就跑 libshizuku.so，再 `pg.sh daemon-start` → 成功后排一轮 GuardJob。
 */
public class Watchdog extends JobService {
    static final String TAG = "PermGuardWD", SZ = "moe.shizuku.privileged.api";
    static final int PERIODIC_ID = 3, ONESHOT_ID = 4, NOTIFY_ID = 0x5a17;
    static final AtomicBoolean running = new AtomicBoolean();

    // 输出里 SZ=… 是结论；starter 输出写文件（它拉起的服务端会继承 fd，接管道会让这条 shell 一直不结束）
    static final String SCRIPT = "D=/data/local/tmp/permguard; mkdir -p $D/log\n"
            + "if pidof shizuku_server >/dev/null; then echo SZ=already; else\n"
            + "  lib=$(dirname \"$(pm path " + SZ + " | head -1 | cut -d: -f2)\")/lib/arm64/libshizuku.so\n"
            + "  \"$lib\" > $D/log/shizuku-starter.log 2>&1; tail -n 3 $D/log/shizuku-starter.log\n"
            + "  i=0; while [ $i -lt 15 ] && ! pidof shizuku_server >/dev/null; do sleep 1; i=$((i+1)); done\n"
            + "  pidof shizuku_server >/dev/null && echo SZ=started || echo SZ=failed\n"
            + "fi\n"
            + "pm grant uk.tonytong.permguard android.permission.WRITE_SECURE_SETTINGS 2>/dev/null\n"
            + "[ -f $D/pg.sh ] && sh $D/pg.sh daemon-start\n";

    volatile boolean stopped;

    static Context de(Context c) { return c.createDeviceProtectedStorageContext(); }
    static SharedPreferences prefs(Context c) { return de(c).getSharedPreferences("wd", Context.MODE_PRIVATE); }

    static void schedulePeriodic(Context c) {
        JobScheduler js = c.getSystemService(JobScheduler.class);
        if (js.getPendingJob(PERIODIC_ID) != null) return;
        js.schedule(new JobInfo.Builder(PERIODIC_ID, new ComponentName(c, Watchdog.class))
                .setPeriodic(30 * 60_000L, 10 * 60_000L)
                .setPersisted(true)
                .build());
    }

    /** delayMs=0 用加急任务：普通任务在本机就绪后还会被压一分多钟（10-03 实测 binder 断后 73 秒才开跑）。 */
    static void kick(Context c, String reason, long delayMs) {
        if (running.get()) return;   // 正在跑的那一轮覆盖这次触发（同 ID 重排会把它停掉）
        PersistableBundle b = new PersistableBundle();
        b.putString("reason", reason);
        JobInfo.Builder j = new JobInfo.Builder(ONESHOT_ID, new ComponentName(c, Watchdog.class)).setExtras(b);
        if (delayMs == 0) j.setExpedited(true);
        else j.setMinimumLatency(delayMs).setOverrideDeadline(delayMs + 5000);
        c.getSystemService(JobScheduler.class).schedule(j.build());
    }

    /** Wi-Fi 连上就叫醒（PendingIntent 形式，进程死了也送达，重启后由 App.onCreate 重新登记）。 */
    static void watchWifi(Context c) {
        try {
            PendingIntent pi = PendingIntent.getBroadcast(c, 1, new Intent(c, Net.class),
                    PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_MUTABLE);
            c.getSystemService(ConnectivityManager.class).registerNetworkCallback(
                    new NetworkRequest.Builder().addTransportType(NetworkCapabilities.TRANSPORT_WIFI).build(), pi);
        } catch (RuntimeException e) {
            log(c, "watchWifi 失败 " + e);
        }
    }

    public static class Net extends BroadcastReceiver {
        @Override
        public void onReceive(Context c, Intent i) {
            if (!Runner.shizukuReady()) kick(c, "wifi", 0);
        }
    }

    /** Shizuku binder 到了：撤通知、清失败计数。 */
    static void onShizukuUp(Context c) {
        prefs(c).edit().putInt("fails", 0).apply();
        c.getSystemService(NotificationManager.class).cancel(NOTIFY_ID);
    }

    @Override
    public boolean onStartJob(JobParameters p) {
        if (!running.compareAndSet(false, true)) return false;
        String reason = p.getJobId() == PERIODIC_ID ? "periodic" : p.getExtras().getString("reason", "kick");
        Context c = getApplicationContext();
        new Thread(() -> {
            String res;
            try {
                res = once(c, reason);
            } catch (Throwable t) {
                res = "fail:other " + t;
            }
            log(c, "结果 " + res);
            running.set(false);
            jobFinished(p, false);
            after(c, res);
        }, "permguard-wd").start();
        return true;
    }

    @Override
    public boolean onStopJob(JobParameters p) {
        stopped = true;
        return false;
    }

    String once(Context c, String reason) throws Exception {
        boolean locked = !c.getSystemService(UserManager.class).isUserUnlocked(), selftest = false;
        log(c, "开始 reason=" + reason + (locked ? "（未解锁）" : ""));
        File ext = locked ? null : c.getExternalFilesDir(null);   // 外部私有目录未解锁时不可用
        if (ext != null) {   // 下面三个文件都是 pair_watchdog.sh 用的
            File imp = new File(ext, "adbkey.import");
            if (imp.isFile()) { Adb.importKey(c, imp); log(c, "已导入 adb 钥匙"); }
            if (Adb.hasKey(c)) writeIfChanged(new File(ext, "adbkey.pub"), Adb.publicKey(c));
            selftest = new File(ext, "wd-selftest").delete();   // Shizuku 在跑也真连一次 adbd
        }
        for (int i = 0; i < 10 && !Runner.shizukuReady(); i++) Runner.sleep(500);
        if (Runner.shizukuReady() && !selftest) return "ok:binder";

        long end = SystemClock.elapsedRealtime() + 120_000;
        String r = "fail:other";
        while (!stopped && SystemClock.elapsedRealtime() < end) {
            r = attempt(c);
            if (r.startsWith("ok") || r.equals("fail:key") || r.equals("fail:perm")) break;
            Runner.sleep(5000);
        }
        return r;
    }

    String attempt(Context c) {
        String w = ensureAdbWifi(c);
        if (!w.equals("on")) return w;
        List<Integer> ports = Adb.findPorts(c);
        if (ports.isEmpty()) return "fail:port";
        String r = "fail:port";
        for (int port : ports) {
            try {
                String out = Adb.shell(c, port, SCRIPT).trim();
                log(c, "adbd:" + port + " →\n" + out);
                if (out.contains("SZ=started")) return "ok:started";
                if (out.contains("SZ=already")) return "ok:already";
                return "fail:starter";
            } catch (Adb.NotAdb e) {
                log(c, "跳过 " + e.getMessage());
            } catch (Adb.Rejected e) {
                log(c, "adbd:" + port + " 拒绝本 App 的钥匙：" + e.getMessage());
                return "fail:key";
            } catch (Exception e) {
                log(c, "adbd:" + port + " 出错：" + e);
                r = "fail:adb";
            }
        }
        return r;
    }

    /** 返回 on / fail:nowifi / fail:untrusted / fail:perm。 */
    static String ensureAdbWifi(Context c) {
        ContentResolver cr = c.getContentResolver();
        try {
            if (Settings.Global.getInt(cr, Settings.Global.ADB_ENABLED, 0) != 1) Settings.Global.putInt(cr, Settings.Global.ADB_ENABLED, 1);
            // 钥匙 7 天没连过会被系统清出 adb_keys（Shizuku 也这么设）
            if (Settings.Global.getLong(cr, "adb_allowed_connection_time", -1) != 0) Settings.Global.putLong(cr, "adb_allowed_connection_time", 0);
            if (Settings.Global.getInt(cr, "adb_wifi_enabled", 0) == 1) return "on";
            long net = wifiNetwork(c);
            if (net == 0) return "fail:nowifi";
            // 不受信任的 Wi-Fi（按 BSSID）上开无线调试，系统会把开关拨回 0 并弹「允许无线调试」框：同一次连接最多试 3 次。
            // 网络句柄跨重启会重复（10-03 实测：上次开机试了 2 次，这次接着记成第 3 次），所以按「开机次数:句柄」认连接，开成了就清零
            String key = Settings.Global.getInt(cr, Settings.Global.BOOT_COUNT, 0) + ":" + net;
            SharedPreferences sp = prefs(c);
            int n = key.equals(sp.getString("net_key", "")) ? sp.getInt("net_tries", 0) : 0;
            if (n >= 3) return "fail:untrusted";
            sp.edit().putString("net_key", key).putInt("net_tries", n + 1).apply();
            Settings.Global.putInt(cr, "adb_wifi_enabled", 1);
            log(c, "打开无线调试（第 " + (n + 1) + " 次）");
            Runner.sleep(3000);
            if (Settings.Global.getInt(cr, "adb_wifi_enabled", 0) != 1) return "fail:untrusted";
            sp.edit().putInt("net_tries", 0).apply();
            return "on";
        } catch (SecurityException e) {
            log(c, "没有 WRITE_SECURE_SETTINGS：" + e.getMessage());
            return "fail:perm";
        }
    }

    static long wifiNetwork(Context c) {
        ConnectivityManager cm = c.getSystemService(ConnectivityManager.class);
        for (Network n : cm.getAllNetworks()) {
            NetworkCapabilities nc = cm.getNetworkCapabilities(n);
            if (nc != null && nc.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) && !nc.hasTransport(NetworkCapabilities.TRANSPORT_VPN))
                return n.getNetworkHandle();
        }
        return 0;
    }

    static void after(Context c, String res) {
        SharedPreferences sp = prefs(c);
        String stamp = new SimpleDateFormat("MM-dd HH:mm:ss", Locale.US).format(new Date());
        if (res.startsWith("ok")) {
            sp.edit().putInt("fails", 0).putString("last", stamp + " " + res).apply();
            c.getSystemService(NotificationManager.class).cancel(NOTIFY_ID);
            if (res.equals("ok:binder")) return;
            boolean locked = !c.getSystemService(UserManager.class).isUserUnlocked();
            for (int i = 0; i < 20 && !locked && !Runner.shizukuReady(); i++) Runner.sleep(500);
            if (Runner.shizukuReady()) {
                if (res.equals("ok:started")) guardJob(c, 0);
                return;
            }
            // 服务端在跑、本进程却没 binder：未解锁时起的进程 ShizukuProvider 没装上，服务端对同一 pid/uid 不会重发。
            // 排好 GuardJob 后自杀，新进程启动时服务端会把 binder 交过来。解锁后 10 分钟内最多一次，界面开着不动
            // （这两种情况交给 GuardJob 自己的退避重试，别在这里再排它，免得和它来回踢）。
            long now = System.currentTimeMillis();
            if (MainActivity.visible || (!locked && now - sp.getLong("recycle", 0) < 600_000)) return;
            sp.edit().putLong("recycle", now).commit();
            guardJob(c, 5000);
            log(c, "本进程没拿到 Shizuku binder" + (locked ? "（未解锁）" : "") + "，退出换新进程");
            Runner.sleep(500);
            Process.killProcess(Process.myPid());
            return;
        }
        int f = sp.getInt("fails", 0) + 1;
        sp.edit().putInt("fails", f).putString("last", stamp + " " + res + "（连续 " + f + " 轮）").apply();
        if (f >= 2 || res.equals("fail:key") || res.equals("fail:perm")) notifyDown(c, res);
        long delay = Math.min(30_000L << Math.min(f - 1, 5), 15 * 60_000L);
        log(c, "第 " + f + " 轮失败，" + delay / 1000 + " 秒后重试");
        kick(c, "retry", delay);
    }

    /** 「成功后强制跑一轮 GuardJob」。GuardJob 不是 directBootAware：未解锁时排上，解锁后才跑。 */
    static void guardJob(Context c, long delayMs) {
        try { GuardJob.kick(c, "watchdog", delayMs); } catch (RuntimeException e) { log(c, "排 GuardJob 失败 " + e); }
    }

    static void notifyDown(Context c, String res) {
        String why;
        switch (res) {
            case "fail:nowifi": why = "没连 Wi-Fi，无线调试开不了；连上受信任的 Wi-Fi 后会自动启动。"; break;
            case "fail:untrusted": why = "当前 Wi-Fi 没被无线调试信任（系统若弹「允许无线调试」，勾「始终允许」）。"; break;
            case "fail:key": why = "PermGuard 的 adb 钥匙不被信任，需在 Mac 上跑 permguard/adb/pair_watchdog.sh。"; break;
            case "fail:perm": why = "PermGuard 缺 WRITE_SECURE_SETTINGS（adb shell pm grant 一次）。"; break;
            default: why = "自动启动没成功（" + res + "），会继续重试。";
        }
        String text = why + "点此打开 Shizuku →「启动」。";
        Intent sz = c.getPackageManager().getLaunchIntentForPackage(SZ);   // 未解锁时为 null
        PendingIntent pi = PendingIntent.getActivity(c, 2, sz != null ? sz : new Intent(c, MainActivity.class),
                PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
        Notification n = new Notification.Builder(c, Runner.CH).setSmallIcon(android.R.drawable.ic_lock_lock)
                .setContentTitle("Shizuku 未运行").setContentText(text).setStyle(new Notification.BigTextStyle().bigText(text))
                .setContentIntent(pi).setAutoCancel(true).setOnlyAlertOnce(true).build();
        c.getSystemService(NotificationManager.class).notify(NOTIFY_ID, n);
    }

    static void writeIfChanged(File f, String s) throws Exception {
        if (f.isFile() && s.equals(Runner.readAll(new FileInputStream(f)))) return;
        try (FileOutputStream o = new FileOutputStream(f)) { o.write(s.getBytes(StandardCharsets.UTF_8)); }
    }

    static File logFile(Context c) { return new File(de(c).getFilesDir(), "watchdog.log"); }

    static synchronized void log(Context c, String s) {
        Log.i(TAG, s);
        File f = logFile(c);
        if (f.length() > 128 * 1024) f.renameTo(new File(f.getPath() + ".1"));
        String line = new SimpleDateFormat("MM-dd HH:mm:ss", Locale.US).format(new Date()) + " " + s + "\n";
        try (FileOutputStream o = new FileOutputStream(f, true)) { o.write(line.getBytes(StandardCharsets.UTF_8)); } catch (Exception ignored) { }
    }
}
