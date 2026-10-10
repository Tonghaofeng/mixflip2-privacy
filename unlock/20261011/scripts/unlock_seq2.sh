#!/bin/bash
K=/Users/Tony/PhoneBackups/unlock_tools/bixi_unlock_kit
run() { perl -e 'alarm shift; exec @ARGV' "$@"; }
pkill -9 usbmuxd 2>/dev/null
sleep 4
echo "=== devices:"; run 15 fastboot devices
echo "=== 基线:"; run 15 fastboot getvar unlocked 2>&1
echo "=== 刷魔改GPT:"; run 90 fastboot flash partition:4 $K/jiesuo_gpt_both4.bin 2>&1
echo "=== boot解锁:"; run 150 fastboot boot $K/boot.img 2>&1
sleep 25
echo "=== 复查:"; run 15 fastboot getvar unlocked 2>&1
echo "=== SEQ2_END"
