# 病毒扫描 / 云扫描 / 电诈防护 切断记录（2026-10-01 晚）

## 起因
22:08 安全中心发通知「您已超7天未进行病毒扫描」（id 1012，渠道 com.miui.securitycenter；20:02 也发过一次）。
点进去是 `com.miui.antivirus.activity.MainActivity`，首屏弹窗原文：

> **使用云扫描** —— 为了提升病毒扫描能力，我们会上传**应用包名和应用的特征**至云病毒引擎进行扫描；本功能使用了合作方提供的杀毒引擎，详情可见《杀毒引擎许可协议》。［不同意］［同意］

## 反编译结论（安全中心 MIUISecurityCenter.apk + 设置 + framework/services）
| 事实 | 证据 |
|---|---|
| 提醒判据只读 `secure key_latest_virus_scan_date`：值 ≤0 或距今 ≤7(或10) 天直接 return | `p352z1/r.G()` |
| 该键只在一次扫描完成时写入 | `p282u1/k`（扫描结束 putLong） |
| 扫描引擎在 **com.miui.guardprovider**：前台扫描、后台 `VirusScanJobService`（job 210610，扫指定应用、发现风险还会处置）、病毒库更新 `VirusAutoUpdateJobService`（job 99）全部 bind 它 | `com/miui/antivirus/service/*` |
| 安全中心本体**没有**第三方杀毒 SDK；antivirus / securityscan / electricrisk(电诈) / appmanager / networkassistant 的扫描调用全部指向 guardprovider | 源码包名清点 + `IAntiVirusServer`/`content://guard` 引用统计 |
| guardprovider 持有特权：CAPTURE_AUDIO_OUTPUT、**CAPTURE_VOICE_COMMUNICATION_OUTPUT**、MANAGE_MEDIA_PROJECTION、**MANAGE_EXTERNAL_STORAGE**、WRITE_SECURE_SETTINGS、QUERY_ALL_PACKAGES、MODIFY_PHONE_STATE | `dumpsys package com.miui.guardprovider` |
| 打开「AI 反诈守护」时安全中心会给 guardprovider 授 **RECORD_AUDIO** | `AiGuardUtils.setAiGuardEnable` |
| 电诈防护 4 类开关：通话 `system cloud_antispam`(+`key_yellowpage_main_switch`)、短信 `secure settings_sms_risk_warn_enable` / `settings_sms_code_clipboard_warn_enable`、应用（安全中心私有 prefs，shell 读写被 signatureOrSystem 权限拒）、屏幕共享 `secure screen_share_protection`；网页 `secure com.android.browser.web_page_warning_states` | `com/miui/electricrisk/p.java`、`U7/z.java` |

## 做了什么
1. `pm uninstall --user 0 com.miui.guardprovider`（22:31:40）；等 3 分钟后 `svc power reboot`，`WATCH=90 postboot_check` 全过（91 个包全部未装、无系统级崩溃、SystemUI 稳定）。
   删前按铁律查了它的 3 个 authority（`guard`、`com.miui.guardprovider.virusscan`、androidx-startup），**无任何常驻进程注册 ContentObserver**。
2. `secure key_latest_virus_scan_date` 1786942124898 → **0**；通知 1012 已 snooze 到 2036；job 99 / 210610 已 cancel。
3. 显式置 0（原为 null 走缺省）：`secure com.android.browser.web_page_warning_states`、`ai_guard_function_switch`、`com.miui.guardprovider.AI_GUARD_PRIVACY_AGREEMENT`、`optimizer_scan_cloud`；`system cloud_antispam`、`key_yellowpage_main_switch`。其余电诈开关早已是 0。
4. UI 读回：电诈防护页 通话/短信/应用/屏幕共享 4 项全「未开启」；病毒扫描页点「不同意」→ 页面直接退出、不扫描。
5. 全部纳入 `tools/postboot_check.sh`；回滚 `debloat/antivirus_antifraud_restore.sh`。

网络面：安全中心是 UID 1000，早被 Clash 整身份 REJECT（锁定模式，Clash 一停=整机断网）；今晚安装器连 `tracking.miui.com` 四次全部 REJECT（日志可证）。

## 代价与替代
- **adb 装包**：USB 安装确认页 `AdbInstallActivity` 调 `content://guard` 的 parseApk，缺 guardprovider 就 `Invalid apk` → `tools/adb_install.sh <apk>`（临时 install-existing → 装 → 无论成败再卸）。另外国行「USB 安装」开关要过小米账号验证，账号已删后验证页空白、开不了。
- **手机端装 APK**：经 **Chrome 下载 → 打开** 正常走到小米安装器确认（`FullSafeStrategyType:NO_NETWORK`，不因缺引擎受阻）；Google Files 交给安装器报「错误 33」= `error reading session apk`（两者会话兼容问题，与引擎无关）。

## 删不掉的两个入口（设置→隐私与安全→安全）
| 入口 | 显示判据 | 为什么删不掉 |
|---|---|---|
| 电诈防护 | `TelephonyManager.isVoiceCapable()` | 改它=手机不能打电话。改页面 XML 需覆盖层：安全中心未声明 overlayable，自签 RRO 过不了 idmap 策略（推断，未装成实测）；shell 造 fabricated overlay 被 OMS 写死拒绝：`if (callingUid == 2000) throw "Non-root shell cannot fabricate overlays"`（b/202768292，cmd 与 binder API 同拦） |
| 手机管家 | `ro.miui.support.system.app.uninstall.v2`（ro，改不了）且**未装** `com.miui.securitymanager` | 按「自写空壳顶替」思路构建了无代码空壳（`stubs/securitymanager`），经 Chrome→小米安装器安装被系统拒：`PKMSImpl.assertCallerAndPackage … FAILED_VERIFICATION_FAILURE SIGNATURE FAIL`（安装器报 -22）= MIUI 对小米保留包名做签名强校验 |

两个入口现在都是死壳：引擎已删、开关全关、所在身份无网。
