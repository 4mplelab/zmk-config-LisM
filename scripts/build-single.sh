#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/build-helpers.sh"

BUILD_MATRIX_PATH="${ROOT_DIR}/build.yaml"
COUNT="$(yq -r '.include | length' "${BUILD_MATRIX_PATH}")"
[ "${COUNT}" -gt 0 ] || { echo "No builds defined in ${BUILD_MATRIX_PATH}"; exit 1; }

echo "Select build preset (from build.yaml):"
for i in $(seq 0 $((COUNT - 1))); do
  TITLE="$(yq -r ".include[${i}].[\"artifact-name\"] // \"\"" "${BUILD_MATRIX_PATH}")"
  [ -n "${TITLE}" ] || TITLE="$(yq -r ".include[${i}].shield // \"\"" "${BUILD_MATRIX_PATH}") - $(yq -r ".include[${i}].board" "${BUILD_MATRIX_PATH}")"
  printf "  %d) %s\n" "$((i+1))" "${TITLE}"
done
read -rp "Enter choice [1-${COUNT}]: " CHOICE
SEL=$((CHOICE - 1))
[ "${SEL}" -ge 0 ] && [ "${SEL}" -lt "${COUNT}" ] || { echo "Invalid choice"; exit 1; }

BOARD="$(yq -r ".include[${SEL}].board" "${BUILD_MATRIX_PATH}")"
SHIELDS_LINE="$(yq -r ".include[${SEL}].shield // \"\"" "${BUILD_MATRIX_PATH}")"
ARTIFACT_NAME_CFG="$(yq -r ".include[${SEL}].[\"artifact-name\"] // \"\"" "${BUILD_MATRIX_PATH}")"
SNIPPET="$(yq -r ".include[${SEL}].snippet // \"\"" "${BUILD_MATRIX_PATH}")"

# overlay-path（配列/文字列対応）
NODE_TYPE="$(yq -r ".include[${SEL}].[\"overlay-path\"] | type" "${BUILD_MATRIX_PATH}" || echo null)"
OVERLAY_ITEMS_STR=""
if [ "${NODE_TYPE}" = "!!seq" ]; then
  LEN="$(yq -r ".include[${SEL}].[\"overlay-path\"] | length" "${BUILD_MATRIX_PATH}")"
  for j in $(seq 0 $((LEN - 1))); do
    item="$(yq -r ".include[${SEL}].[\"overlay-path\"][${j}]" "${BUILD_MATRIX_PATH}")"
    [ -n "${item}" ] && OVERLAY_ITEMS_STR="${OVERLAY_ITEMS_STR}${item} "
  done
else
  OVERLAY_ITEMS_STR="$(yq -r ".include[${SEL}].[\"overlay-path\"] // \"\"" "${BUILD_MATRIX_PATH}")"
fi

BUILD_DIR="$(mktemp -d)"

EXTRA_WEST_ARGS=()
[ -n "${SNIPPET}" ] && EXTRA_WEST_ARGS+=(-S "${SNIPPET}")

EXTRA_CMAKE_ARGS=()
SHIELD_ARGS_STR="$(prepare_shield_args "${SHIELDS_LINE}")"
[ -n "${SHIELD_ARGS_STR}" ] && read -r -a shield_args <<<"${SHIELD_ARGS_STR}" && EXTRA_CMAKE_ARGS+=( "${shield_args[@]}" )
OVERLAY_ARG="$(prepare_overlay_arg "${OVERLAY_ITEMS_STR}")"
[ -n "${OVERLAY_ARG}" ] && EXTRA_CMAKE_ARGS+=( "${OVERLAY_ARG}" )

run_west_build "${BOARD}" "${BUILD_DIR}" \
  "${EXTRA_WEST_ARGS[@]}" -- \
  -DZMK_CONFIG="${CONFIG_DIR}" \
  "${EXTRA_CMAKE_ARGS[@]}"

ARTIFACT_NAME="${ARTIFACT_NAME_CFG}"
if [ -z "${ARTIFACT_NAME}" ]; then
  ARTIFACT_NAME="$( [ -n "${SHIELDS_LINE}" ] && echo "$(echo "${SHIELDS_LINE}" | tr ' ' '-' )-${BOARD}-zmk" || echo "${BOARD}-zmk" )"
fi
copy_artifacts "${BUILD_DIR}" "${ARTIFACT_NAME}"
