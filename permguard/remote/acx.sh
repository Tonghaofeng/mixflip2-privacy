#!/system/bin/sh
# Clash Meta 访问控制：把 com.android.shell 设为绕过 VPN（on）或取消绕过（off）。用法：acx.sh on|off
# Clash 运行时这些选项改不了，所以：暂停看门狗 → STOP → 界面操作 → START。全程在手机本地跑，不依赖远程通道。
# 读勾选状态：uiautomator dump 里 text="com.android.shell" 之后第一个 switch_view 复选框的 checked。
# 安全：独立会话的保险进程 180 秒后 Clash 还没起来就强制 START；任何一步失败都直接 START 收尾。日志 cw/ac.log。
WANT=${1:-on}
D=/data/local/tmp/cw; cd $D || exit 1
. /data/local/tmp/rt/ui.sh
PKG=com.github.metacubex.clash.meta; ACT=$PKG/com.github.kr328.clash.ExternalControlActivity
L=$D/ac.log
log() { echo "$(date '+%T') [$WANT] $*" >> $L; }
snap() { dump; cp /sdcard/.u.xml $D/ac-$1.xml 2>/dev/null; }
start_clash() { am start -n $ACT -a $PKG.action.START_CLASH > /dev/null 2>&1; }
vpn_up() { dumpsys connectivity 2>/dev/null | grep -q "VPN:$PKG"; }
tapd() { dump; c=$(center "content-desc=\"$1\"") || return 1; input tap $c; }
# 找不到就往下滑再找（折叠屏外屏/小窗时主界面放不下「设置」）
seek() { for k in 1 2 3 4 5; do has "$1" && return 0; input swipe 500 1500 500 500 250; sleep 1; done; has "$1"; }
shell_state() { dump; tr '>' '\n' < /sdcard/.u.xml | awk '/text="com.android.shell"/{f=1} f && /switch_view/{match($0,/checked="[a-z]*"/); print substr($0,RSTART+9,RLENGTH-10); exit}'; }
fin() {
  for k in 1 2 3 4; do input keyevent KEYCODE_BACK; sleep 1; done
  start_clash; sleep 15
  vpn_up && log "Clash 已启动（$1）" || { log "START 后 VPN 没起来，再拉一次"; start_clash; sleep 10; }
  rm -f $D/pause_until
  [ "$1" = 完成 ] && exit 0 || exit 1
}
echo $(( $(date +%s) + 300 )) > $D/pause_until
setsid sh -c "sleep 180; dumpsys connectivity | grep -q 'VPN:$PKG' || am start -n $ACT -a $PKG.action.START_CLASH" < /dev/null > /dev/null 2>&1 &

input keyevent KEYCODE_WAKEUP
monkey -p $PKG -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1; sleep 3
if ! seek "设置"; then snap pre; log "屏幕不可操作（锁屏/防误触？），未停 Clash，退出"; rm -f $D/pause_until; exit 2; fi
log "停 Clash"
am start -n $ACT -a $PKG.action.STOP_CLASH > /dev/null 2>&1; sleep 5
monkey -p $PKG -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1; sleep 3
seek "设置"; tapt "设置" || { snap main; log "找不到 设置"; fin 失败; }; sleep 2
seek "网络"; tapt "网络" || { snap settings; log "找不到 网络"; fin 失败; }; sleep 2
if [ $WANT = on ]; then
  seek "访问控制模式"; tapt "访问控制模式" || { snap net; log "找不到 访问控制模式"; fin 失败; }; sleep 2
  has "不允许已选择的应用" && tapt "不允许已选择的应用" && log "模式 → 不允许已选择的应用" || { snap mode; log "没有『不允许已选择的应用』"; fin 失败; }
  sleep 2
fi
seek "访问控制应用包列表"; tapt "访问控制应用包列表" || { snap net2; log "找不到 应用包列表"; fin 失败; }; sleep 3
# 「更多 → 过滤 → 系统应用」勾上 = 把系统应用过滤掉（看不到 Shell）。确保它是不勾的状态（10-05 14:28 曾按反了）。
tapd "更多" || tapt "更多"; sleep 1; tapt "过滤"; sleep 1; snap filter
if grep -o 'text="系统应用"[^>]*' /sdcard/.u.xml | grep -q 'checked="true"'; then tapt "系统应用"; log "取消 过滤系统应用"; else input keyevent KEYCODE_BACK; sleep 1; has "过滤" && input keyevent KEYCODE_BACK; fi
sleep 2
found=0
for i in $(seq 1 60); do has "com.android.shell" && { found=1; break; }; input swipe 600 2300 600 900 250; sleep 1; done
[ $found = 1 ] || { snap list; log "列表里没找到 com.android.shell"; fin 失败; }
target=true; [ $WANT = off ] && target=false
st=$(shell_state)
if [ "$st" != "$target" ]; then c=$(center 'text="com.android.shell"'); input tap $c; sleep 1; st=$(shell_state); fi
snap list
[ "$st" = "$target" ] && log "Shell 勾选 = $st（目标 $target）" || { log "Shell 勾选 = $st，没达到目标 $target"; fin 失败; }
fin 完成
