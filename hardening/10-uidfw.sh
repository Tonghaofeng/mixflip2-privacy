#!/system/bin/sh
# UID 防火墙 (2026-10-11): 系统身份(1000 system/1001 radio/10229 qualcomm.location)在物理网卡上直连=绕过 VPN 锁定的后门(OPEN_ITEMS #7)
# root 下 iptables owner 匹配封之; 合法流量仍走 tun(白名单 shell/root/clash 10277 不受影响)
# 代价: uid1001 的彩信直连断(电话/短信走 RIL 不受影响)
sleep 40   # 等 wlan/rmnet 就绪
for IF in wlan0 rmnet_data0 rmnet_data1 rmnet_data2; do
  for U in 1000 1001 10229; do
    iptables  -C OUTPUT -o $IF -m owner --uid-owner $U -j REJECT 2>/dev/null || \
    iptables  -I OUTPUT -o $IF -m owner --uid-owner $U -j REJECT
    ip6tables -C OUTPUT -o $IF -m owner --uid-owner $U -j REJECT 2>/dev/null || \
    ip6tables -I OUTPUT -o $IF -m owner --uid-owner $U -j REJECT
  done
done
