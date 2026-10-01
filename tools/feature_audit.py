#!/usr/bin/env python3
"""功能面审计（只读）：查「留下来的包还能做什么、什么时候会冒出来」，补网络审计（accept.py）看不到的盲区。

背景：2026-10-01 晚病毒扫描「上传应用特征到云」弹窗漏网——引擎 guardprovider 因安装依赖被保留、只断了网，
网络验收全绿，但没人盘点它的特权、它的定时任务和它会弹的授权框；提醒要「7 天未扫描」才触发，精简当天看不到。
本脚本按「能力 + 触发点」盘点所有非谷歌、非用户自装的厂商包：
  1) 特权/敏感权限（install-time 特权不受 appops 管，最容易被忽略）
  2) JobScheduler 任务 + 闹钟（定时冒出来的功能）
  3) 近 7 天发过的通知（弹窗/提醒的入口）
  4) 高权位：无障碍、设备管理器、通知监听、默认角色
  5) settings 里值为开的「同意/云/上传/上报/AI/推荐」类键
用法: feature_audit.py [输出 json 路径]
"""
import json, re, subprocess, sys, collections, time

def sh(cmd):
    return subprocess.run(["adb", "shell", "-n", cmd], capture_output=True, text=True).stdout

VENDOR = re.compile(r"^(com\.miui|com\.xiaomi|com\.mi\.|miui\.|com\.lbe|com\.qualcomm|com\.qti|vendor\.qti|com\.mfashiongallery|"
                    r"com\.sohu|com\.baidu|com\.tencent|com\.amap|com\.autonavi|com\.unionpay|com\.duokan|com\.fido|org\.ifaa|"
                    r"com\.android\.(updater|thememanager|camera|soundrecorder|contacts|incallui|mms|calendar|deskclock|browser|"
                    r"fileexplorer|providers\.downloads\.ui|nfc|phone|server\.telecom|systemui|settings|bluetooth|se|"
                    r"cellbroadcastreceiver|stk|wallpaper))")
SENSITIVE = ["CAPTURE_AUDIO_OUTPUT", "CAPTURE_VOICE_COMMUNICATION_OUTPUT", "CAPTURE_VIDEO_OUTPUT", "RECORD_AUDIO",
             "MANAGE_EXTERNAL_STORAGE", "READ_EXTERNAL_STORAGE", "READ_MEDIA_IMAGES", "READ_SMS", "RECEIVE_SMS", "SEND_SMS",
             "READ_CALL_LOG", "READ_CONTACTS", "ACCESS_FINE_LOCATION", "ACCESS_BACKGROUND_LOCATION", "CAMERA",
             "READ_PHONE_STATE", "READ_PRIVILEGED_PHONE_STATE", "PACKAGE_USAGE_STATS", "QUERY_ALL_PACKAGES",
             "MANAGE_MEDIA_PROJECTION", "BIND_ACCESSIBILITY_SERVICE", "WRITE_SECURE_SETTINGS", "INSTALL_PACKAGES",
             "DELETE_PACKAGES", "READ_LOGS", "DUMP", "INTERACT_ACROSS_USERS_FULL", "READ_CLIPBOARD_IN_BACKGROUND",
             "SYSTEM_ALERT_WINDOW", "READ_FRAME_BUFFER", "ACCESS_NOTIFICATIONS", "GET_ACCOUNTS_PRIVILEGED"]
CONSENT_KEY = re.compile(r"agree|consent|privacy|cloud|upload|report|improve|experience|ai_|_ai|recommend|personal|"
                         r"analytics|track|onetrack|stat|feedback|xiaoai|smart|scan|guard|risk|fraud", re.I)

pkgs = sorted(re.findall(r"package:(\S+)", sh("pm list packages --user 0")))
vendor = [p for p in pkgs if VENDOR.match(p)]
out = {"time": time.strftime("%F %T"), "vendor_pkgs": {}, "roles": {}, "settings_on": []}

# 1) 权限：一次 dumpsys package 全量，按包切块
dump = sh("dumpsys package packages")
blocks = re.split(r"\n  Package \[", dump)
perm_of = {}
for b in blocks[1:]:
    name = b.split("]", 1)[0]
    if name in vendor:
        granted = set(re.findall(r"android\.permission\.([A-Z_]+): granted=true", b))
        perm_of[name] = sorted(g for g in granted if g in SENSITIVE)
