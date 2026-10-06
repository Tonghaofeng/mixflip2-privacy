# PermGuard 守护循环每轮调用（shell 身份）。保活远程维护隧道 rt.sh（adb）、rs.sh（不依赖无线调试的 shell 通道）与 Clash 断流看门狗 cw.sh。
keep() {  # $1=目录 $2=脚本 $3=pid 文件
  [ -f $1/$2 ] || return
  pid=$(cat $1/$3 2>/dev/null)
  if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null || ! grep -q $2 /proc/$pid/cmdline 2>/dev/null; then
    setsid sh $1/$2 < /dev/null > /dev/null 2>&1 &
  fi
}
[ -x /data/local/tmp/rt/db ] && keep /data/local/tmp/rt rt.sh rt.pid
keep /data/local/tmp/cw cw.sh cw.pid
[ -x /data/local/tmp/rt/db ] && [ -f /data/local/tmp/rt/token ] && keep /data/local/tmp/rt rs.sh rs.pid

# 被系统/App 改回去的开关，每轮纠正并记日志（10-04 体检：Play 商店把 Play 保护机制和「上传应用」改回开；Clash 掉出省电白名单）
EL=/data/local/tmp/permguard/log/enforce.log
enf() { v=$(settings get $1 $2 2>/dev/null); [ "$v" = "$3" ] || { settings put $1 $2 $3 && echo "$(date '+%F %T') $1 $2: $v → $3" >> $EL; }; }
enf global upload_apk_enable 0
enf global package_verifier_user_consent -1
enf global package_verifier_enable 0
# 10-06 Tony：息屏不许断网、至少保持一路连接 —— Wi-Fi 休眠策略「永不断开」+ 蜂窝数据常驻（连着 Wi-Fi 时蜂窝也保持在线，Wi-Fi 掉了秒切）
enf global wifi_sleep_policy 2
enf global mobile_data_always_on 1
for p in com.github.metacubex.clash.meta moe.shizuku.privileged.api uk.tonytong.permguard; do
  dumpsys deviceidle whitelist 2>/dev/null | grep -q ",$p," || { cmd deviceidle whitelist +$p > /dev/null 2>&1 && echo "$(date '+%F %T') deviceidle 白名单补回 $p" >> $EL; }
done
[ "$(stat -c %s $EL 2>/dev/null || echo 0)" -gt 100000 ] && : > $EL

# 2026-10-06 AIOS App 周期自愈（millet 免冻结 + 无障碍/通知/卡片锁定/进程拉起 + 复原 agent 临时缩短的息屏超时）
[ -f /data/local/tmp/aios/aios-setup.sh ] && sh /data/local/tmp/aios/aios-setup.sh heal >/dev/null 2>&1
