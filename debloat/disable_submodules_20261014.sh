#!/bin/sh
# 2026-10-14 小米 MIX Flip 2 (root) 隐形子应用与周期弹窗源全量清理脚本
# 背景现象：
#   1. 2026-10-14 20:25:44 com.miui.securitycenter/.service.RemoteService 的 15 天周期定时任务触发，
#      在 com.miui.applicationlock 渠道弹出「开启应用锁」引导通知，点击后拉起 NewFirstUseAppLockActivity。
#   2. 全量扫描发现：
#      - 10-11 线刷后从 /product/data-app 自动恢复了 com.miui.securitymanager（手机管家独立桌面壳），
#        另留有 com.goodix.gftest（汇顶指纹产线测试）与 uk.tonytong.aiostest.stub（测试空壳）。
#      - com.miui.securitycenter 与 com.miui.securitycore 宿主因承载系统权限管理、电池统计与电源键手势不可整包卸载，
#        但内部塞有应用锁、游戏加速、迅游弹窗、微信红包助手、垃圾清理诱导弹窗、隐藏应用、应用预测、安全分享、
#        反诈检测、地震/灾害预警、安全体检、晕车缓解、全局侧边栏、气泡通知、手机分身/双开、绿色守护、企业模式等 135 个非原生组件，
#        以及 RemoteService / CleanerReceiver / CloudDataUpdateService 等周期唤醒源。
# 改法与铁律：
#   - 独立无依赖包整包 pm uninstall --user 0；保留 soundrecorder / thememanager / misound。
#   - 宿主包内仅 root pm disable Activity / Service / Receiver，严禁禁用任何 ContentProvider（防 Android 16 缺 authority 崩溃）。
# 用法：在手机 root shell 下直接执行（或经 phone-api.sh sh "su -c 'sh ...'" 调用）。

set -e

echo "=== 1. 卸载独立非原生包 ==="
for p in com.miui.securitymanager com.goodix.gftest uk.tonytong.aiostest.stub; do
  pm uninstall --user 0 "$p" 2>/dev/null && echo "  uninstalled: $p" || echo "  already absent: $p"
done

