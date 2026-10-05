#!/usr/bin/env python3
"""由主策略 mixflip2.yaml 派生「海外直连」版 mixflip2-travel.yaml（10-05 Tony：在新加坡/日本时不要把流量都拉回上海）。

只改出口，不改拦截：
- PROXY 组 fallback[HOME, DIRECT] → select[DIRECT, HOME]，默认 DIRECT = 当地网络直接出去；需要国内 IP 时在 Clash「代理」页把 PROXY 切到 HOME
- 隐私拦截（小米/系统身份/遥测/国内裸 IP）、Mac mini 与 10.77 走 HOME（面板、策略更新照常可达）保持不变
用法: make_travel.py <主策略.yaml> <输出.yaml>
"""
import sys

src, dst = sys.argv[1], sys.argv[2]
s = open(src, encoding="utf-8").read()
old = "  - {name: PROXY, type: fallback, proxies: [HOME, DIRECT], url: 'http://connectivitycheck.gstatic.com/generate_204', interval: 120, timeout: 3000}"
assert old in s, "主策略里找不到 PROXY 组定义，生成器格式变了？"
s = s.replace(old, "  # 海外直连版：默认 DIRECT（当地出网），需要上海家里出口时手动切 HOME\n"
                   "  - {name: PROXY, type: select, proxies: [DIRECT, HOME]}")
s = s.replace("# 由 tools/gen_clash_config.py 生成", "# 海外直连版（tools/make_travel.py 由主策略派生）· 由 tools/gen_clash_config.py 生成", 1)
open(dst, "w", encoding="utf-8").write(s)
print("ok", dst)
