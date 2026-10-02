#!/bin/zsh
# 手搓构建 permguard.apk（不用 Gradle）：javac → d8 → aapt2 link（清单 + assets）→ 塞 classes.dex → zipalign → apksigner(v2+v3)。
# 需要：brew openjdk、brew --cask android-commandlinetools + sdkmanager "build-tools;36.0.0" "platforms;android-36"。
# Shizuku API 13.1.5 从 Maven Central 取，按下面钉死的 sha256 校验。core/Core.java 一起编进 APK（App 用 app_process 以 APK 为 classpath 跑它）。
# 签名钥匙 app/permguard.keystore 首次自动生成、不入库（.gitignore）；丢了只能先卸再装。产物 app/out/permguard.apk
set -euo pipefail
cd "${0:A:h}"
SDK=${ANDROID_SDK_ROOT:-/opt/homebrew/share/android-commandlinetools}
BT=$(ls -d $SDK/build-tools/* | sort -V | tail -1)
JAR=$(ls -d $SDK/platforms/android-* | sort -V | tail -1)/android.jar
export JAVA_HOME=${JAVA_HOME:-/opt/homebrew/opt/openjdk}; export PATH=$JAVA_HOME/bin:$PATH
CACHE=${CACHE:-$HOME/.cache/permguard}; mkdir -p $CACHE
typeset -A SHA=(
  api      4def9bde498ef8626614c2fc5db9af4749c86f16f6c33e3f5658d35e70bab59b
  provider b0f18cd9812464ec171c53cac93a819fe411718a3965c311f01eb4de265381b3
  aidl     33fe7191cdd69fcb66d649264f3b0c47acb2f3d6343afc05b98dbbff6f221963
  shared   4659642c9339be0a26e9c65bb8648f7ad6d8f4a465f557993ccbc78802381635
)
libs=()
for a in api provider aidl shared; do
  f=$CACHE/$a-13.1.5.aar
  [ -f $f ] || curl -sSfL -o $f https://repo1.maven.org/maven2/dev/rikka/shizuku/$a/13.1.5/$a-13.1.5.aar
  [ "$(shasum -a 256 $f | cut -d' ' -f1)" = "${SHA[$a]}" ] || { echo "❌ $a AAR sha256 不符"; exit 1; }
  unzip -p $f classes.jar > $CACHE/$a.jar
  libs+=($CACHE/$a.jar)
done

KS=permguard.keystore
[ -f $KS ] || keytool -genkeypair -keystore $KS -storepass permguard -keypass permguard -alias permguard \
  -keyalg RSA -keysize 3072 -validity 36500 -dname "CN=permguard, O=tonytong.uk" >/dev/null 2>&1

w=$(mktemp -d); mkdir -p out $w/classes $w/assets
cp ../whitelist.conf ../phone/pg.sh $w/assets/
javac --release 11 -encoding UTF-8 -nowarn -cp $JAR:${(j.:.)libs} -d $w/classes \
  src/uk/tonytong/permguard/*.java ../core/src/uk/tonytong/permguard/Core.java 2>&1 | grep -v -E '^(warning|Note|注)' || true
[ -f $w/classes/uk/tonytong/permguard/Core.class ] || { echo "❌ javac 失败"; exit 1; }
java -cp $BT/lib/d8.jar com.android.tools.r8.D8 --release --min-api 30 --lib $JAR --output $w \
  $(find $w/classes -name '*.class') ${libs[@]}
$BT/aapt2 link -I $JAR --manifest AndroidManifest.xml -A $w/assets -o $w/u.apk
(cd $w && zip -q -u u.apk classes.dex)
$BT/zipalign -f 4 $w/u.apk $w/a.apk
$BT/apksigner sign --ks $KS --ks-pass pass:permguard --key-pass pass:permguard --out out/permguard.apk $w/a.apk
rm -rf $w out/permguard.apk.idsig
$BT/apksigner verify out/permguard.apk && echo "-> app/out/permguard.apk ($(stat -f%z out/permguard.apk) B, sha256 $(shasum -a 256 out/permguard.apk | cut -c1-16)…)"
