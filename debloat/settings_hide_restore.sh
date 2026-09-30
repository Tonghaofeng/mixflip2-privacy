#!/bin/zsh
# 回滚 2026-10-01「设置菜单瘦身」（见 settings_hide.md）。
# 小米账号装回后需在设置里重新登录。ex_func 开关没有改动，无需回滚。
adb shell -n settings put secure quick_control_all_devices 1
adb shell -n settings delete secure smart_device_control      # 原值为 null
echo "com.xiaomi.account: $(adb shell -n cmd package install-existing com.xiaomi.account)"
