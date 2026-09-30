# mixflip2-privacy — 小米 MIX Flip 2 国行去审查 / 去上报

手机：Xiaomi MIX Flip 2（bixi），HyperOS 3.0.304 **国行**，Android 16，**BL 锁**（不 root）。
目标：贴近国际版 + 谷歌生态；**审核功能关闭、隐私上报切断，而且出门（蜂窝）也要生效**。

验收只认底层证据（按 UID 的连接→域名、网关抓包、连接日志），不认界面开关。

**完整工作总结（阶段、发现、验收、踩坑与失误、运维手册）见 [总结.md](总结.md)。**

---

## 架构

```
手机（任何网络）
  ├─ 卸载/禁用：小米上报、广告、小爱、国行服务、支付卡包、车联、云与推送…（debloat/，持久）
  ├─ 系统 settings：体验计划/诊断上传/APK 云查杀/联网检测改 gstatic.cn …（持久）
  └─ Clash Meta for Android（mihomo）= 常驻 VPN，always-on + 锁定（非 VPN 连接一律禁止，含系统身份）
        策略 = tools/gen_clash_config.py 生成的 YAML：
        ⓪ Mac mini 本机 192.168.50.2 → MACMINI 组：在家直连、出门自动走 WG（其余 192.168.x 直连）
        ① 整个身份禁网：PROCESS-NAME（+UID 冗余）— 查找设备/主题/权限管理/相机/安全中心所在的 system(1000)…
        ② 域名族 REJECT：xiaomi/miui/mi.com/xmpush/迅雷 sandai/高德/百度&腾讯地图定位/qualcomm.cn/联通自注册…
        ③ 兜底：直连国内裸 IP（HTTPDNS/写死 IP）一律 REJECT —— 不依赖进程识别
        ④ 其余 → WireGuard 回家（tonytong.uk:51820）→ 家里 Surge（规则/代理与在家一致）
                                   │
家里 Mac mini（mac-mini-autostart 仓库管理自启）
  ├─ wg0（utun，10.77.0.1）+ 自愈守护 com.tony.wireguard.wg0：
  │     pf NAT 把隧道流量变成 Surge TUN 源地址（否则 Surge 不理）；手机公网 endpoint 主机路由直走路由器（否则回包端口被 Surge 改掉）
  ├─ 策略分发 com.tony.phone-config：仅局域网、token 路径，手机 Clash 点「更新」拉最新策略
  └─ 路由器 RT-AX89U 静态转发 51820/UDP → 192.168.50.2
```

## 目录

| 路径 | 内容 |
|---|---|
| `debloat/removed.txt` `disabled.txt` | 已 `pm uninstall --user 0` / `disable-user` 的包（逐条有证据理由，见下） |
| `debloat/restore.sh` | 恢复：`./restore.sh` 全部，`./restore.sh 包名…` 单个 |
| `debloat/replace_with_google.sh` | 小米应用 → Google 原版替换（先确认 Google 版已装再卸） |
| `debloat/bpf_block.sh` | 内核 BPF（OEM_DENY_3）按包禁网 —— **重启即失、UID<10000 内核豁免**，仅留作临时手段 |
| `tools/gen_clash_config.py` | 生成手机策略（包名→UID/共享身份名实时从手机取，WG 密钥从 Mac mini 取，本机 mihomo 校验） |
| `tools/publish_config.sh` | 生成并推到 Mac mini 分发点；手机在家点 Clash「更新」 |
| `tools/uid_domain_audit.py` | 取证：手机 /proc/net「端口→UID」× Surge「来源端口→域名/字节」→ 每个 UID 连了哪些域名 |
| `tools/accept.py` | 验收：Clash 连接日志里「小米/国内/裸 IP 却未拦截」+ Surge 侧绕过 VPN 的直连 |
| `tools/postboot_check.sh` | **每次重启后的自检**（只读，未解锁也能跑）：removed.txt 与已装包交集为空、停用包仍停用、上报开关、常驻 VPN、地区时区；任一 FAIL 退出码 1 |
| `tools/sysregion/` | 用 adb 把「系统地区」改成新加坡（zh-CN → zh-Hans-SG）+ 时区；原理与各层归属地见其 README |
| `tools/ui-automation/` | 仅在无接口时用的 uiautomator 小工具（Play 安装、Clash 保存/更新） |
| `evidence/` | 基线（精简后仍在上报的 UID→域名）、验收日志、证书/权限普查 |
| `clash/`（不入库） | 生成的策略 YAML，含 WireGuard 私钥 |

## 关键证据与结论（2026-09-30）

**基线（精简 + 关开关后，15 分钟，UID→域名）** `evidence/baseline_2157.json`
- 系统下载服务（UID 10092 `android.media`）内嵌**迅雷加速 SDK**：etl-xlmc-ssl.sandai.net 上传、hub5pn P2P 节点
- **查找设备**（6110）：find.api.micloud.xiaomi.net 15 分钟约 20 次上报
- **system(1000)**（安全中心/powerkeeper/融合定位里的高德百度腾讯 SDK/SystemUI…）：**裸 IP** 111.13.141.211 等（HTTPDNS 绕 DNS）
- 蓝牙(1002)→hlth.io.mi.com；账号/fido/主题 → account.xiaomi.com；tracking.miui.com、sdkconfig、resolver.msg（小米 HTTPDNS）等**当时只被家里 Surge 拦着，出门即放行**

