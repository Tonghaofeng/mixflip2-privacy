# INSTALL — 从零复现（小米 MIX Flip 2 国行，BL 锁，不 root）

> 全程在 Mac 上用 adb/ssh 脚本完成；只有 4 处必须在手机上点：USB 调试授权、Clash 的 VPN 授权与「保存/更新」、（可选）退出小米账号。

## 0. 前提
- Mac：`brew install --cask android-platform-tools`；`brew install mihomo`（策略本机校验）；Python 3
- 手机：开发者选项 → USB 调试 + USB 调试（安全设置）+ USB 安装；插原装线（充电线不行，`system_profiler SPUSBDataType` 看得到 Xiaomi 才算连上）
- 家里：Mac mini（Surge 增强模式 + 网关模式）、路由器能做 UDP 端口转发、DDNS 域名（本例 tonytong.uk）

## 1. 精简（持久）
```bash
cd debloat
# 先看 removed.txt / disabled.txt 每一行（README 里有逐项证据）；照单卸载：
for p in $(cat removed.txt); do adb shell -n pm uninstall --user 0 $p; done
for p in $(cat disabled.txt); do adb shell -n pm disable-user --user 0 $p; done
./replace_with_google.sh          # 先在 Play 装好 Google 相册/Keep/计算器/时钟/日历/Files
```
**不能删的**：com.android.contacts + incallui（系统兜底拨号器 = 紧急呼叫）、securitycenter、lbe、xiaomi.location.fused、
**guardprovider**（MIUI 侧载/adb 安装校验依赖它，删了报 `INSTALL_FAILED_USER_RESTRICTED: Invalid apk`）。恢复：`./restore.sh [包名]`。

## 2. 系统设置（持久）
```bash
adb shell settings put secure upload_log_pref 0; adb shell settings put secure upload_debug_log_pref 0
adb shell settings put secure operator_service_improve_plan 0; adb shell settings put global upload_apk_enable 0
adb shell settings put global passport_ad_status OFF
adb shell settings put secure miui_miprotect_risk_app_download_warn 0; adb shell settings put secure miui_miprotect_risk_app_remind_warn 0
adb shell settings put global captive_portal_mode 0     # 关联网检测探针（MIUI 忽略探针 URL 设置，只能整体关）
```

## 3. 家里 Mac mini：WireGuard 回家（见 tony/mac-mini-autostart 仓库「WireGuard」卡片与踩坑 13–15）
- `brew install wireguard-tools wireguard-go`；`/opt/homebrew/etc/wireguard/` 生成服务端/手机密钥与 wg0.conf（10.77.0.1/24，UDP 51820）
- LaunchDaemon `com.tony.wireguard.wg0` 常驻 `/Library/PrivilegedHelperTools/com.tony.wireguard-home`：wg0 保活、pf NAT 进 Surge TUN、手机 endpoint 主机路由直走路由器
- 路由器静态转发 `51820/UDP → Mac mini`（华硕 API 写法与编码坑见 mac-mini-autostart 踩坑 14）
- 策略分发：LaunchAgent `com.tony.phone-config`（`~/bin/phone-config-server.py`，仅局域网 + token 路径）

## 4. 手机：Clash Meta for Android（常驻 VPN）
```bash
adb install cmfa-2.11.34-meta-arm64-v8a-release.apk     # 核对 sha256 见 _checksums.txt；需 guardprovider 在
cd tools && ./publish_config.sh                          # 生成策略 + 推到 Mac mini 分发点（会打印 URL，token 不回显）
T=$(ssh macserver cat ~/phone-config/.token)
adb shell am start -a android.intent.action.VIEW -d "clash://install-config?url=http%3A%2F%2F192.168.50.2%3A18765%2F$T%2Fmixflip2.yaml\&name=MixFlip2"
#   手机上点「保存」→ 选中 MixFlip2 → 启动 → VPN 授权点「确定」
adb shell settings put secure always_on_vpn_app com.github.metacubex.clash.meta
adb shell settings put secure always_on_vpn_lockdown 1
adb reboot                                               # 必须重启：锁定才生效，且清掉 VPN 之前的旧连接
```
以后改策略：改 `tools/gen_clash_config.py` → `./publish_config.sh` → 手机在家 Clash「配置 → ⋮ → 更新」。

## 5. 验收（只认底层证据）
```bash
cd evidence
python3 ../tools/accept.py 300          # 手机侧「小米/国内未拦截」必须 0；Surge 侧只允许 WG/NTP/DoH 与 Clash 自身的 DIRECT 健康检查
adb shell dumpsys connectivity | grep -A3 "Lockdown filtering rules"
adb shell dumpsys network_stack | grep -c " - PROBE_"   # 重连 Wi-Fi 前后不变
adb shell svc wifi disable   # 出门模拟：看 Mac mini 上 sudo wg show all 的 endpoint 变运营商 IP、transfer 在涨；完事 svc wifi enable
```
取证（任意时刻看某 UID 连了哪些域名，需手机在家 Wi-Fi）：`python3 tools/uid_domain_audit.py 600`。
