# 手机本地 UI 小工具：按文字找控件并点击（uiautomator dump，不需要网络）
dump() { uiautomator dump /sdcard/.u.xml > /dev/null 2>&1; }
center() { b=$(grep -o "$1[^>]*bounds=\"\[[0-9]*,[0-9]*\]\[[0-9]*,[0-9]*\]\"" /sdcard/.u.xml | head -1 | grep -o 'bounds="[^"]*"'); [ -n "$b" ] || return 1; set -- $(echo "$b" | tr -c '0-9' ' '); echo $(( ($1 + $3) / 2 )) $(( ($2 + $4) / 2 )); }
tapt() { dump; c=$(center "text=\"$1\"") || return 1; input tap $c; }
has() { dump; grep -q "text=\"$1\"" /sdcard/.u.xml; }
