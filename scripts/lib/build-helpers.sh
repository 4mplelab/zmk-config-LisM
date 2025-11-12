#!/usr/bin/env bash
set -euo pipefail

# 共通環境の取り込み（ROOT_DIR, WEST_WS, CONFIG_DIR, OUTPUT_DIR）
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/west-common.sh"

# overlay-path を _west 起点で絶対化し、末尾に lism.keymap を追加して
# セミコロン連結の“値だけ”を返す（なければ空文字）
# 戻り値例: DTC_OVERLAY_FILE=/abs/overlay1;/abs/overlay2;/abs/lism.keymap
prepare_overlay_value() {
  local overlay_items_str="${1:-}"
  local -a items=()
  local -a resolved=()

  # 入力はセミコロン/スペース混在を許容し、スペース配列へ正規化
  if [ -n "${overlay_items_str}" ]; then
    IFS=' ' read -r -a items <<<"$(echo "${overlay_items_str}" | tr ';' ' ')"
  fi

  # 相対パスは WEST_WS 基点で絶対化
  for rel in "${items[@]}"; do
    [ -z "${rel}" ] && continue
    case "${rel}" in
      /*) resolved+=( "${rel}" ) ;;
      *)  resolved+=( "${WEST_WS}/${rel}" ) ;;
    esac
  done

  # 末尾に lism.keymap を付与（存在すれば）
  local keymap_path="${ROOT_DIR}/config/lism.keymap"
  if [ -f "${keymap_path}" ]; then
    resolved+=( "${keymap_path}" )
  else
    echo "Warning: ${keymap_path} not found. Continuing without keymap overlay." >&2
  fi

  # セミコロン連結で“値だけ”生成
  if [ "${#resolved[@]}" -gt 0 ]; then
    local dtc_val
    dtc_val="$(printf "%s;" "${resolved[@]}" | sed 's/;$//')"
    echo "DTC_OVERLAY_FILE=${dtc_val}"
  else
    echo ""
  fi
}

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
