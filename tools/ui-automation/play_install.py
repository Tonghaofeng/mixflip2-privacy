#!/usr/bin/env python3
"""逐个打开 Play 商店详情页，用 uiautomator 找到「安装/更新」按钮并点击。"""
import re, subprocess, sys, time, xml.etree.ElementTree as ET

PKGS = sys.argv[1:]
INSTALL = {"安装", "Install", "更新", "Update"}
DONE = {"打开", "Open", "卸载", "Uninstall", "取消", "Cancel"}  # 取消=已在下载
FAIL = ("不兼容", "not compatible", "无法在您所在的国家", "isn't available", "找不到")


def adb(*a, check=False):
    return subprocess.run(["adb", "shell", "-n", *a], capture_output=True, text=True).stdout


def installed(p):
    return f"package:{p}\n" in adb("pm", "list", "packages", p).replace("\r", "")


def dump():
    for _ in range(4):
        out = adb("uiautomator", "dump", "/sdcard/ui.xml")
        if "dumped" in out:
            x = adb("cat", "/sdcard/ui.xml")
            try:
                return ET.fromstring(x)
            except ET.ParseError:
                pass
        time.sleep(1.5)
    return None


def center(b):
    x1, y1, x2, y2 = map(int, re.findall(r"\d+", b))
    return (x1 + x2) // 2, (y1 + y2) // 2


def handle(p):
    adb("am", "start", "-a", "android.intent.action.VIEW",
        "-d", f"market://details?id={p}", "-p", "com.android.vending")
    deadline = time.time() + 25
    while time.time() < deadline:
        time.sleep(2.5)
        root = dump()
        if root is None:
            continue
        nodes = [n for n in root.iter("node") if n.get("package") == "com.android.vending"]
        if not nodes:
            continue  # 还没切到 Play 商店（或锁屏）
        texts = []
        for n in nodes:
            t = (n.get("text") or n.get("content-desc") or "").strip()
            texts.append(t)
            if t in INSTALL and n.get("enabled") == "true":
                # 按钮文字可能在不可点的子节点上，点它的中心即可
                x, y = center(n.get("bounds"))
                adb("input", "tap", str(x), str(y))
                time.sleep(3)
                return f"tapped '{t}'"
        blob = " | ".join(texts)
        if any(f in blob for f in FAIL):
            return "UNAVAILABLE: " + next(f for f in FAIL if f in blob)
        if any(t in DONE for t in texts):
            return "already installed/up to date"
    return "TIMEOUT (no button found)"


if "isKeyguardShowing=true" in adb("dumpsys", "window"):
    sys.exit("屏幕锁着，先解锁")
for p in PKGS:
    if p != "com.google.android.gms" and installed(p):
        print(f"{p:45s} skip (installed)", flush=True)
        continue
    print(f"{p:45s} {handle(p)}", flush=True)
adb("input", "keyevent", "HOME")
