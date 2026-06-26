#!/usr/bin/env bash
set -euo pipefail

PAPER_JAR="/opt/paper/paper.jar"
CONSOLE_PIPE="${CONSOLE_PIPE:-/tmp/minecraft-console.in}"

if [ "${EULA,,}" = "true" ]; then
  echo "eula=true" > /data/eula.txt
else
  cat >&2 <<'EOF'
=====================================================================
 You must accept the Minecraft EULA to run this server.
 Set the environment variable EULA=true to accept it:
   https://aka.ms/MinecraftEULA
 Example: docker run -e EULA=true ...
=====================================================================
EOF
  exit 1
fi

MEMORY="${MEMORY:-2G}"

AIKAR_FLAGS=(
  "-XX:+UseG1GC"
  "-XX:+ParallelRefProcEnabled"
  "-XX:MaxGCPauseMillis=200"
  "-XX:+UnlockExperimentalVMOptions"
  "-XX:+DisableExplicitGC"
  "-XX:+AlwaysPreTouch"
  "-XX:G1NewSizePercent=30"
  "-XX:G1MaxNewSizePercent=40"
  "-XX:G1HeapRegionSize=8M"
  "-XX:G1ReservePercent=20"
  "-XX:G1HeapWastePercent=5"
  "-XX:G1MixedGCCountTarget=4"
  "-XX:InitiatingHeapOccupancyPercent=15"
  "-XX:G1MixedGCLiveThresholdPercent=90"
  "-XX:G1RSetUpdatingPauseTimePercent=5"
  "-XX:SurvivorRatio=32"
  "-XX:+PerfDisableSharedMem"
  "-XX:MaxTenuringThreshold=1"
  "-Dusing.aikars.flags=https://mcflags.emc.gs"
  "-Daikars.new.flags=true"
)

read -r -a EXTRA_JVM_OPTS <<< "${JVM_OPTS:-}"
read -r -a EXTRA_PAPER_FLAGS <<< "${PAPER_FLAGS:-}"

rm -f "${CONSOLE_PIPE}"
mkfifo "${CONSOLE_PIPE}"
exec 3<>"${CONSOLE_PIPE}"

echo "Starting PaperMC ${PAPER_VERSION:-?} (build ${PAPER_BUILD:-?}) with ${MEMORY} heap..."
echo "Send console commands with: docker exec <container> mc <command>"

java \
  "-Xms${MEMORY}" "-Xmx${MEMORY}" \
  "${AIKAR_FLAGS[@]}" \
  "${EXTRA_JVM_OPTS[@]}" \
  -jar "${PAPER_JAR}" \
  --nogui \
  "${EXTRA_PAPER_FLAGS[@]}" <&3 &
JAVA_PID=$!

trap 'echo "Stopping PaperMC gracefully..."; echo "stop" >&3' TERM INT

set +e
EXIT_CODE=0
while kill -0 "${JAVA_PID}" 2>/dev/null; do
  wait "${JAVA_PID}"
  EXIT_CODE=$?
done
set -e

exec 3>&-
rm -f "${CONSOLE_PIPE}"
exit "${EXIT_CODE}"
