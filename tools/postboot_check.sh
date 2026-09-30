#!/bin/bash
# 开机后自检（只读）：精简 / 上报开关 / 常驻 VPN / 地区时区 有没有被悄悄改回。任一 FAIL → 退出码 1。
# 手机开机后、解锁前即可跑（包状态与 settings 在 DE 存储）；VPN 是否已连上要解锁后才看得到。
# 背景：2026-10-01 发现 18 个包重启后回来（卸载后几秒就 adb reboot，用户态没落盘）、passport_ad_status 被小米账号改回 ON。
set -uo pipefail
cd "$(dirname "$0")/.."
S=${ADB_SERIAL:-7f37d4d8}
A="adb -s $S"
EXPECT_LOCALE=${EXPECT_LOCALE:-zh-Hans-SG}
EXPECT_TZ=${EXPECT_TZ:-Asia/Singapore}
fail=0
ok()  { printf '  ✅ %s\n' "$1"; }
bad() { printf '  ❌ %s\n' "$1"; fail=1; }
inf() { printf '  ·  %s\n' "$1"; }

echo "== 开机"
inf "$($A shell 'uptime -s 2>/dev/null || uptime') / boot reason: $($A shell getprop persist.sys.boot.reason.history | head -1 | tr -d '\r')"

echo "== 精简（debloat/removed.txt 与 user 0 已安装包的交集必须为空）"
tmp=$(mktemp)
$A shell pm list packages --user 0 | sed 's/^package://' | tr -d '\r' | sort > "$tmp"
back=$(grep -xFf debloat/removed.txt "$tmp" || true)
if [ -z "$back" ]; then ok "removed.txt $(wc -l < debloat/removed.txt | tr -d ' ') 个全部未安装"; else bad "回来了: $(echo $back)"; fi
dis=$($A shell pm list packages -d | sed 's/^package://' | tr -d '\r')
notdis=$(grep -vxF -f <(echo "$dis") debloat/disabled.txt || true)
if [ -z "$notdis" ]; then ok "disabled.txt 全部仍停用"; else bad "不再停用: $(echo $notdis)"; fi
rm -f "$tmp"

echo "== 上报 / 探针开关"
while read -r ns key want; do
  got=$($A shell -n settings get "$ns" "$key" | tr -d '\r')
  if [ "$got" = "$want" ]; then ok "$ns $key=${got}"; else bad "$ns $key=${got}（应为 ${want}）"; fi
done <<'EOF'
secure upload_log_pref 0
secure upload_debug_log_pref 0
secure operator_service_improve_plan 0
secure miui_miprotect_risk_app_download_warn 0
secure miui_miprotect_risk_app_remind_warn 0
global upload_apk_enable 0
global passport_ad_status OFF
global captive_portal_mode 0
EOF

echo "== 常驻 VPN（Clash always-on + 锁定）"
app=$($A shell settings get secure always_on_vpn_app | tr -d '\r')
lock=$($A shell settings get secure always_on_vpn_lockdown | tr -d '\r')
[ "$app" = "com.github.metacubex.clash.meta" ] && ok "always_on_vpn_app=${app}" || bad "always_on_vpn_app=${app}"
[ "$lock" = "1" ] && ok "always_on_vpn_lockdown=1" || bad "always_on_vpn_lockdown=${lock}"
rules=$($A shell dumpsys connectivity | grep -A1 "Lockdown filtering rules" | tail -1 | tr -d '\r' | sed 's/^ *//')
[ -n "$rules" ] && ok "lockdown 规则: $rules" || inf "lockdown 规则未出现（未解锁时 Clash 还没起来，属正常）"
if $A shell dumpsys connectivity | grep -q "VPN CONNECTED.*clash.meta"; then ok "tun0 VPN 已连接"; else inf "VPN 未连接（未解锁时正常；解锁后仍未连接则异常）"; fi

echo "== 地区 / 时区（tools/sysregion）"
loc=$($A shell getprop persist.sys.locale | tr -d '\r')
tz=$($A shell getprop persist.sys.timezone | tr -d '\r')
auto=$($A shell cmd time_zone_detector is_auto_detection_enabled | tr -d '\r')
[ "$loc" = "$EXPECT_LOCALE" ] && ok "persist.sys.locale=${loc}" || bad "persist.sys.locale=${loc}（应为 ${EXPECT_LOCALE}）"
[ "$tz" = "$EXPECT_TZ" ] && ok "persist.sys.timezone=${tz}" || bad "persist.sys.timezone=${tz}（应为 ${EXPECT_TZ}）"
[ "$auto" = "false" ] && ok "自动时区=false" || bad "自动时区=${auto}（开着会被运营商改回上海）"

echo
[ $fail -eq 0 ] && echo "结果：全部通过" || echo "结果：有 FAIL，见上"
exit $fail
