package uk.tonytong.permguard;

import android.app.Activity;
import android.app.AlertDialog;
import android.graphics.Typeface;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

import rikka.shizuku.Shizuku;

/** 只做状态与手动操作；定时执行不依赖这个界面。 */
public class MainActivity extends Activity {
    TextView status, log;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(32, 96, 32, 32);
        status = new TextView(this);
        status.setTextSize(14);
        root.addView(status);
        LinearLayout row1 = new LinearLayout(this), row2 = new LinearLayout(this);
        root.addView(row1);
        root.addView(row2);
        btn(row1, "授权 Shizuku", v -> {
            if (Runner.shizukuReady()) Shizuku.requestPermission(1);   // binder 不在时调用会抛异常
            refresh();
        });
        btn(row1, "预览", v -> bg("plan", 0));
        btn(row1, "立即收回", v -> bg("apply", 0));
        btn(row2, "体检", v -> bg("verify", 0));
        btn(row2, "回滚", v -> new AlertDialog.Builder(this).setTitle("回滚到最近一次 apply 前的快照？")
                .setMessage("权限授予状态、权限标志、appop 模式都会改回快照时的值。守护循环 6 小时后还会再收，要长期保留请改白名单。")
                .setPositiveButton("回滚", (d, w) -> bg("restore", 0)).setNegativeButton("取消", null).show());
        btn(row2, "导出日志", v -> new Thread(() -> {
            String r;
            try { r = Runner.export(this); } catch (Exception e) { r = e.toString(); }
            String fr = r;
            runOnUiThread(() -> log.setText(fr + "\n\n" + log.getText()));
        }).start());
        ScrollView sv = new ScrollView(this);
        log = new TextView(this);
        log.setTypeface(Typeface.MONOSPACE);
        log.setTextSize(10);
        log.setTextIsSelectable(true);
        sv.addView(log);
        root.addView(sv, new LinearLayout.LayoutParams(-1, 0, 1));
        setContentView(root);
        Shizuku.addRequestPermissionResultListener((code, res) -> refresh());
    }

    void btn(LinearLayout row, String text, View.OnClickListener l) {
        Button b = new Button(this);
        b.setText(text);
        b.setAllCaps(false);
        b.setOnClickListener(l);
        row.addView(b, new LinearLayout.LayoutParams(0, -2, 1));
    }

    void bg(String mode, long minAge) {
        if (!Runner.shizukuReady() || !Runner.shizukuGranted()) { refresh(); return; }
        log.setText("运行中：" + mode + " …");
        new Thread(() -> {
            String out = Runner.run(this, mode, "manual", minAge);
            runOnUiThread(() -> { log.setText(out); refresh(); });
        }).start();
    }

    @Override
    protected void onResume() {
        super.onResume();
        refresh();
        log.setText(Runner.latestLog(this));
    }

    void refresh() {
        android.content.SharedPreferences p = Runner.prefs(this);
        long ts = p.getLong("last_ts", 0);
        status.setText("Shizuku：" + (Runner.shizukuReady() ? "运行中" : "未运行（打开 Shizuku → 启动）")
                + "　授权：" + (Runner.shizukuGranted() ? "已授权" : "未授权")
                + "\n上次：" + (ts == 0 ? "从未" : new SimpleDateFormat("MM-dd HH:mm", Locale.US).format(new Date(ts)) + "（" + p.getString("last_reason", "") + "）")
                + "\n" + p.getString("last_line", "")
                + "\n白名单：" + Runner.confSource(this)
                + "\n定时：每 6 小时 + 开机 + Shizuku 就绪；守护循环每 5 分钟查新装 App");
    }
}
