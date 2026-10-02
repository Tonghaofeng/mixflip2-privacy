# permguard —「关不掉」清单

## 第三方 App（按影响排序）

| # | App | 为什么权限模型管不住 | 建议 |
|---|---|---|---|
| 1 | com.github.metacubex.clash.meta | 特殊权限：常驻 VPN（只报告，不自动改）；QUERY_ALL_PACKAGES（安装时权限，收不回；MIUI 10022 只挡 getInstalledPackages 一条路） | 保留（本方案组件；Clash 按包分流需要应用列表） |
| 2 | com.google.android.inputmethod.latin | 特殊权限：默认输入法（看得到所有键入）（只报告，不自动改） | 保留但定期复核（特殊权限只能在系统设置里手动关） |
| 3 | com.google.android.projection.gearhead | QUERY_ALL_PACKAGES（安装时权限，收不回；MIUI 10022 只挡 getInstalledPackages 一条路）；sharedUserId=com.google.android.projection.gearhead：权限按 UID 共用 | 保留（谷歌系；网络侧 GOOGLE_TELEMETRY 已拦遥测） |
| 4 | com.x8bit.bitwarden | 特殊权限：无障碍服务（只报告，不自动改） | 保留但定期复核（特殊权限只能在系统设置里手动关） |
| 5 | com.android.chrome | QUERY_ALL_PACKAGES（安装时权限，收不回；MIUI 10022 只挡 getInstalledPackages 一条路） | 保留（谷歌系；网络侧 GOOGLE_TELEMETRY 已拦遥测） |
| 6 | com.google.android.apps.chromecast.app | QUERY_ALL_PACKAGES（安装时权限，收不回；MIUI 10022 只挡 getInstalledPackages 一条路） | 保留（谷歌系；网络侧 GOOGLE_TELEMETRY 已拦遥测） |
| 7 | com.google.android.apps.nbu.files | QUERY_ALL_PACKAGES（安装时权限，收不回；MIUI 10022 只挡 getInstalledPackages 一条路） | 保留（谷歌系；网络侧 GOOGLE_TELEMETRY 已拦遥测） |
| 8 | com.google.android.apps.subscriptions.red | QUERY_ALL_PACKAGES（安装时权限，收不回；MIUI 10022 只挡 getInstalledPackages 一条路） | 保留（谷歌系；网络侧 GOOGLE_TELEMETRY 已拦遥测） |
| 9 | com.google.android.dialer | QUERY_ALL_PACKAGES（安装时权限，收不回；MIUI 10022 只挡 getInstalledPackages 一条路） | 保留（谷歌系；网络侧 GOOGLE_TELEMETRY 已拦遥测） |
| 10 | com.google.android.googlequicksearchbox | QUERY_ALL_PACKAGES（安装时权限，收不回；MIUI 10022 只挡 getInstalledPackages 一条路） | 保留（谷歌系；网络侧 GOOGLE_TELEMETRY 已拦遥测） |
| 11 | com.google.android.tts | QUERY_ALL_PACKAGES（安装时权限，收不回；MIUI 10022 只挡 getInstalledPackages 一条路） | 保留（谷歌系；网络侧 GOOGLE_TELEMETRY 已拦遥测） |
| 12 | com.google.android.videos | QUERY_ALL_PACKAGES（安装时权限，收不回；MIUI 10022 只挡 getInstalledPackages 一条路） | 保留（谷歌系；网络侧 GOOGLE_TELEMETRY 已拦遥测） |
| 13 | com.mfashiongallery.emag | QUERY_ALL_PACKAGES（安装时权限，收不回；MIUI 10022 只挡 getInstalledPackages 一条路） | 卸载（已停用，`pm uninstall --user 0`，按 debloat 流程先查依赖） |
| 14 | com.miui.cleanmaster | QUERY_ALL_PACKAGES（安装时权限，收不回；MIUI 10022 只挡 getInstalledPackages 一条路） | 卸载（已停用，`pm uninstall --user 0`，按 debloat 流程先查依赖） |
| 15 | com.miui.gallery | QUERY_ALL_PACKAGES（安装时权限，收不回；MIUI 10022 只挡 getInstalledPackages 一条路） | 卸载（已停用，`pm uninstall --user 0`，按 debloat 流程先查依赖） |
| 16 | com.miui.screenrecorder | QUERY_ALL_PACKAGES（安装时权限，收不回；MIUI 10022 只挡 getInstalledPackages 一条路） | 不常用就卸载；要用就隔离到手机分身/工作资料 |
| 17 | com.google.android.calendar | sharedUserId=com.google.android.calendar.uid.shared：权限按 UID 共用 | 保留（谷歌系；网络侧 GOOGLE_TELEMETRY 已拦遥测） |

## 系统 App（按 UID 身份合并；只报告。SYSTEM_FIXED = shell 也收不了；能删的走 debloat 流程，KEEP.txt 禁删）

