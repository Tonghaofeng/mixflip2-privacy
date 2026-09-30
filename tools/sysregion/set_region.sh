#!/bin/bash
# 改手机「系统地区」+ 时区（shell 身份、不 root、不点界面）
#   ./set_region.sh                    查看当前
#   ./set_region.sh SG Asia/Singapore  地区→新加坡（zh-CN → zh-Hans-SG），时区→新加坡并关自动时区
#   ./set_region.sh --revert           回到 zh-CN + Asia/Shanghai + 自动时区
# 原理见 README.md；syslocale.dex 由 build.sh 从 SysLocale.java 生成。
set -euo pipefail
cd "$(dirname "$0")"
S=${ADB_SERIAL:-7f37d4d8}
A="adb -s $S"
$A push syslocale.dex /data/local/tmp/syslocale.dex >/dev/null
syslocale() { $A shell "CLASSPATH=/data/local/tmp/syslocale.dex app_process / SysLocale $*"; }
show() {
  $A shell 'echo "persist.sys.locale=$(getprop persist.sys.locale) system_locales=$(settings get system system_locales)";
            echo "persist.sys.timezone=$(getprop persist.sys.timezone) auto_tz=$(cmd time_zone_detector is_auto_detection_enabled) auto_time=$(settings get global auto_time)";
            echo "只读(改不了) ro.miui.region=$(getprop ro.miui.region) sim_iso=$(getprop gsm.sim.operator.iso-country)"'
}

case "${1:-}" in
  "")
    syslocale get; show ;;
  --revert)
    syslocale set zh-CN
    $A shell 'cmd time_zone_detector set_auto_detection_enabled true; cmd alarm set-timezone Asia/Shanghai'
    show ;;
  *)
    CC=$1; TZ_ID=${2:-}
    syslocale set-region "$CC"
    if [ -n "$TZ_ID" ]; then
      # 自动时区开着会被运营商 NITZ/MCC 改回；suggest_manual_time_zone 需 SUGGEST_MANUAL_TIME_AND_ZONE（shell 没有），用 alarm 的 set-timezone
      $A shell "cmd time_zone_detector set_auto_detection_enabled false; cmd alarm set-timezone $TZ_ID"
    fi
    show ;;
esac
