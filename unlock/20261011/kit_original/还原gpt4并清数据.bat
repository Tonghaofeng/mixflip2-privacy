@echo off
fastboot flash partition:4 mi_gpt_both4.bin
fastboot erase userdata
fastboot erase metadata
fastboot reboot
pause