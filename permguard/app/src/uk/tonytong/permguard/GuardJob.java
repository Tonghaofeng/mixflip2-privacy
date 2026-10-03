package uk.tonytong.permguard;

import android.app.job.JobInfo;
import android.app.job.JobParameters;
import android.app.job.JobScheduler;
import android.app.job.JobService;
import android.content.ComponentName;
import android.content.Context;
import android.os.PersistableBundle;

/**
 * JobScheduler：周期任务（6 小时，持久化跨重启）+ 一次性任务（开机 / Shizuku 就绪 / 守门员拉起 Shizuku 后 / 手动）。
 * 一次性任务等不到 Shizuku 就叫守门员（Watchdog）并按指数退避重试（1 分钟起）。
 */
public class GuardJob extends JobService {
    static final int PERIODIC_ID = 1, ONESHOT_ID = 2;
    static final long PERIOD = 6 * 3600_000L, FLEX = 3600_000L;

    static void schedulePeriodic(Context c) {
        JobScheduler js = c.getSystemService(JobScheduler.class);
        if (js.getPendingJob(PERIODIC_ID) != null) return;
        js.schedule(new JobInfo.Builder(PERIODIC_ID, new ComponentName(c, GuardJob.class))
                .setPeriodic(PERIOD, FLEX)
                .setPersisted(true)
                .build());
    }

    static void kick(Context c, String reason) { kick(c, reason, 0); }

    static void kick(Context c, String reason, long delayMs) {
        schedulePeriodic(c);
        PersistableBundle b = new PersistableBundle();
        b.putString("reason", reason);
        c.getSystemService(JobScheduler.class).schedule(new JobInfo.Builder(ONESHOT_ID, new ComponentName(c, GuardJob.class))
                .setExtras(b)
                .setMinimumLatency(delayMs)
                .setOverrideDeadline(delayMs + 3000)
                .setBackoffCriteria(60_000, JobInfo.BACKOFF_POLICY_EXPONENTIAL)
                .build());
    }

    @Override
    public boolean onStartJob(JobParameters p) {
        String reason = p.getJobId() == PERIODIC_ID ? "periodic" : p.getExtras().getString("reason", "oneshot");
        new Thread(() -> {
            boolean retry = Runner.fromJob(this, reason, p.getJobId() == ONESHOT_ID);
            jobFinished(p, retry);
        }, "permguard-job").start();
        return true;
    }

    @Override
    public boolean onStopJob(JobParameters p) {
        return true;
    }
}
