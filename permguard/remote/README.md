# 远程维护隧道（2026-10-03）

手机在外（任意 Wi-Fi + Clash 回家）时，让 Mac mini 能 adb 调试手机。不依赖 Termux：Termux 退到后台会被 MIUI 冻结，转发就挂死了。

## 组成

- `dropbearmulti-aarch64-static`：Alpine 静态编译的 dropbear 2024.86（用其中的 dbclient），推到手机 `/data/local/tmp/rt/db`。
- `rt.sh` → `/data/local/tmp/rt/rt.sh`：shell 身份的循环。
  - 从 `/proc/net/tcp*` 读出 uid=2000 的监听口，即无线调试的 TLS 端口（本机 `getprop service.adb.tls.port` 是空的）。
  - 执行 `dbclient -R <远端口>:127.0.0.1:<该端口> tony@192.168.50.2`。
  - 端口变了（无线调试重开）就重建隧道。
- `hooks.sh` → `/data/local/tmp/permguard/hooks.sh`：pg.sh 守护循环每轮调用一次（v2026.10.03.1 起），负责保活 rt.sh 和 cw.sh（见文末）。
- 手机钥匙 `/data/local/tmp/rt/key`（dropbear ed25519）。Mac mini 的 authorized_keys 里注释为 `phone-shell-tunnel`，限制为：
  `restrict,port-forwarding,permitlisten="localhost:15556",permitlisten="localhost:15557",permitlisten="localhost:15558",command="/usr/bin/true"`

## Mac mini 上连手机

```zsh
zsh -lc 'for p in 15556 15557 15558; do adb connect 127.0.0.1:$p; done; adb devices'   # 哪个是 device 就用哪个
```

**远端口轮换 15556 → 15557 → 15558 → 15556…**

- 为什么要轮换：
  - Mac mini 的 sshd 没开 ClientAliveInterval，改要 sudo。
  - 手机重启或断网后，Mac 上的旧会话可能还占着口：要么 Mac 往旧连接发数据、被手机回 RST，要么等 TCP keepalive 超时（约 2 小时），旧会话才会消失。
- 怎么判定被占：远端口被占时，dbclient 打一行 `Remote TCP forward request failed`，但**进程不退出**。rt.sh 在整个连接期间每 10 秒看一次这行字，看到就杀掉 dbclient、换下一个口。
- 每次开机都从 15556 试起。
- 实测 23:08：从判定占用到换口连上约 30 秒。

## 开机后的链路

```
开机 → PermGuard 守门员（LOCKED_BOOT_COMPLETED 起，未解锁也跑）
     → 打开无线调试 → 用自己的 adb 钥匙连本机 adbd
     → 没有 shizuku_server 就起它 → pg.sh daemon-start
     → 守护循环 → hooks.sh → rt.sh → 隧道
```

- 守门员详见 `permguard/README.md`「Shizuku 守门员」。Shizuku 自己的开机启动也会同时尝试，谁先起来都行。
- 隧道要等 Clash 回家的路通了才能连上；Clash 是 always-on VPN，所以要等**解锁之后**。
- 10-03 两次 `adb reboot` 实测（证据 `evidence/permguard_20261003/reboot_watchdog.md`）：

| | 第 1 次 | 第 2 次 |
|---|---|---|
| 解锁 | +22s | +22s |
| Shizuku 就绪 | +34s | +25s |
| 隧道恢复 | +6m00s | **+29s** |

- 第 1 次慢的原因：旧版 rt.sh 检测转发失败用了 `\|`，在 toybox grep 里不生效，空连接挂了 4 分钟；之后又被 sshd 丢了几次连接（见下）。修正后实测 15556 被占时约 30 秒就换到 15557。

## 已知坑

- **别用 `adb tcpip 5555`**：它会重启 adbd，把 shizuku_server 和守护循环一起带掉。
- **toybox grep（BRE）不认 `\|`**：手机端脚本里要么写单一模式，要么用 `grep -E`。
- **Mac mini 的 22 端口一直有公网口令爆破**（sshd 日志里每几秒一条）。`MaxStartups 10:30:100` 会随机丢未认证连接，手机这边偶尔看到 `Remote closed the connection`，rt.sh 20 秒后重试即可。根治要 sudo 改 sshd，或在路由器上收窄 22 端口的暴露面。
- **经隧道执行 `adb reboot`，adb 客户端会一直挂着**：用 `perl -e 'alarm 15; exec @ARGV' adb -s … reboot` 限时。

## Clash 断流看门狗 cw.sh（2026-10-04）

- 现象：Clash 进程活着、VPN 也在，但流量全断，要手动重启 Clash 才恢复。10-04 舟山酒店 Wi-Fi 实测：酒店双出口，手机 WG 端点在
  61.175.96.118 / 115.229.171.47 之间几秒一跳（Mac mini `/var/log/wireguard-home.log`），随后隧道卡死，重启 Clash 后恢复。
- `cw.sh` → `/data/local/tmp/cw/cw.sh`，由 hooks.sh 保活（hooks.sh 现在同时保活 rt.sh 与 cw.sh）。
  - 每 30 秒经 TUN 真实发 HTTP 探测：cp.cloudflare.com / connectivitycheck.gstatic.com / captive.apple.com，任一通即算通。
    toybox nc 要 `(printf 请求; sleep 4) | nc -w 5`，stdin 一关 mihomo 就断连接、拿不到响应。只做 TCP 连接没用：TUN 会本地完成握手。
  - 没有 Wi-Fi 地址也没有蜂窝默认路由、或 Clash VPN 不在时不计数。
  - 连续 3 轮不通 → `am start -n …/com.github.kr328.clash.ExternalControlActivity -a com.github.metacubex.clash.meta.action.STOP_CLASH`，
    4 秒后 START_CLASH；VPN 没起来再 START 一次。10-04 实测 STOP→START 后 13 秒 VPN 恢复，远程隧道约 55 秒恢复。
  - 重启后仍不通则退避 3、6、12…最长 30 分钟，避免 Wi-Fi 本身没网时反复重启。
  - 每次重启前把 ClashMeta/PermGuard 的 logcat 存到 `/data/local/tmp/cw/inc/`（留最近 20 份），日志 `cw.log`。
