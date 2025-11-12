#!/usr/bin/env bash
set -euo pipefail

# 共通環境の取り込み（ROOT_DIR, WEST_WS, CONFIG_DIR, OUTPUT_DIR）
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/west-common.sh"

# overlay-path を _west 起点で絶対化し、末尾に lism.keymap を追加して
# セミコロン連結の一引数として返す（なければ空文字）
prepare_overlay_arg() {
  local overlay_items_str="${1:-}"
  local -a items=()
  local -a resolved=()

  if [ -n "${overlay_items_str}" ]; then
    IFS=' ' read -r -a items <<<"$(echo "${overlay_items_str}" | tr ';' ' ')"
  fi

  for rel in "${items[@]}"; do
    [ -z "${rel}" ] && continue
    case "${rel}" in
      /*) resolved+=( "${rel}" ) ;;
      *)  resolved+=( "${WEST_WS}/${rel}" ) ;;
    esac
  done

  local keymap_path="${ROOT_DIR}/config/lism.keymap"
  if [ -f "${keymap_path}" ]; then
    resolved+=( "${keymap_path}" )
  else
    echo "Warning: ${keymap_path} not found. Continuing without keymap overlay." >&2
  fi

  if [ "${#resolved[@]}" -gt 0 ]; then
    local dtc_val
    dtc_val="$(printf "%s;" "${resolved[@]}" | sed 's/;$//')"
    echo "-DDTC_OVERLAY_FILE=${dtc_val}"
  else
    echo ""
  fi
}

# "lism_left rgbled_adapter" → -DSHIELD=... の配列化（echoで返す）
prepare_shield_args() {
  local shields_line="${1:-}"
  local -a shields=()
  local -a args=()
  if [ -n "${shields_line}" ]; then
    read -r -a shields <<<"${shields_line}"
    for s in "${shields[@]}"; do
      [ -n "${s}" ] && args+=( "-DSHIELD=${s}" )
    done
  fi
  echo "${args[@]}"
}

# _west を working-dir に固定して west build を実行
run_west_build() {
  local board="${1:?board required}"; shift
  local build_dir="${1:?build_dir required}"; shift
  (
    cd "${WEST_WS}"
    set -x
    # shellcheck disable=SC2068
    west build -s zmk/app -d "${build_dir}" -b "${board}" $@
    set +x
  )
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