echo "=== 2. 禁用 com.miui.securitycenter 内部应用锁与非原生子模块（114 个组件） ==="
SC_COMPONENTS="
com.miui.applicationlock.AppLockActivity
com.miui.applicationlock.ApplockRecommendActivity
com.miui.applicationlock.ChooseAccessControl
com.miui.applicationlock.ChooseLockTypeActivity
com.miui.applicationlock.ConfirmAccessControl
com.miui.applicationlock.ConfirmAccountActivity
com.miui.applicationlock.FirstUseAppLockActivity
com.miui.applicationlock.LockChooseAccessControl
com.miui.applicationlock.MaskNotificationActivity
com.miui.applicationlock.NewApplockRecommendActivity
com.miui.applicationlock.NewFirstUseAppLockActivity
com.miui.applicationlock.PrivacyAndAppLockManageActivity
com.miui.applicationlock.PrivacyAppsConfirmAccessControl
com.miui.applicationlock.ResetChooseAccessControl
com.miui.applicationlock.SettingLockActivity
com.miui.applicationlock.TransitionHelper
com.miui.auth.BiometricAppLockSettingMainActivity
com.miui.securitycenter.service.RemoteService
com.miui.securitycenter.receiver.CleanerReceiver
com.miui.securitycenter.service.CloudDataUpdateService
com.miui.antivirus.service.VirusAutoUpdateJobService
com.miui.securitycenter.service.ConnectivityChangeJobService2
com.miui.securityscan.job.ScanJobService
com.miui.antivirus.service.GuardService
com.miui.antispam.service.AntiSpamService
com.miui.antifraud.PayActivityMonitorService
com.miui.ai.service.OperationListCollectService
com.miui.gamebooster.beauty.BeautyManageActivity
com.miui.gamebooster.beauty.BeautySettingsActivity
com.miui.gamebooster.beauty.BeautyService
com.miui.gamebooster.beauty.PrivacyCameraGlobalSettingsActivity
com.miui.gamebooster.gamemode.GameModeSettingsActivity
com.miui.gamebooster.gbservices.AntiMsgAccessibilityService
com.miui.gamebooster.mutiwindow.FreeformWindowService
com.miui.gamebooster.service.DockWindowManagerService
com.miui.gamebooster.service.GameBoosterService
com.miui.gamebooster.service.NotificationListener
com.miui.gamebooster.service.VideoToolBoxService
com.miui.gamebooster.shoulderkey.ShoulderKeyLightEffectActivity
com.miui.gamebooster.ui.GameBoxAlertActivity
com.miui.gamebooster.ui.PreDownloadSettingsActivity
com.miui.gamebooster.ui.QuickReplySettingsActivity
com.miui.gamebooster.ui.SelectGameLandActivity
com.miui.gamebooster.ui.SettingsActivity
com.miui.gamebooster.ui.WelcomActivity
com.miui.gamebooster.ui.WindowCallActivity
com.miui.gamebooster.ui.WonderfulMomentActivity
com.miui.gamebooster.videobox.settings.VideoBoxAppManageActivity
com.miui.gamebooster.xunyou.XunyouAlertActivity
com.xiaomi.game.predownload.service.PreDownloadService
com.xiaomi.game.predownload.workmanager.PreDownloadJobService
com.miui.cleanmaster.CleanerHandleService
com.miui.cleanmaster.CleanerInstallActivity
com.miui.cleanmaster.LowMemoryIntentDispatchActivity
com.miui.luckymoney.ui.activity.GuideActivity
com.miui.luckymoney.ui.activity.LuckySettingActivity
com.miui.luckymoney.ui.activity.OpenLockScreenActivity
com.miui.luckymoney.ui.activity.RemoveLuckyMoneyActivity
com.miui.luckymoney.ui.activity.SecondarySettingActivity
com.miui.privacyapps.ui.PrivacyAppsActivity
com.miui.privacyapps.ui.PrivacyAppsHelper
com.miui.privacyapps.ui.PrivacyAppsManageActivity
com.miui.privacyapps.ui.PrivacyAppsOperationTutorialActivity
com.miui.privacyapps.ui.PrivacySettingsActivity
com.miui.apppredict.activity.GuideDialogActivity
com.miui.apppredict.activity.WidgetBlackListSettingActivity
com.miui.apppredict.service.AiService
com.miui.apppredict.service.AppPredictService
com.miui.zman.ui.LoadingActivity
com.miui.zman.ui.PrivacyProtectSettingsActivity
com.miui.zman.ui.PrivacyProtectTipSettingsActivity
com.miui.zman.ui.ShareActivity
com.miui.zman.ui.ShareSettingActivity
com.xiaomi.security.xsof.MiSafetyDetectService
com.xiaomi.security.xsof.frauddetection.service.MiFraudDetectionService
com.miui.warningcenter.WarningCenterMainActivity
com.miui.warningcenter.caraccident.WarningCarAccidentActivity
com.miui.warningcenter.disasterwarning.WarningCenterDisasterActivity
com.miui.warningcenter.policeassist.PaService
com.miui.warningcenter.policeassist.PaSettingActivity
com.miui.earthquakewarning.service.EarthquakeWarningService
com.miui.earthquakewarning.ui.EarthquakeWarningAlertActivity
com.miui.earthquakewarning.ui.EarthquakeWarningContactsActivity
com.miui.earthquakewarning.ui.EarthquakeWarningEmergencyActivity
com.miui.earthquakewarning.ui.EarthquakeWarningGuideActivity
com.miui.earthquakewarning.ui.EarthquakeWarningInfoActivity
com.miui.earthquakewarning.ui.EarthquakeWarningListActivity
com.miui.earthquakewarning.ui.EarthquakeWarningMainActivity
com.miui.earthquakewarning.ui.EarthquakeWarningMonitorActivity
com.miui.earthquakewarning.ui.EarthquakeWarningSettingActivity
com.miui.firstaidkit.FirstAidKitActivity
com.miui.securityscan.MainEntryActivity
com.miui.securityscan.OptimizeAndResultActivity
com.miui.securityscan.cards.DownloadInstallReceiver
com.miui.securityscan.fileobserver.DelImgInterceptActivity
com.miui.securityscan.shortcut.ShortcutActivity
com.miui.securityscan.ui.settings.AboutActivity
com.miui.securityscan.ui.settings.SettingsActivity
com.miui.carsick.services.AntiCarsickManager
com.miui.carsickness.broadcastreceiver.CarsicknessReliefReceiver
com.miui.carsickness.service.CarSicknessService
com.miui.carsickness.ui.CarSicknessReliefSettingsActivity
com.miui.dock.DockMonitorService
com.miui.dock.edit.DockAppEditActivity
com.miui.dock.settings.DockSettingsActivity
com.miui.bubbles.services.BubbleRemoteService
com.miui.bubbles.services.BubblesService
com.miui.bubbles.settings.BubbleSettingsActivity
com.miui.analytics.RemoteAnalyticsReceiver
com.miui.push.XiaomiPushReceiver
com.xiaomi.push.service.XMPushService
com.xiaomi.push.service.receivers.PingReceiver
com.xiaomi.mipush.sdk.MessageHandleService
com.xiaomi.mipush.sdk.PushMessageHandler
"

