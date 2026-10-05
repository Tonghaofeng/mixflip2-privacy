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
# 连哪台（「主机 端口」）：shell 不走 Clash 时（Clash 访问控制绕过 com.android.shell + 锁定白名单 always_on_vpn_lockdown_whitelist，10-05 起）
# 在家走局域网 192.168.50.2:22；在外走公网 tonytong.uk:50022（路由器转发 → Mac:22；酒店等网络常封出站 22，家宽封入站 443）；最后才试公网 22。
# 先 nc -z 探测（4 秒）。仍走 Clash 时 TUN 本地完成握手、探测恒通 → 选 192.168.50.2:22，照旧经 WG 回家。
pickhost() {
  for hp in "192.168.50.2 22" "tonytong.uk 50022" "tonytong.uk 22"; do
    toybox nc -z -w 4 $hp > /dev/null 2>&1 && { echo "$hp"; return; }
  done
  echo "tonytong.uk 50022"
}
# dbclient 是静态编译的 musl 程序，不走安卓的 DNS（没有 /etc/resolv.conf），连域名会解析失败 → 用系统 ping 先解析成 IP 再交给它。
# 10-05 11:44 实测：绕开 Clash 后 nc -z 已能连到 tonytong.uk:50022，但 dbclient 一个包都没发出去，就是卡在这里。
resolve() { case $1 in *[a-z]*) ping -c 1 -W 2 $1 2>/dev/null | sed -n '1s/^PING [^(]*(\([0-9.]*\)).*/\1/p';; *) echo $1;; esac; }
n=0
while [ "$(cat rs.pid 2>/dev/null)" = "$$" ]; do
  listener || { setsid toybox nc -L -s 127.0.0.1 -p 2222 sh $D/rsh.sh < /dev/null > /dev/null 2>&1 & sleep 1; log "监听 127.0.0.1:2222 已启动"; }
  r=$((15559 + n % 2))
  : > rs-cur.log
  set -- $(pickhost); H=$1:$2; ip=$(resolve $1); ./db dbclient -i key -y -N -T -K 30 -p $2 -R $r:127.0.0.1:2222 tony@${ip:-$1} > rs-cur.log 2>&1 &
  c=$!
  log "通道 → Mac($H) 127.0.0.1:$r"
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
