# permguard — 隐私权限定时收回（无 root）

小米 MIX Flip 2（bixi，国行 HyperOS 3 / Android 16，BL 锁）。思路是**默认拒绝 + 白名单**：第三方 App 的隐私权限，除白名单写明的组以外，每轮都收回。

执行身份是 shell（uid 2000）。有两条通路，跑的是同一份规则引擎：

- **adb**：Mac 上跑 `adb/permguard.sh`。
- **手机自己**：Shizuku 起一个 shell 进程，再拉起一个 shell 身份的守护循环。

验收只认 `dumpsys package` 和 `cmd appops` 的原值，不看界面。

## 目录

| 路径 | 内容 |
|---|---|
| `whitelist.conf` | 白名单（包名 → 允许的权限组），带逐行注释。**Tony 增减就改这个**。同一份内置在 App 里 |
| `core/src/…/Core.java` → `core/permguard.dex` | 规则引擎。纯 JDK，不用隐藏 API，只调系统命令：`dumpsys package`、`cmd package revoke/grant/set-permission-flags`、`cmd appops`、`dumpsys role`。用 `app_process` 以 shell 身份运行 |
| `phone/pg.sh` | 手机端驱动，部署在 `/data/local/tmp/permguard/`。负责加锁运行、写日志，以及守护循环 |
| `adb/permguard.sh` | adb 版：`--dry-run` / `--apply` / `--verify` / `--restore` / `--status` / `--daemon-start` |
| `adb/setup_phone.sh` | 手机端一次性配置：装包、授权、启动 Shizuku、核对定时任务 |
| `app/` | PermGuard App（Java，用 aapt2/d8/apksigner 手工构建，不用 Gradle）：JobScheduler、开机广播、Shizuku 执行、日志导出 |
| `state/`（不入库） | apply 前的快照 `snapshot-*.tsv` 和执行记录 `journal-*.tsv`。手机 `/data/local/tmp/permguard/state/` 也存一份 |

## 管什么

**运行时权限组**（引擎里的 `PERM_GROUP`）：

| 组 | 包含的权限 |
|---|---|
| LOCATION / LOCATION_BG | 精确定位、大致定位 / 后台定位 |
| CONTACTS | 通讯录读写、GET_ACCOUNTS |
| CALL_LOG | 通话记录读写、PROCESS_OUTGOING_CALLS |
| SMS | 短信收发与读取、彩信、WAP_PUSH、小区广播 |
| PHONE | 电话状态、本机号码、拨号、接听、ADD_VOICEMAIL、SIP |
| CAMERA / MICROPHONE / CALENDAR | 相机 / 麦克风 / 日历 |
| SENSORS / ACTIVITY | 身体传感器（含 Android 16 的 `health.*`）/ 活动识别 |
| MEDIA / MEDIA_LOCATION | 照片视频音频与存储 / 读照片里的 GPS |
| NEARBY | 蓝牙扫描/连接/广播、附近 Wi-Fi、UWB |
| INSTALLED_APPS | 小米自定义权限 `com.android.permission.GET_INSTALLED_APPS`（由 com.lbe.security.miui 定义，dangerous） |

不收 `POST_NOTIFICATIONS`。不认识的运行时权限归 OTHER 组，只报告。

**appop**：MIUI 自有 op 只有编号，常量名由 `Core opnames` 在本机反射 `android.app.AppOpsManager` 实测得到（`evidence/permguard_20261003/opnames.txt`）。

