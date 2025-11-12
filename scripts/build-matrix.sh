#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/build-helpers.sh"

BUILD_MATRIX_PATH="${ROOT_DIR}/build.yaml"
COUNT="$(yq -r '.include | length' "${BUILD_MATRIX_PATH}")"
[ "${COUNT}" -gt 0 ] || { echo "No builds defined in ${BUILD_MATRIX_PATH}"; exit 1; }

for idx in $(seq 0 $((COUNT - 1))); do
  BOARD="$(yq -r ".include[${idx}].board" "${BUILD_MATRIX_PATH}")"
  SHIELDS_LINE="$(yq -r ".include[${idx}].shield // \"\"" "${BUILD_MATRIX_PATH}")"
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

  EXTRA_WEST_ARGS=()
  [ -n "${SNIPPET}" ] && EXTRA_WEST_ARGS+=(-S "${SNIPPET}")

  EXTRA_CMAKE_ARGS=()
  # shields
  SHIELD_ARGS_STR="$(prepare_shield_args "${SHIELDS_LINE}")"
  [ -n "${SHIELD_ARGS_STR}" ] && read -r -a shield_args <<<"${SHIELD_ARGS_STR}" && EXTRA_CMAKE_ARGS+=( "${shield_args[@]}" )
  # overlay + lism.keymap
  OVERLAY_ARG="$(prepare_overlay_arg "${OVERLAY_ITEMS_STR}")"
  [ -n "${OVERLAY_ARG}" ] && EXTRA_CMAKE_ARGS+=( "${OVERLAY_ARG}" )
  # 追加 cmake-args
  if [ -n "${CMAKE_ARGS_CFG_RAW}" ]; then
    read -r -a cmargs <<<"${CMAKE_ARGS_CFG_RAW}"
    EXTRA_CMAKE_ARGS+=( "${cmargs[@]}" )
  fi

  run_west_build "${BOARD}" "${BUILD_DIR}" \
    "${EXTRA_WEST_ARGS[@]}" -- \
    -DZMK_CONFIG="${CONFIG_DIR}" \
    "${EXTRA_CMAKE_ARGS[@]}"

  ARTIFACT_NAME="${ARTIFACT_NAME_CFG}"
  if [ -z "${ARTIFACT_NAME}" ]; then
    ARTIFACT_NAME="$( [ -n "${SHIELDS_LINE}" ] && echo "$(echo "${SHIELDS_LINE}" | tr ' ' '-' )-${BOARD}-zmk" || echo "${BOARD}-zmk" )"
  fi

  copy_artifacts "${BUILD_DIR}" "${ARTIFACT_NAME}"
done

echo "🎉 All builds copied to ${OUTPUT_DIR}"
