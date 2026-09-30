#!/bin/zsh
# 生成手机 Clash 策略 → 推到 Mac mini 的分发点（com.tony.phone-config）。手机在家时在 Clash 里点「更新」即生效。
set -e
cd ${0:A:h}
python3 gen_clash_config.py
T=$(ssh macserver 'cat ~/phone-config/.token')
scp -q ../clash/mixflip2.yaml "macserver:phone-config/$T/mixflip2.yaml"
ssh macserver "chmod 600 ~/phone-config/$T/mixflip2.yaml"
code=$(curl -s -o /dev/null -w '%{http_code}' "http://192.168.50.2:18765/$T/mixflip2.yaml")
echo "已发布：http://192.168.50.2:18765/<token>/mixflip2.yaml → HTTP $code；错误路径应 404：$(curl -s -o /dev/null -w '%{http_code}' http://192.168.50.2:18765/)"
