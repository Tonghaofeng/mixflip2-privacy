#!/system/bin/sh
# 远程 shell 通道（shell 身份，hooks.sh 保活）：不依赖无线调试，蜂窝网络下也能用。
# 为什么要有它：无线调试只能在 Wi-Fi 下开，且在「不受信任」的 Wi-Fi 上系统会反复把它关掉（10-05 酒店 Wi-Fi
# 07:09 同一网络下被关），夜里断 Wi-Fi、早上走流量时 adb 通道必断。这条通道只依赖 Shizuku 拉起的守护进程还活着。
# 结构：toybox nc 在 127.0.0.1:2222 监听，每个连接交给 rsh.sh（首行口令校验通过才给 sh）；
#       dbclient -R 把它映射到 Mac mini 127.0.0.1:15559（被占用换 15560）。
D=/data/local/tmp/rt; export HOME=$D; cd $D || exit 1
echo $$ > rs.pid
log() { echo "$(date '+%F %T') $*" >> rs.log; }
fwdfail() { grep -q -i "forward request failed" rs-cur.log; }
listener() { ps -A -o ARGS 2>/dev/null | grep -q "^toybox nc -L -s 127.0.0.1 -p 2222"; }
# 通知栏状态：这条通道不经过无线调试，系统不会显示任何东西，所以自己发一条（只在状态变化时更新，不反复打扰）
st=""
note() {
  [ "$1" = "$st" ] && return; st=$1
  net=$(ip -4 addr show wlan0 2>/dev/null | grep -q "inet " && echo Wi-Fi || echo 流量)
  case $1 in
    up) cmd notification post -t "远程通道 🟢 已连接" rsh "AIOS 可远程操作手机（$net）· $(date +%H:%M) 起" > /dev/null 2>&1 ;;
    down) cmd notification post -t "远程通道 🔴 未连接" rsh "正在自动重连（$net）· $(date +%H:%M)" > /dev/null 2>&1 ;;
  esac
}
n=0
while [ "$(cat rs.pid 2>/dev/null)" = "$$" ]; do
  listener || { setsid toybox nc -L -s 127.0.0.1 -p 2222 sh $D/rsh.sh < /dev/null > /dev/null 2>&1 & sleep 1; log "监听 127.0.0.1:2222 已启动"; }
  r=$((15559 + n % 2))
  : > rs-cur.log
  ./db dbclient -i key -y -N -T -K 30 -R $r:127.0.0.1:2222 tony@192.168.50.2 > rs-cur.log 2>&1 &
  c=$!
  log "通道 → Mac 127.0.0.1:$r"
  sleep 8
  kill -0 $c 2>/dev/null && ! fwdfail && note up
  while kill -0 $c 2>/dev/null && ! fwdfail && listener && [ "$(cat rs.pid 2>/dev/null)" = "$$" ]; do sleep 10; done
  note down
  kill $c 2>/dev/null
  fwdfail && { log "远端 $r 被占用，换下一个"; n=$((n + 1)); }
  grep -v "failed to identify current user" rs-cur.log | grep . >> rs.log
  [ "$(stat -c %s rs.log 2>/dev/null || echo 0)" -gt 100000 ] && : > rs.log
  sleep 15
done
