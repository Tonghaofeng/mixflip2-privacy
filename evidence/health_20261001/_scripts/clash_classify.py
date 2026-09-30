#!/usr/bin/env python3
"""Read-only classifier for CMFA connection logs (replicates tools/accept.py phone-side logic, more detail)."""
import re, sys, collections, ipaddress

src = sys.argv[1]
SUS = re.compile(r"xiaomi|miui|mi\.com|xmpush|sandai|xunlei|amap|autonavi|baidu|qq\.com|tencent|qualcomm\.cn|"
                 r"wo\.com\.cn|umeng|getui|jpush|\.cn(:\d+)?$|^\d+\.\d+\.\d+\.\d+(:\d+)?$", re.I)
XIAOMI_PROC = re.compile(r"xiaomi|miui|lbe|android\.uid\.|com\.android\.(systemui|camera|contacts|incallui|thememanager|htmlviewer|updater)|"
                         r"android\.media|fido|qualcomm", re.I)
CONN = re.compile(r"\[(TCP|UDP)\] (\S+?)\(([^)]*)\) --> (\S+) match ([A-Za-z-]+)(?:\((.*?)\))? using (\S+)")
CONN2 = re.compile(r"\[(TCP|UDP)\] (\S+) --> (\S+) (?:match ([A-Za-z-]+)(?:\((.*?)\))?|doesn't match any rule)? ?using (\S+)")
DIALERR = re.compile(r"\[(TCP|UDP)\] dial (\S+) \(match ([^)]*)\) (\S+?)\(([^)]*)\) --> (\S+) error: (.*)")

rows = []
errs = []
first = last = None
for l in open(src, errors="replace"):
    if "ClashMetaForAndroid" not in l:
        continue
    ts = " ".join(l.split()[:2])
    first = first or ts; last = ts
    m = CONN.search(l)
    if m:
        proto, s, proc, dst, rtype, rpay, out = m.groups()
        rows.append((ts, proto, proc, dst, f"{rtype}({rpay})", out)); continue
    m = CONN2.search(l)
    if m and "[PKG]" not in l:
        proto, s, dst, rtype, rpay, out = m.groups()
        rows.append((ts, proto, "?", dst, f"{rtype}({rpay})", out)); continue
    m = DIALERR.search(l)
    if m:
        errs.append((ts,) + m.groups())

def is_cn_ip(host):
    h = host.rsplit(":", 1)[0].strip("[]")
    try:
        ip = ipaddress.ip_address(h)
    except ValueError:
        return None
    return ip

print(f"window {first} .. {last}; connection lines {len(rows)}; dial errors {len(errs)}")
by_verdict = collections.Counter(r[5] for r in rows)
print("verdicts:", dict(by_verdict))

rej = collections.Counter((r[2], r[3].rsplit(':',1)[0], r[4]) for r in rows if r[5] == "REJECT")
print(f"\n== REJECTED ({sum(rej.values())}) by process/dest/rule")
for (p, d, rule), n in rej.most_common(40):
    print(f"  {n:4d}  {p[:36]:36s} {d[:44]:44s} {rule[:50]}")

allowed = collections.Counter((r[2], r[3].rsplit(':',1)[0], r[5], r[4]) for r in rows if r[5] != "REJECT")
print(f"\n== ALLOWED ({sum(allowed.values())}) by process/dest/outbound")
for (p, d, o, rule), n in allowed.most_common(60):
    print(f"  {n:4d}  {p[:36]:36s} {d[:44]:44s} {o[:16]:16s} {rule[:40]}")

leaks = collections.Counter()
for ts, proto, proc, dst, rule, out in rows:
    if out == "REJECT":
        continue
    tunnel = "wg-home" in out
    # same exclusions as accept.py: Clash's own DNS via tunnel, DoH 1.1.1.1, overseas bare IP through tunnel (CN bare IPs are GEOIP-rejected)
    if tunnel and (dst.startswith("198.18.0.2:53") or dst.startswith("1.1.1.1:443") or re.match(r"^\d+\.\d+\.\d+\.\d+:\d+$", dst)):
        continue
    if SUS.search(dst) or XIAOMI_PROC.search(proc):
        leaks[(proc, dst, out, rule)] += 1
print(f"\n== SUSPICIOUS NOT REJECTED (accept.py criteria): {sum(leaks.values())}")
for (p, d, o, rule), n in leaks.most_common(40):
    print(f"  {n:4d}  {p[:36]:36s} {d[:44]:44s} -> {o}  [{rule[:50]}]")

# bare IPs allowed through tunnel (listed for transparency even though accept.py exempts them)
bare = collections.Counter((r[2], r[3], r[5]) for r in rows if r[5] != "REJECT" and re.match(r"^\d+\.\d+\.\d+\.\d+:\d+$", r[3]))
print(f"\n== bare-IP destinations allowed (for manual review): {sum(bare.values())}")
for (p, d, o), n in bare.most_common(30):
    print(f"  {n:4d}  {p[:36]:36s} {d:28s} {o}")

direct = [r for r in rows if r[5] == "DIRECT"]
print(f"\n== DIRECT (bypass tunnel) {len(direct)}")
for r in direct:
    print("  ", r)
print(f"\n== dial errors {len(errs)} (sample)")
for e in errs[:8]:
    print("  ", e[0], e[1], e[4], "->", e[6], e[7][:80])
