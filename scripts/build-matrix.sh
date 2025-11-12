#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/build-helpers.sh"

BUILD_MATRIX_PATH="${ROOT_DIR}/build.yaml"
COUNT="$(yq -r '.include | length' "${BUILD_MATRIX_PATH}")"
[ "${COUNT}" -gt 0 ] || { echo "No builds defined in ${BUILD_MATRIX_PATH}"; exit 1; }

for idx in $(seq 0 $((COUNT - 1))); do
  BOARD="$(yq -r ".include[${idx}].board" "${BUILD_MATRIX_PATH}")"
  SHIELDS_LINE_RAW="$(yq -r ".include[${idx}].shield // \"\"" "${BUILD_MATRIX_PATH}")"
  ARTIFACT_NAME_CFG="$(yq -r ".include[${idx}].[\"artifact-name\"] // \"\"" "${BUILD_MATRIX_PATH}")"
  SNIPPET="$(yq -r ".include[${idx}].snippet // \"\"" "${BUILD_MATRIX_PATH}")"

  # overlay-path（配列/文字列両対応）を安全にまとめる
  OVERLAY_NODE_TYPE="$(yq -r ".include[${idx}].[\"overlay-path\"] | type" "${BUILD_MATRIX_PATH}" || echo null)"
  OVERLAY_ITEMS_STR=""
  if [ "${OVERLAY_NODE_TYPE}" = "!!seq" ]; then
    MAP_LEN="$(yq -r ".include[${idx}].[\"overlay-path\"] | length" "${BUILD_MATRIX_PATH}")"
    for j in $(seq 0 $((MAP_LEN - 1))); do
      item="$(yq -r ".include[${j}]" <(yq ".include[${idx}].[\"overlay-path\"]" "${BUILD_MATRIX_PATH}"))" || true
      [ -n "${item}" ] && OVERLAY_ITEMS_STR="${OVERLAY_ITEMS_STR}${item} "
    done
  else
    OVERLAY_ITEMS_STR="$(yq -r ".include[${idx}].[\"overlay-path\"] // \"\"" "${BUILD_MATRIX_PATH}")"
  fi

  CMAKE_ARGS_CFG_RAW="$(yq -r ".include[${idx}].[\"cmake-args\"] // \"\"" "${BUILD_MATRIX_PATH}")"

  BUILD_DIR="$(mktemp -d)"

  # west の追加引数
  EXTRA_WEST_ARGS=()
  [ -n "${SNIPPET}" ] && EXTRA_WEST_ARGS+=( -S "${SNIPPET}" )

  # CMake 引数（配列のまま保持）
  CM_ARGS=()

  # ZMK_CONFIG は常に追加
  CM_ARGS+=( -DZMK_CONFIG="${CONFIG_DIR}" )

  # SHIELD の値をメインで正規化し、-D と値を「別要素」で追加（値にクォートは含めない）
  SHIELDS_LINE="$(echo "${SHIELDS_LINE_RAW}" | tr -s '[:space:]' ' ' | sed 's/^ *//; s/ *$//')"
  if [ -n "${SHIELDS_LINE}" ]; then
    declare -A _seen=()
    read -r -a _items <<<"${SHIELDS_LINE}"
    uniq_items=()
    for it in "${_items[@]}"; do
      [ -z "${it}" ] && continue
      if [ -z "${_seen[${it}]+x}" ]; then
        uniq_items+=( "${it}" )
        _seen["${it}"]=1
      fi
    done
    SHIELD_VALUE="$(IFS=' ' ; echo "${uniq_items[*]}")"
    CM_ARGS+=( -D "SHIELD=${SHIELD_VALUE}" )
  fi

  # overlay + lism.keymap（値だけを返す関数に揃える） → 値を -D と別要素で追加
  DTC_OVERLAY_VAL="$(prepare_overlay_value "${OVERLAY_ITEMS_STR}")"
  if [ -n "${DTC_OVERLAY_VAL}" ]; then
    CM_ARGS+=( -D "${DTC_OVERLAY_VAL}" )
  fi

  # 追加 cmake-args（そのまま配列へ）
  if [ -n "${CMAKE_ARGS_CFG_RAW}" ]; then
    read -r -a cmargs <<<"${CMAKE_ARGS_CFG_RAW}"
    CM_ARGS+=( "${cmargs[@]}" )
  fi

  # west build を配列のまま直接実行
  cmd=( west build -s zmk/app -d "${BUILD_DIR}" -b "${BOARD}" )
  cmd+=( "${EXTRA_WEST_ARGS[@]}" )
  cmd+=( -- )
  cmd+=( "${CM_ARGS[@]}" )

  (
    cd "${WEST_WS}"
    set -x
    "${cmd[@]}"
    set +x
  )

  # アーティファクト名
  ARTIFACT_NAME="${ARTIFACT_NAME_CFG}"
  if [ -z "${ARTIFACT_NAME}" ]; then
    if [ -n "${SHIELDS_LINE}" ]; then
      ARTIFACT_NAME="$(echo "${SHIELDS_LINE}" | tr ' ' '-' )-${BOARD}-zmk"
    else
      ARTIFACT_NAME="${BOARD}-zmk"
    fi
  fi

  copy_artifacts "${BUILD_DIR}" "${ARTIFACT_NAME}"
done

echo "🎉 All builds copied to ${OUTPUT_DIR}"
