#!/usr/bin/env python3
"""生成小米 MIX Flip 2 的 mihomo（Clash Meta for Android）策略。

- 包名→UID 实时从手机查（UID 会被回收重用，不能写死）
- WireGuard 密钥从 Mac mini 读（ssh macserver），不入库
- 输出 ../clash/mixflip2.yaml（600 权限），并用本机 mihomo -t 校验
用法: gen_clash_config.py [--check-only]
"""
import json, os, re, secrets, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "..", "clash")
OUT = os.path.join(OUT_DIR, "mixflip2.yaml")
HOME_WAN = "tonytong.uk"      # DDNS（cloudflare-ddns 容器维护）；路由器静态转发 UDP 51820 → 192.168.50.2
HOME_LAN = "192.168.50.2"
SS_PORT = 50388                # Mac mini ssserver（~/apps/ss-home/config.json，口令不入库）

# 整个 UID 禁网（系统身份 UID<10000 在这里拦得住：VPN 接管全部 UID）
BLOCK_PKGS = {
    "com.xiaomi.finddevice": "查找设备：定期上报位置（基线 20 次/15min）",
    "com.android.thememanager": "主题：借小米账号接口通信",
    "com.xiaomi.cameramind": "相机 AI 场景",
    "com.miui.backup": "本地备份（不需要联网）",
    "com.xiaomi.bluetooth": "蓝牙扩展：连 hlth.io.mi.com（UID 1002 共享）",
    "com.lbe.security.miui": "权限管理：api.sec.miui.com / xmpush",
    "com.miui.guardprovider": "病毒扫描：保留供安装校验，只断网",
    "com.miui.packageinstaller": "安装器：反诈/风险应用云检测",
    "com.android.camera": "小米相机（保留拍照，断网）",
    "com.xiaomi.cameratools": "", "com.android.soundrecorder": "", "com.miui.screenrecorder": "",
    "com.miui.compass": "", "com.android.contacts": "小米拨号：号码识别云查询",
    "com.android.incallui": "", "com.miui.home": "桌面：推荐/云控", "com.miui.fliphome": "外屏桌面",
    "com.miui.securityadd": "", "com.miui.powerinsight": "", "com.miui.misound": "",
    "com.miui.screenshot": "", "com.miui.extraphoto": "", "com.miui.miwallpaper": "",
    "com.android.htmlviewer": "", "com.miui.core": "", "com.miui.accessibility": "",
    "com.xiaomi.macro": "", "com.xiaomi.continuity.sdkapp": "", "com.fido.asm": "连小米账号",
    "com.miui.securityinputmethod": "", "com.miui.system": "", "com.miui.rom": "",
    "com.qualcomm.qti.qms.service.connectionsecurity": "",
    "com.miui.gallery": "已禁用，双保险", "com.miui.notes": "已禁用", "com.miui.calculator": "已禁用",
    "com.miui.cleanmaster": "已禁用", "com.mfashiongallery.emag": "已禁用",
    "com.android.systemui": "实测连小米裸 IP 111.13.142.153（HTTPDNS）",
}
# UID 1000(system)：安全中心/powerkeeper/融合定位(高德百度腾讯 SDK)/云控 全在这个身份里，删不掉 → 默认全拦，只放行 GNSS 辅助
SYSTEM_UIDS = [1000]
SYSTEM_ALLOW_SUFFIX = ["izatcloud.net", "gpsonextra.net", "supl.google.com", "connectivitycheck.gstatic.cn"]
# 系统更新（安全补丁）放行
OTA_ALLOW = ["DOMAIN,update.miui.com", "DOMAIN-SUFFIX,d.miui.com"]
# 网络定位窄口子（10-07 Tony 选定）：国行 ROM 的 network provider 只认 metoknlp，它把附近 Wi-Fi/基站 ID 发给高德
# aps.amap.com 换坐标；只放行「这个进程 × 这个域名」，其余 amap/小米流量照拦（第 4 段 amap.com REJECT 不变）。
# 不放行时现象：室内 /v1/location 503，logcat「metoknlp --> aps.amap.com:443 match DomainSuffix(amap.com) using REJECT」
NLP_ALLOW = ["AND,((PROCESS-NAME,com.xiaomi.metoknlp),(DOMAIN,aps.amap.com))"]
# 任何 UID 都拦的域名族
REJECT_KEYWORD = ["xiaomi", "miui", "xmpush", "sandai", "xunlei"]
REJECT_SUFFIX = ["mi.com", "mi-img.com", "mi-fds.com", "mifile.cn", "mipay.com", "micloud.com",
                 "amap.com", "autonavi.com", "map.baidu.com", "map.qq.com", "sparta.html5.qq.com",
                 "qualcomm.cn", "dm.wo.com.cn", "umeng.com", "umengcloud.com", "getui.com", "jpush.cn",
                 # 10-01 晚补：腾讯 SDK（原 guardprovider 云查杀在连）；电信终端自注册/管理（com.xiaomi.registration，带 IMEI/定位，UID 1001 不在整身份封禁里）
                 "rcpc-sdk-access.m.qq.com", "rcpc-sdk-access-v6.m.qq.com", "zzhc.vnet.cn", "tydevice.com"]


