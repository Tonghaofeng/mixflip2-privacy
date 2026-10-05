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
# 通知栏状态（端到端）：家里 AIOS 每分钟经本通道连进来写 last_ping（go2 phone-ping.timer）。
# 判据只看心跳新鲜度（≤150 秒为通），不看本地进程在不在 —— 进程活着但 TCP 已死时也能如实显示断开；
# 网络标签按当前 wlan0 实时取，切 Wi-Fi/流量也会更新。只在「通/断 或 网络」变化时重发，不反复打扰。
st=""; since=""
note() {
  now=$(date +%s); lp=$(cat last_ping 2>/dev/null || echo 0)
  ok=down; [ $((now - lp)) -le 150 ] && ok=up
  net=$(ip -4 addr show wlan0 2>/dev/null | grep -q "inet " && echo Wi-Fi || echo 流量)
  key="$ok/$net"; [ "$key" = "$st" ] && return
  [ "${st%%/*}" != "$ok" ] && since=$(date +%H:%M)
  st=$key
  if [ $ok = up ]; then
    cmd notification post -t "远程通道 🟢 已连接" rsh "AIOS 可远程操作手机（$net）· $since 起 · 每分钟实测" > /dev/null 2>&1
  else
    last=$( [ "$lp" -gt 0 ] && date -d @$lp +%H:%M || echo 无)
    cmd notification post -t "远程通道 🔴 未连接" rsh "AIOS 连不进来（$net）· 上次连通 $last · 自动重连中" > /dev/null 2>&1
  fi
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
  note
  while kill -0 $c 2>/dev/null && ! fwdfail && listener && [ "$(cat rs.pid 2>/dev/null)" = "$$" ]; do sleep 10; note; done
  note
  kill $c 2>/dev/null
  fwdfail && { log "远端 $r 被占用，换下一个"; n=$((n + 1)); }
  grep -v "failed to identify current user" rs-cur.log | grep . >> rs.log
  [ "$(stat -c %s rs.log 2>/dev/null || echo 0)" -gt 100000 ] && : > rs.log
  sleep 5; note; sleep 10; note
done
