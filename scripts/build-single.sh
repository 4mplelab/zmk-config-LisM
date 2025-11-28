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
SHIELDS_LINE_RAW="$(yq -r ".include[${SEL}].shield // \"\"" "${BUILD_MATRIX_PATH}")"
ARTIFACT_NAME_CFG="$(yq -r ".include[${SEL}].[\"artifact-name\"] // \"\"" "${BUILD_MATRIX_PATH}")"
SNIPPET="$(yq -r ".include[${SEL}].snippet // \"\"" "${BUILD_MATRIX_PATH}")"

BUILD_DIR="$(mktemp -d)"

# west の追加引数
EXTRA_WEST_ARGS=()
[ -n "${SNIPPET}" ] && EXTRA_WEST_ARGS+=( -S "${SNIPPET}" )

# CMake 引数（配列で保持）
CM_ARGS=()
CM_ARGS+=( -DZMK_CONFIG="${CONFIG_DIR}" )
CM_ARGS+=( -DZMK_EXTRA_MODULES="${ROOT_DIR}" )

# SHIELD をメインで正規化し、-D と値を別要素で追加（値にクォートは含めない）
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

# 追加 cmake-args
CMAKE_ARGS_CFG_RAW="$(yq -r ".include[${SEL}].[\"cmake-args\"] // \"\"" "${BUILD_MATRIX_PATH}")"
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
