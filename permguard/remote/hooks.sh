# PermGuard 守护循环每轮调用（shell 身份）。保活远程维护隧道 rt.sh 与 Clash 断流看门狗 cw.sh。
keep() {  # $1=目录 $2=脚本 $3=pid 文件
  [ -f $1/$2 ] || return
  pid=$(cat $1/$3 2>/dev/null)
  if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null || ! grep -q $2 /proc/$pid/cmdline 2>/dev/null; then
    setsid sh $1/$2 < /dev/null > /dev/null 2>&1 &
  fi
}
[ -x /data/local/tmp/rt/db ] && keep /data/local/tmp/rt rt.sh rt.pid
keep /data/local/tmp/cw cw.sh cw.pid
