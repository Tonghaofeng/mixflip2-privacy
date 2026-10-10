#!/bin/bash
# 等 fastboot 真响应 → 自动跑解锁序列(内含杀usbmuxd+4s等待)
for i in $(seq 1 150); do
  if /opt/homebrew/bin/fastboot devices 2>/dev/null | grep -q fastboot; then
    echo "=== FASTBOOT响应 at ${i}x4s, 开跑序列"
    bash /tmp/unlock_seq2.sh
    exit 0
  fi
  sleep 4
done
echo "=== 10分钟无fastboot响应"
