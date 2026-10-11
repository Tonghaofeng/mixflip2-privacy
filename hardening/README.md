# 底层加固 2026-10-11（root 深挖轮，Tony 指令：不能全靠 Clash）
1. **iptables UID 防火墙**（10-uidfw.sh，装机 /data/adb/service.d/10-uidfw.sh）：系统身份 uid 1000/1001/10229 在物理网卡(wlan0/rmnet*)直连=绕 VPN 后门(旧 OPEN_ITEMS #7)，owner 匹配 REJECT，12+12 规则 v4/v6，开机自启。代价：uid1001 彩信直连断(电话/短信走 RIL 不受影响)。
2. **hosts 系统级模块**（/data/adb/modules/hostsblock）：31 遥测域 0.0.0.0（Clash REJECT 域提取，剔除 amap/autonavi 保 metoknlp 窄口子），mount --bind 即时生效+Magisk 持久。全 UID 含系统身份，DNS 层兜底。
3. **相机推送组件禁用**：MiPushMessageReceiver + PingReceiver（旧 #14 相机后台反复外联的根）。
4. qdma 非独立包(内嵌)，跳过；qualcomm.location(10229)/bluetooth 由 UID 防火墙罩住。
★方法论：`su <uid>` 起的进程没有 defaultNetwork → DNS/网络测试假阴性；root(uid0) 流量被 VPN 白名单绕过也是设计行为。网络测试只能用真应用。

## 追加(10-11晚 Tony 1/4 号指令)
- **Zygisk+Shamiko+DenyList**：zygisk=1、Shamiko v1.2.5、denylist enforced(gms/unstable/vending/gsf/okex)。银行类 App 装完记得 `magisk --denylist add <pkg>`。
- **ro.miui.region=SG 持久**：模块 /data/adb/modules/regionsg(system.prop) + 双脚本(post-fs-data.d/20-region.sh + service.d/21-region.sh,用 /product/bin/resetprop——★/data/adb/magisk/magisk64 路径不存在,主二进制叫 magisk)。重启实测 SG 保持。
- **Play 账号区域→SG**：谷歌硬规则=需 SG IP+一年一次。人在 SG 时：Play→头像→设置→常规→账号和设备偏好设置→国家/个人资料→添加新加坡并切换。
