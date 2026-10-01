#!/bin/zsh
# adb 装包（guardprovider 已卸载时用）：MIUI 的「USB 安装」确认页 AdbInstallActivity 要调 content://guard 的 parseApk
# 解析 APK，guardprovider 不在就 Failure [Invalid apk]。所以：临时装回 → adb install → 无论成败都再卸掉。
# 用法: tools/adb_install.sh [adb install 参数...] <apk>     例: tools/adb_install.sh -r cmfa.apk
set -u
A=(adb -s ${ADB_SERIAL:-7f37d4d8})
G=com.miui.guardprovider
restore_gone() { echo "卸回 $G: $($A shell -n pm uninstall --user 0 $G)"; }
echo "临时装回 $G: $($A shell -n cmd package install-existing --user 0 $G)"
trap restore_gone EXIT
$A install "$@"
