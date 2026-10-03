package uk.tonytong.permguard;

import android.app.Application;

import rikka.shizuku.Shizuku;

public class App extends Application {
    @Override
    public void onCreate() {
        super.onCreate();
        Runner.ensureChannel(this);
        Watchdog.schedulePeriodic(this);
        Watchdog.watchWifi(this);
        try { GuardJob.schedulePeriodic(this); } catch (RuntimeException ignored) { }   // 守门员会在未解锁时起本进程
        // Shizuku 服务端（重启后自动或手动启动）把 binder 交过来时立刻跑一轮；sticky = 已有 binder 也回调一次
        Shizuku.addBinderReceivedListenerSticky(() -> {
            Watchdog.onShizukuUp(this);
            GuardJob.kick(this, "shizuku");
        });
        // 服务端没了（被杀 / 崩溃 / 手动停止）→ 守门员把它拉起来（Shizuku 自己重启的话它等 5 秒 binder 就会收手）
        Shizuku.addBinderDeadListener(() -> Watchdog.kick(this, "binder-dead", 0));
    }
}