| op | 组 | 第三方 App 现状（10-03 apply 前） |
|---|---|---|
| `GET_USAGE_STATS` 使用情况访问 | USAGE_STATS | 无 |
| `MANAGE_EXTERNAL_STORAGE` 所有文件访问 | ALL_FILES | Files（白名单） |
| `READ_CLIPBOARD` | CLIPBOARD（**只报告**） | Chrome、Gboard、小米便签 allow |
| 10008 `OP_AUTO_START` 自启动 | AUTOSTART | 只有 Clash allow（豁免） |
| 10021 `OP_BACKGROUND_START_ACTIVITY` 后台弹出界面 | BG_START | 全部 ignore |
| 10022 `OP_GET_INSTALLED_APPS` 获取应用列表 | INSTALLED_APPS | 6 个 allow → **已收** |
| 10019 `OP_GET_TASKS` 获取运行中应用 | USAGE_STATS | 3 个小米 App → **已收** |
| 10037 `OP_GET_OAID` 广告标识符；10024/10025/10038/10050 设备标识 | AD_ID | 17 个 allow（Bose 21 分钟前刚读过）→ **已收** |
| 10039 `OP_GET_PHONE_NUMBER_OPERATOR` 运营商取本机号码 | PHONE | 8 个小米 App → **已收** |
| 10004 发彩信、10018 读通知类短信、10028 READ_SMS_REAL | SMS | Telegram 10004 → **已收** |
| 10032 READ_PHONE_STATE_REAL | PHONE | Telegram → **已收**；拨号、通讯录属白名单 |
| 10027 后台定位、10036/10043 定位 REAL、10029–10031 联系人/日历/通话记录 REAL、10046 通话录音 | 对应组 | 无 |
| 10054 `OP_AI_GET_SCREEN_CONTENT`、10055 `OP_AI_CTL_SCREEN_APP` | SCREEN | 无 |

**特殊权限只报告，不自动改**：通知使用权、无障碍（目前是 Bitwarden）、默认输入法（Gboard）、设备管理器、常驻 VPN。这几项关掉就等于把 App 的功能整个关掉，要在系统设置里手动关。

**系统 App 只报告。** 本机持有 GET_INSTALLED_APPS 的 28 个系统包全部是 `SYSTEM_FIXED`，shell 也收不了。用户手动授予过的只有两个：相机的定位（照片地理标记）、fliphome 的日历。要收某个系统 App，在白名单里写 `@manage 包名`，先逐个评估风险。

**永不触碰**（写死在代码里，配置写错也碰不到）：Clash Meta（always-on + 锁定，动它整机断网）、Shizuku、permguard 自身。

**自动保留**：

- 包当前持有默认角色（`dumpsys role`），且权限带 `GRANTED_BY_ROLE` 标志。拨号、短信、助理、浏览器、桌面属于这一类。
- 带 `SYSTEM_FIXED` / `POLICY_FIXED` 的权限（只报告）。

## 收回动作的取舍

| 动作 | 用不用 | 理由 |
|---|---|---|
| `pm revoke` | ✅ | 标准撤销，Settings 关权限走的也是这条路。**会杀该 App 进程**，所以 App 在前台、或正在用相机/麦克风/定位（appop running）时，这一项**推迟**到下一轮。守护循环 15 分钟后重试，退出码 3 |
| 设 `FLAG_USER_FIXED` | ❌ 不设 | 设了以后 App 再请求会被系统静默拒绝，不弹窗，只能去设置里开。permguard 的模型是**临时授权**：App 要用时弹窗，你点允许，它就能用到下一轮（≤6 小时）。设 USER_FIXED 会把这条路堵死，还会让「点按钮没反应」这类故障很难查。保留 revoke 前的原有标志，restore 能精确还原 |
| 运行时权限再叠一层 `appops set … ignore` | ❌ 不叠 | revoke 后系统已把对应 uid 模式置为 ignore。再叠一层包模式 ignore，会出现「已授权但被静默拦截」的状态（相机黑屏、麦克风无声），而且你临时授权以后仍然不能用 |
| 非运行时 op（MIUI op / 使用情况 / 所有文件） | ✅ `ignore` | 不用 `deny`：deny 会抛 SecurityException，部分 App 会崩。MIUI 自己默认拒绝也是 ignore。uid 模式和包模式分别处理 |
| targetSdk < 23 | 兼容模式 | 这类 App 的权限安装即授予，`pm revoke` 不支持。引擎改为设 `revoked-compat` 标志 + 对应 appop ignore。本机现有 App 的 targetSdk 都 ≥ 35 |
| 每次 apply 前 | 快照 | 写快照：所有受管包全部运行时权限的授予状态和标志，以及受管 op 的 uid/包模式原值。`--restore` 按快照逐项改回（先改标志再 grant/revoke），可重复执行 |

