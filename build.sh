#!/usr/bin/env bash
#
# build.sh - resolve a PaperMC build for a given Minecraft version against the
# PaperMC API and build a Docker image tagged with that version.
#
# Usage:
#   ./build.sh <minecraft-version> [--build <build>] [--image <name>]
#                                  [--push] [--platform <list>]
#
# Examples:
#   ./build.sh 1.21.4
#   ./build.sh 1.21.4 --image ghcr.io/me/papermc --push
#   ./build.sh 1.21.4 --platform linux/amd64,linux/arm64 --push
#
set -euo pipefail

API="https://api.papermc.io/v2/projects/paper"
IMAGE="papermc"
PAPER_BUILD=""
PLATFORM=""
PUSH="false"
PAPER_VERSION=""

usage() {
  sed -n '2,18p' "$0"
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help) usage 0 ;;
    --build)    PAPER_BUILD="$2"; shift 2 ;;
    --image)    IMAGE="$2"; shift 2 ;;
    --platform) PLATFORM="$2"; shift 2 ;;
    --push)     PUSH="true"; shift ;;
    -*) echo "Unknown option: $1" >&2; usage 1 ;;
    *)
      if [ -z "${PAPER_VERSION}" ]; then
        PAPER_VERSION="$1"; shift
      else
        echo "Unexpected argument: $1" >&2; usage 1
      fi
      ;;
  esac
done

[ -n "${PAPER_VERSION}" ] || { echo "Error: minecraft version is required." >&2; usage 1; }

command -v jq >/dev/null   || { echo "Error: jq is required." >&2; exit 1; }
command -v curl >/dev/null || { echo "Error: curl is required." >&2; exit 1; }

if [ -z "${PAPER_BUILD}" ]; then
  echo "Resolving latest build for Paper ${PAPER_VERSION}..."
  PAPER_BUILD="$(curl -fsSL "${API}/versions/${PAPER_VERSION}" | jq -r '.builds[-1]')"
  [ -n "${PAPER_BUILD}" ] && [ "${PAPER_BUILD}" != "null" ] \
    || { echo "Error: no builds found for version ${PAPER_VERSION}." >&2; exit 1; }
fi

BUILD_JSON="$(curl -fsSL "${API}/versions/${PAPER_VERSION}/builds/${PAPER_BUILD}")"
PAPER_JAR="$(echo "${BUILD_JSON}"    | jq -r '.downloads.application.name')"
PAPER_SHA256="$(echo "${BUILD_JSON}" | jq -r '.downloads.application.sha256')"
CHANNEL="$(echo "${BUILD_JSON}"      | jq -r '.channel')"

[ "${PAPER_JAR}" != "null" ] || { echo "Error: could not resolve jar for build ${PAPER_BUILD}." >&2; exit 1; }

if [ "${CHANNEL}" != "STABLE" ]; then
  echo "Warning: build ${PAPER_BUILD} for ${PAPER_VERSION} is channel '${CHANNEL}' (not STABLE)." >&2
fi

echo "Paper ${PAPER_VERSION} build ${PAPER_BUILD} (${CHANNEL})"
echo "  jar:    ${PAPER_JAR}"
echo "  sha256: ${PAPER_SHA256}"

TAG="${IMAGE}:${PAPER_VERSION}"
BUILD_ARGS=(
  --build-arg "PAPER_VERSION=${PAPER_VERSION}"
  --build-arg "PAPER_BUILD=${PAPER_BUILD}"
  --build-arg "PAPER_JAR=${PAPER_JAR}"
  --build-arg "PAPER_SHA256=${PAPER_SHA256}"
)

if [ -n "${PLATFORM}" ]; then
  set -- docker buildx build --platform "${PLATFORM}" "${BUILD_ARGS[@]}" -t "${TAG}"
  [ "${PUSH}" = "true" ] && set -- "$@" --push || set -- "$@" --load
  exec "$@" .
else
  docker build "${BUILD_ARGS[@]}" -t "${TAG}" .
  [ "${PUSH}" = "true" ] && docker push "${TAG}"
fi

echo "Built ${TAG}"
