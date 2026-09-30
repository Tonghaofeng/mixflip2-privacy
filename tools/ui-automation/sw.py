#!/usr/bin/env python3
"""sw.py        列出当前界面所有开关及其旁边的标题
   sw.py off    关掉所有处于开启状态的开关（逐个点，点一次重新 dump）"""
import re, subprocess, sys, time, xml.etree.ElementTree as ET
def sh(*a): return subprocess.run(["adb","shell","-n",*a],capture_output=True,text=True).stdout
def dump():
    for _ in range(4):
        if "dumped" in sh("uiautomator","dump","/sdcard/ui.xml"):
            try: return ET.fromstring(sh("cat","/sdcard/ui.xml"))
            except ET.ParseError: pass
        time.sleep(1.5)
def box(n): return list(map(int,re.findall(r"\d+",n.get("bounds"))))
def switches(root):
    ns=list(root.iter("node")); out=[]
    texts=[(box(n),(n.get("text") or "").strip()) for n in ns if (n.get("text") or "").strip()]
    for n in ns:
        if n.get("checkable")=="true" and ("Switch" in n.get("class") or "CheckBox" in n.get("class") or "Toggle" in n.get("class")):
            b=box(n); cy=(b[1]+b[3])//2
            # 同一行里、开关左边、最靠上的那段文字当标题
            row=[t for tb,t in texts if tb[2]<=b[0]+5 and tb[1]-120<=cy<=tb[3]+120]
            out.append((n, row[0] if row else "?", n.get("checked")=="true"))
    return out
root=dump()
if len(sys.argv)>1 and sys.argv[1]=="off":
    for _ in range(20):
        on=[s for s in switches(root) if s[2]]
        if not on: break
        n,title,_=on[0]; b=box(n); sh("input","tap",str((b[0]+b[2])//2),str((b[1]+b[3])//2)); print("关闭:",title); time.sleep(2)
        root=dump()
for n,title,c in switches(root): print(("ON " if c else "off"), title, n.get("bounds"))
