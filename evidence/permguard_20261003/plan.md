# permguard plan（dry-run，未改任何东西）20261003-010008

- 设备：`Xiaomi/bixi/bixi:16/BP2A.250605.031.A3/OS3.0.304.0.WOHCNXM:user/release-keys`；第三方 App 51 个；permguard 2026.10.03
- 收回 49 项 / 25 个 App；推迟 0；保留（白名单/角色/豁免）87；只报告 4；系统固定 0

## 收回（49）

| App | 组 | 权限 / appop | 当前 | 动作 | 理由 |
|---|---|---|---|---|---|
| com.android.soundrecorder | PHONE | 10039 OP_GET_PHONE_NUMBER_OPERATOR 运营商取本机号码 | allow | ignore | 默认拒绝 |
| com.anthropic.claude | AD_ID | 10037 OP_GET_OAID 广告标识符 OAID | allow (最近使用 1d7h59m33s696ms 前) | ignore | 默认拒绝 |
| com.azure.authenticator | CAMERA | CAMERA | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | revoke | 默认拒绝 |
| com.azure.authenticator | AD_ID | 10037 OP_GET_OAID 广告标识符 OAID | allow (最近使用 2d5h27m16s664ms 前) | ignore | 默认拒绝 |
| com.bose.bosemusic | AD_ID | 10037 OP_GET_OAID 广告标识符 OAID | allow (最近使用 23m58s76ms 前) | ignore | 默认拒绝 |
| com.google.android.apps.chromecast.app | INSTALLED_APPS | 10022 OP_GET_INSTALLED_APPS 获取应用列表 | allow | ignore | 默认拒绝 |
| com.google.android.apps.maps | AD_ID | 10037 OP_GET_OAID 广告标识符 OAID | allow (最近使用 13h3m24s405ms 前) | ignore | 默认拒绝 |
| com.google.android.apps.nbu.files | INSTALLED_APPS | 10022 OP_GET_INSTALLED_APPS 获取应用列表 | allow (最近使用 1d2h11m45s140ms 前) | ignore | 默认拒绝 |
| com.google.android.apps.photos | AD_ID | 10037 OP_GET_OAID 广告标识符 OAID | allow (最近使用 2d5h39m44s693ms 前) | ignore | 默认拒绝 |
| com.google.android.calendar | AD_ID | 10037 OP_GET_OAID 广告标识符 OAID | allow (最近使用 2d4h11m12s461ms 前) | ignore | 默认拒绝 |
| com.google.android.gm | AD_ID | 10037 OP_GET_OAID 广告标识符 OAID | allow (最近使用 4h17m36s673ms 前) | ignore | 默认拒绝 |
| com.google.android.googlequicksearchbox | CAMERA | CAMERA | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | revoke | 默认拒绝 |
| com.google.android.googlequicksearchbox | AD_ID | 10037 OP_GET_OAID 广告标识符 OAID | allow (最近使用 2d5h42m47s366ms 前) | ignore | 默认拒绝 |
| com.google.android.videos | AD_ID | 10037 OP_GET_OAID 广告标识符 OAID | allow (最近使用 13h3m22s481ms 前) | ignore | 默认拒绝 |
| com.google.android.youtube | CAMERA | CAMERA | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | revoke | 默认拒绝 |
| com.google.android.youtube | MICROPHONE | RECORD_AUDIO | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | revoke | 默认拒绝 |
| com.mfashiongallery.emag | USAGE_STATS | 10019 OP_GET_TASKS 获取运行中的应用 | allow | ignore | 默认拒绝 |
| com.mfashiongallery.emag | INSTALLED_APPS | 10022 OP_GET_INSTALLED_APPS 获取应用列表 | allow | ignore | 默认拒绝 |
| com.mfashiongallery.emag | AD_ID | 10037 OP_GET_OAID 广告标识符 OAID | allow (最近使用 2d5h45m33s263ms 前) | ignore | 默认拒绝 |
| com.mfashiongallery.emag | PHONE | 10039 OP_GET_PHONE_NUMBER_OPERATOR 运营商取本机号码 | allow | ignore | 默认拒绝 |
| com.miui.calculator | USAGE_STATS | 10019 OP_GET_TASKS 获取运行中的应用 | allow | ignore | 默认拒绝 |
| com.miui.calculator | PHONE | 10039 OP_GET_PHONE_NUMBER_OPERATOR 运营商取本机号码 | allow | ignore | 默认拒绝 |
| com.miui.cleanmaster | INSTALLED_APPS | 10022 OP_GET_INSTALLED_APPS 获取应用列表 | allow (最近使用 3d2h16m3s575ms 前) | ignore | 默认拒绝 |
| com.miui.cleanmaster | AD_ID | 10037 OP_GET_OAID 广告标识符 OAID | allow (最近使用 15d12h32m59s159ms 前) | ignore | 默认拒绝 |
| com.miui.cleanmaster | PHONE | 10039 OP_GET_PHONE_NUMBER_OPERATOR 运营商取本机号码 | allow | ignore | 默认拒绝 |
| com.miui.compass | PHONE | 10039 OP_GET_PHONE_NUMBER_OPERATOR 运营商取本机号码 | allow | ignore | 默认拒绝 |
| com.miui.gallery | MEDIA | READ_EXTERNAL_STORAGE | granted [GRANTED_BY_DEFAULT\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT\|RESTRICTION_SYSTEM_EXEMPT] | revoke | 默认拒绝 |
| com.miui.gallery | MEDIA | READ_MEDIA_IMAGES | granted [GRANTED_BY_DEFAULT\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | revoke | 默认拒绝 |
| com.miui.gallery | MEDIA | READ_MEDIA_VIDEO | granted [GRANTED_BY_DEFAULT\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | revoke | 默认拒绝 |
| com.miui.gallery | MEDIA | WRITE_EXTERNAL_STORAGE | granted [GRANTED_BY_DEFAULT\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT\|RESTRICTION_SYSTEM_EXEMPT] | revoke | 默认拒绝 |
| com.miui.gallery | USAGE_STATS | 10019 OP_GET_TASKS 获取运行中的应用 | allow | ignore | 默认拒绝 |
| com.miui.gallery | AD_ID | 10037 OP_GET_OAID 广告标识符 OAID | allow (最近使用 2d5h6m58s88ms 前) | ignore | 默认拒绝 |
| com.miui.gallery | PHONE | 10039 OP_GET_PHONE_NUMBER_OPERATOR 运营商取本机号码 | allow | ignore | 默认拒绝 |
| com.miui.notes | AD_ID | 10037 OP_GET_OAID 广告标识符 OAID | allow (最近使用 2d4h36m24s153ms 前) | ignore | 默认拒绝 |
| com.miui.notes | PHONE | 10039 OP_GET_PHONE_NUMBER_OPERATOR 运营商取本机号码 | allow | ignore | 默认拒绝 |
| com.miui.screenrecorder | PHONE | 10039 OP_GET_PHONE_NUMBER_OPERATOR 运营商取本机号码 | allow | ignore | 默认拒绝 |
| com.okinc.okex.gp | AD_ID | 10037 OP_GET_OAID 广告标识符 OAID | allow (最近使用 4h13m33s493ms 前) | ignore | 默认拒绝 |
| com.openai.chatgpt | AD_ID | 10037 OP_GET_OAID 广告标识符 OAID | allow (最近使用 2d5h46m40s750ms 前) | ignore | 默认拒绝 |
| com.plexapp.android | AD_ID | 10037 OP_GET_OAID 广告标识符 OAID | allow (最近使用 1d5h26m31s857ms 前) | ignore | 默认拒绝 |
| com.whatsapp | INSTALLED_APPS | 10022 OP_GET_INSTALLED_APPS 获取应用列表 | allow (最近使用 2d5h33m10s287ms 前) | ignore | 默认拒绝 |
| com.whatsapp | AD_ID | 10037 OP_GET_OAID 广告标识符 OAID | allow (最近使用 4h1m48s252ms 前) | ignore | 默认拒绝 |
| org.telegram.messenger | CALL_LOG | READ_CALL_LOG | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT] | revoke | 默认拒绝 |
| org.telegram.messenger | PHONE | READ_PHONE_NUMBERS | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | revoke | 默认拒绝 |
| org.telegram.messenger | PHONE | READ_PHONE_STATE | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | revoke | 默认拒绝 |
| org.telegram.messenger | PHONE | CALL_PHONE | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | revoke | 默认拒绝 |
| org.telegram.messenger | MEDIA_LOCATION | ACCESS_MEDIA_LOCATION | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | revoke | 默认拒绝 |
| org.telegram.messenger | SMS | 10004 OP_SEND_MMS 发彩信 | allow | ignore | 默认拒绝 |
| org.telegram.messenger | INSTALLED_APPS | 10022 OP_GET_INSTALLED_APPS 获取应用列表 | allow | ignore | 默认拒绝 |
| org.telegram.messenger | PHONE | 10032 OP_READ_PHONE_STATE_REAL | allow (最近使用 2d5h37m0s835ms 前) | ignore | 默认拒绝 |

## 只报告不改（4）

| App | 组 | 权限 / appop | 当前 | 动作 | 理由 |
|---|---|---|---|---|---|
| com.android.chrome | CLIPBOARD | READ_CLIPBOARD 读剪贴板 | allow (最近使用 1d18h17m13s402ms 前) | — | 该组只报告 |
| com.google.android.apps.maps | OTHER | com.google.android.gms.permission.CAR_SPEED | granted [USER_SET] | — | 该组只报告 |
| com.google.android.inputmethod.latin | CLIPBOARD | READ_CLIPBOARD 读剪贴板 | allow (最近使用 1d18h17m15s196ms 前) | — | 该组只报告 |
| com.miui.notes | CLIPBOARD | READ_CLIPBOARD 读剪贴板 | allow | — | 该组只报告 |

## 保留（87）

| App | 组 | 权限 / appop | 当前 | 动作 | 理由 |
|---|---|---|---|---|---|
| com.android.soundrecorder | NEARBY | BLUETOOTH_CONNECT | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.android.soundrecorder | MEDIA | READ_EXTERNAL_STORAGE | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT] | — | 白名单 |
| com.android.soundrecorder | MEDIA | WRITE_EXTERNAL_STORAGE | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT] | — | 白名单 |
| com.android.soundrecorder | MICROPHONE | RECORD_AUDIO | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.bose.bosemusic | NEARBY | NEARBY_WIFI_DEVICES | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.bose.bosemusic | NEARBY | BLUETOOTH_CONNECT | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.bose.bosemusic | NEARBY | BLUETOOTH_SCAN | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.github.metacubex.clash.meta | AUTOSTART | 10008 OP_AUTO_START 自启动 | allow | — | 豁免 |
| com.github.metacubex.clash.meta | INSTALLED_APPS | 10022 OP_GET_INSTALLED_APPS 获取应用列表 | foreground (最近使用 8h37m55s378ms 前) | — | 豁免 |
| com.google.android.apps.adm | LOCATION | ACCESS_FINE_LOCATION | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|524288] | — | 白名单 |
| com.google.android.apps.adm | LOCATION | ACCESS_COARSE_LOCATION | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.apps.maps | LOCATION | ACCESS_FINE_LOCATION | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|524288] | — | 白名单 |
| com.google.android.apps.maps | LOCATION | ACCESS_COARSE_LOCATION | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.apps.messaging | SMS | READ_SMS | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT\|RESTRICTION_SYSTEM_EXEMPT\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.messaging | SMS | RECEIVE_WAP_PUSH | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT\|RESTRICTION_SYSTEM_EXEMPT\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.messaging | MEDIA | READ_MEDIA_VISUAL_USER_SELECTED | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.messaging | SMS | RECEIVE_MMS | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT\|RESTRICTION_SYSTEM_EXEMPT\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.messaging | SMS | RECEIVE_SMS | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT\|RESTRICTION_SYSTEM_EXEMPT\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.messaging | MEDIA | READ_EXTERNAL_STORAGE | granted [REVOKE_WHEN_REQUESTED\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT\|RESTRICTION_SYSTEM_EXEMPT\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.messaging | PHONE | READ_PHONE_STATE | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.messaging | SMS | SEND_SMS | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT\|RESTRICTION_SYSTEM_EXEMPT\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.messaging | PHONE | CALL_PHONE | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.messaging | MEDIA | READ_MEDIA_IMAGES | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.messaging | CONTACTS | WRITE_CONTACTS | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.messaging | CAMERA | CAMERA | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.messaging | MEDIA | READ_MEDIA_AUDIO | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.messaging | MEDIA | READ_MEDIA_VIDEO | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.messaging | SMS | READ_CELL_BROADCASTS | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT\|RESTRICTION_SYSTEM_EXEMPT\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.messaging | MEDIA | WRITE_EXTERNAL_STORAGE | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT\|RESTRICTION_SYSTEM_EXEMPT\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.messaging | MICROPHONE | RECORD_AUDIO | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.messaging | CONTACTS | READ_CONTACTS | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [SMS] |
| com.google.android.apps.nbu.files | ALL_FILES | MANAGE_EXTERNAL_STORAGE 所有文件访问（uid 模式） | allow (最近使用 1d2h3m22s833ms 前) | — | 白名单 |
| com.google.android.apps.photos | MEDIA | READ_MEDIA_VISUAL_USER_SELECTED | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.apps.photos | MEDIA | READ_MEDIA_IMAGES | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.apps.photos | MEDIA | READ_MEDIA_VIDEO | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.apps.photos | MEDIA_LOCATION | ACCESS_MEDIA_LOCATION | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.apps.tachyon | PHONE | READ_PHONE_STATE | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.apps.tachyon | CONTACTS | WRITE_CONTACTS | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.apps.tachyon | CAMERA | CAMERA | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.apps.tachyon | CALL_LOG | WRITE_CALL_LOG | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT] | — | 白名单 |
| com.google.android.apps.tachyon | MICROPHONE | RECORD_AUDIO | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.apps.tachyon | CONTACTS | READ_CONTACTS | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.calendar | CALENDAR | READ_CALENDAR | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.calendar | CALENDAR | WRITE_CALENDAR | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.contacts | PHONE | READ_PHONE_NUMBERS | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.contacts | PHONE | READ_PHONE_STATE | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.contacts | PHONE | CALL_PHONE | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.contacts | CONTACTS | WRITE_CONTACTS | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.contacts | CONTACTS | GET_ACCOUNTS | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.contacts | CONTACTS | READ_CONTACTS | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.contacts | PHONE | 10032 OP_READ_PHONE_STATE_REAL | allow (最近使用 12h31m28s6ms 前) | — | 白名单 |
| com.google.android.dialer | CALL_LOG | READ_CALL_LOG | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT\|RESTRICTION_SYSTEM_EXEMPT\|GRANTED_BY_ROLE] | — | 默认角色 [DIALER] |
| com.google.android.dialer | PHONE | READ_PHONE_NUMBERS | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.google.android.dialer | SMS | RECEIVE_SMS | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT\|RESTRICTION_SYSTEM_EXEMPT\|GRANTED_BY_ROLE] | — | 默认角色 [DIALER] |
| com.google.android.dialer | PHONE | READ_PHONE_STATE | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [DIALER] |
| com.google.android.dialer | SMS | SEND_SMS | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT\|RESTRICTION_SYSTEM_EXEMPT\|GRANTED_BY_ROLE] | — | 默认角色 [DIALER] |
| com.google.android.dialer | PHONE | CALL_PHONE | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [DIALER] |
| com.google.android.dialer | CONTACTS | WRITE_CONTACTS | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [DIALER] |
| com.google.android.dialer | CAMERA | CAMERA | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [DIALER] |
| com.google.android.dialer | CALL_LOG | WRITE_CALL_LOG | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT\|RESTRICTION_SYSTEM_EXEMPT\|GRANTED_BY_ROLE] | — | 默认角色 [DIALER] |
| com.google.android.dialer | CONTACTS | GET_ACCOUNTS | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [DIALER] |
| com.google.android.dialer | MICROPHONE | RECORD_AUDIO | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [DIALER] |
| com.google.android.dialer | CONTACTS | READ_CONTACTS | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [DIALER] |
| com.google.android.dialer | PHONE | ADD_VOICEMAIL | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|GRANTED_BY_ROLE] | — | 默认角色 [DIALER] |
| com.google.android.dialer | PHONE | 10032 OP_READ_PHONE_STATE_REAL | allow (最近使用 1d1h10m34s656ms 前) | — | 白名单 |
| com.google.android.googlequicksearchbox | SMS | READ_SMS | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT\|RESTRICTION_SYSTEM_EXEMPT\|GRANTED_BY_ROLE] | — | 默认角色 [ASSISTANT] |
| com.google.android.googlequicksearchbox | CALL_LOG | READ_CALL_LOG | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT\|RESTRICTION_SYSTEM_EXEMPT\|GRANTED_BY_ROLE] | — | 默认角色 [ASSISTANT] |
| com.google.android.googlequicksearchbox | SMS | SEND_SMS | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED\|RESTRICTION_INSTALLER_EXEMPT\|RESTRICTION_SYSTEM_EXEMPT\|GRANTED_BY_ROLE] | — | 默认角色 [ASSISTANT] |
| com.whatsapp | MEDIA | READ_MEDIA_VISUAL_USER_SELECTED | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.whatsapp | MEDIA | READ_MEDIA_IMAGES | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.whatsapp | CONTACTS | WRITE_CONTACTS | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.whatsapp | CAMERA | CAMERA | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.whatsapp | MEDIA | READ_MEDIA_VIDEO | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.whatsapp | CONTACTS | GET_ACCOUNTS | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| com.whatsapp | CONTACTS | READ_CONTACTS | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| me.estk.lpa | NEARBY | BLUETOOTH_CONNECT | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| me.estk.lpa | PHONE | READ_PHONE_STATE | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| me.estk.lpa | NEARBY | BLUETOOTH_SCAN | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| org.telegram.messenger | MEDIA | READ_MEDIA_VISUAL_USER_SELECTED | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| org.telegram.messenger | MEDIA | READ_MEDIA_IMAGES | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| org.telegram.messenger | CONTACTS | WRITE_CONTACTS | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| org.telegram.messenger | CAMERA | CAMERA | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| org.telegram.messenger | MEDIA | READ_MEDIA_AUDIO | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| org.telegram.messenger | MEDIA | READ_MEDIA_VIDEO | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| org.telegram.messenger | CONTACTS | GET_ACCOUNTS | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| org.telegram.messenger | MICROPHONE | RECORD_AUDIO | granted [USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
| org.telegram.messenger | CONTACTS | READ_CONTACTS | granted [USER_SET\|USER_SENSITIVE_WHEN_GRANTED\|USER_SENSITIVE_WHEN_DENIED] | — | 白名单 |
