#!/bin/zsh
# 内核 BPF 防火墙（FIREWALL_CHAIN_OEM_DENY_3）按包禁网。UID<10000 的系统身份内核一律放行，拦不住，不在此列。
# 用法: ./bpf_block.sh        应用规则并校验
#       ./bpf_block.sh undo   撤销
PKGS=(
  com.lbe.security.miui          # 权限管理服务（连 api.sec.miui.com / xmpush）
  com.miui.packageinstaller      # 安装器（反诈/风险应用云检测）
  com.android.camera             # 小米相机（保留拍照，断网）
  com.xiaomi.cameratools
  com.android.soundrecorder com.miui.screenrecorder com.miui.compass
  com.android.contacts com.android.incallui   # 小米拨号/来电界面（号码识别云查询）；紧急呼叫不走数据网络
  com.miui.home com.miui.fliphome             # 内外屏桌面（推荐/云控）
  com.miui.securityadd com.miui.powerinsight com.miui.misound com.miui.screenshot
  com.miui.extraphoto com.miui.miwallpaper com.android.htmlviewer com.miui.core
  com.miui.accessibility com.xiaomi.macro com.xiaomi.continuity.sdkapp com.fido.asm
  com.miui.securityinputmethod com.miui.system com.miui.rom
  com.qualcomm.qti.qms.service.connectionsecurity
  com.miui.gallery com.miui.notes com.miui.calculator com.miui.cleanmaster com.mfashiongallery.emag  # 已禁用，双保险
)
state=false; [ "$1" = undo ] && state=true
[ "$1" = undo ] || adb shell -n cmd connectivity set-chain3-enabled true
for p in $PKGS; do
  adb shell -n pm list packages -U $p | tr -d '\r' | grep -q "^package:$p uid:" || { echo "absent  $p"; continue; }
  uid=$(adb shell -n pm list packages -U $p | tr -d '\r' | grep "^package:$p uid:" | sed 's/.*uid://; s/,.*//')
  (( uid < 10000 )) && { echo "SYSUID  $p ($uid) 内核豁免，跳过"; continue; }
  adb shell -n cmd connectivity set-package-networking-enabled $state $p >/dev/null
  printf "%-6s %-48s uid=%s\n" "$(adb shell -n cmd connectivity get-package-networking-enabled $p | tr -d '\r' | cut -d: -f2)" $p $uid
done
echo "chain3: $(adb shell -n cmd connectivity get-chain3-enabled | tr -d '\r')"
