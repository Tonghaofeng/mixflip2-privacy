# bixi (MIX Flip 2) BL 解锁 + Root 全程档案 · 2026-10-11

## 一、一句话定位
2026-10-11 00:20–07:15 一夜完成小米 MIX Flip 2（bixi, SM8750, HyperOS 3.0.304.0.WOHCNXM CN 版）的 **Bootloader 免账号解锁 + Magisk 30.7 root**：9008 工程线 EDL 免授权全量降级 → bixi 专属工程 abl + 魔改 GPT + boot 镜像解锁 → fastboot 回刷 3.0.304.0 → init_boot 修补刷入。无小米账号、无社区等级、无代解，全程自己动手。

## 二、来源与核验
- **解锁四件套**（kit/）：来自 XDA 帖 4786790《[GUIDE][BREAKTHROUGH] Free Offline Bootloader Unlock》工具包的 `8e解锁文件/mi flip2/` 目录（酷安 @汤圆就是汤圆 原作、@莫离然然 整理；Google Drive 镜像 `1uxBpKgJhTKtqCy0rabYntjUbe_x8vtMb`，解压密码 `Unlock`）。
  - `abl.elf` md5 `285829047a5269c38c57adec4de33caa`（与官方 3.0.4.0 abl、K90/Pad8Pro 工程 abl 均不同，bixi 独立件）
  - `mi_gpt_both4.bin` md5 `b4c40a6e75d7e1db1e2dc97563e948ee` —— **与官方 bixi 3.0.4.0 包内 gpt_both4.bin 完全一致**（本机 `bixi_fw/bixi_images_OS3.0.4.0.WOHCNXM_16.0/images/` 实测比对），铁证为 bixi 件
  - `jiesuo_gpt_both4.bin` md5 `9ff5a93d91c4547fb0f995093fd29e1e`：与官方 GPT 逐字节仅差 4 个分区名——`vbmeta_a/b→xbmeta_a/b`、`pvmfw_a/b→xvmfw_a/b`（LBA 全不动），即「把 AVB 元数据分区从分区表藏掉」
- **EDL loader**：`fhprg_8E_noauth.bin`（1,697,740B，GitHub bkerler/loaders，与夸克 8750 免授权包同源）；Sahara 握手成功 = 9008 未熔断。
- **固件**：官方 MiFlash 包 3.0.4.0（WOHCNXM_16.0，anti=1，SPL 2025-11-01）与 3.0.304.0（anti=1，SPL 2026-02-01），macserver `~/PhoneBackups/bixi_fw/` 两份 11G tgz，gz 校验 OK；EDL 刷写全部回读校验（abl_a 首 partition 逐字节比对 + 后续 ACK）。

## 三、操作时间线（发生了什么）
1. **00:20** 高通二代工程线（~¥14）到手 → 关机+按住线开关+电源 5 秒 → 真 EDL（05c6:9008，注意音量上下+插线进的是 crashdump 18d1:4e11 不通用）
2. **00:50–01:16** EDL 免授权全量刷 3.0.4.0：47 组映射 87 个分区写（_ab 双槽、super 稀疏直写 6.5 分钟 @27MB/s、abl_a 回读校验一致），不动 GPT、不刷 userdata
3. **01:20** 首启红字 **"The system has been destroyed"** → 排查：两包 anti 都=1、两包 vbmeta rollback 都=0、bixi 无 crclist 分区 → 定案为 **SPL 级防回滚（计数在 RPMB，锁态降级必触发**，XDA 4787466 同结论）
4. **01:40** Xiaomi15(dada) 工程 abl 跨机型尝试 → `error unknown project type 5`（abl 必须机型严格匹配，实证）
5. **02:00** 调研代理从 XDA 4786790 挖到 **bixi 专属解锁件**（见第二节核验）
6. **02:30–03:00** 换回工程线进 EDL 写 bixi 工程 abl 双槽（回读一致）→ 重启后工程 abl **自动落 fastboot** → `fastboot flash partition:4 jiesuo_gpt_both4.bin`（OKAY，魔改 GPT 藏 vbmeta）→ `fastboot boot boot.img`（OKAY，52MB 解锁载体在手机上盲跑，白屏灰斜纹=显示驱动不匹配，无害）→ 强重启 → **`fastboot getvar unlocked` = `yes`** → `fastboot flash partition:4 mi_gpt_both4.bin` 还原官方 GPT + `erase userdata/metadata`
7. **05:30–06:00** fastboot 跑官方 `flash_all_except_storage.sh` 全量回刷 3.0.304.0（含 stock abl 双槽，super 16 段稀疏 @40MB/s）→ **系统正常启动，红字消失**（SPL 回到出厂水位）
8. **07:00–07:15** 过设置向导+激活锁 → 开 USB 调试 → 装正版 Magisk v30.7（GitHub 重下，本地旧 apk 是截断坏档）→ App 内修补 304 包 init_boot.img → fastboot 双槽刷入 magisk_patched → **`su -c id` = `uid=0(root) context=u:r:magisk:s0`** → 重新冻结 com.android.updater

