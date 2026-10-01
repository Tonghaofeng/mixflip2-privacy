# 后台隐私与遥测排查（2026-10-01 夜 → 10-02）

用户纠偏：「我们主要是处理隐私问题，特别是背后的那种隐私问题和遥测」。本轮只看**后台实际行为**，不看界面入口：开机后的全量外联（含被拒的）、遥测 SDK 落在哪些进程、所有 App 可读的设置里留下的标识符、谷歌后台采集。

## 1. 开机后谁在往外连（`evidence/background_20261002/boot_connections.txt`）
23:48:43 重启，约 10 分钟内的 CMFA 连接日志按「进程 → 目标 → 动作」聚合。**被拒 ≠ 无害**：被拒说明那段上报代码还活着。

| 身份（CMFA 所报） | 目标（全部 REJECT） | 次数 | 性质 |
|---|---|---|---|
| com.android.camera | mcc.inf.miui.com | 34 | 相机云控/统计，最频繁 |
| UID 1000（CMFA 统一报作 systemui） | tracking.miui.com、api.sec / adv.sec.miui.com、cn.register.xmpush.xiaomi.com、ccc.sys.miui.com | 22 | OneTrack、安全中心云、推送注册、云控 |
| android.media（下载服务，UID 10092） | etl-xlmc-ssl.sandai.net（迅雷）、sdkconfig.ad.xiaomi.com（广告 SDK）、tracking.miui.com、api.tw06.xlmc.sec.miui.com | 15 | 下载服务内嵌迅雷 + 广告 SDK |
| com.lbe.security.miui | auth-engine / api.sec.miui.com | 4 | 权限管理云 |
| android.uid.bluetooth | cdn.cnbj1.fds.api.mi-img.com | 2 | 蓝牙插件/配置下载 |

当时**放行**里的谷歌遥测：GMS → `googleads.g.doubleclick.net`、`footprints-pa.googleapis.com`、`play.googleapis.com`（Clearcut 日志，与 Play 下载同域）。

注意：UID 1000 和 10092 属于可绕过 VPN 锁定的身份（体检 §3c），「被拒」只覆盖普通 socket。

## 2. 遥测 SDK 落在哪些进程（`telemetry_sdk_processes.txt`）
按日志反查 pid：
- **小米推送 SDK（xmpush）**：`com.miui.securitycenter.remote`（UID 1000）、`com.android.htmlviewer:pushservice`、`com.android.camera:pushservice`。中央推送 xmsf 已删，这些 App 自带的推送进程各自尝试连接。
- **OneTrack**：`system_server`、`securitycenter.remote`、`com.android.bluetooth`。system_server 反复报 `Unable to start service com.miui.analytics/.onetrack.TrackService: not found`：**系统层埋点的总收集器早已删除，交不出去**。各 App 里的 SDK 模式 OneTrack 直连 tracking.miui.com，被域名规则拒。

## 3. 所有 App 可读的设置里残留的标识符
`global`、`system` 表任何 App 无需权限即可按键名读取。用 `dumpsys settings` 的 `pkg:` 字段查写入方，**写入方已删除的就删值**（原值存于 `raw_private/identifier_leftovers_20261001.txt`，不入库）。

| 键 | 内容 | 写入方 | 处理 |
|---|---|---|---|
| `global ad_aaid` | 小米广告 ID（`MiuiSettings.Ad.getAaid()` 原样返回，无则 null） | com.miui.analytics（已删） | **已删** |
| `secure last_synced_account` | 小米账号 ID | com.miui.micloudsync（已删） | **已删** |
| `secure antispam_sync_token` / `antispam_water_mark` | 骚扰拦截与账号绑定的同步令牌 | 同上 | **已删** |
| `global miui_bonded_device_account_key` | 配对过的蓝牙设备 MAC 明文 | com.android.bluetooth（在用） | 未删：配对时会写回，见 OPEN_ITEMS |
| `secure pay_session_id` / `tokenization_session_id` | 谷歌钱包会话 | GMS | 功能性，保留 |

## 4. 谷歌后台采集
- **Google 定位准确性一直开着**：`content://com.google.settings/partner` 里 `network_location_opt_in=1`。GMS 在被动定位源上挂着两个 `hiddenFromAppOps` 的监听（fused / network），能旁听全机每一次定位且不留使用记录，开启时会把 Wi-Fi/基站扫描连同位置传给谷歌。shell 写 partner 表被拒（需要 `WRITE_GSETTINGS`），只能经 GMS 设置页（`am start -a com.google.android.gms.location.settings.LOCATION_ACCURACY`）关闭 → **已关，provider 读回 `value=0`**，已纳入开机体检。
- **备份**：Backup Manager 开启，传输为 GMS；partner 表中 `backup_enabled:com.android.providers.telephony=1`、`mms_backup_enabled=1`、`backup_enabled:com.android.calllogbackup=1` → 短信、彩信、通话记录在备份到谷歌云端。关掉会丢掉换机恢复能力 → **待用户决定**（整体关：`adb shell bmgr enable false`）。
- **谷歌遥测端点**：`gen_clash_config.py` 新增 `GOOGLE_TELEMETRY`（doubleclick、googlesyndication、googleadservices、adservice.google.com、app-measurement、google-analytics、firebaselogging-pa、crashlyticsreports-pa、firebase-settings.crashlytics、footprints-pa、gvt2.com、gvt3.com）。不拦 `play.googleapis.com`（Play 下载同域）、checkin、mtalk（推送）。mihomo -t 通过、已发布；10-02 00:05 探测**手机端尚未更新**（doubleclick 等仍命中 Match），需在 Clash 点「更新」。

## 5. 仍在的后台残余
- 相机、htmlviewer 自带推送进程反复尝试连接（被拒）。htmlviewer 是 SystemUI 开机必需，不动；相机可考虑后台限制。
- 小米快连每分钟一次本地 BLE 扫描（无用户开关），扫描结果的位置记录已被 `need_receive_offline_find_broadcast=0` 挡住。
