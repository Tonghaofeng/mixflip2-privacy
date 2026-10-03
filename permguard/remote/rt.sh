#!/system/bin/sh
# 远程维护反向隧道（shell 身份，由 PermGuard 守护循环经 hooks.sh 保活；不受 MIUI 冻结 App 影响）。
# 把本机 adbd 的无线调试 TLS 端口（随机，读 /proc/net/tcp* 里 uid=2000 的监听口）经 SSH 反向映射到
# Mac mini 127.0.0.1:15556；Mac mini 上 `adb connect 127.0.0.1:15556`。端口变了（无线调试重开）就重建。
D=/data/local/tmp/rt; export HOME=$D; cd $D || exit 1
echo $$ > rt.pid
port() { awk '$4=="0A" && $8==2000 {split($2,a,":"); print a[2]; exit}' /proc/net/tcp6 /proc/net/tcp 2>/dev/null; }
while [ "$(cat rt.pid 2>/dev/null)" = "$$" ]; do
  h=$(port)
  if [ -n "$h" ]; then
    p=$((0x$h))
    echo "$(date '+%F %T') tunnel → 127.0.0.1:$p" >> rt.log
    ./db dbclient -i key -y -N -T -K 30 -R 15556:127.0.0.1:$p tony@192.168.50.2 >> rt.log 2>&1 &
    c=$!
    while kill -0 $c 2>/dev/null && [ "$(port)" = "$h" ] && [ "$(cat rt.pid 2>/dev/null)" = "$$" ]; do sleep 30; done
    kill $c 2>/dev/null
  fi
  [ "$(stat -c %s rt.log 2>/dev/null || echo 0)" -gt 200000 ] && : > rt.log
  sleep 20
done
