#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/build-helpers.sh"

BUILD_MATRIX_PATH="${ROOT_DIR}/build.yaml"
FILTER_MODE="${FILTER_MODE:-all}"  # all | include_studio | exclude_studio

COUNT="$(yq -r '.include | length' "${BUILD_MATRIX_PATH}")"
[ "${COUNT}" -gt 0 ] || { echo "No builds defined in ${BUILD_MATRIX_PATH}"; exit 1; }

matched=0

for idx in $(seq 0 $((COUNT - 1))); do
  BOARD="$(yq -r ".include[${idx}].board" "${BUILD_MATRIX_PATH}")"
  SHIELDS_LINE_RAW="$(yq -r ".include[${idx}].shield // \"\"" "${BUILD_MATRIX_PATH}")"
  ARTIFACT_NAME_CFG="$(yq -r ".include[${idx}].[\"artifact-name\"] // \"\"" "${BUILD_MATRIX_PATH}")"
  SNIPPET="$(yq -r ".include[${idx}].snippet // \"\"" "${BUILD_MATRIX_PATH}")"

  # フィルタ判定（artifact-name に studio を含むか）
  is_studio_entry=false
  if [[ "${ARTIFACT_NAME_CFG}" == *studio* ]]; then
    is_studio_entry=true
  fi

  case "${FILTER_MODE}" in
    include_studio)
      if [ "${is_studio_entry}" != true ]; then
        continue
      fi
      ;;
    exclude_studio)
      if [ "${is_studio_entry}" = true ]; then
        continue
      fi
      ;;
    all)
      # no filter
      ;;
    *)
      echo "Unknown FILTER_MODE: ${FILTER_MODE}" >&2
      exit 2
      ;;
  esac

  matched=$((matched + 1))

  CMAKE_ARGS_CFG_RAW="$(yq -r ".include[${idx}].[\"cmake-args\"] // \"\"" "${BUILD_MATRIX_PATH}")"

  BUILD_DIR="$(mktemp -d)"

  # west の追加引数
  EXTRA_WEST_ARGS=()
  [ -n "${SNIPPET}" ] && EXTRA_WEST_ARGS+=( -S "${SNIPPET}" )

  # CMake 引数（配列のまま保持）
  CM_ARGS=()

  # ZMK_CONFIG は常に追加
  CM_ARGS+=( -DZMK_CONFIG="${CONFIG_DIR}" )
  CM_ARGS+=( -DZMK_EXTRA_MODULES="${ROOT_DIR}" )

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

if [ "${matched}" -eq 0 ]; then
  echo "ℹ No builds matched FILTER_MODE='${FILTER_MODE}' (artifact-name studio filter)."
  exit 0
fi

echo "🎉 All builds copied to ${OUTPUT_DIR}"