uid_of = dict(re.findall(r"package:(\S+) uid:(\d+)", sh("pm list packages -U --user 0")))

# 2) 任务与闹钟
jobs = collections.defaultdict(set)
for m in re.finditer(r"JOB #(?:u\d+a)?\d+/\d+: \S+ (\S+?)/(\S+)", sh("dumpsys jobscheduler")):
    jobs[m.group(1)].add(m.group(2))
alarms = collections.Counter(re.findall(r"\*(?:walarm|alarm)\*:\S*\s*\n?.*?(?:pkg|package)[=:](\S+)", sh("dumpsys alarm"), re.S))
alarms2 = collections.Counter(re.findall(r"RTC(?:_WAKEUP)? #\d+: Alarm\{\S+ type \d+ origWhen \d+ \S+ (\S+)\}", sh("dumpsys alarm")))
alarms2 += collections.Counter(re.findall(r"ELAPSED(?:_WAKEUP)? #\d+: Alarm\{\S+ type \d+ origWhen \d+ \S+ (\S+)\}", sh("dumpsys alarm")))

# 3) 近 7 天通知
cut = time.strftime("%Y-%m-%d", time.localtime(time.time() - 7 * 86400))
notif = collections.Counter()
for d, p, ch in re.findall(r'time="(\S+) \S+" type=NOTIFICATION_INTERRUPTION package=(\S+) channelId=(\S+)', sh("dumpsys usagestats")):
    if d >= cut:
        notif[(p, ch)] += 1

for p in vendor:
    out["vendor_pkgs"][p] = {"uid": int(uid_of.get(p, -1)), "sensitive_perms": perm_of.get(p, []),
                             "jobs": sorted(jobs.get(p, [])), "alarms": alarms2.get(p, 0),
                             "notif_7d": {ch: n for (pp, ch), n in notif.items() if pp == p}}

# 4) 高权位
out["roles"]["accessibility"] = sh("settings get secure enabled_accessibility_services").strip()
out["roles"]["notification_listeners"] = sh("settings get secure enabled_notification_listeners").strip()
out["roles"]["device_admins"] = re.findall(r"admin=ComponentInfo\{(\S+?)\}", sh("dumpsys device_policy"))
for r in ["android.app.role.ASSISTANT", "android.app.role.SMS", "android.app.role.DIALER", "android.app.role.BROWSER",
          "android.app.role.HOME", "android.app.role.CALL_SCREENING", "android.app.role.CALL_REDIRECTION"]:
    out["roles"][r.split(".")[-1]] = sh(f"cmd role get-role-holders --user 0 {r}").strip()

# 5) settings 里开着的同意/云/上报类键
for ns in ("system", "secure", "global"):
    for line in sh(f"settings list {ns}").splitlines():
        k, _, v = line.partition("=")
        if CONSENT_KEY.search(k) and v.strip().lower() in ("1", "true", "on", "yes"):
            out["settings_on"].append(f"{ns} {k}={v.strip()}")

path = sys.argv[1] if len(sys.argv) > 1 else f"feature_audit_{time.strftime('%Y%m%d_%H%M%S')}.json"
json.dump(out, open(path, "w"), ensure_ascii=False, indent=1)

# 终端汇总：只列有东西的
print(f"== 厂商包 {len(vendor)} 个（user 0 已装）")
for p, v in out["vendor_pkgs"].items():
    flags = []
    if v["sensitive_perms"]: flags.append("权限:" + ",".join(v["sensitive_perms"]))
    if v["jobs"]: flags.append(f"任务{len(v['jobs'])}")
    if v["alarms"]: flags.append(f"闹钟{v['alarms']}")
    if v["notif_7d"]: flags.append("通知:" + ",".join(f"{c}×{n}" for c, n in v["notif_7d"].items()))
    if flags: print(f"  {p} (uid {v['uid']}): " + " | ".join(flags))
print("== 高权位"); [print(f"  {k}: {v}") for k, v in out["roles"].items()]
print("== 开着的同意/云/上报类键"); [print("  " + s) for s in out["settings_on"]]
print(f"-> {path}")
