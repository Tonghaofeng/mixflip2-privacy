#!/system/bin/sh
# 银行/金融 App 自动进 Magisk DenyList (2026-10-11): 装上即隐藏 root, 懒得每次手动 add
# 名单猜错=无害跳过(pm 不在装就跳过); hooks.sh 每 5 分钟调一次
BL=/data/local/tmp/permguard/banklist.txt
for p in $(cat $BL 2>/dev/null); do
  pm path $p >/dev/null 2>&1 || continue
  magisk --denylist ls 2>/dev/null | grep -q " $p/" || { magisk --denylist add $p && echo "$(date '+%F %T') denylist+$p" >> /data/local/tmp/permguard/log/denylist.log; }
done
