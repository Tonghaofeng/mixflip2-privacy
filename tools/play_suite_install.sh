#!/bin/bash
# Play 全家桶自动安装（root 版重写 2026-10-11）
# 用法: bash play_suite_install.sh   （需手机已登录 Google 账号、解锁亮屏）
# 原理: market:// 详情页逐个开 → uiautomator 找「安装/获取」按钮(仅认 com.android.vending 包的节点) → 点 → 等装完 → 下一个
set -u
APPS="com.google.android.inputmethod.latin com.google.android.googlequicksearchbox com.google.android.tts com.google.android.gm com.google.android.apps.maps com.google.android.apps.docs com.google.android.apps.translate com.google.android.apps.adm com.google.android.calendar com.google.android.dialer com.google.android.apps.messaging com.google.android.contacts com.google.android.apps.walletnfcrel com.google.android.apps.youtube.music com.google.android.keep com.google.android.apps.meetings com.google.android.apps.nbu.files com.google.android.apps.chromecast.app com.google.android.tv.remote com.google.android.projection.gearhead"

dump() { adb shell "uiautomator dump /data/local/tmp/pl.xml >/dev/null 2>&1; cat /data/local/tmp/pl.xml" 2>/dev/null; }
tapbtn() {  # 找 text/desc=$1 且 package=com.android.vending 的可点节点, 点中心
  B=$(dump | grep -oE "(text|content-desc)=\"$1\"[^>]*package=\"com.android.vending\"[^>]*bounds=\"\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]\"" | grep -oE '\[[0-9]+,[0-9]+\]\[[0-9]+,[0-9]+\]' | head -1 | tr -d '\r')
  [ -z "$B" ] && return 1
  CX=$(echo $B | sed -E 's/\[([0-9]+),([0-9]+)\]\[([0-9]+),([0-9]+)\]/\1 \2 \3 \4/' | awk '{print int(($1+$3)/2), int(($2+$4)/2)}')
  adb shell "su -c 'input tap $CX'" 2>/dev/null
  return 0
}
wait_gone() {  # 等安装按钮消失(最多200s)
  for i in $(seq 1 40); do
    dump | grep -q "package=\"com.android.vending\"" && [ -n "$(dump | grep -oE 'text="(安装|打开|获取)"')" ] || break
    sleep 5
  done
}
for p in $APPS; do
  echo "== $p"
  adb shell "pm list packages $p" 2>/dev/null | grep -q "package:$p" && { echo "  已装,跳过"; continue; }
  adb shell "am start -a android.intent.action.VIEW -d 'market://details?id=$p'" >/dev/null 2>&1
  sleep 6
  tapbtn "安装" || tapbtn "获取" || { echo "  没找到安装按钮"; continue; }
  wait_gone
  adb shell "pm list packages $p" 2>/dev/null | grep -q "package:$p" && echo "  ✔ 装上" || echo "  ? 未确认"
  adb shell "input keyevent 4" >/dev/null 2>&1; sleep 2
done
echo SUITE_DONE
