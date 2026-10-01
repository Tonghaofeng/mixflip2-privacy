#!/bin/zsh
# 回滚 2026-10-01 晚「病毒扫描 / 电诈防护」切断（见 antivirus_antifraud.md）。
# 原值：key_latest_virus_scan_date=1786942124898，其余 6 个键原为 null（代码缺省值）。
adb shell -n settings put secure key_latest_virus_scan_date 1786942124898
adb shell -n settings delete secure com.android.browser.web_page_warning_states
adb shell -n settings delete secure ai_guard_function_switch
adb shell -n settings delete secure com.miui.guardprovider.AI_GUARD_PRIVACY_AGREEMENT
adb shell -n settings delete secure optimizer_scan_cloud
adb shell -n settings delete system cloud_antispam
adb shell -n settings delete system key_yellowpage_main_switch
adb shell -n settings put global package_verifier_user_consent 1   # Play 保护机制扫描（10-01 晚关，原值 1）
adb shell -n settings delete global package_verifier_enable          # 原值 null
adb shell -n settings put global wifi_scan_always_enabled 1        # 10-01 晚关，原值 1（定位用 Wi-Fi 常扫描）
adb shell -n settings put global need_receive_offline_find_broadcast 1   # 小米离线查找「参与网络」真开关（原写入方 finddevice 已删，原值 1）
# OFFLINE_FIND_SCAN/_SWITCH/_NO_*_BROADCAST 是蓝牙插件云控（MiuiCloudControl）每次开机按 fc_offline_find.json 重写的「支持位」，无需回滚
# Chrome「帮助改进 Chrome 的功能和性能」在 Chrome 设置→Google 服务里手动打开（Chrome 私有偏好，无 shell 接口）
echo "com.miui.guardprovider: $(adb shell -n cmd package install-existing com.miui.guardprovider)"