## 手机端定时执行

三层，任何一层单独都能工作：

1. **守护循环**（`pg.sh daemon-loop`，shell 身份，`setsid` 脱离会话，PPID=1，`oom_score_adj=-1000`）
   - 每 5 分钟比对一次第三方包列表。距上次 apply 满 6 小时、包列表变了（新装或卸载，即 PACKAGE_ADDED）、或上轮有推迟项满 15 分钟，就跑 apply。
   - 它不是 App 进程，**「一键清理」强停 App 不影响它**。重启后消失。
   - 由 App（经 Shizuku）或 adb（`--daemon-start`）拉起。
2. **PermGuard App**（JobScheduler）
   - 周期任务每 6 小时一次（flex 1 小时），`setPersisted` 跨重启。
   - 一次性任务的触发：开机广播、Shizuku 服务端启动后把 binder 交给 App（经 ShizukuProvider，顺带拉起进程）、App 更新。等不到 Shizuku 就指数退避重试，从 1 分钟起。
   - 每轮都会重写 `pg.sh`、白名单和 classpath（指向 APK），并确保守护循环在跑。
   - 运行时会给自己设 MIUI 自启动 10008=allow 加省电白名单（同 Clash 的处理），给 Shizuku 授 `WRITE_SECURE_SETTINGS`，给自己授通知权限。
   - 日志写 App 私有目录 `files/logs/`（保留 60 份）；「导出日志」写到 `下载/permguard/`（MediaStore，不需要存储权限）。
   - 白名单优先读 `/sdcard/Android/data/uk.tonytong.permguard/files/whitelist.conf`，没有就用内置的。
3. **adb 版**：Mac 在旁时手动跑，也可以用来拉起守护循环。

**HyperOS 的影响（据 10-01 Clash 掉线实测推断）**：

- 「一键清理」= force-stop，会取消该 App 的 JobScheduler 任务，并让它收不到开机广播（stopped 状态）。
- 缓解：自启动 10008=allow 加省电白名单。守护循环本身不受影响。
- 重启后，Shizuku 启动时调 ShizukuProvider 会重新拉起 App 进程。
- 想更稳可以在多任务里锁定 PermGuard 卡片，但不是必需的。

**重启后的限制（如实）**：

- 已收回的权限跨重启保持（`runtime-permissions.xml` 持久化），重启只影响「下一轮」能不能执行。
- **Shizuku 不是 root**：无 root 时它靠无线调试启动，每次开机都要重新启动。13.6.0 起支持在 Android 13+ 连上**受信任的 WLAN** 时自动开机启动，前提是：
  - Shizuku 自己做过一次无线调试配对；
  - 它有 `WRITE_SECURE_SETTINGS`（shell 可以 `pm grant`，App 每轮会补授）；
  - 设置里打开了开机启动。
- 开机时不在受信任 Wi-Fi 上（比如在外面开机），Shizuku 就起不来。PermGuard 会发通知「permguard 暂停：Shizuku 未运行」。连上 Wi-Fi 后可以在 Shizuku 里手动启动（配对过就不需要电脑），启动后 App 自动补跑一轮并拉起守护。
- 上述自启条件**本轮未实测**：Shizuku 尚未装上，见 OPEN_ITEMS #16。

**备选：Tasker / MacroDroid + Shizuku**

