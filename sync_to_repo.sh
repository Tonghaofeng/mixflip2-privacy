#!/bin/zsh
# 本地工作区（要连 adb）→ Mac mini 上的权威仓库 ~/CodeVault/git/mixflip2-privacy（→ Gitea tony/mixflip2-privacy）。
# 含 WireGuard 私钥的 clash/、安装包、体检原始 dump（raw_private/）永不同步（.gitignore 同样排除）。用法: ./sync_to_repo.sh "提交说明"
# ★rsync --delete 是单向覆盖：别的会话直接在 Mac mini 仓库提交过（10-01 的 9767bdb/27e7ee9 就是），先把那些提交合进本工作区再同步。
#   护栏：.last_sync_head 记上次同步后的远端 HEAD；远端 HEAD 变了就拒绝，打印要合入的提交（合完 echo <新HEAD> > .last_sync_head 再跑）。
set -e
cd ${0:A:h}
R=~/CodeVault/git/mixflip2-privacy
head=$(ssh macserver "git -C $R rev-parse HEAD")
if [ -f .last_sync_head ] && [ "$(cat .last_sync_head)" != "$head" ]; then
  echo "✋ 远端有本工作区没合入的提交（上次同步后 $(cat .last_sync_head | cut -c1-7) → 现在 ${head:0:7}）："
  ssh macserver "git -C $R log --oneline --stat $(cat .last_sync_head)..HEAD"
  echo "先合入（ssh macserver 'git -C $R format-patch --stdout <旧>..HEAD' | git apply），再 echo $head > .last_sync_head 后重跑。"
  exit 1
fi
rsync -a --delete --exclude .git --exclude clash/ --exclude '*.apk' --exclude .DS_Store --exclude raw_private/ --exclude .last_sync_head --exclude __pycache__/ --exclude stubs/stub.keystore --exclude stubs/out/ ./ macserver:CodeVault/git/mixflip2-privacy/
ssh macserver "cd $R && git add -A && (git diff --cached --quiet || git commit -q -m \"$1\") && git log --oneline -1"
ssh macserver "git -C $R rev-parse HEAD" > .last_sync_head
