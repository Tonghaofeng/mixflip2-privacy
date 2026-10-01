# 待办与「保留只断网」清单（每次会话开始先看，结束更新状态）

状态：🔴 待定 / 🟡 进行中 / ✅ 已关闭（写日期与证据）

## 体检 / 审计建议
| # | 项 | 来源 | 状态 |
|---|---|---|---|
| 1 | AdGuard 遗留用户 CA | 体检 10-01 §5 | ✅ 10-01 23:2x 设置「信任的凭据→用户」为空 |
| 2 | Clash `store-fake-ip` | 体检 §3 建议 a | ✅ 10-01 晚发布，用户已点更新；nc 探测 zzhc.vnet.cn / tydevice / rcpc 均命中 REJECT（新规则在跑） |
| 3 | 拒 `rcpc-sdk-access(-v6).m.qq.com` | 体检 §3 建议 b | ✅ 同上 |
| 4 | `com.xiaomi.registration` 运营商自注册（短信 10659401 + zzhc.vnet.cn/tydevice.com，读精确定位、MAC） | 体检 §4/建议 5 | 🟡 网络端点已拒；appops 改不动（SYSTEM_FIXED 权限会被同步回 allow）；**删包待定**：常驻进程 com.android.phone 绑着它的 RegistrationService，静态分析没找到绑定代码，无法证明删后开机不崩 → 需要带回滚预案的实测 |
| 5 | accept.py 的 `logcat -c` | 体检建议 13 | ✅ 10-01 晚改为 `logcat -T` |
| 6 | 安全补丁 / OTA 窗口（vendor 补丁 240+ 天） | 体检 §9/建议 8 | 🔴 update.miui.com 已放行，需要用户定一个查更新的窗口 |
| 7 | 系统身份可绕过 VPN 锁定（1000/1001/10134/10229…） | 体检 §3c | 🔴 无 root 无解；在家靠 Surge 兜底，走蜂窝时没有观测手段；对策 = 能删的风险包尽量删 |
| 8 | 谷歌侧：Wi-Fi 常扫描、Chrome 遥测（beacons.gvt2.com）；~~OFFLINE_FIND_SCAN~~ 实为**小米离线查找**（`dumpsys settings` 写入方 com.xiaomi.bluetooth，含断网/关机蓝牙信标广播） | feature_audit 10-01 | ✅ 10-01 晚用户同意：`wifi_scan_always_enabled=0`；小米离线查找：`OFFLINE_FIND_*` 是蓝牙插件云控每次开机重写的「支持位」（shell 改了重启即回 1，已实测），真正的开关是 `need_receive_offline_find_broadcast`（写入方 finddevice 已删）→ 置 0；蓝牙信标广播日志显示本就关着（`broadcast switch is closed`）；快连本地 BLE 扫描仍在跑（无用户开关、网络已封）；Chrome「帮助改进 Chrome 的功能和性能」界面关闭并读回。同页「改善搜索和浏览体验」（发送访问网址）、「改进搜索建议」仍开，待用户定 |
| 9 | 小米 BLE 扫描类开关（`is_fastconnect_scan_enable` 等） | feature_audit 10-01 | ✅ 10-01 结论：`is_fastconnect_scan_enable` 是快连服务自写的状态位，不是开关；快连无用户开关可关，网络已封 |
| 10 | Google 定位准确性（`network_location_opt_in`，GMS 被动旁听定位 + 上传 Wi-Fi/基站扫描） | 后台排查 10-02 | ✅ 10-02 00:0x 经 GMS 设置页关闭，partner 表读回 `value=0`；已入开机体检（shell 不能写，需 WRITE_GSETTINGS） |
| 11 | 公开可读设置里的标识符残留（小米广告 ID、小米账号 ID、骚扰拦截同步令牌） | 后台排查 10-02 | ✅ 4 个键已删（写入方 analytics / micloudsync 均已删，不会再生）；原值在 raw_private（不入库） |
| 12 | 谷歌后台遥测端点（doubleclick、Firebase 分析/崩溃、footprints、Chrome 信标…） | 后台排查 10-02 | 🟡 已写入策略并发布；**10-02 00:05 探测手机端未更新**（仍命中 Match）→ 需在 Clash 点「更新」后再探测 |
| 13 | 谷歌备份：短信 / 彩信 / 通话记录上传云端（Backup Manager 开、传输 GMS） | 后台排查 10-02 | 🔴 用户决定：整体关（`bmgr enable false`，丢换机恢复）或保留 |
| 14 | 相机 / htmlviewer 自带推送进程后台反复尝试连接 | 后台排查 10-02 | 🔴 被拒；相机可做后台限制，htmlviewer 不动（SystemUI 开机必需） |
| 15 | 配对蓝牙设备 MAC 明文在 `global miui_bonded_device_account_key`（任何 App 可读） | 后台排查 10-02 | 🔴 写入方 com.android.bluetooth 在用，删了配对时写回；无根治 |

## 保留但只断网的包（每个都要写特权与理由；能删就删）
| 包 | 敏感/特权能力（feature_audit） | 为什么还留着 | 复审 |
|---|---|---|---|
| com.miui.securitycenter (1000) | 系统身份全套；任务 5 个 | 权限管理/应用管理宿主，删不掉 | 引擎 guardprovider 已删 |
| com.miui.packageinstaller | INSTALL/DELETE_PACKAGES、使用情况 | 唯一的系统安装器 | 连 tracking.miui.com 已被拒 |
| com.lbe.security.miui | 后台读剪贴板、使用情况、写安全设置 | 权限管理后端 | — |
| com.qualcomm.location (10229) | 收短信、读手机状态；可绕过锁定 | GNSS / XTRA | 本机无 izat.conf；网络待观测 |
| com.miui.home / fliphome | 相机、联系人、读帧缓冲 | 桌面 | — |
| com.android.soundrecorder / com.miui.screenrecorder | 截获通话音频/视频 | 用户在用（待定） | 用户决定 |
| com.android.updater (6102) | — | OTA（update.miui.com 放行） | 见 #6 |
