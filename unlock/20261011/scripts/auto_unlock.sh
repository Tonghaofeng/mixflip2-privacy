#!/bin/zsh
# bixi BL 解锁自动流（EDL watcher 版）
# 阶段: WAIT_EDL → GPT+备份 → 写工程abl → RESET → WAIT_FASTBOOT → flashing unlock → 还原abl → reboot
# 状态写 op_status.txt；任何一步失败写 FAIL 并停。日志 op.log
export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
cd /Users/Tony/PhoneBackups/op
EDL="/Users/Tony/PhoneBackups/venv-edl/bin/python3 /Users/Tony/PhoneBackups/unlock_tools/edl-src/edl.py --loader=/Users/Tony/PhoneBackups/op/fhprg_8E_noauth.bin"
LOADER_VIDPID="05c6:9008"

say() { echo "[$(date +%H:%M:%S)] $*" | tee -a op.log; }
fail() { echo "FAIL" > op_status.txt; say "❌ FAIL: $*"; exit 1; }

echo "RUNNING_STAGE1" > op_status.txt
say "等待 9008 设备出现（Tony: 关机→按住音量上+下→插线）..."

# --- 等 EDL（最多10分钟）---
seen=0
for i in $(seq 1 600); do
  if ioreg -p IOUSB -w 0 2>/dev/null | grep -qi "qualcomm\|QDLoader\|9008"; then seen=1; break; fi
  if system_profiler SPUSBDataType 2>/dev/null | grep -qi "Qualcomm HS-USB\|9008"; then seen=1; break; fi
  sleep 1
done
[ $seen = 1 ] || fail "10分钟没等到 9008 设备"
say "✅ 9008 设备已出现"

# --- GPT + abl 备份 ---
say "读 GPT..."
$EDL printgpt > gpt_backup.txt 2>> op.log || fail "printgpt 失败（loader 被拒=9008 熔断，或驱动问题）"
say "✅ GPT 已存 gpt_backup.txt"
say "备份原厂 abl..."
$EDL rs abl abl_stock_backup.bin >> op.log 2>&1 || fail "备份 abl 失败"
SZ=$(stat -f%z abl_stock_backup.bin); say "原厂 abl 备份 ${SZ}B"
[ "$SZ" -gt 100000 ] || fail "abl 备份尺寸异常"

# --- 写工程 abl ---
say "写入工程 abl（Xiaomi15, SM8750 同源）..."
$EDL w abl eng_abl.elf >> op.log 2>&1 || fail "写工程 abl 失败"
say "✅ 工程 abl 已写入，重启设备..."
$EDL reset >> op.log 2>&1 || say "reset 命令未应答（正常，设备自己会重启）"

# --- 等 fastboot ---
say "等待 fastboot 设备（工程 abl 引导）..."
fbseen=0
for i in $(seq 1 90); do
  if fastboot devices 2>/dev/null | grep -qi "fastboot"; then fbseen=1; break; fi
  sleep 2
done
[ $fbseen = 1 ] || fail "90秒没等到 fastboot（工程 abl 可能不兼容 bixi；恢复=关机后音量上下+插线回 EDL，我重刷原厂 abl）"
say "✅ fastboot 在线：$(fastboot devices)"

# --- 解锁（Tony 按音量上确认）---
echo "UNLOCK_CONFIRM_WAIT" > op_status.txt
say ">>> 现在向手机发 flashing unlock；屏幕出现确认页时【按音量上】选择 UNLOCK <<<"
fastboot flashing unlock >> op.log 2>&1 || say "unlock 命令返回非零，检查屏幕"
sleep 3
U=$(fastboot getvar unlocked 2>&1 | head -1)
say "解锁状态: $U"
echo "$U" | grep -qi "unlocked: *yes" || fail "设备仍为锁定（确认没按？重跑：fastboot flashing unlock）"

# --- 还原原厂 abl ---
say "写回原厂 abl..."
fastboot flash abl abl.elf >> op.log 2>&1 || fail "还原 abl 失败（!!此时已解锁，EDL 可救）"
say "✅ 原 abl 已还原，重启进系统（全新 3.0.304，数据已清）"
fastboot reboot >> op.log 2>&1
echo "STAGE1_DONE" > op_status.txt
say "🎉 解锁完成。等手机开机走初始设置（Tony: 语言/WiFi/PIN，跳过账号），开 USB 调试后叫我"
