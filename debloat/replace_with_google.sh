#!/bin/zsh
# 用 Google 原版替换小米自带应用：确认 Google 版已安装，再 pm uninstall --user 0 小米版，记入 removed.txt
BK=${0:A:h:h}
pairs=(
  com.miui.gallery:com.google.android.apps.photos
  com.miui.mediaeditor:com.google.android.apps.photos
  com.miui.mediaviewer:com.google.android.apps.photos
  com.miui.notes:com.google.android.keep
  com.miui.calculator:com.google.android.calculator
  com.android.deskclock:com.google.android.deskclock
  com.android.calendar:com.google.android.calendar
  com.android.fileexplorer:com.google.android.apps.nbu.files
)
have=$(adb shell -n pm list packages | tr -d '\r')
for pr in $pairs; do
  mi=${pr%%:*}; g=${pr##*:}
  if ! echo "$have" | grep -qx "package:$g"; then echo "SKIP $mi (替代品 $g 未安装)"; continue; fi
  if ! echo "$have" | grep -qx "package:$mi"; then echo "GONE $mi"; continue; fi
  r=$(adb shell -n pm uninstall --user 0 $mi | tr -d '\r'); echo "$r  $mi -> $g"
  [ "$r" = "Success" ] && echo $mi >> $BK/removed.txt
done
