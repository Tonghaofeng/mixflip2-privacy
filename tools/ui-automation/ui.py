#!/usr/bin/env python3
"""ui.py dump            列出当前界面文字和坐标
   ui.py tap <文字>       点击文字完全匹配的节点（没找到就退出码 1）
   ui.py tapc <文字>      点击包含该文字的节点"""
import re, subprocess, sys, time, xml.etree.ElementTree as ET
def sh(*a): return subprocess.run(["adb","shell","-n",*a],capture_output=True,text=True).stdout
def nodes():
    for _ in range(4):
        if "dumped" in sh("uiautomator","dump","/sdcard/ui.xml"):
            try: return list(ET.fromstring(sh("cat","/sdcard/ui.xml")).iter("node"))
            except ET.ParseError: pass
        time.sleep(1.5)
    return []
def label(n): return (n.get("text") or n.get("content-desc") or "").strip()
def center(n):
    x1,y1,x2,y2=map(int,re.findall(r"\d+",n.get("bounds"))); return (x1+x2)//2,(y1+y2)//2
cmd=sys.argv[1]
ns=nodes()
if cmd=="dump":
    for n in ns:
        if label(n): print(f"{label(n)[:50]!r:55} {n.get('package')[-22:]:22} {n.get('bounds')}")
else:
    want=sys.argv[2]
    hit=[n for n in ns if (label(n)==want if cmd=="tap" else want in label(n))]
    if not hit: print(f"NOT FOUND: {want}"); sys.exit(1)
    x,y=center(hit[0]); sh("input","tap",str(x),str(y)); print(f"tapped {label(hit[0])!r} @ {x},{y}")
