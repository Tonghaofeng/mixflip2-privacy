package uk.tonytong.permguard;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/** 开机 / 本 App 更新后：补登记定时任务并排一轮（等 Shizuku 就绪，见 GuardJob）。 */
public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context c, Intent i) {
        String a = i.getAction();
        GuardJob.kick(c, Intent.ACTION_BOOT_COMPLETED.equals(a) ? "boot" : "updated");
    }
}
