# PermGuard 守护循环每轮调用（shell 身份）。保活远程维护隧道。
R=/data/local/tmp/rt
if [ -x $R/db ] && [ -f $R/rt.sh ]; then
  pid=$(cat $R/rt.pid 2>/dev/null)
  if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null || ! grep -q rt.sh /proc/$pid/cmdline 2>/dev/null; then
    setsid sh $R/rt.sh < /dev/null > /dev/null 2>&1 &
  fi
fi
