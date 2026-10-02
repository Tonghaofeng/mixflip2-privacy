#!/bin/bash
# Core.java → permguard.dex（纯 JDK + 系统命令，不需要 android.jar）。adb 版用它；App 构建时也编进 APK。
# 需要 JDK（brew openjdk）与 d8（Google Maven 的 r8.jar，缺则自动下载，同 tools/sysregion/build.sh）。
set -euo pipefail
cd "$(dirname "$0")"
JAVA_HOME=${JAVA_HOME:-/opt/homebrew/opt/openjdk}
R8=${R8_JAR:-$HOME/.cache/r8/r8.jar}
if [ ! -f "$R8" ]; then
  mkdir -p "$(dirname "$R8")"
  V=$(curl -sS https://dl.google.com/android/maven2/com/android/tools/r8/maven-metadata.xml \
      | grep -oE "<version>[0-9]+\.[0-9]+\.[0-9]+</version>" | sed -E 's/<\/?version>//g' \
      | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
  curl -sS -o "$R8" "https://dl.google.com/android/maven2/com/android/tools/r8/$V/r8-$V.jar"
fi
B=$(mktemp -d)
"$JAVA_HOME/bin/javac" --release 11 -encoding UTF-8 -d "$B" src/uk/tonytong/permguard/Core.java
"$JAVA_HOME/bin/java" -cp "$R8" com.android.tools.r8.D8 --min-api 30 --output "$B" $(find "$B" -name '*.class')
cp "$B/classes.dex" permguard.dex
rm -rf "$B"
echo "built permguard.dex ($(stat -f%z permguard.dex) B, sha256 $(shasum -a 256 permguard.dex | cut -c1-16)…)"
