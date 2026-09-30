#!/usr/bin/env python3
"""fwlist.py  列出联网控制当前列表每一行的开关状态（允许/禁止），自动滚完整个列表"""
import re, subprocess, time, xml.etree.ElementTree as ET
def sh(*a): return subprocess.run(["adb","shell","-n",*a],capture_output=True,text=True).stdout
def box(n): return list(map(int,re.findall(r"\d+",n.get("bounds"))))
def rows():
    for _ in range(4):
        if "dumped" in sh("uiautomator","dump","/sdcard/ui.xml"):
            try: ns=list(ET.fromstring(sh("cat","/sdcard/ui.xml")).iter("node")); break
            except ET.ParseError: pass
        time.sleep(1)
    out={}
    for n in ns:
        if (n.get("text") or "") and box(n)[0]==237:
            cy=(box(n)[1]+box(n)[3])//2
            sw=[m for m in ns if m.get("class")=="android.widget.Switch" and box(m)[1]<=cy<=box(m)[3]]
            if sw: out[n.get("text")]=sw[0].get("checked")=="true"
    return out
for _ in range(10): sh("input","swipe","600","900","600","2600","150")
time.sleep(1); allr={}; prev=None
for _ in range(30):
    r=rows(); allr.update(r)
    if list(r)==prev: break
    prev=list(r); sh("input","swipe","600","2400","600","1300","400"); time.sleep(0.8)
for k,v in allr.items(): print(("允许" if v else "禁止"), k)
