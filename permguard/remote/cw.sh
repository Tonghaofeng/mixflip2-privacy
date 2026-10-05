#!/system/bin/sh
# Clash 断流看门狗（shell 身份，由 hooks.sh 保活，和 rt.sh 一样不受 MIUI 冻结影响）。
# 现象：Clash 进程活着、VPN 也在，但流量全断，手动重启 Clash 才恢复（10-04 舟山酒店 Wi-Fi：
# 双出口轮换导致 WG 端点在两个公网 IP 间来回跳，之后隧道卡死）。
# 做法：每 30 秒经 TUN 真实发 HTTP 探测（三个不同站点，任一通即算通）；连续 3 轮不通 → STOP+START 重启 Clash。
# 重启后仍不通则退避（3、6、12…最长 30 分钟）再试，免得 Wi-Fi 本身没网时反复重启。每次出事存一份 logcat 取证。
D=/data/local/tmp/cw; mkdir -p $D/inc; cd $D || exit 1
echo $$ > cw.pid
PKG=com.github.metacubex.clash.meta
ACT=$PKG/com.github.kr328.clash.ExternalControlActivity
log() { echo "$(date '+%F %T') $*" >> cw.log; }
probe1() { (printf "GET $2 HTTP/1.1\r\nHost: $1\r\nConnection: close\r\n\r\n"; sleep 4) | nc -w 5 $1 80 2>/dev/null | head -1 | grep -q "HTTP/1"; }
probe() { probe1 cp.cloudflare.com /generate_204 || probe1 connectivitycheck.gstatic.com /generate_204 || probe1 captive.apple.com /hotspot-detect.html; }
vpn_up() { dumpsys connectivity 2>/dev/null | grep -q "VPN:$PKG"; }
# 有没有底层网络（Wi-Fi 或带 INTERNET 能力的蜂窝）——没网时不算 Clash 的锅
uplink() { ip -4 addr show wlan0 2>/dev/null | grep -q "inet " || ip route show table all 2>/dev/null | grep -q "default.*rmnet"; }
restart() {
  logcat -d -v time 2>/dev/null | grep -E "ClashMeta|PermGuard" | tail -400 > inc/$(date +%m%d-%H%M%S).log
  ls -t inc/*.log 2>/dev/null | sed -n '21,$p' | xargs rm -f 2>/dev/null
  log "连续 $fail 轮不通，重启 Clash（第 $tries 次）"
  am start -n $ACT -a $PKG.action.STOP_CLASH > /dev/null 2>&1
  sleep 4
  am start -n $ACT -a $PKG.action.START_CLASH > /dev/null 2>&1
  sleep 12
  vpn_up || { log "START 后 VPN 没起来，再拉一次"; am start -n $ACT -a $PKG.action.START_CLASH > /dev/null 2>&1; sleep 10; }
}
fail=0; tries=0; next=0; vd=0
while [ "$(cat cw.pid 2>/dev/null)" = "$$" ]; do
  # 暂停开关：维护脚本（如改 Clash 访问控制）写 pause_until=<epoch>，最长 10 分钟，期间不拉起/不重启 Clash
  pu=$(cat pause_until 2>/dev/null || echo 0); now=$(date +%s)
  if [ "$pu" -gt "$now" ] && [ $((pu - now)) -le 600 ]; then sleep 10; continue; fi
  # Clash 整个停了（被手动/误点停止、STOP 后没起来）：锁定模式下全机断网。常驻 VPN 设的就是 Clash，连续 2 轮（约 1 分钟）不在就拉起。
  # 10-05 09:38 实测：远程 STOP 后的「4 分钟保险」子进程随 rsh 会话一起被杀，Clash 一直停着，看门狗原逻辑见 VPN 不在就跳过。
  if ! vpn_up && [ "$(settings get secure always_on_vpn_app)" = "$PKG" ]; then
    vd=$((vd + 1))
    [ $vd -ge 2 ] && { log "Clash VPN 不在（$vd 轮），拉起"; am start -n $ACT -a $PKG.action.START_CLASH > /dev/null 2>&1; vd=0; sleep 15; }
  else vd=0; fi
  if ! uplink || ! vpn_up; then
    fail=0
  elif probe; then
    [ $tries -gt 0 ] && log "恢复（之前重启 $tries 次）"
    fail=0; tries=0; next=0
  else
    fail=$((fail + 1))
    now=$(date +%s)
    if [ $fail -ge 3 ] && [ $now -ge $next ]; then
      tries=$((tries + 1))
      restart
      b=$((180 * (1 << (tries - 1)))); [ $b -gt 1800 ] && b=1800
      next=$(( $(date +%s) + b )); fail=0
    fi
  fi
  [ "$(stat -c %s cw.log 2>/dev/null || echo 0)" -gt 200000 ] && : > cw.log
  sleep 30
done
