@echo off
fastboot deivces
fastboot flash partition:4 jiesuo_gpt_both4.bin
fastboot boot boot.img
pause