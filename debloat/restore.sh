#!/bin/zsh
# 恢复小米 MIX Flip 2 精简掉的应用。
# 用法: ./restore.sh            全部恢复
#       ./restore.sh 包名 ...    只恢复指定的
D=${0:A:h}
if [ $# -gt 0 ]; then list=("$@"); else list=(${(f)"$(cat $D/removed.txt $D/disabled.txt)"}); fi
for p in $list; do
  if grep -qx "$p" $D/disabled.txt; then echo "$p: $(adb shell -n pm enable $p)"
  else echo "$p: $(adb shell -n cmd package install-existing $p)"; fi
done
