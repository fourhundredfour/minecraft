#!/usr/bin/env bash
set -euo pipefail

CONSOLE_PIPE="${CONSOLE_PIPE:-/tmp/minecraft-console.in}"

if [ "$#" -eq 0 ]; then
  echo "Usage: mc <minecraft console command>" >&2
  exit 64
fi

if [ ! -p "${CONSOLE_PIPE}" ]; then
  echo "Console pipe '${CONSOLE_PIPE}' not found - is the server running?" >&2
  exit 1
fi

printf '%s\n' "$*" > "${CONSOLE_PIPE}"
