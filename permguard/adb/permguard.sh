#!/bin/zsh
# permguard adb 版：Mac 经 adb 跑同一套规则（规则引擎 core/permguard.dex = 手机 App 里的同一份代码）。
#   permguard.sh --dry-run            只算不改，清单写 evidence/permguard_<日期>/plan.md|tsv
#   permguard.sh --apply              先在手机上写快照（同时拉回 permguard/state/），再收回，回读核对
#   permguard.sh --verify             实际状态表 verify.md/csv + 「关不掉」清单 unfixable.md（含系统 App）
#   permguard.sh --restore [快照]     回滚到快照（默认手机上最新一份；给本机 permguard/state/ 里的文件则先推上去）
#   permguard.sh --status | --daemon-start | --daemon-stop | --logs
# 环境变量：ADB_SERIAL（默认无线调试序列号）、OUT（证据目录，默认 evidence/permguard_<日期>）
set -euo pipefail
R=${0:A:h:h}            # permguard/
REPO=${R:h}
D=/data/local/tmp/permguard
A=(adb -s ${ADB_SERIAL:-adb-7f37d4d8-qKCl29._adb-tls-connect._tcp})
OUT=${OUT:-$REPO/evidence/permguard_$(date +%Y%m%d)}
DEX=$R/core/permguard.dex

st=$($A get-state 2>/dev/null | tr -d '\r' || true)
[ "$st" = device ] || { echo "❌ adb 连不上（state=${st:-none}）。无线调试：adb mdns services 找端口后 adb connect"; exit 2; }
[ -f $DEX ] || { echo "缺 $DEX，先跑 permguard/core/build.sh"; exit 2; }

push() {
  $A shell -n "mkdir -p $D/log $D/state $D/out"
  $A push -q $DEX $D/permguard.dex.new >/dev/null
  $A shell -n "chmod 444 $D/permguard.dex.new && mv -f $D/permguard.dex.new $D/permguard.dex"
  # 先推 .new 再 mv：守护循环的 sh 正在读 pg.sh，原地覆盖会打乱它
  $A push -q $R/phone/pg.sh $D/pg.sh.new >/dev/null
  $A push -q $R/whitelist.conf $D/whitelist.conf.new >/dev/null
  $A shell -n "mv -f $D/pg.sh.new $D/pg.sh && mv -f $D/whitelist.conf.new $D/whitelist.conf"
}
# adb 跑的一律用推上去的 dex（PG_CP），不改 App 写的 classpath
pg() { $A shell -n "PG_CP=$D/permguard.dex sh $D/pg.sh $*"; }
pull_state() { mkdir -p $R/state; $A pull -q $D/state/. $R/state/ >/dev/null && echo "快照/日志已拉回 permguard/state/（$(ls $R/state | wc -l | tr -d ' ') 个文件）"; }

case "${1:-}" in
  --dry-run)
    push; mkdir -p $OUT
    pg run plan | tee $OUT/plan_stdout.txt
    $A pull -q $D/out/plan.md $OUT/plan.md >/dev/null; $A pull -q $D/out/plan.tsv $OUT/plan.tsv >/dev/null
    echo "→ $OUT/plan.md" ;;
  --apply)
    push; mkdir -p $OUT
    set +e; pg run apply | tee $OUT/apply_stdout.txt; rc=${pipestatus[1]}; set -e
    pull_state
    $A pull -q $D/out/last-apply.md $OUT/apply.md >/dev/null || true
    echo "→ $OUT/apply.md（rc=$rc：0 正常 / 3 有推迟项 / 1 失败）"; exit $rc ;;
  --verify)
    push; mkdir -p $OUT
    pg run verify --system | tee $OUT/verify_stdout.txt
    for f in verify.md verify.csv unfixable.md verify-items.tsv; do $A pull -q $D/out/$f $OUT/$f >/dev/null; done
    echo "→ $OUT/verify.md  $OUT/unfixable.md" ;;
  --restore)
    push
    if [ -n "${2:-}" ]; then
      f=${2:A}; $A push -q $f $D/state/${f:t} >/dev/null; pg run restore --snapshot $D/state/${f:t}
    else
      pg run restore
    fi ;;
  --status) pg status ;;
  --daemon-start)   # 没装 App 时由 adb 拉起守护（重启即失）
    push; $A shell -n "[ -s $D/classpath ] || echo $D/permguard.dex > $D/classpath"; $A shell -n "sh $D/pg.sh daemon-start" ;;
  --daemon-stop) push; $A shell -n "sh $D/pg.sh daemon-stop" ;;
  --logs) $A shell -n "tail -n ${2:-80} $D/log/permguard.log" ;;
  *) sed -n '2,9p' $0; exit 2 ;;
esac
