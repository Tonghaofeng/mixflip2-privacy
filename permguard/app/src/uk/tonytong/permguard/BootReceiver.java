package uk.tonytong.permguard;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;

/**
 * 开机 / 本 App 更新：守门员先确保 Shizuku 在跑（LOCKED_BOOT_COMPLETED 起就开始，不等解锁），
 * 再补登记定时任务并排一轮（GuardJob 要解锁后才跑，所以等 BOOT_COMPLETED）。
 */
public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context c, Intent i) {
        String a = String.valueOf(i.getAction());
        boolean boot = a.endsWith("BOOT_COMPLETED");
        Watchdog.kick(c, boot ? "boot" : "updated", 0);
        if (!Intent.ACTION_LOCKED_BOOT_COMPLETED.equals(a)) GuardJob.kick(c, boot ? "boot" : "updated");
    }
}
