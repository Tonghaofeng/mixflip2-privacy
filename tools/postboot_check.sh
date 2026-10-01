#!/bin/bash
# 开机后自检（只读）：精简 / 上报开关 / 常驻 VPN / 地区时区 有没有被悄悄改回。任一 FAIL → 退出码 1。
# 手机开机后、解锁前即可跑（包状态与 settings 在 DE 存储）；VPN 是否已连上要解锁后才看得到。
# 背景：2026-10-01 发现 18 个包重启后回来（卸载后几秒就 adb reboot，用户态没落盘）、passport_ad_status 被小米账号改回 ON；
#       同日重做卸载后本脚本初版报「全部通过」，而 SystemUI 正因缺 htmlviewer 崩溃循环（初版不看崩溃）→ 加了禁删包与稳定性两节。
set -uo pipefail
cd "$(dirname "$0")/.."
S=${ADB_SERIAL:-7f37d4d8}
A="adb -s $S"
st=$($A get-state 2>/dev/null | tr -d '\r')
[ "$st" = "device" ] || { echo "❌ adb 连不上 ${S}（state=${st:-none}）：插线/授权后再跑"; exit 2; }
EXPECT_LOCALE=${EXPECT_LOCALE:-zh-Hans-SG}
EXPECT_TZ=${EXPECT_TZ:-Asia/Singapore}
WATCH=${WATCH:-30}   # 观察 SystemUI 是否崩溃重启的秒数（开机后立刻跑时建议 ≥60：07:23 那次崩溃循环在开机 15 秒后才开始）
fail=0
ok()  { printf '  ✅ %s\n' "$1"; }
bad() { printf '  ❌ %s\n' "$1"; fail=1; }
inf() { printf '  ·  %s\n' "$1"; }

echo "== 开机"
inf "$($A shell 'uptime -s 2>/dev/null || uptime') / boot reason: $($A shell getprop persist.sys.boot.reason.history | head -1 | tr -d '\r')"

echo "== 精简（debloat/removed.txt 与 user 0 已安装包的交集必须为空）"
tmp=$(mktemp)
$A shell pm list packages --user 0 | sed 's/^package://' | tr -d '\r' | sort > "$tmp"
[ "$(wc -l < "$tmp")" -gt 100 ] || bad "pm list 只返回 $(wc -l < "$tmp") 个包（adb 异常？），以下包检查不可信"
back=$(grep -xFf debloat/removed.txt "$tmp" || true)
if [ -z "$back" ]; then ok "removed.txt $(wc -l < debloat/removed.txt | tr -d ' ') 个全部未安装"; else bad "回来了: $(echo $back)"; fi
dis=$($A shell pm list packages -d | sed 's/^package://' | tr -d '\r')
notdis=$(grep -vxF -f <(echo "$dis") debloat/disabled.txt || true)
if [ -z "$notdis" ]; then ok "disabled.txt 全部仍停用"; else bad "不再停用: $(echo $notdis)"; fi
missing=""
while read -r k _; do
  case "$k" in ''|\#*) continue;; esac
  grep -qx "$k" "$tmp" || missing="$missing $k"
done < debloat/KEEP.txt
if [ -z "$missing" ]; then ok "KEEP.txt 禁删包全部在装"; else bad "禁删包不在:${missing}（htmlviewer 缺失会让 SystemUI 崩溃循环 → cmd package install-existing --user 0 <包>）"; fi
rm -f "$tmp"