**审核类功能（静态分析，安全中心 APK）**
- `com.miui.riskcontrol.SensitiveWordDetectProvider`：系统级敏感词检测（原生库 AES 加密词库），设置里改设备名时调用 —— 安全中心删不掉，已断其所在 system 身份的网络
- 反诈引擎：自动扫描已装应用、`PayActivityMonitorService` 监控微信/支付宝/QQ 转账界面、云端配置 fraud-detection.engine.miui.com —— 开关已关，网络已断
- 安装器的**云端禁止安装名单** `packageinstaller_forbidden_app_list`（v5）—— 安装器已断网

**实测踩坑（都已修）**
1. CMFA 只把**包名**交给 mihomo，**UID 规则永远不匹配**（日志 `by 1000[com.android.systemui]` 却 `match Match`）→ 改 PROCESS-NAME；UID 1000 全部被报成 `com.android.systemui`，共享身份报 `android.uid.bluetooth` / `android.media` 等
2. WG 端点域名：DoH 走 PROXY→要隧道→要解析端点 = **死锁**；明文 DNS 在家被 Surge 劫持成 fake-ip，**出门不可达** → 端点用按 IP 的 DoH 解析
3. 同一把 WG 密钥开两个出站（lan/wan）→ 服务端 endpoint 漂移、两边都判死 → 只留一个
4. 服务端回包走默认路由进 Surge，源端口被改（55616≠51820）→ 蜂窝不通 → endpoint 主机路由直走路由器（2 秒跟随）
5. MIUI 的 adb/侧载安装依赖 `guardprovider`（删了就 `INSTALL_FAILED_USER_RESTRICTED: Invalid apk`）→ 保留、只断网
6. `adb reverse` 在这台机器上 adb 服务重启后失效 → 改由 Mac mini 局域网分发点下发策略
7. 锁定 VPN 下 CMFA「绕过私有网络」开着 → 私有网段不进 VPN、被系统拒绝，手机打不开任何局域网页面（Clash 自己不受影响，易误判）→ 关掉该开关；出门访问 Mac mini 靠 MACMINI 组（10-01）

**验收** → 见 `evidence/accept_*.log`（结论写在文末「验收结果」）

## 已知限制

- BL 锁：system_server 与 UID 1000 的代码删不掉，只能**断网**（Clash 锁定模式下所有身份都必须经 VPN，这一点已由 lockdown 规则 `UIDs: 1-10280,10282-99999` 证实）
- 进程识别失败的连接（日志 `could not get uid`）不受身份规则约束 → 由域名族与「国内裸 IP」兜底规则 + 家里 Surge 双层把关
- IMS/VoLTE、彩信等运营商流量按 Android 设计绑定运营商网络，不经 VPN（属正常通话/短信）
- 小米账号保持登录但无法联网（退出需联网，被拦；用户确认保持）；激活锁仍在，重置后需小米密码
- 家里断网/Mac mini 宕机时，手机回退为直连（本机拦截规则仍生效，但无法翻墙）

## 验收结果（2026-09-30 23:10，重启后，always-on + 锁定生效）

| 项 | 结果 | 证据 |
|---|---|---|
| 锁定模式覆盖 | 除 Clash 自身(10281)外 UID 1–99999 全部禁止走非 VPN | `dumpsys connectivity` Lockdown filtering rules |
| 手机侧 5 分钟 | 179 条连接，拦截 41 条（全是小米：UID1000 裸 IP HTTPDNS ×20、idm/resolver.msg/tracking/ccc；下载服务 tracking；注入 WhatsApp 进程的 sdkconfig.ad.xiaomi.com），**小米/国内未拦截 = 0** | `evidence/accept_2259.log` |
| 手机侧 2 分钟（复验） | 拦截 18 条，**未拦截 = 0** | `evidence/accept_final_*.log` |
| 绕过 VPN 的直连（Surge 侧） | 仅 Clash 自身对 DIRECT 的健康检查（connectivitycheck.gstatic.com:80，无身份信息） | 同上 + `Health Checked, proxy: DIRECT` |
| 联网检测探针 | 原来每次联网都探 connect.rom.miui.com + www.baidu.com（**在 VPN 外**）；设 `captive_portal_mode=0` 后重连 **0 新探针**（MIUI 忽略 captive_portal_*_url） | `dumpsys network_stack` PROBE_ 计数 14→14 |
| 出门（蜂窝） | WG 从运营商 IP 握手，15 秒 387 KB；切回 Wi-Fi 自动回漫游 15 秒 207 KB | `wg show` endpoint 58.246.155.11 → 192.168.50.1 |