# 谷歌后台遥测（10-02 用户：重点是背后的隐私与遥测）：广告/分析/崩溃上报/活动足迹/Chrome 信标。
# 不拦 play.googleapis.com（Clearcut 日志与 Play 下载同域，拦了装不了 App）、checkin、mtalk（推送）。
GOOGLE_TELEMETRY = ["doubleclick.net", "googlesyndication.com", "googleadservices.com", "adservice.google.com",
                    "app-measurement.com", "google-analytics.com", "firebaselogging-pa.googleapis.com",
                    "crashlyticsreports-pa.googleapis.com", "firebase-settings.crashlytics.com",
                    "footprints-pa.googleapis.com", "gvt2.com", "gvt3.com"]


def sh(cmd, **kw):
    return subprocess.run(cmd, capture_output=True, text=True, **kw).stdout


def phone_uids():
    out = sh(["adb", "shell", "-n", "pm", "list", "packages", "-U", "-u"])
    return {m.group(1): int(m.group(2)) for m in re.finditer(r"package:(\S+) uid:(\d+)", out)}


def shared_user(pkg):
    """共享 UID 的包，CMFA 报的进程名可能是 sharedUserId（如 android.uid.bluetooth），两个名字都要写。"""
    m = re.search(r"sharedUser=SharedUserSetting\{\S+ ([\w.]+)/\d+\}", sh(["adb", "shell", "-n", "dumpsys", "package", pkg]))
    return m.group(1) if m else None


