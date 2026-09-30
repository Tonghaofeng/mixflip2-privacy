#!/bin/zsh
# 本地工作区（要连 adb）→ Mac mini 上的权威仓库 ~/CodeVault/git/mixflip2-privacy（→ Gitea tony/mixflip2-privacy）。
# 含 WireGuard 私钥的 clash/ 与安装包永不同步（.gitignore 同样排除）。用法: ./sync_to_repo.sh "提交说明"
set -e
cd ${0:A:h}
rsync -a --delete --exclude .git --exclude clash/ --exclude '*.apk' --exclude .DS_Store ./ macserver:CodeVault/git/mixflip2-privacy/
ssh macserver "cd ~/CodeVault/git/mixflip2-privacy && git add -A && (git diff --cached --quiet || git commit -q -m \"$1\") && git log --oneline -1"