- 如果自写 App 不可用，可以用 Tasker 的 Shizuku 插件，或 MacroDroid 的「Shell 脚本（Shizuku）」动作。
- 定时（每 6 小时）、开机、应用安装三个触发器各配一个，执行 `sh /data/local/tmp/permguard/pg.sh run apply`。前提是先用 adb 版 `--dry-run` 把 `permguard.dex` 和 `pg.sh` 推上去。
- 代价：多一个闭源 App 常驻；这两个 App 同样会受「一键清理」影响。

## 用法

```bash
permguard/core/build.sh                 # 改了 Core.java 才需要；permguard.dex 已入库
permguard/adb/permguard.sh --dry-run    # 清单 → evidence/permguard_<日期>/plan.md
permguard/adb/permguard.sh --apply      # 快照 → 收回 → 回读核对；快照拉回 permguard/state/
permguard/adb/permguard.sh --verify     # verify.md/csv（每 App 每项实际状态）+ unfixable.md（关不掉清单）
permguard/adb/permguard.sh --restore [permguard/state/snapshot-….tsv]   # 默认手机上最新一份
permguard/adb/permguard.sh --status | --logs | --daemon-start | --daemon-stop
permguard/app/build.sh                  # → app/out/permguard.apk（签名钥匙 app/permguard.keystore 不入库，丢了只能先卸再装）
permguard/adb/setup_phone.sh            # 手机解锁时跑：装包（手机上点两次「继续安装」）、授权、启动 Shizuku、核对
```

在手机上（不需要电脑）：

```
sh /data/local/tmp/permguard/pg.sh status
sh /data/local/tmp/permguard/pg.sh run plan
```

经 Shizuku 的终端（rish）可以跑。PermGuard App 里有「预览 / 立即收回 / 体检 / 回滚 / 导出日志」。

**改白名单**：改 `whitelist.conf`，然后 `--dry-run` 看清单，再 `--apply`。手机端要用新白名单，有两种办法：

- 重新构建 App；
- 或者 `adb push whitelist.conf /sdcard/Android/data/uk.tonytong.permguard/files/whitelist.conf`，下一轮生效。

配置里写了不认识的组名时，apply 会拒绝执行，只在 plan 里给出警告。

## 安装件（官方来源与核对）

- **Shizuku v13.6.0**（`shizuku-v13.6.0.r1086.2650830c-release.apk`）
  - 来源：GitHub RikkaApps/Shizuku Release。
  - sha256 `6e273ab0e991c4e79bc8b1bbb9b9dd739ccac1a8712a541a214078886b7b790f`。GitHub 下载两次，与 IzzyOnDroid 镜像独立比对，三份一致。
  - 签名证书 CN=Rikka，SHA-256 `268b5590e868fb08bae7e0ac413564cd1ff88f5ccff74af9dbd0dc918e30db30`。
- **Shizuku API 13.1.5**（Maven Central `dev.rikka.shizuku:{api,provider,aidl,shared}`）：sha256 钉在 `app/build.sh` 里。
- **PermGuard**：签名证书 CN=permguard, O=tonytong.uk，SHA-256 `bba3fb2b596ad64ef514872acc53fd1d5b23014e583550b501f59b1a38a7b174`。

## 已知限制

- 权限模型管不住的部分见 `unfixable.md`。
  - QUERY_ALL_PACKAGES 是安装时权限，收不回；MIUI 10022 只挡 `getInstalledPackages` 一条路。
  - 系统身份和 SYSTEM_FIXED 收不了。
  - 默认输入法看得到所有键入，无障碍服务看得到屏幕内容。
- 默认角色带来的权限会保留，例如默认助理 Google App 有读短信、读通话记录、发短信。要收只能换掉角色。
- 收回只能防「之后」的读取，已经读走的数据收不回来。网络侧仍靠 Clash 规则。
- 临时授权最长可以用到下一轮（≤6 小时）。
- 白名单里标「待 Tony 定」的是为了不弄坏常用功能而暂时保留的，不代表已经评估过它们安全。
