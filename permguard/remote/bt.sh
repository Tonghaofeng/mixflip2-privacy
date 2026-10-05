#!/system/bin/sh
# 自测：让 shell 绕过 Clash（acx on），等最多 3 分钟看家里心跳（go2 phone-ping 每分钟经 rsh 写 last_ping）能否经直连路径写进来；
# 写进来 = 端到端成功，保留；否则 acx off 回退。回退时屏幕不可操作（锁屏/防误触）就发通知并每 30 秒重试，最多 15 分钟。结果记 cw/bt.log。
D=/data/local/tmp/cw; cd $D || exit 1
L=$D/bt.log; log() { echo "$(date '+%F %T') $*" >> $L; }
t0=$(date +%s)
log "开始：acx on"
sh $D/acx.sh on; rc=$?
[ $rc = 2 ] && { log "屏幕不可操作，未执行"; exit 2; }
[ $rc = 0 ] || { log "acx on 失败（rc=$rc），已收尾"; exit 1; }
for i in $(seq 1 36); do
  lp=$(cat /data/local/tmp/rt/last_ping 2>/dev/null || echo 0)
  if [ "$lp" -gt $((t0 + 60)) ]; then log "成功：绕过 Clash 后家里心跳 $(date -d @$lp +%T) 写入，通道走 $(grep 通道 /data/local/tmp/rt/rs.log | tail -1 | grep -o 'Mac([^)]*)')"; exit 0; fi
  sleep 5
done
log "失败：3 分钟内没收到家里心跳，回退 acx off"
for k in $(seq 1 30); do
  sh $D/acx.sh off; rc=$?
  [ $rc = 0 ] && { log "已回退"; cmd notification cancel rsh-revert > /dev/null 2>&1; exit 1; }
  [ $k = 1 ] && cmd notification post -t "远程通道 需要你点亮屏幕" rsh-revert "AIOS 要把 Clash 访问控制改回原样，请打开手机屏幕（别放口袋）1 分钟" > /dev/null 2>&1
  log "回退未成功（rc=$rc，第 $k 次），30 秒后重试"; sleep 30
done
log "回退失败！"
exit 1
