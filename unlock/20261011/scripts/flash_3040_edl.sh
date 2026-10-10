#!/bin/bash
# bixi(MIX Flip 2) EDL 降级刷机：3.0.304.0 → 3.0.4.0 (WOHCNXM_16.0)
# 现象: BL 锁死，fastboot/recovery 降级均被拒
# 证据: 2026-10-11 工程线进真EDL(05c6:9008)，loader fhprg_8E_noauth.bin 被接受，
#       GPT 已备份(op/gpt_backup_20261011.txt)，abl/init_boot 原件已备份(op/part_backup_20261011)
# 改法: 按 MiFlash flash_all_except_storage.sh 的原顺序，firehose 逐分区写(_ab 双槽)，
#       super.img 稀疏格式由 edl v3.62 firehose.py:477 原生流式解稀疏
# 影响: 手机数据清空(全量备份在 Gitea Release 199)；不动 GPT/不刷 userdata；
#       vm-bootsys 按设备 GPT 实名写入(连字符分区名)；全部写完才 reset 重启
# 救砖: 任何一步失败停在 EDL，重跑本脚本从失败分区续刷；整机变砖可再进 EDL 刷回 3.0.304.0
set -u
PY="$HOME/PhoneBackups/venv-edl/bin/python3"
EDL="$HOME/PhoneBackups/unlock_tools/edl-src/edl.py"
LOADER="$HOME/PhoneBackups/unlock_tools/fhprg_8E_noauth.bin"
IMG="$HOME/PhoneBackups/bixi_fw/bixi_images_OS3.0.4.0.WOHCNXM_16.0/images"
LOG="$HOME/PhoneBackups/op/flash_3040.log"

# 顺序完全照搬 flash_all_except_storage.sh；格式 分区:镜像 ，_ab 由脚本展开为 _a/_b
PAIRS=(
  "abl_ab:abl.elf" "xbl_ab:xbl_s.melf" "xbl_config_ab:xbl_config.elf"
  "cpucp_dtb_ab:cpucp_dtbs.elf" "shrm_ab:shrm.elf" "aop_ab:aop.mbn"
  "aop_config_ab:aop_devcfg.mbn" "tz_ab:tz.mbn" "devcfg_ab:devcfg.mbn"
  "featenabler_ab:featenabler.mbn" "hyp_ab:hypvmperformance.mbn" "uefi_ab:uefi.elf"
  "uefisecapp_ab:uefi_sec.mbn" "spuservice_ab:spu_service.mbn" "modem_ab:NON-HLOS.bin"
  "modemfirmware_ab:MODEM-FW.bin" "bluetooth_ab:BTFM.bin" "dsp_ab:dspso.bin"
  "keymaster_ab:keymint.mbn" "qupfw_ab:qupv3fw.elf" "multiimgoem_ab:multi_image.mbn"
  "multiimgqti_ab:multi_image_qti.mbn" "cpucp_ab:cpucp.elf" "pdp_cdb_ab:pdp_cdb.elf"
  "soccp_debug_ab:sdi.mbn" "soccp_dcd_ab:dcd.mbn" "pdp_ab:pdp.elf"
  "xbl_sc_test_mode:xbl_sc_test_mode.bin" "logfs:logfs_ufs_8mb.bin"
  "storsec:storsec.mbn" "toolsfv:tools.fv" "xbl_ramdump_ab:XblRamdump.elf"
  "imagefv_ab:imagefv.elf" "pvmfw_ab:pvmfw.img" "init_boot_ab:init_boot.img"
  "idmanager_ab:idmanager.mbn" "super:super.img" "vendor_boot_ab:vendor_boot.img"
  "dtbo_ab:dtbo.img" "vm-bootsys_ab:vm-bootsys.img" "vbmeta_ab:vbmeta.img"
  "vbmeta_system_ab:vbmeta_system.img" "rescue:rescue.img" "misc:misc.img"
  "recovery_ab:recovery.img" "boot_ab:boot.img" "countrycode_ab:countrycode.img"
)

log() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

write_one() {  # $1=分区 $2=镜像文件
  local out
  out=$("$PY" "$EDL" --loader="$LOADER" w "$1" "$2" 2>&1)
  if [[ $? -eq 0 && "$out" == *"Wrote "*" to sector"* ]]; then
    log "OK  $1 <- $(basename "$2")"
    return 0
  fi
  log "RETRY $1 (第一次输出尾: $(echo "$out" | tail -1))"
  out=$("$PY" "$EDL" --loader="$LOADER" w "$1" "$2" 2>&1)
  if [[ $? -eq 0 && "$out" == *"Wrote "*" to sector"* ]]; then
    log "OK  $1 <- $(basename "$2") (重试成功)"
    return 0
  fi
  log "FAIL $1 —— 停止，设备留在 EDL。输出尾: $(echo "$out" | tail -3 | tr '\n' ' ')"
  return 1
}

# MiFlash 脚本对 imagefv 是先 erase 再写；firehose 直接覆写等效，跳过 erase。
# 第一个分区写完做回读校验（abl_a 8MB，便宜且关键）
: > "$LOG"
log "开始 bixi EDL 降级 3.0.304.0 → 3.0.4.0"
TOTAL=0; DONE=0
EXPANDED=()
for pair in "${PAIRS[@]}"; do
  part="${pair%%:*}"; img="${pair#*:}"
  if [[ "$part" == *_ab ]]; then
    EXPANDED+=("${part%_ab}_a:$img" "${part%_ab}_b:$img"); TOTAL=$((TOTAL+2))
  else
    EXPANDED+=("$part:$img"); TOTAL=$((TOTAL+1))
  fi
done
log "共 $TOTAL 个分区写操作"

VERIFY_AFTER_FIRST=1
for pair in "${EXPANDED[@]}"; do
  part="${pair%%:*}"; img="${pair#*:}"
  write_one "$part" "$IMG/$img" || exit 1
  DONE=$((DONE+1))
  if [[ "$VERIFY_AFTER_FIRST" == 1 ]]; then
    VERIFY_AFTER_FIRST=0
    "$PY" "$EDL" --loader="$LOADER" r "$part" /tmp/verify_$part.bin >/dev/null 2>&1
    # 修正 2026-10-11: r 回读是整个分区(8MB)，镜像只有实际内容长度，只比镜像长度那一段
    IMGSZ=$(stat -f%z "$IMG/$img")
    # 修正: macOS cmp -n 语义与 GNU 不同(实测误报不一致)，用 head -c 截断后管道比对
    if head -c "$IMGSZ" /tmp/verify_$part.bin | cmp -s - "$IMG/$img"; then
      log "回读校验 $part 一致 ✔ 写入链路可信"
    else
      log "回读校验 $part 不一致！停止（文件大小: $(stat -f%z /tmp/verify_$part.bin 2>/dev/null) vs $(stat -f%z "$IMG/$img"))"
      exit 1
    fi
    rm -f /tmp/verify_$part.bin
  fi
done

log "全部 $DONE/$DONE 完成，reset 重启进 3.0.4.0"
"$PY" "$EDL" --loader="$LOADER" reset 2>&1 | tail -1 | tee -a "$LOG"
log "FLASH_ALL_DONE"
