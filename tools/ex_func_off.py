#!/usr/bin/env python3
"""ex_func_off.py [--dry]  设置→更多设置→应用扩展功能：把指定入口取消勾选（隐藏）。
ex_func 存在 com.android.settings 私有 SharedPreferences，shell 无写入口，只能走界面。
直达：am start SubSettings(:settings:show_fragment)；按标题找行→读 android:id/checkbox(miuix 为 Switch 类) 的 checked→需要时点行→复读验证。"""
import re, subprocess, sys, time, json, xml.etree.ElementTree as ET
HIDE = ["问题反馈","卡包","企业模式","儿童空间","CarWith","设备激活信息","安全守护",
        "安全-查找设备","米币中心","小米云服务","游戏加速","小爱同学","小米澎湃AI"]
KEEP = ["备份与恢复","健康使用手机"]
DRY = "--dry" in sys.argv
def sh(*a): return subprocess.run(["adb","shell","-n",*a],capture_output=True,text=True).stdout
def nodes():
    for _ in range(5):
        if "dumped" in sh("uiautomator","dump","/sdcard/ui.xml"):
            try: return ET.fromstring(sh("cat","/sdcard/ui.xml"))
            except ET.ParseError: pass
        time.sleep(1)
    raise SystemExit("uiautomator dump failed")
def box(n): return list(map(int,re.findall(r"\d+",n.get("bounds"))))
def rows():
    """返回 {标题: (checked, 行中心坐标)}：以含 checkbox 的可点击行为单位"""
    root=nodes(); out={}
    for row in root.iter("node"):
        if row.get("clickable")!="true": continue
        titles=[n.get("text") for n in row.iter("node") if n.get("resource-id")=="android:id/title" and n.get("text")]
        cbs=[n for n in row.iter("node") if n.get("resource-id")=="android:id/checkbox"]
        if len(titles)==1 and len(cbs)==1:
            b=box(row); out[titles[0]]=(cbs[0].get("checked")=="true",((b[0]+b[2])//2,(b[1]+b[3])//2))
    return out
def scan():
    """滚动收集整页状态"""
    allr={}; last=None
    sh("input","swipe","600","900","600","2600","150"); time.sleep(0.6)
    for _ in range(8):
        r=rows(); allr.update({k:v[0] for k,v in r.items()})
        if tuple(r)==last: break
        last=tuple(r); sh("input","swipe","600","2300","600","1200","400"); time.sleep(0.7)
    return allr
sh("am","start","-n","com.android.settings/.SubSettings","--es",":settings:show_fragment",
   "com.android.settings.special.ExtensionFunctionFragment"); time.sleep(2)
before=scan(); print("BEFORE", json.dumps(before,ensure_ascii=False))
if not before: raise SystemExit("页面没打开或没找到勾选框")
if not DRY:
    for t in HIDE:
        if not before.get(t): continue          # 不存在或已取消
        sh("input","swipe","600","900","600","2600","150"); time.sleep(0.5)
        for _ in range(8):
            r=rows()
            if t in r:
                x,y=r[t][1]; sh("input","tap",str(x),str(y)); time.sleep(1.2); break
            sh("input","swipe","600","2300","600","1200","400"); time.sleep(0.6)
    after=scan(); print("AFTER ", json.dumps(after,ensure_ascii=False))
    bad=[t for t in HIDE if after.get(t)] + [t for t in KEEP if t in before and after.get(t)!=before[t]]
    print("RESULT", "OK" if not bad else f"FAIL {bad}")
