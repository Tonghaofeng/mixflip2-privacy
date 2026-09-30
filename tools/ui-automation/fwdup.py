#!/usr/bin/env python3
"""fwdup.py <名字> [allow]  列出同名的每一行及开关状态；带 allow 则把所有同名行都点成允许"""
import re, subprocess, sys, time, xml.etree.ElementTree as ET
def sh(*a): return subprocess.run(["adb","shell","-n",*a],capture_output=True,text=True).stdout
def box(n): return list(map(int,re.findall(r"\d+",n.get("bounds"))))
def dump():
    for _ in range(4):
        if "dumped" in sh("uiautomator","dump","/sdcard/ui.xml"):
            try: return list(ET.fromstring(sh("cat","/sdcard/ui.xml")).iter("node"))
            except ET.ParseError: pass
        time.sleep(1)
name=sys.argv[1]; allow=len(sys.argv)>2
for _ in range(10): sh("input","swipe","600","900","600","2600","150")
time.sleep(1)
for _ in range(25):
    ns=dump(); hits=[]
    for n in ns:
        if (n.get("text") or "")==name and box(n)[0]==237:
            cy=(box(n)[1]+box(n)[3])//2
            sw=[m for m in ns if m.get("class")=="android.widget.Switch" and box(m)[1]<=cy<=box(m)[3]]
            if sw: hits.append(sw[0])
    if hits:
        for s in hits:
            print(name, s.get("bounds"), "允许" if s.get("checked")=="true" else "禁止")
            if allow and s.get("checked")=="false":
                b=box(s); sh("input","tap",str((b[0]+b[2])//2),str((b[1]+b[3])//2)); time.sleep(1.2); print("  -> 点成允许")
        break
    sh("input","swipe","600","2400","600","1300","400"); time.sleep(0.8)
