package uk.tonytong.permguard;

import android.app.Application;

import rikka.shizuku.Shizuku;

public class App extends Application {
    @Override
    public void onCreate() {
        super.onCreate();
        Runner.ensureChannel(this);
        GuardJob.schedulePeriodic(this);
        // Shizuku 服务端（重启后自动或手动启动）把 binder 交过来时立刻跑一轮；sticky = 已有 binder 也回调一次
        Shizuku.addBinderReceivedListenerSticky(() -> GuardJob.kick(this, "shizuku"));
    }
}
