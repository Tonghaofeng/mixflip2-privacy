package uk.tonytong.permguard;

import java.io.File;
import java.lang.reflect.Method;

/**
 * 以 shell 身份（app_process）持有 PARTIAL_WAKE_LOCK，让手机睡眠时 CPU 不挂起。
 * 用途：rs.sh 远程通道掉线后要立刻重连，但折叠合盖久了 CPU 深睡，shell 里的 sleep 也跟着停（10-06 实测：
 * 00:15 掉线，下一次重连尝试到 01:28 才轮到）。掉线时持锁、连上就放，只在掉线期间耗电。
 * shell（uid 2000 < 10000）的唤醒锁在 Doze 下不会被系统禁用（只禁用非白名单的应用 uid）。
 * 用法：app_process -cp wakehold.dex /system/bin uk.tonytong.permguard.WakeHold <最长秒数> [标志文件]
 *       到时或标志文件被删即释放退出；进程被杀时系统经 binder 死亡通知自动回收。
 * 只用反射调隐藏接口 IPowerManager.acquireWakeLock，不依赖 android.jar；参数按类型填，兼容各版本签名。
 */
public class WakeHold {
    public static void main(String[] a) throws Exception {
        long secs = a.length > 0 ? Long.parseLong(a[0]) : 900;
        File flag = a.length > 1 ? new File(a[1]) : null;
        Class<?> ibinder = Class.forName("android.os.IBinder");
        Object b = Class.forName("android.os.ServiceManager").getMethod("getService", String.class).invoke(null, "power");
        Object pm = Class.forName("android.os.IPowerManager$Stub").getMethod("asInterface", ibinder).invoke(null, b);
        Object token = Class.forName("android.os.Binder").getConstructor().newInstance();
        Method acq = null, rel = null;
        for (Method m : pm.getClass().getMethods()) {
            if (m.getName().equals("acquireWakeLock")) acq = m;
            if (m.getName().equals("releaseWakeLock")) rel = m;
        }
        Class<?>[] pt = acq.getParameterTypes();
        Object[] args = new Object[pt.length];
        int ints = 0, strs = 0;
        for (int i = 0; i < pt.length; i++) {
            if (pt[i].isAssignableFrom(token.getClass())) args[i] = token;
            else if (pt[i] == int.class) args[i] = ints++ == 0 ? 1 /* PARTIAL_WAKE_LOCK */ : -1 /* INVALID_DISPLAY */;
            else if (pt[i] == String.class) args[i] = new String[]{"aios:rsh-reconnect", "com.android.shell", null}[Math.min(strs++, 2)];
            else if (pt[i] == long.class) args[i] = 0L;
            else if (pt[i] == boolean.class) args[i] = false;
            else args[i] = null;
        }
        acq.invoke(pm, args);
        final Object fpm = pm, ftok = token; final Method frel = rel;
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            try { frel.invoke(fpm, ftok, 0); } catch (Exception ignored) { }
        }));
        System.out.println("held " + secs + "s");
        long end = System.currentTimeMillis() + secs * 1000;
        while (System.currentTimeMillis() < end && (flag == null || flag.exists())) Thread.sleep(2000);
        rel.invoke(pm, token, 0);
        System.out.println("released");
    }
}
