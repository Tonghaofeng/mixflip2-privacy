#!/bin/bash
# SysLocale.java → syslocale.dex（纯反射，不需要 android.jar）。需要 JDK（brew openjdk）与 d8（Google Maven 的 r8.jar，缺则自动下载）。
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
"$JAVA_HOME/bin/javac" --release 11 -d "$B" SysLocale.java
"$JAVA_HOME/bin/java" -cp "$R8" com.android.tools.r8.D8 --min-api 30 --output "$B" "$B"/*.class
cp "$B/classes.dex" syslocale.dex
rm -rf "$B"
echo "built syslocale.dex"
