#!/usr/bin/env bash
set -euo pipefail

# 共通環境の取り込み（ROOT_DIR, WEST_WS, CONFIG_DIR, OUTPUT_DIR）
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/west-common.sh"

# uf2 優先で firmware_builds/ へコピー（なければ bin）
copy_artifacts() {
  local build_dir="${1:?build_dir required}"
  local name="${2:?artifact name required}"
  local uf2="${build_dir}/zephyr/zmk.uf2"
  local bin="${build_dir}/zephyr/zmk.bin"

  if [ -f "${uf2}" ]; then
    cp "${uf2}" "${OUTPUT_DIR}/${name}.uf2"
    echo "✅ ${OUTPUT_DIR}/${name}.uf2"
  elif [ -f "${bin}" ]; then
    cp "${bin}" "${OUTPUT_DIR}/${name}.bin"
    echo "✅ ${OUTPUT_DIR}/${name}.bin"
  else
    echo "❌ No firmware found for ${name}"
    return 1
  fi
}