echo "== 稳定性（开机以来崩溃 / RescueParty；观察 ${WATCH}s）"
boot=$($A shell uptime -s | tr -d '\r')
hist=$($A shell getprop persist.sys.boot.reason.history | tr -d '\r' | head -3 | sed -E 's/,[0-9]+$//')
cur=$(echo "$hist" | head -1); older=$(echo "$hist" | tail -n +2 | tr '\n' ' ')
case "$cur" in *rescueparty*|*recovery*) bad "本次开机原因是 RescueParty/recovery: ${cur}";; *) ok "本次开机原因: ${cur}";; esac
case "$older" in *rescueparty*|*recovery*) inf "更早的开机里有 RescueParty/recovery: ${older}（历史，核对是否已处理）";; esac
pid0=$($A shell pidof com.android.systemui | tr -d '\r')
[ "$WATCH" -gt 0 ] && sleep "$WATCH"
pid1=$($A shell pidof com.android.systemui | tr -d '\r')
crashes=$($A shell dumpsys dropbox 2>/dev/null | tr -d '\r' \
  | awk -v b="$boot" '($1" "$2)>=b && $3 ~ /^(system_app_crash|system_server_crash|system_app_native_crash|SYSTEM_TOMBSTONE)$/ {print $3}' | sort | uniq -c | tr '\n' ' ')
[ -z "$crashes" ] && ok "开机（${boot}）以来无系统级崩溃" || bad "开机以来系统级崩溃: ${crashes}（dumpsys dropbox --print system_app_crash 看堆栈）"
[ -n "$pid0" ] && [ "$pid0" = "$pid1" ] && ok "SystemUI 进程稳定（pid ${pid1}）" || bad "SystemUI 进程变化/缺失: ${pid0:-无} → ${pid1:-无}"

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
global maintenance_mode_user_id 110
secure quick_control_all_devices 0
secure smart_device_control 0
secure second_space_entrance_status 0
system three_gesture_up none
secure key_latest_virus_scan_date 0
secure settings_sms_risk_warn_enable 0
secure settings_sms_code_clipboard_warn_enable 0
secure screen_share_protection 0
secure com.android.browser.web_page_warning_states 0
secure ai_guard_function_switch 0
secure com.miui.guardprovider.AI_GUARD_PRIVACY_AGREEMENT 0
secure optimizer_scan_cloud 0
system cloud_antispam 0
system key_yellowpage_main_switch 0
global package_verifier_user_consent -1
global package_verifier_enable 0
EOF

echo "== 常驻 VPN（Clash always-on + 锁定）"
app=$($A shell settings get secure always_on_vpn_app | tr -d '\r')
lock=$($A shell settings get secure always_on_vpn_lockdown | tr -d '\r')
[ "$app" = "com.github.metacubex.clash.meta" ] && ok "always_on_vpn_app=${app}" || bad "always_on_vpn_app=${app}"
[ "$lock" = "1" ] && ok "always_on_vpn_lockdown=1" || bad "always_on_vpn_lockdown=${lock}"
rules=$($A shell dumpsys connectivity | grep -A1 "Lockdown filtering rules" | tail -1 | tr -d '\r' | sed 's/^ *//')
[ -n "$rules" ] && ok "lockdown 规则: $rules" || inf "lockdown 规则未出现（未解锁时 Clash 还没起来，属正常）"
if $A shell dumpsys connectivity | grep -q "VPN CONNECTED.*clash.meta"; then ok "tun0 VPN 已连接"; else inf "VPN 未连接（未解锁时正常；解锁后仍未连接则异常）"; fi
# 防 HyperOS 杀 Clash（2026-10-01：exit-info 7 次退出全是多任务「一键清理」强停，锁定模式下即整机断网）
CP=com.github.metacubex.clash.meta
as=$($A shell cmd appops get $CP 10008 | tr -d '\r')
case "$as" in *allow*) ok "Clash 自启动(10008)=allow" ;; *) bad "Clash 自启动(10008): ${as}（应为 allow）" ;; esac
$A shell dumpsys deviceidle whitelist | grep -q "$CP" && ok "Clash 在省电白名单" || bad "Clash 不在 deviceidle 白名单"
$A shell settings get system locked_apps | grep -q "$CP" && ok "Clash 在多任务锁定名单" || bad "Clash 不在多任务锁定名单（多任务界面长按卡片→锁定）"

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
