#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEST_WS="${ROOT_DIR}/_west"
CONFIG_DIR="${ROOT_DIR}/config"
OUTPUT_DIR="${ROOT_DIR}/firmware_builds"

command -v west >/dev/null 2>&1 || { echo "west not found"; exit 1; }
command -v yq >/dev/null 2>&1 || { echo "yq not found"; exit 1; }

# ワークスペース確認
if [ ! -d "${WEST_WS}/.west" ]; then
  echo "West workspace not initialized at ${WEST_WS}. Run 'make setup-west'."
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

export ROOT_DIR WEST_WS CONFIG_DIR OUTPUT_DIR
