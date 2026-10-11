# 远程 shell 通道的每连接处理：第一行必须是口令（/data/local/tmp/rt/token，仅 shell 可读），否则断开。
# 2026-10-11 修卡死：原来 exec sh 把 socket 当 stdio 直接交给命令，am start/dumpsys 等留下的子进程
#   会一直占着 socket fd → 串行 nc -L 监听器等不到 EOF → 后续所有连接排队 1-2 分钟「RSH_DOWN」。
# 改法：逐行读命令，输出写临时文件再回写；命令 stdio 与 socket 完全解耦 + timeout 兜底，
#   会话必在命令结束后立刻结束。协议不变（口令 → 命令行×N → exit）。
read -r t
[ -n "$t" ] && [ "$t" = "$(cat /data/local/tmp/rt/token 2>/dev/null)" ] || { echo DENIED; exit 1; }
while IFS= read -r line; do
  [ "$line" = exit ] && break
  [ -n "$line" ] || continue
  O=$(mktemp /data/local/tmp/rt/out.XXXXXX) || O=/data/local/tmp/rt/out.$$
  timeout 280 sh -c "$line" > "$O" 2>&1 < /dev/null
  cat "$O"
  rm -f "$O"
done
exit
