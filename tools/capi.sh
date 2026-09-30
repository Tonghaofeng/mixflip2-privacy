#!/bin/zsh
# 在手机本机调用 Clash Meta (CMFA) 的 REST API（CMFA 把控制器绑在随机 127.x 地址，adb forward 够不着）
# 用法: ./capi.sh /proxies     ./capi.sh /connections
S=$(grep -E "^secret:" ${0:A:h}/../clash/mixflip2.yaml | awk '{print $2}')
EP=$(adb shell -n cat /proc/net/tcp | awk -v u=$(adb shell -n pm list packages -U com.github.metacubex.clash.meta | sed 's/.*uid://' | tr -d '\r') \
  '$4=="0A" && $8==u && $2 ~ /^[0-9A-F]+7F:/ {print $2; exit}')
IP=$(python3 -c "h='${EP%%:*}';print('.'.join(str(int(h[i:i+2],16)) for i in (6,4,2,0)))"); PORT=$((16#${EP##*:}))
adb shell -n "printf 'GET $1 HTTP/1.0\r\nAuthorization: Bearer $S\r\n\r\n' | nc -w 5 $IP $PORT" | sed '1,/^\r*$/d'
