#!/system/bin/sh
# permguard 手机端驱动（shell 身份：adb shell 或 Shizuku 起的进程）。App 每次运行都会把本文件写到 $D/pg.sh。
#   sh pg.sh run plan|apply|verify|restore [Core 参数…]   加锁运行规则引擎，输出追加到 $D/log/permguard.log
#   sh pg.sh daemon-start | daemon-stop | status
# 守护循环（shell 身份，App 被「一键清理」强停也不受影响；重启后要靠 App/Shizuku 或 adb 再拉起）：
#   每 POLL 秒看一次第三方包列表；距上次 apply ≥ INTERVAL、包列表变了（新装/卸载）、或上轮有推迟项满 RETRY 秒 → apply
D=${PG_DIR:-/data/local/tmp/permguard}
INTERVAL=${PG_INTERVAL:-21600}
POLL=${PG_POLL:-300}
RETRY=${PG_RETRY:-900}
LOG=$D/log/permguard.log
mkdir -p "$D/log" "$D/state" "$D/out"

log() { echo "$(date '+%F %T') [pg $$] $*" >> "$LOG"; }

rotate() {
  sz=$(stat -c %s "$LOG" 2>/dev/null || echo 0)
  [ "$sz" -gt 524288 ] && mv -f "$LOG" "$LOG.1"
}

classpath() {
  if [ -n "$PG_CP" ]; then echo "$PG_CP"; return; fi
  cp=$(cat "$D/classpath" 2>/dev/null)
  [ -n "$cp" ] && [ -r "$cp" ] && { echo "$cp"; return; }
  echo "$D/permguard.dex"
}

run_core() {   # 加锁：mkdir 是原子的；锁超过 15 分钟视为残留
  if ! mkdir "$D/lock" 2>/dev/null; then
    age=$(( $(date +%s) - $(stat -c %Y "$D/lock" 2>/dev/null || echo 0) ))
    if [ "$age" -gt 900 ]; then rmdir "$D/lock" 2>/dev/null; mkdir "$D/lock" 2>/dev/null || { echo "BUSY"; return 4; }
    else echo "BUSY 另一轮正在跑"; return 4; fi
  fi
  rotate
  mode=$1; shift
  cp=$(classpath)
  log "run $mode $* (cp=$cp)"
  out=$D/log/last-$mode.log
  CLASSPATH="$cp" app_process /system/bin uk.tonytong.permguard.Core "$mode" --dir "$D" "$@" > "$out" 2>&1
  rc=$?
  cat "$out" >> "$LOG"
  log "end $mode rc=$rc"
  [ "$mode" = apply ] && [ "$rc" -ne 1 ] && date +%s > "$D/last_apply"
  rmdir "$D/lock" 2>/dev/null
  cat "$out"
  return $rc
}

daemon_alive() {
  pid=$(cat "$D/pgd.pid" 2>/dev/null)
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && grep -q daemon-loop "/proc/$pid/cmdline" 2>/dev/null
}

case "$1" in
  run)
    shift; run_core "$@"; exit $? ;;
  daemon-start)
    if daemon_alive; then echo "daemon 已在运行 pid=$(cat "$D/pgd.pid")"; exit 0; fi
    setsid sh "$D/pg.sh" daemon-loop < /dev/null > /dev/null 2>&1 &
    sleep 1
    daemon_alive && echo "daemon 已启动 pid=$(cat "$D/pgd.pid")" || { echo "daemon 启动失败"; exit 1; } ;;
  daemon-stop)   # 先删 pid 文件（循环下轮自检会退出），再杀它正在等的 sleep 和它本身（sh 等子进程时 SIGTERM 会被延后）
    if daemon_alive; then
      pid=$(cat "$D/pgd.pid"); rm -f "$D/pgd.pid"
      pkill -P "$pid" 2>/dev/null; kill "$pid" 2>/dev/null; echo "daemon 已停 pid=$pid"
    else rm -f "$D/pgd.pid"; fi ;;
  daemon-loop)
    echo $$ > "$D/pgd.pid"
    log "daemon start interval=${INTERVAL}s poll=${POLL}s"
    lastpk=""; retry_at=0
    while :; do
      [ "$(cat "$D/pgd.pid" 2>/dev/null)" = "$$" ] || { log "daemon 被替换/停止，退出"; exit 0; }
      # 可选钩子：$D/hooks.sh 不随 App 覆盖，每轮跑一次（如保活远程维护隧道 /data/local/tmp/rt/rt.sh）
      [ -f "$D/hooks.sh" ] && sh "$D/hooks.sh" < /dev/null > /dev/null 2>&1
      now=$(date +%s)
      last=$(cat "$D/last_apply" 2>/dev/null || echo 0)
      pk=$(cmd package list packages -3 --user 0 | sort | md5sum | cut -c1-32)
      why=""
      [ $((now - last)) -ge "$INTERVAL" ] && why="定时"
      [ -n "$lastpk" ] && [ "$pk" != "$lastpk" ] && why="${why:+$why+}应用变更"
      [ "$retry_at" -gt 0 ] && [ "$now" -ge "$retry_at" ] && why="${why:+$why+}推迟重试"
      if [ -n "$why" ]; then
        run_core apply > /dev/null
        rc=$?
        log "daemon apply 触发=$why rc=$rc"
        retry_at=0; [ "$rc" -eq 3 ] && retry_at=$((now + RETRY))
        [ "$rc" -eq 1 ] && sleep "$RETRY"   # 出错（如白名单写错被拒）别每 5 分钟刷一遍日志
      fi
      lastpk=$pk
      sleep "$POLL"
    done ;;
  status)
    daemon_alive && echo "daemon: 运行中 pid=$(cat "$D/pgd.pid")" || echo "daemon: 未运行"
    last=$(cat "$D/last_apply" 2>/dev/null || echo 0)
    echo "上次 apply: $( [ "$last" -gt 0 ] && date -d "@$last" '+%F %T' || echo 从未 )"
    echo "classpath: $(classpath)"
    grep -h '^SUMMARY' "$D/log/last-apply.log" 2>/dev/null | tail -1 ;;
  *)
    echo "用法: pg.sh run <mode> … | daemon-start | daemon-stop | status"; exit 2 ;;
esac
