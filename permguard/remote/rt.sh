#!/system/bin/sh
# 远程维护反向隧道（shell 身份，由 PermGuard 守护循环经 hooks.sh 保活；不受 MIUI 冻结 App 影响）。
# 把本机 adbd 的无线调试 TLS 端口（随机，读 /proc/net/tcp* 里 uid=2000 的监听口）经 SSH 反向映射到
# Mac mini 127.0.0.1:15556（被占用则轮换 15557/15558——手机重启后 Mac 上旧 ssh 会话可能还占着口，sshd 无 ClientAlive）。
# Mac mini 上依次试 `adb connect 127.0.0.1:1555{6,7,8}`。端口变了（无线调试重开）就重建。
D=/data/local/tmp/rt; export HOME=$D; cd $D || exit 1
echo $$ > rt.pid
# 排除 rsh 通道自己的监听口 2222（=0x08AE，10-05 rs.sh 上线后它也是 uid 2000 监听，曾被误当成无线调试端口）
port() { awk '$4=="0A" && $8==2000 {split($2,a,":"); if (a[2] != "08AE") {print a[2]; exit}}' /proc/net/tcp6 /proc/net/tcp 2>/dev/null; }
# 远端口被占时 dbclient 不退出，只打一行 "Remote TCP forward request failed"；连得慢时几秒后才出现，所以整个连接期间都要看。
# toybox grep 的 BRE 不认 \|（10-03 实测），只用单一模式。
fwdfail() { grep -q -i "forward request failed" cur.log; }
# 无线调试被关掉（断 Wi-Fi/换网时系统会自动关）就没有端口可转发。守门员只在开机/Wi-Fi 刚连上时开它，
# 而 Shizuku 一直活着时守门员 periodic 只看 binder（10-04 景区 Wi-Fi 上实测：隧道断了、没人去开）。
# 所以这里兜底：连着 Wi-Fi 且没端口时自己（shell 有 WRITE_SECURE_SETTINGS）打开无线调试。
# 不受信任的网络上系统会拨回去并弹确认框，所以同一网络（按 wlan0 地址认）最多试 3 次、每次间隔 ≥60 秒。
wifi() { ip -4 addr show wlan0 2>/dev/null | awk '/inet /{print $2; exit}'; }
wn=""; wt=0; wl=0
openadb() {
  w=$(wifi); [ -n "$w" ] || return
  [ "$w" != "$wn" ] && { wn=$w; wt=0; wl=0; }
  now=$(date +%s)
  if [ $wt -lt 3 ] && [ $((now - wl)) -ge 60 ]; then
    wt=$((wt + 1)); wl=$now
    echo "$(date '+%F %T') 无线调试没开，打开（$w 第 $wt 次）" >> rt.log
    settings put global adb_wifi_enabled 1
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
while [ "$(cat rt.pid 2>/dev/null)" = "$$" ]; do
  h=$(port)
  if [ -n "$h" ]; then
    p=$((0x$h)); r=$((15556 + n % 3))
    echo "$(date '+%F %T') tunnel $r → 127.0.0.1:$p via $H" >> rt.log
    : > cur.log
    set -- $(pickhost); H=$1:$2; ip=$(resolve $1); ./db dbclient -i key -y -N -T -K 30 -p $2 -R $r:127.0.0.1:$p tony@${ip:-$1} > cur.log 2>&1 &
    c=$!
    sleep 8
    while kill -0 $c 2>/dev/null && ! fwdfail && [ "$(port)" = "$h" ] && [ "$(cat rt.pid 2>/dev/null)" = "$$" ]; do sleep 10; done
    kill $c 2>/dev/null
    fwdfail && { echo "$(date '+%F %T') 远端 $r 被占用，换下一个" >> rt.log; n=$((n + 1)); }
    cat cur.log >> rt.log
    wt=0
  else
    openadb
  fi
  [ "$(stat -c %s rt.log 2>/dev/null || echo 0)" -gt 200000 ] && : > rt.log
  sleep 20
done
