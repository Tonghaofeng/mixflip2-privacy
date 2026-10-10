@echo off
adb.exe reboot bootloader
fastboot.exe oem set-gpu-preemption 0 androidboot.selinux=permissive
fastboot continue
timeout /t 15
adb shell getenforce
adb.exe devices
adb.exe push abl.elf /data/local/tmp/abl
adb.exe shell service call miui.mqsas.IMQSNative 21 i32 1 s16 "dd" i32 1 s16 'if=/data/local/tmp/abl of=/dev/block/by-name/abl_a' s16 '/data/mqsas/log.txt' i32 60
adb.exe shell service call miui.mqsas.IMQSNative 21 i32 1 s16 "dd" i32 1 s16 'if=/data/local/tmp/abl of=/dev/block/by-name/abl_b' s16 '/data/mqsas/log.txt' i32 60
adb reboot bootloader
timeout /t 15
fastboot flash partition:4 jiesuo_gpt_both4.bin
fastboot boot boot.img
pause