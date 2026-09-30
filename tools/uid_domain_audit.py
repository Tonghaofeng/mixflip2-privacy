#!/usr/bin/env python3
"""UID → 域名 流量取证：手机 /proc/net 的「本地端口→UID」 × Surge 网关的「来源端口→域名/字节」。

用法: uid_domain_audit.py <秒数> [输出前缀]
  手机须 adb 连着、处于 Surge 网关下的 Wi-Fi；Mac 能 `ssh macserver`（Surge 所在机）。
输出: <前缀>.json（原始连接） + 终端汇总（按 UID/包名 → 域名，标出国内/小米相关）。
"""
import json, re, subprocess, sys, threading, time, collections

DUR = int(sys.argv[1]) if len(sys.argv) > 1 else 600
OUT = sys.argv[2] if len(sys.argv) > 2 else f"audit_{time.strftime('%Y%m%d_%H%M%S')}"
PHONE_IP = subprocess.run(["adb", "shell", "-n", "ip", "-4", "addr", "show", "wlan0"],
                          capture_output=True, text=True).stdout
PHONE_IP = re.search(r"inet (\d+\.\d+\.\d+\.\d+)", PHONE_IP).group(1)
SSH = ["ssh", "-o", "ControlMaster=auto", "-o", "ControlPath=/tmp/.ssh-surge-%r@%h", "-o", "ControlPersist=120", "macserver"]
CLI = "/Applications/Surge.app/Contents/Applications/surge-cli --raw dump"
CN = re.compile(r"xiaomi|miui|mi\.com|mi-img|xmpush|amap|autonavi|baidu|bdstatic|qq\.com|tencent|gtimg|"
                r"wo\.com\.cn|10010|chinamobile|189\.cn|qualcomm\.cn|umeng|jpush|getui|alipay|taobao|"
                r"163\.com|sohu|bytedance|douyin|volces|aliyun|alicdn|\.cn$", re.I)

port_uid = {}          # (proto, 本地端口) -> uid（最近一次见到的）
conns = {}             # surge 连接 id -> 记录
stop = time.time() + DUR
PROCS = []

def phone_sampler():
    # 手机上一个常驻 shell 循环，每 0.5s 输出一次四张表，避免反复起 adb 进程漏掉短连接
    loop = ("while true; do for f in tcp tcp6 udp udp6; do echo \"@@$f\"; cat /proc/net/$f; done; "
            "echo @@END; sleep 0.5; done")
    p = subprocess.Popen(["adb", "shell", loop], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, stdin=subprocess.DEVNULL, text=True)
    PROCS.append(p)
    proto = None
    for line in p.stdout:
        if time.time() > stop + 5:
            p.kill(); break
        line = line.strip()
        if line.startswith("@@"):
            proto = line[2:]; continue
        f = line.split()
        if len(f) < 8 or not f[0].endswith(":"):
            continue
        lport = int(f[1].split(":")[1], 16)
        uid = int(f[7])
        port_uid[(proto.rstrip("6"), lport)] = uid

def surge_poller():
    while time.time() < stop:
        for kind in ("active", "recent"):
            try:
                raw = subprocess.run(SSH + [f"{CLI} {kind}"], capture_output=True, text=True, timeout=20).stdout
                reqs = json.loads(raw).get("requests", [])
            except Exception:
                continue
            for r in reqs:
                if r.get("sourceAddress") != PHONE_IP:
                    continue
                old = conns.get(r["id"], {})
                # 活动连接字节数在增长，取最大值
                r["inBytes"] = max(r.get("inBytes", 0), old.get("inBytes", 0))
                r["outBytes"] = max(r.get("outBytes", 0), old.get("outBytes", 0))
                conns[r["id"]] = r
        time.sleep(2)

t1 = threading.Thread(target=phone_sampler, daemon=True); t1.start()
t2 = threading.Thread(target=surge_poller, daemon=True); t2.start()
print(f"采集 {DUR}s：手机 {PHONE_IP}，Surge 连接按来源端口对齐 UID …", flush=True)
while time.time() < stop:
    time.sleep(30)
    print(f"  {int(stop - time.time())}s 剩余 | 网关连接 {len(conns)} | 端口映射 {len(port_uid)}", flush=True)
time.sleep(4)
for _p in PROCS: _p.kill()

# UID → 包名
pk = subprocess.run(["adb", "shell", "-n", "pm", "list", "packages", "-U", "-u"], capture_output=True, text=True).stdout
uidpkg = collections.defaultdict(list)
for m in re.finditer(r"package:(\S+) uid:(\d+)", pk):
    uidpkg[int(m.group(2))].append(m.group(1))
def who(uid):
    if uid is None: return "?(未对上端口)"
    ps = uidpkg.get(uid, [])
    return f"{uid} " + (",".join(ps[:2]) + (f" +{len(ps)-2}" if len(ps) > 2 else "") if ps else "(无包/内核)")

agg = collections.defaultdict(lambda: collections.defaultdict(lambda: [0, 0, 0, set()]))
rows = []
for r in conns.values():
    proto = "udp" if r.get("method") in ("QUIC", "UDP", "DNS") else "tcp"
    uid = port_uid.get((proto, r.get("sourcePort"))) or port_uid.get(("udp" if proto == "tcp" else "tcp", r.get("sourcePort")))
    host = (r.get("remoteHost") or r.get("URL") or "?").rsplit(":", 1)[0]
    a = agg[who(uid)][host]
    a[0] += 1; a[1] += r.get("outBytes", 0); a[2] += r.get("inBytes", 0)
    a[3].add("拦" if r.get("rejected") else r.get("policyName", ""))
    rows.append({"uid": uid, "pkg": uidpkg.get(uid), "host": host, "out": r.get("outBytes"), "in": r.get("inBytes"),
                 "policy": r.get("policyName"), "rule": r.get("rule"), "rejected": r.get("rejected"),
                 "start": r.get("startDate"), "sport": r.get("sourcePort"), "method": r.get("method")})
json.dump(rows, open(OUT + ".json", "w"), ensure_ascii=False, indent=1, default=list)

print(f"\n==== 结果（{len(rows)} 条连接，原始数据 {OUT}.json）====")
for w, hosts in sorted(agg.items(), key=lambda kv: -sum(v[1] for v in kv[1].values())):
    tot_out = sum(v[1] for v in hosts.values())
    print(f"\n[{w}]  上行 {tot_out/1024:.1f} KB")
    for h, (n, o, i, pol) in sorted(hosts.items(), key=lambda kv: -kv[1][1]):
        flag = " ⚠国内" if CN.search(h) else ""
        print(f"   {h:48s} x{n:<3d} ↑{o/1024:7.1f}KB ↓{i/1024:7.1f}KB  {'/'.join(sorted(pol))}{flag}")
