# 设置菜单瘦身（2026-10-01）

目标：设置里「有外传风险、且已经关掉/删掉」的 HyperOS 专属入口不再显示；对标谷歌原版（AOSP android16 `packages/apps/Settings/res/xml` + Pixel），原版也有的类别保留。

方法：反编译 `/system_ext/priv-app/Settings/Settings.apk`（jadx），逐个追每个条目的显示条件（`MiuiSettings.updateHeaderList`、各 Controller 的 `getAvailabilityStatus`），再判断无 root 能否翻转。审计只读完成后才执行；没有逐页点界面。

## 结论：能用的手段只有三种

| 排序 | 手段 | 覆盖面 | shell 能否驱动 |
|---|---|---|---|
| 1 | 更多设置 → **应用扩展功能**（`ExtensionFunctionFragment`，存 Settings 私有 SharedPreferences `ex_func`） | 14 类入口：问题反馈/卡包/企业模式/儿童空间/CarWith/备份与恢复/设备激活信息/安全守护/安全-查找设备/米币中心/小米云服务/游戏加速/小米澎湃AI/健康使用手机；搜索结果和安全中心页面同步生效 | 否（uid 1000 私有文件）。只能点界面，`tools/ex_func_off.py` 直达页面 + 读回状态 |
| 2 | 删包 `pm uninstall --user 0` | 只对「查包/查 intent 是否存在」的条目有效 | 是 |
| 3 | 个别 Settings 键 | 很少，多数已处于隐藏态 | 是 |

走不通的（已核实）：
- 云控：`content://com.android.settings.cloud.CloudSettings` 需要 signature|privileged 权限。
- 企业隐藏名单 `getSettingsMenuHideList`：需要 `persist.sys.ent_activated`，shell 写不了。
- cust 定制：`/mi_ext/product/etc/cust_features` 在只读 erofs 上。
- device_config / FeatureFlags：不管这些小米条目。
- device owner：设备上已有账号，设不了。
- 首页没有「intent 解析不到就隐藏」的通用逻辑，只有少数几个 header 自己检查。

## 本次执行

| 时间 | 操作 | 原值 → 新值 | 效果 |
|---|---|---|---|
| 07:18 | `settings put secure quick_control_all_devices 0` | 1 → 0 | 关掉「实时发现周围设备」持续扫描（融合设备中心 milink 已删，原本是个死入口却还在扫） |
| 07:18 | `settings put secure smart_device_control 0` | null → 0 | 智能设备控制设为「无」，上面那一行随之隐藏（`NotificationStatusBarSettings.java:539`） |
| 07:19 | `pm uninstall --user 0 com.xiaomi.account` | installed → 未安装 | 用户要求删除小米账号。系统同步清掉 `com.xiaomi` 账号；这个包持有 RECEIVE_SMS，每次打开账号页都会上传 userId/OAID/机型/token |
| — | 应用扩展功能 | 页面当前只出现 5 项，全部**早已关闭** | 企业模式、备份与恢复、安全守护、安全-查找设备、健康使用手机。其余 9 项因为包已删，勾选框本身就不出现；小米澎湃AI 已被 `ex_func_xiao_ai=false` 锁住 |

小米账号的副作用：首页顶部「峰」变成「**登录小米账号**」。这个 header 只在国际版或 `global maintenance_mode_user_id=110` 时隐藏（`MiuiSettings.java:771`）。后者会**禁止修改锁屏密码**（`MiuiSecurityChooseUnlock.java:329`），所以不用；这一行只能留着，点了也打不开。
激活锁在小米服务器侧，删包不解绑。卖机或解绑前先 `cmd package install-existing com.xiaomi.account`，再登录、退出。

## 删包之后已自动隐藏（无需操作）

- 智能密码管理、传送门/复制直达、钱包与支付/卡包、网络通话助手、游戏加速/视频工具箱等、AI 字幕/圈定即搜
- 小米云服务、保修期/本机权益/售后/以旧换新/换机记录/参数解读
- 互联/妙享、融合 NFC/无线副屏/算力共享/连接至 Windows、CarWith
- 锁屏画报、通知列表总结（AI）、在线字体、小爱同学音量
- 小爱同学 / AI 服务 / 小米澎湃AI 首页入口、系统安全组（由安全中心接管）

## 隐藏不了的（N）及原因

| 条目 | 位置 | 原因 | 现状 |
|---|---|---|---|
| 加入用户体验改进计划 / 使用情况和诊断数据 | 隐私与安全 → 更多安全设置 | Controller 恒 true | 已关（upload_log_pref=0 / upload_debug_log_pref=0） |
| 广告服务 | 同上 | 包不在时照样返回 true（`AdPreferenceController.java:26-43`） | 已关，systemAdSolution 已删 |
| 登录小米账号 | 首页 | 见上 | 死入口 |
| 系统更新卡片 | 我的设备 | 写死；**每次打开「我的设备」都会调起 updater 检查更新**（`MiuiMyDeviceSettings.java:605`） | 小米域名已被 Clash 拦截；updater 删不删仍待用户决定 |
| 小米换机 | 我的设备 | 需要 MDM 限制才能隐藏 | 死链（huanji 从未安装） |
| 应用升级提醒 / 资源推荐 | 应用设置（安全中心） | 无条件 / ro 属性 | 已关，商店已删 |
| SIM 卡保护 / 骚扰拦截 / 电诈防护 / 地震与灾害预警 | 隐私与安全（安全中心） | 通话能力、ro 属性或无条件 | 推送 xmsf 已删 |
| 实时字幕（小米闻声） | 辅助功能 | 国内版手机恒显示 | 点击是死链（aiasst.vision 已删） |
| 来电秀 | 声音与触感 | 要删 thememanager 或 incallui | thememanager 待定，incallui 禁删 |
| 隐私与安全 / 省电与电池 / 应用设置 / 系统个性化 / 桌面 | 首页 | 分别属于 securitycenter / thememanager / miui.home | 这些包禁删 |

## 待定 / 未核实

- 未动（含义未核实，可能是 LE Audio 广播或小米离线查找）：`global enable_ble_broadcast=1`、`global need_receive_offline_find_broadcast=1`、`secure interconnection_service=1`、`secure mishare_auto_start_scan=1`、`global flip_continuity_default=1`
- `three_gesture_up=launch_ai_memory`：三指上滑仍指向已删的 AI 应用，要在 securitycore 里改
- `minors_mode=1` / `provision_minor_mode_flag=1`：只是国内版「支持未成年人模式」的标记；真正的开关 `minors_mode_enabled` 未设置，等于 0

## 注意

- **别清「设置」APP 的数据**：`ex_func` 会复位，小米澎湃AI 等入口会回来。复位后 `ex_func_xiao_ai` 的勾选框只在装了 voiceassist 时才出现，要先临时 `install-existing` 装回来，关掉后再删。
- **卸载后至少等 3 分钟再重启，或用 `adb shell svc power reboot`**：PMS 延迟写 `package-restrictions.xml`，`adb reboot` 不走 framework 关机刷盘。10-01 00:23/00:25 两批就是这样在重启后「复活」的（firstInstallTime 仍是 1970，不是被重装）。
- 回滚：`debloat/settings_hide_restore.sh`
