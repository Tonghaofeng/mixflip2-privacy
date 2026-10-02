# permguard 验收证据 — 2026-10-03

手机：bixi `OS3.0.304.0.WOHCNXM`，Android 16。Mac mini 经无线调试连接（`adb-7f37d4d8-qKCl29._adb-tls-connect._tcp`）。

规则引擎在手机上以 **uid=2000（shell）** 运行，每份输出首行都有 `uid=2000`。原始文件在 `evidence/permguard_20261003/`。

## 1. 实测前提

- **MIUI op 编号**：在本机反射 `android.app.AppOpsManager` 实测（`opnames.txt`，共 55 个）。
  - 10008 = `OP_AUTO_START`，10021 = `OP_BACKGROUND_START_ACTIVITY`，10022 = `OP_GET_INSTALLED_APPS`
  - 10037 = `OP_GET_OAID`，10039 = `OP_GET_PHONE_NUMBER_OPERATOR`，10054 = `OP_AI_GET_SCREEN_CONTENT` 等
  - `cmd appops get` 只显示 `MIUIOP(n)`，不认这些名字。
- **小米权限**：`com.android.permission.GET_INSTALLED_APPS`，prot=dangerous，由 com.lbe.security.miui 定义。
  - 本机 28 个系统包持有，全部 `SYSTEM_FIXED`。
  - 第三方 App 无人申请。
- **默认角色**（`dumpsys role`）：拨号 = Google 电话，短信 = Google 信息，助理 = Google App，浏览器 = Chrome，桌面 = MIUI 桌面。
  - 角色授予的权限带 `GRANTED_BY_ROLE` 标志，引擎据此自动保留。

## 2. dry-run（`plan.md` / `plan.tsv`，00:58:49）

拟收回 **49 项 / 25 个 App**，保留 87 项（白名单、角色、豁免），只报告 4 项，系统固定 0。

Clash 只出现两行 `KEEP … 豁免`（10008 allow、10022 foreground）。

## 3. 回滚演练（apply 前，00:58）

用临时配置，只放出两个低风险目标：YouTube 的相机和麦克风、指南针的 10039。

| 步骤 | 结果 |
|---|---|
| apply | 3 项 OK，回读确认 3。YouTube `CAMERA/RECORD_AUDIO granted=false`，标志 `USER_SET\|USER_SENSITIVE_*` 不变；`MIUIOP(10039): ignore` |
| restore | 「改回 3 项，失败 0，本来就一致 621 项」。授予状态和标志与快照逐字一致；`MIUIOP(10039): allow` |
| 再 restore | 「改回 0 项」，可重复执行 |

## 4. 正式 apply

| 时间 | 结果 |
|---|---|
| 01:00:22（`apply_1_0100.md`） | 收回 44 项，**回读确认 44**，失败 0。Telegram 正在前台，它的 5 项运行时权限**推迟**（rc=3） |
| 01:15:22（`apply_2_0115.md`，手机已锁屏） | 补收 Telegram 5 项，回读确认 5，失败 0 |

两轮合计 **49 项 / 25 个 App**：

- 运行时权限 13 项：
  - Telegram：读通话记录、本机号码、电话状态、拨号、读照片位置
  - YouTube：相机、麦克风
  - Google App：相机
  - Azure Authenticator：相机
  - 已停用的小米相册：存储与媒体 4 项
- appop 36 项：
  - 广告标识 OAID 10037：17 个 App
  - 运营商取号 10039：8 个
  - 获取应用列表 10022：6 个
  - 获取运行中应用 10019：3 个
  - Telegram 发彩信 10004、READ_PHONE_STATE_REAL 10032

快照和执行记录在 `permguard/state/`（不入库）和手机 `/data/local/tmp/permguard/state/`。

## 5. verify：前后对比（`before/` vs `after/`，dumpsys/appops 原值）

| 指标 | 前 | 后 |
|---|---|---|
| 第三方 App 已授予的隐私类运行时权限 | 96 项 / 34 个 App | 83 项 / 19 个 App |
| 其中不在白名单、也不是豁免 | 14 | 5（见下） |
| 受管 appop 放行（allow/foreground），不在白名单、不含剪贴板 | 36 | **0** |

剩下的 5 项：

- 4 项是默认角色授予：Google App（助理）的读短信、读通话记录、发短信；Google 电话的相机。
- 1 项是 Google 地图的 `CAR_SPEED`（OTHER 组，只报告）。

## 6. 「关不掉」清单（`after/unfixable.md`）前几名

1. **Clash**：常驻 VPN + QUERY_ALL_PACKAGES → 保留（本方案组件）
2. **Gboard**：默认输入法，看得到所有键入 → 保留但定期复核
3. **Android Auto**：QUERY_ALL_PACKAGES + sharedUserId → 保留（谷歌系）
4. **Bitwarden**：无障碍服务 → 保留但定期复核
5. **8 个谷歌系 App 有 QUERY_ALL_PACKAGES**：Chrome、Home、Files、Google One、电话、Google App、TTS、TV → 保留
6. **小米锁屏画报、垃圾清理、相册**：已停用，但有 QUERY_ALL_PACKAGES → 建议卸载（走 debloat 流程）
7. **小米屏幕录制**：QUERY_ALL_PACKAGES → 不常用就卸载

系统 App 按 UID 身份汇总：

- android.uid.system/1000：28 个包，各 33 项固定隐私权限
- android.uid.phone/1001：17 个包

这些只报告，不改。

## 7. 手机端定时执行

- **守护循环**：01:15:37 经 adb 拉起，`pid 3489`。`PPID=1`（已脱离 adb 会话），`oom_score_adj=-1000`。`pg.sh status`：运行中，上次 apply 01:15:26。
- **换脚本后重启守护**：01:26 换了新版 pg.sh（`daemon-stop` 先杀 sleep 子进程；出错时退避），停/启实测干净。现为单实例 `pid 8609`，`oom_score_adj=-1000`。
- **隔离测试**：另起一份实例（`PG_INTERVAL=60 PG_POLL=20`，独立目录），01:15:58 和 01:17:03 各按「定时」触发一次 apply。两次 revoke=0，说明可重复执行。测完已停止并删除。
- **App 未装上**：`tools/adb_install.sh` 装 Shizuku 时报 `Failure [INSTALL_FAILED_USER_RESTRICTED: Install canceled by user]`。原因是 MIUI「USB 安装」要在手机上点确认，而手机已锁屏；guardprovider 已按脚本卸回。
  - APK 已推到手机 `下载/permguard/`，附 sha256.txt。
  - 因此 jobscheduler 注册、开机任务、Shizuku 开机自启**本轮未验证**，见 OPEN_ITEMS #16。

## 8. 体检

- `postboot_check_0118.txt`（`WATCH=20`）**全部通过**：开机以来无系统级崩溃，SystemUI pid 稳定，上报开关全对。Clash 处于 always-on + 锁定，tun0 已连接，自启动 allow，在省电白名单和多任务锁定名单里。
- `dropbox_since_apply.txt`：00:58 以来 crash / anr / tombstone / wtf 共 **0 条**。
- 本轮没有装 App，也没有改系统设置，所以没有重启。
