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
listener() { toybox nc -z -w 2 127.0.0.1 2222 > /dev/null 2>&1; }
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
# 掉线重连期间持唤醒锁（10-06）：折叠合盖久了 CPU 深睡，shell 的 sleep 跟着停，掉线后下一次重连要等几十分钟
# （实测 00:15 掉线 → 01:28 才第二次尝试）。连着的时候不用管：Mac sshd 每 30 秒发保活包，网卡收包会唤醒 CPU。
# wakehold.dex（app_process 以 shell 身份持 PARTIAL_WAKE_LOCK，标志文件 wh.flag 删掉即释放；源码 permguard/core WakeHold.java）。
# 一次掉线最多连续持锁 30 分钟（没网时别把电耗光），之后每次自然醒来只持 2 分钟。
whold_on() {
  [ -f wh.flag ] && kill -0 "$(cat wh.pid 2>/dev/null)" 2>/dev/null && return
  now=$(date +%s); [ -n "$ep0" ] || ep0=$now
  secs=1800; [ $((now - ep0)) -ge 1800 ] && secs=120
  touch wh.flag
  setsid app_process -cp $D/wakehold.dex /system/bin uk.tonytong.permguard.WakeHold $secs $D/wh.flag < /dev/null > /dev/null 2>&1 &
  echo $! > wh.pid; log "掉线重连，持唤醒锁 ${secs}s"
}
whold_off() { ep0=""; [ -f wh.flag ] || return; rm -f wh.flag; log "通道已稳，释放唤醒锁"; }
ep0=""
# dbclient 是静态编译的 musl 程序，不走安卓的 DNS（没有 /etc/resolv.conf），连域名会解析失败 → 用系统 ping 先解析成 IP 再交给它。
# 10-05 11:44 实测：绕开 Clash 后 nc -z 已能连到 tonytong.uk:50022，但 dbclient 一个包都没发出去，就是卡在这里。
resolve() { case $1 in *[a-z]*) ping -c 1 -W 2 $1 2>/dev/null | sed -n '1s/^PING [^(]*(\([0-9.]*\)).*/\1/p';; *) echo $1;; esac; }
n=0
while [ "$(cat rs.pid 2>/dev/null)" = "$$" ]; do
  whold_on
  # 2026-10-11：优先并发 rshd（线程/连接；串行 nc 会被桥的 25 秒长轮询堵死其它调用），起不来退回老 nc
  listener || { setsid app_process -cp $D/rshd.dex /system/bin uk.tonytong.aios.shell.RshD < /dev/null >> rs-rshd.log 2>&1 & sleep 2;
    listener || { setsid toybox nc -L -s 127.0.0.1 -p 2222 sh $D/rsh.sh < /dev/null > /dev/null 2>&1 & sleep 1; }
    log "监听 127.0.0.1:2222 已启动($(listener && echo rshd || echo nc))"; }
  r=$((15559 + n % 2))
  : > rs-cur.log
  set -- $(pickhost); H=$1:$2; ip=$(resolve $1); ./db dbclient -i key -y -N -T -K 30 -p $2 -R $r:127.0.0.1:2222 tony@${ip:-$1} > rs-cur.log 2>&1 &
  c=$!
  log "通道 → Mac($H) 127.0.0.1:$r"
  sleep 8
  note
  t0=$(date +%s)
  while kill -0 $c 2>/dev/null && ! fwdfail && listener && [ "$(cat rs.pid 2>/dev/null)" = "$$" ]; do
    # 隧道活过 60 秒且（家里心跳已到，或已过 3 分钟——go2 关机时心跳不会来，但通道本身是好的）→ 放锁
    el=$(( $(date +%s) - t0 )); [ -f wh.flag ] && [ $el -ge 60 ] && { [ "${st%%/*}" = up ] || [ $el -ge 180 ]; } && whold_off
    sleep 10; note
  done
  note
  kill $c 2>/dev/null
  fwdfail && { log "远端 $r 被占用，换下一个"; n=$((n + 1)); }
  grep -v "failed to identify current user" rs-cur.log | grep . >> rs.log
  [ "$(stat -c %s rs.log 2>/dev/null || echo 0)" -gt 100000 ] && : > rs.log
  sleep 5; note; sleep 10; note
done