## 四、技术要点（可复用的硬知识）
- **工程线 = fastboot 杀手**：EDL 模式 25 分钟 11G 稳如泰山，但 fastboot 枚举抖、接口栈半死（usb_write e00002ed、主机侧 e00002ed/Permission denied）。**EDL 用工程线，fastboot 必须换普通线**（普通线实测 0.003s 响应）。
- **macOS usbmuxd 抢 Google VID(18d1) 接口**且 launchd 秒复活；EDL 是高通 VID(05c6) 不受影响，Mac 可跑 EDL。fastboot 阶段 root 杀 usbmuxd+等 4s 重枚举可开窗（unlock_seq2.sh 思路），但换普通线后基本不需要。
- `fastboot flash partition:4 <gpt.bin>` 是小米 abl 专用语法；锁态/工程 abl 态行为不同（stock 锁态拒绝、工程 abl 放行）。
- EDL `w` 只写镜像长度、分区尾部留旧数据（正常）；`r` 回读整分区，与镜像比对要用 `head -c N | cmp -`（★macOS `cmp -n` 语义≠GNU，会误报不一致）。
- MIUI/HyperOS 的 adb pull/exec-out 读 /sdcard 文件可被静默拦（0 字节），解法：`cp 到 /data/local/tmp 再 pull`，或 WiFi adb（`adb tcpip 5555`，实测 12MB/s；重启后不持久）。
- 解锁 boot 载体跑完可能卡白屏灰斜纹（显示驱动不匹配），**等 3–5 分钟后长按电源 15 秒强启**即可，解锁写入已完成。
- 锁态降级触发红字后，fastboot 仍可进（音量下+电源）；destroyed 画面下的 stock abl 依旧拒绝 flash/boot。

## 五、本目录附件清单
| 路径 | 内容 | 来源 |
|---|---|---|
| `scripts/flash_3040_edl.sh` | EDL 全量降级脚本（47 映射、双槽展开、失败重试、首分区回读校验、macOS cmp 坑已修） | 本夜自写 |
| `scripts/unlock_seq2.sh` | fastboot 解锁序列（root 跑：杀 usbmuxd→等 4s→devices→getvar→刷魔改 GPT→boot→复查） | 本夜自写 |
| `scripts/watch_and_unlock.sh` | 守 fastboot 出现即自动开火的联动壳 | 本夜自写 |
| `scripts/auto_unlock.sh` | go2(Linux) 版同序列（timeout 版，未用上） | 本夜自写 |
| `kit_original/` | 原工具包的 4 个 .bat 与 注意事项.txt（GBK） | XDA 4786790 |
| `evidence/gpt_backup_20261011.txt` | 刷机前整机 GPT（135 分区×6 LUN）快照 | bkerler/edl printgpt |
| `evidence/flash_3040.log` | EDL 降级 87 分区逐条日志 | flash 脚本 |
| `evidence/part_backup_SHA256SUMS.txt` | 刷前 abl_a/abl_b/init_boot_a/init_boot_b 原件校验 | bkerler/edl rl |
| `evidence/magisk_patched_30700_FXgQg.img` | 本机实际刷入的 Magisk 修补 init_boot（8,388,608B） | Magisk v30.7 App 产出 |
| `kit/`（附件 zip） | bixi 解锁四件套：abl.elf / boot.img / jiesuo_gpt_both4.bin / mi_gpt_both4.bin | XDA 4786790 |
| `loader/fhprg_8E_noauth.bin`（附件 zip） | 9008 免授权 firehose loader | bkerler/loaders |
| `Magisk-v30.7.apk`（附件 zip） | 官方正版 v30.7（11,613,864B；10-07 下载的 10.6MB 版是截断坏档，勿用） | GitHub topjohnwu/Magisk |

## 六、仓库 ≠ 磁盘（工作副本状态）
- **git 内**（本目录）：脚本、文档、GPT 快照、日志、校验清单——全部小文本。
- **Release 附件**（`unlock_artifacts_20261011.zip`，~70MB）：kit 四件套、EDL loader、Magisk apk、修补 init_boot 镜像、part_backup 四件原件（32MB）。
- **macserver 磁盘**：两份 11G 固件 tgz + 解包 images（`~/PhoneBackups/bixi_fw/`）、unlock_tools 全套；本 Mac 同套镜像 + `~/PhoneBackups/op/` 操作残留。固件不入库（体积）。
- 手机当前：3.0.304.0 / BL 解锁 / Magisk 30.7 root / slot a / updater 已冻结 / 数据全新（重建见 mixflip2-privacy 仓 debloat·permguard·aios 脚本）。

## 七、复现步骤（同型 8E 机器照抄）
1. 工程线进 EDL（关机→按住线开关+电源≈5 秒→05c6:9008）；`python3 edl.py --loader=fhprg_8E_noauth.bin printgpt` 只读验证 loader 被接受。
2. `scripts/flash_3040_edl.sh` 全量降级（改 PAIRS/IMG 指向你的包）；首启必红字 destroyed（锁态降级铁律，别慌）。
3. 工程线再进 EDL，写 kit/abl.elf 到 abl_a+abl_b（回读校验）；**换普通线**。
4. 重启 → 工程 abl 自动进 fastboot → `fastboot flash partition:4 jiesuo_gpt_both4.bin` → `fastboot boot boot.img` → 等几分钟强启 → `fastboot getvar unlocked` 应为 yes → `fastboot flash partition:4 mi_gpt_both4.bin` + `erase userdata/metadata`。
5. fastboot 跑目标版本官方 `flash_all_except_storage.sh` 回刷（恢复 stock abl）。
6. 装 Magisk → App 修补该版本 init_boot.img → fastboot 双槽刷入 → root → 冻结 updater。

## 八、阅读顺序与上下文
上一版：`v2026.10.07-preroot-backup`（Release 199，root 前全量备份：DCIM 8 片 7.2G + misc.tar 611M + debloat/permguard 脚本清单）——重建阶段的输入。本 Release 解锁链完成后，重建（debloat/permguard/aios app/Clash/SG 地区/数据恢复）为下一里程碑。技术细节与踩坑全文另见记忆库 `xiaomi-mixflip2-root-project.md`（10-11 版要点）。
