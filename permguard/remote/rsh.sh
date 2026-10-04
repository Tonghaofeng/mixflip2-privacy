# 远程 shell 通道的每连接处理：第一行必须是口令（/data/local/tmp/rt/token，仅 shell 可读），否则断开。
read -r t
[ -n "$t" ] && [ "$t" = "$(cat /data/local/tmp/rt/token 2>/dev/null)" ] || { echo DENIED; exit 1; }
exec /system/bin/sh
