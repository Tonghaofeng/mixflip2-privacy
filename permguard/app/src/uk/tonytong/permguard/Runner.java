package uk.tonytong.permguard;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.ContentValues;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Environment;
import android.provider.MediaStore;
import android.provider.Settings;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;
import java.lang.reflect.Method;
import java.nio.charset.StandardCharsets;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.Date;
import java.util.Locale;

import rikka.shizuku.Shizuku;

/**
 * 经 Shizuku 起一个 shell 身份的 sh，把 pg.sh 与白名单写到 /data/local/tmp/permguard，跑 core，
 * 顺手保证守护循环在跑。core = 本 APK 里的 uk.tonytong.permguard.Core（classpath 指向本 APK）。
 */
final class Runner {
    static final String D = "/data/local/tmp/permguard";
    static final String CH = "permguard";
    static final String EOF = "PG_EOF_7c1e";

    static SharedPreferences prefs(Context c) { return c.getSharedPreferences("pg", Context.MODE_PRIVATE); }

    static boolean shizukuReady() {
        try { return Shizuku.pingBinder() && !Shizuku.isPreV11(); } catch (Throwable t) { return false; }
    }
    static boolean shizukuGranted() {
        try { return Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED; } catch (Throwable t) { return false; }
    }

    /** 定时任务入口。返回 true = 让 JobScheduler 退避重试。 */
    static boolean fromJob(Context c, String reason, boolean oneshot) {
        for (int i = 0; i < 15 && !shizukuReady(); i++) sleep(3000);
        if (!shizukuReady()) {   // 拉起 Shizuku 与「起不来」的通知都归守门员
            status(c, reason, "Shizuku 未运行，本轮跳过（已叫守门员）", -1);
            Watchdog.kick(c, "guardjob", 0);
            return oneshot;
        }
        if (!shizukuGranted()) {
            status(c, reason, "Shizuku 未授权本 App", -1);
            notifyOnce(c, "no-perm", "permguard 需要 Shizuku 授权", "打开 PermGuard → 点「授权 Shizuku」");
            return false;
        }
        long minAge;   // 距上次 apply（任何来源，含守护循环）不足这么久就只保活守护、不重跑
        switch (reason) {
            case "boot": case "watchdog": minAge = 0; break;
            case "periodic": minAge = 5 * 3600; break;
            default: minAge = 1800;
        }
        run(c, "apply", reason, minAge);
        return false;
    }

    /** 执行一轮；返回 core 的输出（也写进私有日志）。 */
    static String run(Context c, String mode, String reason, long minAge) {
        String ts = new SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(new Date());
        StringBuilder out = new StringBuilder();
        int rc = -1;
        try {
            String apk = c.getApplicationInfo().sourceDir;
            String extra = mode.equals("verify") ? " --system" : "";
            StringBuilder sc = new StringBuilder();
            sc.append("exec 2>&1\nD=").append(D).append("\nmkdir -p $D/log $D/state $D/out\n");
            sc.append("cat > $D/pg.sh.new <<'").append(EOF).append("'\n").append(asset(c, "pg.sh")).append("\n").append(EOF)
                    .append("\nmv -f $D/pg.sh.new $D/pg.sh\n");
            sc.append("cat > $D/whitelist.conf.new <<'").append(EOF).append("'\n").append(conf(c)).append("\n").append(EOF)
                    .append("\nmv -f $D/whitelist.conf.new $D/whitelist.conf\n");
            sc.append("echo '").append(apk).append("' > $D/classpath\n");
            // HyperOS：自启动(10008) + 省电白名单，否则开机广播/定时任务可能被拦（同 Clash 的处理）
            sc.append("cmd appops set uk.tonytong.permguard 10008 allow; dumpsys deviceidle whitelist +uk.tonytong.permguard >/dev/null\n");
            // Shizuku 自己的开机自启与本 App 的守门员（开无线调试）都要 WRITE_SECURE_SETTINGS；本 App 的提醒通知要 POST_NOTIFICATIONS
            sc.append("pm grant moe.shizuku.privileged.api android.permission.WRITE_SECURE_SETTINGS 2>/dev/null; pm grant uk.tonytong.permguard android.permission.WRITE_SECURE_SETTINGS 2>/dev/null; pm grant uk.tonytong.permguard android.permission.POST_NOTIFICATIONS 2>/dev/null\n");
            if (mode.equals("apply") && minAge > 0) {
                sc.append("last=$(cat $D/last_apply 2>/dev/null || echo 0); age=$(( $(date +%s) - last ))\n");
                sc.append("if [ $age -ge ").append(minAge).append(" ]; then sh $D/pg.sh run apply; rc=$?; else echo \"SKIP 距上次 apply ${age}s\"; rc=0; fi\n");
            } else {
                sc.append("sh $D/pg.sh run ").append(mode).append(extra).append("; rc=$?\n");
            }
            sc.append("sh $D/pg.sh daemon-start\necho PG_RC=$rc\n");

            Method m = Shizuku.class.getDeclaredMethod("newProcess", String[].class, String[].class, String.class);
            m.setAccessible(true);
            Process p = (Process) m.invoke(null, new String[]{"sh"}, null, null);
            try (OutputStream os = p.getOutputStream()) { os.write(sc.toString().getBytes(StandardCharsets.UTF_8)); }
            out.append(readAll(p.getInputStream()));
            p.waitFor();
            int i = out.lastIndexOf("PG_RC=");
            if (i >= 0) rc = Integer.parseInt(out.substring(i + 6).trim().split("\\s")[0]);
        } catch (Throwable t) {
            out.append("\nERROR ").append(t);
        }
        String text = "# " + ts + " mode=" + mode + " reason=" + reason + " rc=" + rc + "\n" + out;
        writeLog(c, ts + "-" + mode + ".log", text);
        String summary = "";
        for (String l : out.toString().split("\n")) if (l.startsWith("SUMMARY") || l.startsWith("SKIP") || l.startsWith("restore:")) summary = l;
        status(c, reason, summary.isEmpty() ? "rc=" + rc : summary, rc);
        if (rc == 1) notifyOnce(c, "fail-" + ts, "permguard 本轮有失败项", "打开 PermGuard 看日志");
        return text;
    }

