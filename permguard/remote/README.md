# 远程维护隧道（2026-10-03）

手机在外（任意 Wi-Fi + Clash 回家）时让 Mac mini 能 adb 调试手机，不依赖 Termux（Termux 退后台会被 MIUI 冻结，转发挂死）。

- `dropbearmulti-aarch64-static`：Alpine 静态编译的 dropbear 2024.86（dbclient），推到手机 `/data/local/tmp/rt/db`。
- `rt.sh` → `/data/local/tmp/rt/rt.sh`：shell 身份循环，读 `/proc/net/tcp*` 里 uid=2000 的监听口（无线调试 TLS 端口，`getprop service.adb.tls.port` 在本机为空），`dbclient -R 15556:127.0.0.1:<端口> tony@192.168.50.2`；端口变化自动重建。
- `hooks.sh` → `/data/local/tmp/permguard/hooks.sh`：pg.sh 守护循环每轮调用（v2026.10.03.1 起），保活 rt.sh。
- 手机钥匙 `/data/local/tmp/rt/key`（dropbear ed25519），Mac mini authorized_keys 注释 `phone-shell-tunnel`，限制 `restrict,port-forwarding,permitlisten="localhost:15556"`。
- Mac mini：`adb connect 127.0.0.1:15556`。

链路：开机 → Shizuku 自启（需 Wi-Fi 已连；实测一次成功一次失败）→ PermGuard GuardJob → pg.sh daemon → hooks.sh → rt.sh → 隧道。
Shizuku 没起来时手机上打开 Shizuku 点「启动」一次，约 1 分钟内隧道自动建立（2026-10-03 21:35 实测）。
注意：别再用 `adb tcpip 5555`——会重启 adbd，带掉 shizuku_server 和守护循环。
