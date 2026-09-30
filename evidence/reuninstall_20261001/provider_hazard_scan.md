# 已删包 ContentProvider 隐患静态排查（2026-10-01 07:30–07:50，只读）

**问题**：htmlviewer 事故的机理是常驻进程对已删包的 provider `registerContentObserver`，Android 16 找不到 authority 直接抛 `SecurityException`。其余已删包提供的 534 个 authority 里，还有没有同类地雷？

**范围**：反编译 SystemUI 及其插件 `miui.systemui.plugin`（控制中心，跑在 SystemUI 进程）、fliphome、home、phone、HyperComm、TouchService、Telecom（system_server 内）、InCallUI、AOD；`services.jar`、`miui-services.jar`、`framework.jar`、`miui-framework.jar`、`com.miui.system` SDK、micloud SDK、telephony/Xiaomi 框架 boot jar。对 534 个 authority 查字面量与拼接 URI、资源表，逐个核对 observer 注册、`notifyChange`、`call`、`insert`、`update`、`delete`、`acquire*` 调用点。

## 结论
**除 htmlviewer 外，没有常驻/开机关键进程会因已删 provider 崩溃；无需再 install-existing 任何包。**
htmlviewer 必须永久保留：除崩溃的 `com.miui.systemui.CloudDataManager` 外，至少还有 4 处常驻进程对 `CloudSettings` 做无保护的 observer 注册（含 `com.android.phone` 的 `MiStatInterfaceUtil`、`miui.systemui.plugin` 的 `CloudDataManager`）。

两个机理细节：
- `notifyChange` 与 `registerContentObserver` 一样会抛（`ContentService` 同一检查）。
- system_server 不受此检查：它的 ContentResolver 在设 SDK 级别前创建，按 targetSdk 0 处理 → 每次开机它都对已删的 `com.android.mms.prefprovider` 注册观察者而不崩；但 `call()`、`insert()`、`update()` 对缺失 provider 仍会抛。

## 残余低风险调用点
| authority | 已删包 | 调用方 | 进程（常驻?） | try/catch | 触发条件 | 风险 |
|---|---|---|---|---|---|---|
| `com.xiaomi.aiasst.service.aicall.provider` | com.xiaomi.aiasst.service | Telecom `MiuiMissedCallNotifierImpl.reloadAiAnswerCallerInfo`（call） | system_server（是） | 否 | 开机重建未接来电通知，且通话记录里有「AI 代接」行（只有已删的 AI 通话助手会写） | 低：09-30 以来每次开机都走过 |
| `com.miui.micloud` | com.miui.cloudservice | `RestrictionsManagerService`（update） | system_server（是） | 否 | 设备管理应用在登录小米账号时关闭云备份；异常返回给该应用 | 低 |
| `com.xiaomi.dist.provider.app_meta` | com.milink.service | home `AppMetaProvider.queryProvider`（call，经 future） | home（否） | 部分 | 跨设备接力，需要 milink/mirror（均已删） | 低 |
| `com.xiaomi.Joyose.provider` | com.xiaomi.joyose | 安全中心游戏加速「游戏筛选」update | securitycenter 界面（否） | 否 | 在游戏加速里改游戏筛选；最多崩该页面 | 低–中 |
| `com.xiaomi.cloud.cloudidprovider` | com.xiaomi.finddevice | `CloudTelephonyManager`（设置/安全中心/AOD 内置） | 非常驻 | 否 | 广告 ID 为空时取小米云设备 ID，需小米账号在同步（账号已卸载） | 低 |

**已核实安全**（有 try/catch、判空或先查包是否安装）：控制中心设备中心 `com.milink.service.device`、AI 字幕/语音磁贴 `com.xiaomi.aiasst.vision`、灵动岛分享到 personalassistant；SystemUI 的 bugreport `CTAProvider`；各应用内置的统计 SDK；主题/小部件引擎（锁屏主题、外屏小部件，捕获 SecurityException）；home/fliphome 对 `com.xiaomi.mirror.callprovider`、`com.android.quicksearchbox.xiaomi` 的观察者与对 circulate、securityadd.superpwer、personalassistant 的调用；phone 的镜像通话中继观察者、`com.xiaomi.lyra`、aicall 客户端；InCallUI（先查 `com.xiaomi.mirror` 是否安装、aicall 判空、黄页查询安全）；system_server 对 voicetrigger/aicr/thirdappassistant 的调用均有保护。

## dropbox 对照（可追溯到 09-28）
- 09-30 19:13 `com.miui.passwords`：窗口权限错误，非缺 provider；09-30 21:16 `com.qti.qcc`：包移除广播里的只读数据库错误。
- 10-01：SystemUI 崩溃全部是 `com.android.settings.cloud.CloudSettings`（dropbox 18 条；crash 缓冲另有 07:25:57–07:26:38 共 47 条），07:26:39 装回 htmlviewer 后停止。
- 无 `data_app_crash`、无 `system_server_crash`。之后 logcat 只有被捕获的 「Unknown authority」（personalassistant.widget.external、tsmclient.provider.feature、aicr.OpenCapabilityProvider）与返回空的普通查询。

## 未覆盖
WallpaperOS3（锁屏壁纸）、`com.android.contacts`（拨号/通话记录）、`apprecovery.proinstaller.jar`、高通/IMS boot jar 未反编译；设置与安全中心只做了启发式扫描；运行时下发的 URI（主题/云配置）与反射调用无法静态追踪。