| 身份 | 包数 | QUERY_ALL_PACKAGES | 固定隐私权限（最多的那个包） | 特殊权限 | 成员（前 6 个） |
|---|---|---|---|---|---|
| android.uid.system/1000 | 28 | 28 | 33 |  | android com.android.DeviceAsWebcam com.android.dynsystem com.android.inputdevices com.android.keychain com.android.localtransport … |
| android.uid.phone/1001 | 17 | 17 | 22 |  | com.android.cellbroadcastservice com.android.mms.service com.android.ons com.android.phone com.android.providers.telephony com.android.stk … |
| android.uid.shared/10086 | 5 | 5 | 6 |  | com.android.calllogbackup com.android.providers.blockednumber com.android.providers.contactkeys com.android.providers.contacts com.android.providers.userdictionary |
| android.media/10092 | 4 | 4 | 2 |  | com.android.mtp com.android.providers.downloads com.android.providers.media com.android.soundpicker |
| android.uid.bluetooth/1002 | 2 | 2 | 20 |  | com.android.bluetooth com.xiaomi.bluetooth |
| android.uid.networkstack/1073 | 2 | 0 | 4 |  | com.android.networkstack com.android.networkstack.tethering |
| android.uid.nfc/1027 | 2 | 2 | 11 |  | com.android.nfc com.st.android.nfc_extensions_16 |
| com.qualcomm.qti.qtidataservices/10116 | 2 | 2 | 0 |  | com.qualcomm.qti.cne vendor.qti.iwlan |
| android.ext.services | 1 | 1 | 0 |  | android.ext.services |
| android.uid.calendar/10087 | 1 | 0 | 2 |  | com.android.providers.calendar |
| android.uid.se/1068 | 1 | 1 | 0 |  | com.android.se |
| android.uid.shell/2000 | 1 | 1 | 41 |  | com.android.shell |
| android.uid.updater/6102 | 1 | 1 | 1 |  | com.android.updater |
| com.android.adservices.api | 1 | 1 | 0 |  | com.android.adservices.api |
| com.android.apps.tag | 1 | 1 | 0 |  | com.android.apps.tag |
| com.android.bips | 1 | 1 | 0 |  | com.android.bips |
| com.android.bluetoothmidiservice | 1 | 0 | 3 |  | com.android.bluetoothmidiservice |
| com.android.cellbroadcastreceiver | 1 | 0 | 4 |  | com.android.cellbroadcastreceiver |
| com.android.companiondevicemanager | 1 | 1 | 6 |  | com.android.companiondevicemanager |
| com.android.contacts | 1 | 1 | 0 |  | com.android.contacts |
| com.android.credentialmanager | 1 | 1 | 0 |  | com.android.credentialmanager |
| com.android.devicelockcontroller | 1 | 1 | 0 |  | com.android.devicelockcontroller |
| com.android.emergency.uid/10215 | 1 | 0 | 3 |  | com.android.emergency |
| com.android.externalstorage | 1 | 0 | 2 |  | com.android.externalstorage |
| com.android.federatedcompute.services | 1 | 1 | 0 |  | com.android.federatedcompute.services |
| com.android.healthconnect.controller | 1 | 1 | 0 |  | com.android.healthconnect.controller |
| com.android.htmlviewer | 1 | 1 | 0 |  | com.android.htmlviewer |
| com.android.incallui | 1 | 1 | 0 |  | com.android.incallui |
| com.android.intentresolver | 1 | 1 | 0 |  | com.android.intentresolver |
| com.android.managedprovisioning | 1 | 1 | 0 |  | com.android.managedprovisioning |
| com.android.ondevicepersonalization.services | 1 | 1 | 0 |  | com.android.ondevicepersonalization.services |
| com.android.permissioncontroller | 1 | 1 | 0 |  | com.android.permissioncontroller |
| com.android.photopicker | 1 | 1 | 0 |  | com.android.photopicker |
| com.android.printspooler | 1 | 1 | 2 |  | com.android.printspooler |
| com.android.providers.media.module | 1 | 1 | 2 |  | com.android.providers.media.module |
| com.android.sharedstoragebackup | 1 | 0 | 2 |  | com.android.sharedstoragebackup |
| com.android.smspush | 1 | 1 | 0 |  | com.android.smspush |
| com.android.statementservice | 1 | 1 | 0 |  | com.android.statementservice |
| com.android.storagemanager | 1 | 1 | 2 |  | com.android.storagemanager |
| com.android.traceur | 1 | 1 | 0 |  | com.android.traceur |
| com.android.vending | 1 | 1 | 2 |  | com.android.vending |
| com.android.vpndialogs | 1 | 1 | 0 |  | com.android.vpndialogs |
| com.android.wallpaper.livepicker | 1 | 1 | 0 |  | com.android.wallpaper.livepicker |
| com.google.android.documentsui | 1 | 1 | 0 |  | com.google.android.documentsui |
| com.google.android.gms | 1 | 1 | 4 |  | com.google.android.gms |
| com.google.android.gms.location.history | 1 | 0 | 1 |  | com.google.android.gms.location.history |
| com.google.android.marvin.talkback | 1 | 1 | 0 |  | com.google.android.marvin.talkback |
| com.lbe.security.miui | 1 | 1 | 0 |  | com.lbe.security.miui |
| com.miui.core | 1 | 1 | 0 |  | com.miui.core |
| com.miui.fliphome | 1 | 1 | 0 |  | com.miui.fliphome |
| com.miui.home | 1 | 1 | 0 |  | com.miui.home |
| com.miui.misound | 1 | 1 | 0 |  | com.miui.misound |
| com.miui.miwallpaper | 1 | 1 | 0 |  | com.miui.miwallpaper |
| com.miui.packageinstaller | 1 | 1 | 2 |  | com.miui.packageinstaller |
| com.miui.screenshot | 1 | 1 | 0 |  | com.miui.screenshot |
| com.qualcomm.location | 1 | 1 | 4 |  | com.qualcomm.location |
| com.qualcomm.qti.qmsdataservices/10120 | 1 | 1 | 0 |  | vendor.qti.data.txpwradmin |
| com.qualcomm.qti.workloadclassifier | 1 | 1 | 0 |  | com.qualcomm.qti.workloadclassifier |
| com.qualcomm.qtil.aptxacu | 1 | 1 | 0 |  | com.qualcomm.qtil.aptxacu |
| org.codeaurora.ims | 1 | 0 | 3 |  | org.codeaurora.ims |
| vendor.qti.bluetooth.xpan | 1 | 0 | 6 |  | vendor.qti.bluetooth.xpan |