for c in $SC_COMPONENTS; do
  pm disable "com.miui.securitycenter/$c" >/dev/null
done

echo "=== 3. 禁用 com.miui.securitycore 内部分身/双开/绿守/企业组件（21 个组件） ==="
SCORE_COMPONENTS="
com.miui.xspace.ui.activity.XSpaceDualActivity
com.miui.xspace.ui.activity.XSpaceResolveActivity
com.miui.xspace.ui.activity.XSpaceSettingActivity
com.miui.xspace.service.XSpaceDualService
com.miui.xspace.receiver.InstallShortcutReceiver
com.miui.xspace.receiver.MediaScannerReceiver
com.miui.xspace.receiver.ResolveActivitySelectedReceiver
com.miui.securityspace.ui.activity.GreenGuardActivity
com.miui.securityspace.ui.activity.GuideSuccessActivity
com.miui.securityspace.ui.activity.PrivateSpaceMainActivity
com.miui.securityspace.ui.activity.RemoveUserActivity
com.miui.securityspace.service.KidModeSpaceService
com.miui.securityspace.service.SwitchUserService
com.miui.securityspace.receiver.AccountChangeReceiver
com.miui.enterprise.settings.AppRuuningBlockHandleActivity
com.miui.enterprise.settings.EntActivationSettingsActivity
com.miui.enterprise.receiver.EntActivationReceiver
com.miui.aon.ContactlessGestureTutorialActivity
com.miui.aon.service.ContactlessGestureService
com.miui.tof.TofTutorialActivity
com.miui.tof.service.TofService
"

for c in $SCORE_COMPONENTS; do
  pm disable "com.miui.securitycore/$c" >/dev/null
done

echo "=== 4. 封堵应用锁通知与挂起任务 ==="
settings put secure applock_mask_notify 1
cmd jobscheduler cancel com.miui.securitycenter >/dev/null 2>&1 || true
killall -9 com.miui.securitycenter com.miui.securitycenter.remote 2>/dev/null || true
if [ -f /data/data/com.miui.securitycenter/shared_prefs/remote_provider_preferences.xml ]; then
  sed -i 's/name="applock_alarm_count" value="[0-9]*"/name="applock_alarm_count" value="99"/' /data/data/com.miui.securitycenter/shared_prefs/remote_provider_preferences.xml
fi
echo "Done."
