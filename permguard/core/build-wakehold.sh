#!/bin/bash
# WakeHold.java → wakehold.dex（远程通道掉线时持唤醒锁，见类注释）。工具链同 build.sh。
set -euo pipefail
cd "$(dirname "$0")"
JAVA_HOME=${JAVA_HOME:-/opt/homebrew/opt/openjdk}
R8=${R8_JAR:-$HOME/.cache/r8/r8.jar}
B=$(mktemp -d)
"$JAVA_HOME/bin/javac" --release 11 -encoding UTF-8 -d "$B" src/uk/tonytong/permguard/WakeHold.java
"$JAVA_HOME/bin/java" -cp "$R8" com.android.tools.r8.D8 --min-api 30 --output "$B" $(find "$B" -name "*.class")
cp "$B/classes.dex" wakehold.dex; rm -rf "$B"
echo "built wakehold.dex ($(stat -f%z wakehold.dex) B)"
