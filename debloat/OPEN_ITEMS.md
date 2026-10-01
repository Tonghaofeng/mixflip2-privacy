# 待办与「保留只断网」清单（每次会话开始先看，结束更新状态）

状态：🔴 待定 / 🟡 进行中 / ✅ 已关闭（写日期与证据）

## 体检 / 审计建议
| # | 项 | 来源 | 状态 |
|---|---|---|---|
| 1 | AdGuard 遗留用户 CA | 体检 10-01 §5 | ✅ 10-01 23:2x 设置「信任的凭据→用户」为空 |
| 2 | Clash `store-fake-ip` | 体检 §3 建议 a | ✅ 10-01 晚已写入并发布；**手机端需点「更新」** |
| 3 | 拒 `rcpc-sdk-access(-v6).m.qq.com` | 体检 §3 建议 b | ✅ 同上 |
| 4 | `com.xiaomi.registration` 运营商自注册（短信 10659401 + zzhc.vnet.cn/tydevice.com，读精确定位、MAC） | 体检 §4/建议 5 | 🟡 网络端点已拒；appops 改不动（SYSTEM_FIXED 权限会被同步回 allow）；**删包待定**：常驻进程 com.android.phone 绑着它的 RegistrationService，静态分析没找到绑定代码，无法证明删后开机不崩 → 需要带回滚预案的实测 |
| 5 | accept.py 的 `logcat -c` | 体检建议 13 | ✅ 10-01 晚改为 `logcat -T` |
| 6 | 安全补丁 / OTA 窗口（vendor 补丁 240+ 天） | 体检 §9/建议 8 | 🔴 update.miui.com 已放行，需要用户定一个查更新的窗口 |
| 7 | 系统身份可绕过 VPN 锁定（1000/1001/10134/10229…） | 体检 §3c | 🔴 无 root 无解；在家靠 Surge 兜底，走蜂窝时没有观测手段；对策 = 能删的风险包尽量删 |
| 8 | 谷歌侧：Wi-Fi 常扫描 `wifi_scan_always_enabled=1`、Chrome 遥测（beacons.gvt2.com）、`OFFLINE_FIND_SCAN=1` | feature_audit 10-01 | 🔴 用户决定（谷歌生态是自选的） |
| 9 | 小米 BLE 扫描类开关（`is_fastconnect_scan_enable`、`mishare_auto_start_scan`、`bluetooth_support_xiao_ai_scan`） | feature_audit 10-01 | 🔴 低价值（相关包网络已封），可顺手关 |

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
