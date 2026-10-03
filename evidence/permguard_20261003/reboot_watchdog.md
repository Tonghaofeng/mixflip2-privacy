# 重启实测：Shizuku 守门员 + 隧道端口轮换（2026-10-03 22:53 / 23:09）

条件：
- 手机在外（Wi-Fi + Clash，经 WireGuard 10.77.0.2 回家）。Mac mini 经反向隧道执行 `adb reboot`，其余不碰手机；Tony 开机后输一次 PIN。
- PermGuard 2026.10.03.2（versionCode 20261005，带守门员）。
- rt.sh：第 1 次用 AIOS 的轮换版，第 2 次用修正版（见下）。

时间来源：
- 手机 logcat：events 缓冲的 `uc_*` / `am_proc_start`，以及 `PermGuardWD`
- `/proc` 里的进程启动时刻
- 手机 `rt.log`
- Mac 上 `lsof` 看到的监听口

| | 第 1 次 | 第 2 次 |
|---|---|---|
| adb reboot | 22:53:46 | 23:09:49 |
| 内核开机（`/proc/stat` btime） | 22:53:57 | 23:10:01 |
| LOCKED_BOOT_COMPLETED | 22:54:14.6（+18s） | 23:10:18.4（+17s） |
| 守门员开跑（未解锁） | 22:54:15.7 | 23:10:19.5 |
| 解锁（`uc_unlock_user` / USER_PRESENT；BOOT_COMPLETED 紧随其后） | 22:54:19.4（+22s） | 23:10:23.4（+22s） |
| 守门员开无线调试 | 22:54:20.7 第一次开，被系统拨回；22:54:28.7 第二次开成 | 23:10:24.5 一次开成（日志记成「第 3 次」，见下文守门员 bug） |
| shizuku_server 起来 | 22:54:31（**+34s**），守门员拉起，`ok:started` | 23:10:26（**+25s**），Shizuku 自己的开机启动抢先，守门员 `ok:already` |
| 守护循环 / rt.sh | 22:54:32（+35s） | 23:10:27（+26s） |
| GuardJob 补跑 apply | 22:54:33，rc=0 | 23:10:29，rc=0（revoke=0） |
| 隧道恢复（Mac 能 `adb connect`） | 22:59:57，经 15556（**+6m00s**） | 23:10:30，经 15556（**+29s**） |
| dropbox crash/anr | 0 | 0 |

## 第 1 次隧道为什么慢了 6 分钟

1. **检测失效，空连接挂了 4 分钟**（22:54:32–22:58:30）
   - 22:54:32 第一条 dbclient 认证成功，但 15556 还被重启前的旧会话占着（Mac sshd 没开 ClientAlive），报 `Remote TCP forward request failed`。
   - rt.sh 用 `grep -i "forward.*fail\|failed.*forward"` 检测这一行。手机上的 toybox grep 是 BRE，`\|` 不当「或」用，所以永远匹配不上（手机上实测：同一行文本，带 `\|` 的模式不匹配，单一模式匹配）。
   - dbclient 转发失败后进程不退出，于是这条空连接一直挂着，直到 22:58:30 连接中断。
2. **连续三次没连上**（22:58:30–22:59:27）
   - 两次 `Remote closed the connection`。Mac 的 sshd 日志里，这段时间每隔几秒就有一次来自公网的口令爆破（51.89.42.211、77.239.124.39 等，试 root/admin…）。`MaxStartups 10:30:100` 会随机丢掉未认证的连接，推断就是这个原因。
   - 一次 `Connect failed: Permission denied`，是手机本地 connect 被拒，推断发生在 Clash/VPN 切换的瞬间。
   - rt.sh 每次 20 秒后重试，没有卡住。
3. **连上后又断了一次**
   - 22:59:55 连上 15556。
   - 23:01:5x `Keepalive timeout`（链路抖了一下）。
   - 23:02:49 自动重连上。

**修正**：rt.sh 改用单一模式 `grep -qi "forward request failed"`。因为连得慢时失败行会晚到，检测也从「连上 8 秒后看一次」改为「整个连接期间每 10 秒看一次」。

**在线实测**（23:08）：
- 旧实例还占着 15556 时，起一个新实例。
- 23:08:13 新实例试 15556；23:08:21 判定被占用；23:08:41 换到 15557 连上。Mac 在 23:08:43 看到监听。
- 第 2 次重启用的就是修正版。那次 15556 是空的（上一个会话在 15557），所以没有触发轮换。

## 守门员 bug（第 2 次重启时发现，已修，修好后还没经过重启验证）

**问题**：`ensureAdbWifi` 限制「同一次连接最多试 3 次」，按 Wi-Fi 网络句柄计数。但句柄跨重启会重复（两次开机都是 netId 102），计数又从不清零：
- 第 1 次开机试了 2 次；
- 第 2 次开机接着记成「第 3 次」；
- 第 3 次开机会直接返回 `fail:untrusted`，不再开无线调试，只能指望 Shizuku 自己的开机启动——10-03 21:28 那次它就没起来。

**修复**：计数键改成「开机次数（`Settings.Global.BOOT_COUNT`）:句柄」，开成功就清零。

**部署**：
- versionCode 20261006，versionName 仍是 2026.10.03.2。
- 23:13 经 `tools/adb_install.sh` 装上（Tony 在手机上点了「继续安装」）。
- 装完后守门员返回 `ok:binder`，守护循环在跑，classpath 已指向新 APK。

## 其他观察

- 经隧道执行 `adb reboot` 时，adb 客户端会一直挂着（手机那头断了，连接却不会关），用 `perl -e 'alarm 15; exec @ARGV'` 限时即可。
- **重启前的旧 sshd 会话**：
  - 这两次都在手机回网后 1 分钟内消失。推断是 Mac 往旧连接发数据（`adb reboot` 留下的未确认数据、adb server 自动重连），被新开机的手机回了 RST。
  - 如果重启时隧道上没有在途数据（比如手机自己重启），旧会话会一直挂到 TCP keepalive 超时（macOS 约 2 小时）。这种情况下就要靠端口轮换。
- **测试期间的临时改动（已恢复）**：
  - 手机 main 日志缓冲只能保留约 7 分钟，所以测试时临时改过手机上的 hooks.sh：每次开机把 logcat 缓冲加到 16M，并存一份快照。
  - 测完已恢复原样、删掉快照，缓冲改回 2M。
  - 原始 logcat 只留在 Mac 的 `permguard/state/reboot_test/`（不入库）。