    static void status(Context c, String reason, String line, int rc) {
        prefs(c).edit().putLong("last_ts", System.currentTimeMillis()).putString("last_reason", reason)
                .putString("last_line", line).putInt("last_rc", rc).apply();
    }

    static String conf(Context c) throws Exception {
        File o = new File(c.getExternalFilesDir(null), "whitelist.conf");   // adb push 的覆盖文件优先
        if (o.isFile() && o.length() > 0) return readAll(new FileInputStream(o));
        return asset(c, "whitelist.conf");
    }
    static String confSource(Context c) {
        File o = new File(c.getExternalFilesDir(null), "whitelist.conf");
        return o.isFile() && o.length() > 0 ? o.getPath() : "内置（APK assets）";
    }
    static String asset(Context c, String name) throws Exception { return readAll(c.getAssets().open(name)); }

    static String readAll(InputStream in) throws Exception {
        try (InputStream i = in) {
            ByteArrayOutputStream bo = new ByteArrayOutputStream();
            byte[] b = new byte[16384];
            int k;
            while ((k = i.read(b)) > 0) bo.write(b, 0, k);
            return bo.toString("UTF-8");
        }
    }

    static File logDir(Context c) { File d = new File(c.getFilesDir(), "logs"); d.mkdirs(); return d; }

    static void writeLog(Context c, String name, String text) {
        File d = logDir(c);
        try (FileOutputStream f = new FileOutputStream(new File(d, name))) { f.write(text.getBytes(StandardCharsets.UTF_8)); } catch (Exception ignored) { }
        File[] fs = d.listFiles();   // 只留最近 60 份
        if (fs != null && fs.length > 60) {
            Arrays.sort(fs);
            for (int i = 0; i < fs.length - 60; i++) fs[i].delete();
        }
    }

    static String latestLog(Context c) {
        File[] fs = logDir(c).listFiles();
        if (fs == null || fs.length == 0) return "（还没有运行记录）";
        Arrays.sort(fs);
        try { return readAll(new FileInputStream(fs[fs.length - 1])); } catch (Exception e) { return e.toString(); }
    }

    /** 导出：私有日志合并成一个文件写进 下载/permguard/（MediaStore，不需要存储权限）。 */
    static String export(Context c) throws Exception {
        File[] fs = logDir(c).listFiles();
        if (fs == null || fs.length == 0) return "没有日志";
        Arrays.sort(fs);
        StringBuilder all = new StringBuilder();
        for (File f : fs) all.append(readAll(new FileInputStream(f))).append("\n\n");
        File wl = Watchdog.logFile(c);
        if (wl.isFile()) all.append("# 守门员 watchdog.log\n").append(readAll(new FileInputStream(wl)));
        String name = "permguard-logs-" + new SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(new Date()) + ".txt";
        ContentValues v = new ContentValues();
        v.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
        v.put(MediaStore.MediaColumns.MIME_TYPE, "text/plain");
        v.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/permguard");
        Uri u = c.getContentResolver().insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, v);
        try (OutputStream os = c.getContentResolver().openOutputStream(u)) { os.write(all.toString().getBytes(StandardCharsets.UTF_8)); }
        return "已导出 " + fs.length + " 份日志 → 下载/permguard/" + name;
    }

    static void ensureChannel(Context c) {
        c.getSystemService(NotificationManager.class).createNotificationChannel(
                new NotificationChannel(CH, "permguard 状态", NotificationManager.IMPORTANCE_DEFAULT));
    }

    /** 同一 key 每次开机只提醒一次。 */
    static void notifyOnce(Context c, String key, String title, String text) {
        int boot = Settings.Global.getInt(c.getContentResolver(), Settings.Global.BOOT_COUNT, 0);
        SharedPreferences sp = prefs(c);
        if (sp.getInt("n_" + key, -1) == boot) return;
        sp.edit().putInt("n_" + key, boot).apply();
        PendingIntent pi = PendingIntent.getActivity(c, 0, new Intent(c, MainActivity.class), PendingIntent.FLAG_IMMUTABLE);
        Notification n = new Notification.Builder(c, CH).setSmallIcon(android.R.drawable.ic_lock_lock)
                .setContentTitle(title).setContentText(text).setContentIntent(pi).setAutoCancel(true).build();
        c.getSystemService(NotificationManager.class).notify(key.hashCode(), n);
    }

    static void sleep(long ms) { try { Thread.sleep(ms); } catch (InterruptedException ignored) { } }
}
