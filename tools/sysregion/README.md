# sysregion —— 用 adb 改「系统地区」与时区（不 root、不点界面）

2026-10-01：地区 中国 → 新加坡，时区 Asia/Shanghai → Asia/Singapore。

## 用法

```bash
./set_region.sh                     # 查看当前
./set_region.sh SG Asia/Singapore   # 地区→新加坡 + 时区→新加坡（关自动时区）
./set_region.sh --revert            # 回到 zh-CN + Asia/Shanghai + 自动时区
./build.sh                          # 改了 SysLocale.java 后重新生成 syslocale.dex
```

## 原理（反编译 Settings.apk 得出）

HyperOS 3 国行的「设置 → 语言与地区 → 地区」是 Android 16 的 AOSP 地区选择器
（`regionalpreferences/RegionDialogFragment.updateRegion()`），选中后只做一件事：

```
LocalePicker.updateLocales(把同语言同文字的 locale 地区换掉)   // zh-CN → zh-Hans-SG
  → IActivityManager.updatePersistentConfigurationWithAttribution()
  → system_server 写 persist.sys.locale 与 Settings.System.system_locales（重启后仍生效）
```

这个接口要 `CHANGE_CONFIGURATION` + `WRITE_SETTINGS`，**shell（uid 2000）两者都已授予**，所以
`SysLocale.java` 经 `app_process` 以 shell 身份直接调用，效果与在设置里点选完全相同（全部走反射，编译不依赖 android.jar）。

时区：`cmd time_zone_detector set_auto_detection_enabled false` + `cmd alarm set-timezone Asia/Singapore`
（`suggest_manual_time_zone` 需 `SUGGEST_MANUAL_TIME_AND_ZONE`，shell 没有）。新加坡与上海同为 UTC+8、无夏令时，时钟零变化；
但**自动时区必须关**，否则运营商网络（MCC 460）会把它改回上海——代价是出国旅行时时区不会自动切换（`--revert` 或手动改）。
网络校时 `auto_time` 保持开启。

## 各层「归属地」现状

| 层 | 值 | 能否改 |
|---|---|---|
| 系统 locale（App 读 `Locale.getDefault().getCountry()`） | **SG**（zh-Hans-SG，界面仍简体中文） | ✅ 已改 |
| 时区（App 读 `TimeZone.getDefault()`） | **Asia/Singapore** | ✅ 已改 |
| MIUI 地区 `ro.miui.region` / `ro.miui.build.region` / `ro.product.locale` / `ro.boot.ptcountrycode` | CN | ❌ 只读编译属性。`miui.os.Build.getRegion()` 只读 `ro.miui.region`，这版 ROM 没有 `persist.sys.country` 这一层；要改只能解 BL + root 或刷国际版 |
| SIM / 网络国家（`TelephonyManager.getSim/NetworkCountryIso`） | cn（中国电信卡、MCC 460） | ❌ 物理事实，换新加坡卡才会变 |
| 出口 IP | 取决于家里 Surge 的代理节点 | 在 Surge 策略里定 |
| 小米账号地区 | 中国（+86 注册） | ❌ 注册时固定；账号已断网 |
| Google Play 国家 | 跟 Google 账号付款资料 + IP | 在 Google 账号侧改（一年一次） |

MIUI 框架里受 `ro.miui.region==CN` 控制的逻辑（如 `ArtMetricsReportImpl` 把 App 冷启动指标交给本机性能服务）不会因本次改动而关闭。
