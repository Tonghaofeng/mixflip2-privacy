#!/usr/bin/env python3
"""fw.py <名字>...   在小米「联网控制」当前列表里，把指定应用那一行的开关关成「禁止」。
开关是 android.widget.Switch，checked=true 表示允许、false 表示禁止；自动滚动查找。"""
import re, subprocess, sys, time, xml.etree.ElementTree as ET
def sh(*a): return subprocess.run(["adb","shell","-n",*a],capture_output=True,text=True).stdout
def nodes():
    for _ in range(4):
        if "dumped" in sh("uiautomator","dump","/sdcard/ui.xml"):
            try: return list(ET.fromstring(sh("cat","/sdcard/ui.xml")).iter("node"))
            except ET.ParseError: pass
        time.sleep(1)
    return []
def box(n): return list(map(int,re.findall(r"\d+",n.get("bounds"))))
def find(name):
    ns=nodes()
    for n in ns:
        if (n.get("text") or "")==name and box(n)[0]==237:
            cy=(box(n)[1]+box(n)[3])//2
            sw=[m for m in ns if m.get("class")=="android.widget.Switch" and box(m)[1]<=cy<=box(m)[3]]
            return sw[0] if sw else None
    return None
def locate(name):
    for _ in range(10): sh("input","swipe","600","900","600","2600","150")
    time.sleep(1)
    for _ in range(25):
        s=find(name)
        if s is not None: return s
        sh("input","swipe","600","2400","600","1300","400"); time.sleep(0.8)
    return None
for name in sys.argv[1:]:
    s=locate(name)
    if s is None: print(f"{name}: NOT FOUND"); continue
    if s.get("checked")=="false": print(f"{name}: 已禁止"); continue
    b=box(s); sh("input","tap",str((b[0]+b[2])//2),str((b[1]+b[3])//2)); time.sleep(1.5)
    s2=find(name); print(f"{name}: 允许 -> {'禁止' if s2 is not None and s2.get('checked')=='false' else '??'}")
