#!/bin/zsh
# 手机端定时执行的一次性配置（Mac 在旁、手机已解锁时跑）。除「装包确认」外不需要点手机。
#   1. 经 tools/adb_install.sh 装 Shizuku 与 PermGuard（MIUI「USB 安装」会在手机上弹确认，点「继续安装」各一次）
#   2. 授权：Shizuku 的 WRITE_SECURE_SETTINGS（13.6 无 root 开机自启要它）、PermGuard 的通知权限、两者 MIUI 自启动 10008 + 省电白名单
#   3. 用 adb 启动 Shizuku 服务端（本次开机有效；重启后靠 Shizuku 自己在受信任 Wi-Fi 下自启，见 README）
#   4. 打开 PermGuard 并弹出 Shizuku 授权框（这一下要在手机上点「允许」）
#   5. 核对：Shizuku 进程、jobscheduler 里 PermGuard 的周期任务、守护循环
# 用法: permguard/adb/setup_phone.sh [shizuku.apk] [permguard.apk]    只核对: setup_phone.sh --check
set -uo pipefail
CHECK=0; [ "${1:-}" = --check ] && { CHECK=1; shift; }
R=${0:A:h:h}; REPO=${R:h}
export ADB_SERIAL=${ADB_SERIAL:-adb-7f37d4d8-qKCl29._adb-tls-connect._tcp}
A=(adb -s $ADB_SERIAL)
SZ=moe.shizuku.privileged.api; PG=uk.tonytong.permguard
SZ_APK=${1:-$(ls $R/app/out/shizuku-*.apk 2>/dev/null | tail -1)}   # 官方 GitHub Release，sha256 见 permguard/README.md
PG_APK=${2:-$R/app/out/permguard.apk}

[ "$($A get-state 2>/dev/null | tr -d '\r')" = device ] || { echo "❌ adb 连不上"; exit 2; }
inst() { $A shell -n pm list packages | tr -d '\r' | grep -qx "package:$1"; }
if [ $CHECK = 0 ]; then

for pair in "$SZ:$SZ_APK" "$PG:$PG_APK"; do
  p=${pair%%:*}; f=${pair#*:}
  if inst $p && { [ "$p" = "$SZ" ] || [ -z "${PG_REINSTALL:-}" ]; }; then echo "已装 $p（PermGuard 升级用 PG_REINSTALL=1）"; continue; fi
  [ -f "$f" ] || { echo "❌ 缺 APK: $f"; exit 2; }
  echo "安装 $p ← $f（手机上点「继续安装」）"
  $REPO/tools/adb_install.sh -r "$f" || { echo "❌ 安装 $p 失败（锁屏/没点确认会报 INSTALL_FAILED_USER_RESTRICTED）"; exit 1; }
done

echo "== 授权"
$A shell -n pm grant $SZ android.permission.WRITE_SECURE_SETTINGS && echo "  Shizuku WRITE_SECURE_SETTINGS"
$A shell -n pm grant $PG android.permission.POST_NOTIFICATIONS && echo "  PermGuard POST_NOTIFICATIONS"
for p in $SZ $PG; do
  $A shell -n cmd appops set $p 10008 allow
  $A shell -n dumpsys deviceidle whitelist +$p >/dev/null
  echo "  $p 自启动=$($A shell -n cmd appops get $p 10008 | tr -d '\r')"
done

echo "== 启动 Shizuku 服务端"
if $A shell -n 'ps -A -o USER,ARGS' | grep -q 'shizuku_server'; then echo "  已在运行"
else
  lib=$($A shell -n "d=\$(dirname \$(pm path $SZ | head -1 | sed s/package://)); ls \$d/lib/arm64/libshizuku.so" | tr -d '\r')
  $A shell -n "$lib" | tail -3
fi

echo "== 打开 PermGuard（手机上点「授权 Shizuku」→ 允许）"
$A shell -n am start -n $PG/.MainActivity >/dev/null
echo "   授权后再跑一次核对： $0 --check"
fi

echo "== 核对"
$A shell -n 'ps -A -o PID,USER,ARGS' | grep -E 'shizuku_server|pg.sh daemon' | grep -v grep
$A shell -n dumpsys jobscheduler | grep -E "JOB #u0a[0-9]+/[12]: .*$PG" | head
$A shell -n "sh /data/local/tmp/permguard/pg.sh status"