def build():
    uids = phone_uids()
    rule_uids, notes = {}, []
    for p, why in BLOCK_PKGS.items():
        if p in uids:
            rule_uids.setdefault(uids[p], []).append(p)
        else:
            notes.append(f"# (手机上无 {p}，跳过)")
    L = []
    L += ["# 由 tools/gen_clash_config.py 生成 —— 勿手改；改脚本后重新生成", *notes, "",
          "mode: rule", "log-level: info", "ipv6: false", "unified-delay: true",
          "find-process-mode: always",
          "external-controller: 127.0.0.1:9090", f"secret: {secrets.token_hex(12)}",
          "profile: {store-selected: true, store-fake-ip: true}",   # store-fake-ip：重启后不复用 fake-ip，防串域名（10-01 体检 WhatsApp→rcpc 那条）
          "sniffer: {enable: true, sniff: {TLS: {ports: [443]}, HTTP: {ports: [80]}, QUIC: {ports: [443]}}}",
          "dns:", "  enable: true", "  ipv6: false", "  enhanced-mode: fake-ip", "  fake-ip-range: 28.0.0.1/8",
          "  fake-ip-filter: ['+.lan', '+.local', 'connectivitycheck.gstatic.cn', '+.pool.ntp.org']",
          "  default-nameserver: [223.5.5.5]",
          "  # 回家端点 tonytong.uk 必须直连解析：否则 DoH 走 PROXY→要隧道→要解析端点，死锁（09-30 实测）；",
          "  # 且必须用 DoH（按 IP）：家里局域网的明文 DNS 会被 Surge 劫持成 fake-ip(198.18.x)，换到蜂窝后这个地址不可达（09-30 实测）",
          "  proxy-server-nameserver: ['https://223.5.5.5/dns-query', 'https://1.12.12.12/dns-query']",
          "  nameserver: ['https://1.1.1.1/dns-query#PROXY']", ""]
    # 回家通道 = Shadowsocks 2022 over TCP（Mac mini ss-home，launchd com.tony.ss-home，路由器转发 TCP+UDP 50388，
    # pf 锚点 aios-sshreply 让回包走 bond0）。原 WireGuard 出站 10-05 整体取消：换网后留下多个 UDP 套接字、
    # 握手序列发不到家 → 隧道半死断流（同一分钟 12 次握手家里只收到 2 次），且热重载配置清不掉旧实例。
    ss_pw = json.loads(sh(["ssh", "macserver", "cat ~/apps/ss-home/config.json"]))["password"]
    L += ["proxies:",
          f"  - {{name: ss-home, type: ss, server: {HOME_WAN}, port: {SS_PORT}, cipher: 2022-blake3-aes-128-gcm, password: '{ss_pw}', udp: true}}",
          "",
          "proxy-groups:",
          "  - {name: HOME, type: fallback, proxies: [ss-home], url: 'http://connectivitycheck.gstatic.com/generate_204', interval: 120, timeout: 3000}",
          "  - {name: PROXY, type: fallback, proxies: [HOME, DIRECT], url: 'http://connectivitycheck.gstatic.com/generate_204', interval: 120, timeout: 3000}",
          # Mac mini 本机：在家直连能通就直连；出门（蜂窝）直连不通 → 自动改走 HOME（ss-home 就在 Mac 本机）。
          # 健康检查用点检面板 /health（200、不记日志）。10-01 加：否则出门打不开 192.168.50.2 上的点检面板等服务，也拉不到本配置的更新。
          "  # Mac mini 本机（192.168.50.2）：在家局域网直连能通就直连，出门直连不通自动改走 HOME（ss-home 在 Mac 本机，连 192.168.50.2 照通）",
          f"  - {{name: MACMINI, type: fallback, proxies: [DIRECT, HOME], url: 'http://{HOME_LAN}:8899/health', interval: 60, lazy: false, timeout: 3000}}", "",
          "rules:",
          "  # 0 局域网 / NTP",
          f"  - IP-CIDR,{HOME_LAN}/32,MACMINI,no-resolve",
          "  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve",
          "  - DST-PORT,123,DIRECT",
          "  # 1 系统更新（安全补丁）放行"] + [f"  - {r},PROXY" for r in OTA_ALLOW] \
         + ["  # 1b 网络定位：只放行 metoknlp → aps.amap.com"] + [f"  - {r},PROXY" for r in NLP_ALLOW]
    # 2 整个身份禁网。实测（09-30）：CMFA 只把「包名」交给 mihomo，UID 规则永远匹配不上 → 以 PROCESS-NAME 为准，
    #   UID 规则留作冗余。UID 1000 的所有流量被 CMFA 统一报成 com.android.systemui（实测 [PKG] ... by 1000[com.android.systemui]）。
    L += ["  # 2 整个身份禁网（PROCESS-NAME 为主，UID 冗余）"]
    names = []
    for uid, pkgs in sorted(rule_uids.items()):
        if uid in SYSTEM_UIDS:
            continue                      # UID 1000 在第 3 段统一处理（先放行 GNSS 再全拦）
        for p in pkgs:
            for n in (p, shared_user(p)):
                if n and n not in names:
                    names.append(n); L.append(f"  - PROCESS-NAME,{n},REJECT")
        L.append(f"  - UID,{uid},REJECT")
    L += ["  # 3 system(1000)：CMFA 报成 com.android.systemui / android.uid.system；只放行 GNSS 辅助与联网检测，其余全拦"]
    allow = ",".join(f"(DOMAIN-SUFFIX,{d})" for d in SYSTEM_ALLOW_SUFFIX)
    for n in ("com.android.systemui", "android.uid.system", "android"):
        L.append(f"  - AND,((PROCESS-NAME,{n}),(OR,({allow}))),PROXY")
        L.append(f"  - PROCESS-NAME,{n},REJECT")
    L.append(f"  - AND,((UID,1000),(OR,({allow}))),PROXY")
    L.append("  - UID,1000,REJECT")
    L += ["  # 4 域名族（任何 UID）"] + [f"  - DOMAIN-KEYWORD,{k},REJECT" for k in REJECT_KEYWORD] \
         + [f"  - DOMAIN-SUFFIX,{s},REJECT" for s in REJECT_SUFFIX] \
         + ["  # 4b 谷歌后台遥测"] + [f"  - DOMAIN-SUFFIX,{s},REJECT" for s in GOOGLE_TELEMETRY]
    L += ["  # 5 兜底（不依赖 UID 识别，UID 查不到时也生效）：直连国内裸 IP 的连接 = HTTPDNS/写死 IP 上报",
          "  - GEOIP,CN,REJECT,no-resolve"]
    L += ["  # 6 其余回家（家里不通则直连，上面的拦截照样生效）", "  - MATCH,PROXY", ""]
    return "\n".join(L)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    y = build()
    with open(OUT, "w") as f:
        f.write(y)
    os.chmod(OUT, 0o600)
    # macOS 版 mihomo 不支持 UID 规则（仅 Linux/Android）：本机校验时换成同形的 SRC-PORT，其余语法照常校验；
    # UID 规则本身由手机端 CMFA 导入时校验。
    chk = "/tmp/mihomo-check/check.yaml"; os.makedirs("/tmp/mihomo-check", exist_ok=True)
    open(chk, "w").write(re.sub(r"\(UID,(\d+)\)", r"(SRC-PORT,\1)", re.sub(r"- UID,(\d+),", r"- SRC-PORT,\1,", y)))
    r = subprocess.run(["/opt/homebrew/bin/mihomo", "-t", "-f", chk, "-d", "/tmp/mihomo-check"],
                       capture_output=True, text=True)
    os.remove(chk)
    print((r.stdout + r.stderr).strip().splitlines()[-1])
    print(f"-> {OUT}  ({y.count(chr(10))} 行, PROCESS-NAME {y.count('PROCESS-NAME,')} 条, UID {y.count('UID,')} 条)")


if __name__ == "__main__":
    main()
