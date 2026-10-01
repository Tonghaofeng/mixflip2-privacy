#!/bin/zsh
# 构建 stubs/<名>/ 下的无代码 APK（空壳顶替包 / RRO）：aapt2 compile+link → zipalign → apksigner(v2+v3)。
# 用法: stubs/build.sh <目录名>   产物: stubs/out/<目录名>.apk
# 签名钥匙 stubs/stub.keystore 首次自动生成、不入库（.gitignore）；换钥匙后已装的空壳要先卸再装。
set -euo pipefail
cd "$(dirname "$0")"
SDK=${ANDROID_SDK_ROOT:-/opt/homebrew/share/android-commandlinetools}
BT=$(ls -d $SDK/build-tools/* | sort -V | tail -1)
JAR=$(ls -d $SDK/platforms/android-* | sort -V | tail -1)/android.jar
export JAVA_HOME=${JAVA_HOME:-/opt/homebrew/opt/openjdk}; export PATH=$JAVA_HOME/bin:$PATH
n=${1:?用法: build.sh <stubs 下的目录名>}
KS=stub.keystore
[ -f $KS ] || keytool -genkeypair -keystore $KS -storepass stubstub -keypass stubstub -alias stub \
  -keyalg RSA -keysize 2048 -validity 36500 -dname "CN=mixflip2 stub" >/dev/null 2>&1
w=$(mktemp -d); mkdir -p out
res=()
if [ -d $n/res ]; then $BT/aapt2 compile --dir $n/res -o $w/res.zip; res=($w/res.zip); fi
$BT/aapt2 link -I $JAR --manifest $n/AndroidManifest.xml -o $w/u.apk ${res[@]}
$BT/zipalign -f 4 $w/u.apk $w/a.apk
$BT/apksigner sign --ks $KS --ks-pass pass:stubstub --key-pass pass:stubstub --out out/$n.apk $w/a.apk
rm -rf $w out/$n.apk.idsig
$BT/apksigner verify out/$n.apk && echo "-> stubs/out/$n.apk ($(stat -f%z out/$n.apk) B, sha256 $(shasum -a 256 out/$n.apk | cut -c1-16)…)"
