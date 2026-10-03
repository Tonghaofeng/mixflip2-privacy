#!/bin/zsh
# 给 PermGuard「Shizuku 守门员」配对 adb 钥匙（一次性；PermGuard 卸载/清数据、或「撤销 USB 调试授权」后重跑）。全程不用碰手机：
#   1. 临时 adb server（独立 HOME 与端口，LOGNAME/HOSTNAME 定名 permguard@bixi）生成专用 RSA-2048
#   2. shell 持有 MANAGE_DEBUGGING：`service call adb 9` = IAdbManager.enablePairingByQrCode(服务名, 口令)，口令由我们定
#      （事务码在本机 framework.jar 的 IAdbManager$Stub 实测：6 getPairedDevices / 7 unpairDevice / 9 / 10 getAdbWirelessPort / 11 disablePairing；
#       3 是 clearDebuggingKeys，别碰）
#   3. adb forward 到配对端口，临时 server `adb pair` → 钥匙进 adb_keys（设置 → 无线调试 → 已配对设备里叫 permguard@bixi）
#      注：adb pair 发的公钥由它的私钥算出、不读 adbkey.pub，所以没法只配 App 自己生成的公钥，只能这边生成再推过去
#   4. 私钥转 PKCS#8 DER 推到 App 外部私有目录 adbkey.import，守门员收进设备加密存储并删掉；Mac 上临时目录随即删除
#   5. 让 App 真连一次 adbd 自检（wd-selftest），看 logcat PermGuardWD
# 用法（在 zsh -lc 里跑）: ADB_SERIAL=127.0.0.1:15556 permguard/adb/pair_watchdog.sh     已配过还想重配: PG_REPAIR=1
set -uo pipefail
S=${ADB_SERIAL:-adb-7f37d4d8-qKCl29._adb-tls-connect._tcp}
A=(adb -s $S)
PG=uk.tonytong.permguard
EXT=/sdcard/Android/data/$PG/files
LP=${PAIR_LOCAL_PORT:-15557}; SP=${PAIR_SERVER_PORT:-5099}
[ "$($A get-state 2>/dev/null | tr -d '\r')" = device ] || { echo "❌ adb 连不上 $S"; exit 2; }
$A shell -n pm grant $PG android.permission.WRITE_SECURE_SETTINGS

paired() { [ -n "$1" ] && $A shell -n dumpsys adb | tr -d '\r' | grep -aqF -- "$1"; }
apppub=$($A shell -n cat $EXT/adbkey.pub 2>/dev/null | tr -d '\r')
if [ -z "${PG_REPAIR:-}" ] && paired "${apppub%% *}"; then
  echo "✅ App 钥匙已在 adb_keys（${apppub##* }），不用再配对（重配用 PG_REPAIR=1）"
else
  T=$(mktemp -d)
  tadb() { env -u ANDROID_USER_HOME -u ANDROID_SDK_HOME HOME=$T LOGNAME=permguard HOSTNAME=${PG_KEY_HOST:-bixi} adb -P $SP "$@"; }
  cleanup() { tadb kill-server >/dev/null 2>&1; $A forward --remove tcp:$LP >/dev/null 2>&1; $A shell -n service call adb 11 >/dev/null 2>&1; rm -rf $T; }
  trap cleanup EXIT
  tadb start-server >/dev/null 2>&1
  [ -f $T/.android/adbkey ] && [ -f $T/.android/adbkey.pub ] || { echo "❌ 临时 adb server 没生成钥匙"; exit 1; }
  pub=$(<$T/.android/adbkey.pub); pub=${pub%%$'\n'}; echo "新钥匙 ${pub##* }"

  lp() { $A shell -n "awk '\$4==\"0A\" && \$8==1000 {split(\$2,a,\":\"); print a[2]}' /proc/net/tcp6 /proc/net/tcp" | tr -d '\r' | sort -u; }
  before=$(lp)
  pw=$(LC_ALL=C tr -dc 0-9 </dev/urandom | head -c 10)
  $A shell -n service call adb 9 s16 permguard-pair s16 $pw >/dev/null
  sleep 2
  hex=$(comm -13 <(print -r -- $before) <(lp) | head -1)
  [ -n "$hex" ] || { echo "❌ 没找到配对端口（无线调试开着吗？）"; exit 1; }
  port=$((16#$hex)); echo "配对端口 $port"
  $A forward tcp:$LP tcp:$port >/dev/null
  tadb pair 127.0.0.1:$LP $pw
  sleep 1
  paired "${pub%% *}" || { echo "❌ 配对后 adb_keys 里没有新钥匙"; exit 1; }
  echo "✅ 已配对 ${pub##* }"

  openssl pkcs8 -topk8 -nocrypt -in $T/.android/adbkey -outform DER -out $T/adbkey.pk8 || exit 1
  $A push $T/adbkey.pk8 $EXT/adbkey.import >/dev/null || exit 1
  echo "私钥已推给 App（下一轮守门员收进设备加密存储并删掉外部那份）"
fi

echo "== 自检：App 经无线调试真连一次本机 adbd"
t0=$($A shell -n "date '+%m-%d %H:%M:%S.000'" | tr -d '\r')   # 不清 logcat（证据），从此刻读起
$A shell -n "touch $EXT/wd-selftest; cmd jobscheduler run -f $PG 3" >/dev/null
for i in {1..60}; do
  sleep 2
  out=$($A shell -n "logcat -d -T '$t0' -s PermGuardWD:I" | tr -d '\r' | grep -E '结果|拒绝|出错|adbd:|SZ=|daemon' )
  [[ $out == *结果* ]] && break
done
print -r -- "$out"
[[ $out == *"结果 ok:"* ]] || { echo "❌ 自检没过"; exit 1; }
apppub=$($A shell -n cat $EXT/adbkey.pub 2>/dev/null | tr -d '\r')
[ -n "${pub:-}" ] && { [ "${apppub%% *}" = "${pub%% *}" ] && echo "App 算出的公钥与 adb 一致" || echo "⚠️ App 算出的公钥与 adb 不一致（只影响核对，不影响连接）"; }
$A shell -n ls $EXT/adbkey.import >/dev/null 2>&1 && echo "⚠️ 外部目录还留着 adbkey.import"
echo "✅ 守门员可用"
