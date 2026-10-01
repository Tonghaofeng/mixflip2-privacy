#!/usr/bin/env python3
"""验收：手机（Clash Meta + WireGuard 回家）在 N 秒内是否还有漏网的小米/国内上报，以及是否有绕过 VPN 的直连。

证据两路：
  1) 手机 logcat 里 CMFA 的连接日志：进程名 → 目标 → 命中规则 → 出口；标出「小米/国内/裸 IP」却没被 REJECT 的
  2) 家里 Surge：来源 = 手机 Wi-Fi IP 的新连接，只允许 WG 端口 51820、NTP 123、DoH 到 223.5.5.5/1.12.12.12（策略里的直连项）
用法: accept.py [秒数，默认 300]
"""
import json, re, subprocess, sys, time, collections

DUR = int(sys.argv[1]) if len(sys.argv) > 1 else 300
SUS = re.compile(r"xiaomi|miui|mi\.com|xmpush|sandai|xunlei|amap|autonavi|baidu|qq\.com|tencent|qualcomm\.cn|"
                 r"wo\.com\.cn|umeng|getui|jpush|\.cn(:\d+)?$|^\d+\.\d+\.\d+\.\d+(:\d+)?$", re.I)
XIAOMI_PROC = re.compile(r"xiaomi|miui|lbe|android\.uid\.|com\.android\.(systemui|camera|contacts|incallui|thememanager)|"
                         r"android\.media|fido|qualcomm", re.I)
ALLOWED_DIRECT = re.compile(r":(51820|123)$|^(223\.5\.5\.5|1\.12\.12\.12):443$")

def sh(cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout

phone_ip = re.search(r"inet (\d+\.\d+\.\d+\.\d+)", sh(["adb", "shell", "-n", "ip", "-4", "addr", "show", "wlan0"]))
phone_ip = phone_ip.group(1) if phone_ip else None
t0 = time.time()
# 不清 logcat（会毁掉其他会话的取证日志，10-01 体检第 13 条）：记下手机时间，结束时只读这之后的
start = sh(["adb", "shell", "-n", "date '+%m-%d %H:%M:%S.000'"]).strip()
print(f"观察 {DUR}s（手机保持空闲）… Wi-Fi IP={phone_ip}", flush=True)
time.sleep(DUR)

log = sh(["adb", "logcat", "-d", "-T", start])
agg = collections.Counter()
leaks = collections.Counter()
for l in log.splitlines():
    if "ClashMetaForAndroid" not in l or "-->" not in l or "[PKG]" in l:
        continue
    m = re.search(r"\((?:[^)]*)\) --> (\S+)", l) or re.search(r"--> (\S+)", l)
    p = re.search(r":\d+\(([^)]*)\) -->", l)
    proc, dst = (p.group(1) if p else "?"), (m.group(1) if m else "?")
    rej = "REJECT" in l
    err = "error" in l
    out = re.search(r"using (\S+)", l)
    verdict = "REJECT" if rej else (out.group(1) if out else ("ERR" if err else "?"))
    agg[(proc, dst, verdict)] += 1
    # 不算泄漏：Clash 自己经隧道查 Surge DNS / DoH；经隧道回家的海外裸 IP（国内裸 IP 已被 GEOIP 兜底规则拒绝）
    tunnel = "wg-home" in verdict
    if tunnel and (dst.startswith("198.18.0.2:53") or dst.startswith("1.1.1.1:443") or re.match(r"^\d+\.\d+\.\d+\.\d+:\d+$", dst)):
        continue
    if not rej and (SUS.search(dst) or XIAOMI_PROC.search(proc)):
        leaks[(proc, dst, verdict)] += 1

print(f"\n== 1) 手机侧：{sum(agg.values())} 条连接日志")
rejected = [(k, v) for k, v in agg.items() if k[2] == "REJECT"]
print(f"   被拦截 {sum(v for _, v in rejected)} 条，按进程/目标：")
for (proc, dst, _), v in sorted(rejected, key=lambda kv: -kv[1])[:25]:
    print(f"     {v:3d}  {proc[:34]:34s} {dst}")
print(f"   ⚠ 小米/国内/裸 IP 却未被拦截：{sum(leaks.values())} 条")
for (proc, dst, verdict), v in leaks.most_common(30):
    print(f"     {v:3d}  {proc[:34]:34s} {dst:45s} → {verdict}")

print("\n== 2) Surge 侧：来自手机 Wi-Fi IP、且在观察期内新建的连接")
if phone_ip:
    raw = sh(["ssh", "macserver", "/Applications/Surge.app/Contents/Applications/surge-cli --raw dump recent; echo '@@'; "
              "/Applications/Surge.app/Contents/Applications/surge-cli --raw dump active"])
    seen, bad = {}, []
    for part in raw.split("@@"):
        try:
            for r in json.loads(part).get("requests", []):
                if r.get("sourceAddress") == phone_ip and r.get("startDate", 0) >= t0:
                    seen[r["id"]] = r
        except Exception:
            pass
    for r in seen.values():
        host = r.get("remoteHost") or r.get("URL") or "?"
        (bad if not ALLOWED_DIRECT.search(host) else []).append(host)
    print(f"   新连接 {len(seen)} 条；其中不在白名单（WG/NTP/DoH）的：{len(bad)} 条")
    for h in collections.Counter(bad).most_common(20):
        print(f"     {h[1]:3d}  {h[0]}")
else:
    print("   手机不在 Wi-Fi，跳过")
