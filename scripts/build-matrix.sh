#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/build-helpers.sh"

EXEC_MODE="sequential"
PARALLEL_JOBS=""

# --parallel[=N] 引数を解析
if [[ "${1:-}" == --parallel* ]]; then
  EXEC_MODE="parallel"
  if [[ "${1}" == *=* ]]; then
    PARALLEL_JOBS="${1#*=}"
  fi
  shift
fi

BUILD_MATRIX_PATH="${ROOT_DIR}/build.yaml"
FILTER_MODE="${FILTER_MODE:-all}"  # all | include_studio | exclude_studio

COUNT="$(yq -r '.include | length' "${BUILD_MATRIX_PATH}")"
[ "${COUNT}" -gt 0 ] || { echo "No builds defined in ${BUILD_MATRIX_PATH}"; exit 1; }

#
# build_job idx
#
# A function that performs a single build from the matrix.
# It takes the index of the build configuration as an argument.
#
build_job() {
  local idx="$1"

  local BOARD
  BOARD="$(yq -r ".include[${idx}].board" "${BUILD_MATRIX_PATH}")"
  local SHIELDS_LINE_RAW
  SHIELDS_LINE_RAW="$(yq -r ".include[${idx}].shield // \"\"" "${BUILD_MATRIX_PATH}")"
  local ARTIFACT_NAME_CFG
  ARTIFACT_NAME_CFG="$(yq -r ".include[${idx}].[\"artifact-name\"] // \"\"" "${BUILD_MATRIX_PATH}")"
  local SNIPPET
  SNIPPET="$(yq -r ".include[${idx}].snippet // \"\"" "${BUILD_MATRIX_PATH}")"
  local CMAKE_ARGS_CFG_RAW
  CMAKE_ARGS_CFG_RAW="$(yq -r ".include[${idx}].[\"cmake-args\"] // \"\"" "${BUILD_MATRIX_PATH}")"

  echo "--- Starting build for ${ARTIFACT_NAME_CFG:-$BOARD} (index: ${idx}) ---"

  local BUILD_DIR
  BUILD_DIR="$(mktemp -d)"

  # west の追加引数
  local EXTRA_WEST_ARGS=()
  [ -n "${SNIPPET}" ] && EXTRA_WEST_ARGS+=( -S "${SNIPPET}" )

  # CMake 引数（配列のまま保持）
  local CM_ARGS=()

  # ZMK_CONFIG は常に追加
  CM_ARGS+=( -DZMK_CONFIG="${CONFIG_DIR}" )
  CM_ARGS+=( -DZMK_EXTRA_MODULES="${ROOT_DIR}" )

  # SHIELD の値をメインで正規化し、-D と値を「別要素」で追加（値にクォートは含めない）
  local SHIELDS_LINE
  SHIELDS_LINE="$(echo "${SHIELDS_LINE_RAW}" | tr -s '[:space:]' ' ' | sed 's/^ *//; s/ *$//')"
  if [ -n "${SHIELDS_LINE}" ]; then
    declare -A _seen=()
    local _items
    read -r -a _items <<<"${SHIELDS_LINE}"
    local uniq_items=()
    local it
    for it in "${_items[@]}"; do
      [ -z "${it}" ] && continue
      if [ -z "${_seen[${it}]+x}" ]; then
        uniq_items+=( "${it}" )
        _seen["${it}"]=1
      fi
    done
    local SHIELD_VALUE
    SHIELD_VALUE="$(IFS=' ' ; echo "${uniq_items[*]}")"
    CM_ARGS+=( -D "SHIELD=${SHIELD_VALUE}" )
  fi

  # 追加 cmake-args（そのまま配列へ）
  if [ -n "${CMAKE_ARGS_CFG_RAW}" ]; then
    local cmargs
    read -r -a cmargs <<<"${CMAKE_ARGS_CFG_RAW}"
    CM_ARGS+=( "${cmargs[@]}" )
  fi

  # west build を配列のまま直接実行
  local cmd=( west build -s zmk/app -d "${BUILD_DIR}" -b "${BOARD}" )
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
  local ARTIFACT_NAME="${ARTIFACT_NAME_CFG}"
  if [ -z "${ARTIFACT_NAME}" ]; then
    if [ -n "${SHIELDS_LINE}" ]; then
      ARTIFACT_NAME="$(echo "${SHIELDS_LINE}" | tr ' ' '-' )-${BOARD}-zmk"
    else
      ARTIFACT_NAME="${BOARD}-zmk"
    fi
  fi

  copy_artifacts "${BUILD_DIR}" "${ARTIFACT_NAME}"
  echo "--- Finished build for ${ARTIFACT_NAME_CFG:-$BOARD} (index: ${idx}) ---"
}


# Collect indices of matched builds first
matched_indices=()
for idx in $(seq 0 $((COUNT - 1))); do
  ARTIFACT_NAME_CFG="$(yq -r ".include[${idx}].[\"artifact-name\"] // \"\"" "${BUILD_MATRIX_PATH}")"

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

  matched_indices+=("${idx}")
done

if [ ${#matched_indices[@]} -eq 0 ]; then
  echo "ℹ No builds matched FILTER_MODE='${FILTER_MODE}' (artifact-name studio filter)."
  exit 0
fi

echo "Found ${#matched_indices[@]} matched builds to run."

# Execute builds based on the selected mode
if [ "${EXEC_MODE}" = "parallel" ]; then
  if [ -z "${PARALLEL_JOBS}" ]; then
    if command -v nproc > /dev/null; then
      PARALLEL_JOBS=$(nproc)
    elif command -v sysctl > /dev/null; then
      PARALLEL_JOBS=$(sysctl -n hw.ncpu)
    else
      PARALLEL_JOBS=2 # Fallback to a safe default
    fi
  fi

  echo "Running builds in parallel with up to ${PARALLEL_JOBS} jobs."

  pids=()
  for idx in "${matched_indices[@]}"; do
    # Limit the number of concurrent jobs
    while [[ $(jobs -p | wc -l) -ge ${PARALLEL_JOBS} ]]; do
      sleep 1
    done

    build_job "${idx}" &
    pids+=($!)
  done

  exit_code=0
  echo "Waiting for all parallel builds to complete..."
  for pid in "${pids[@]}"; do
    if ! wait "${pid}"; then
      echo "🔥 Build with PID ${pid} failed." >&2
      exit_code=1
    fi
  done

  if [ "${exit_code}" -ne 0 ]; then
    echo "🔥 One or more parallel builds failed." >&2
    exit "${exit_code}"
  fi
else # sequential
  for idx in "${matched_indices[@]}"; do
    build_job "${idx}"
  done
fi

echo "🎉 All builds copied to ${OUTPUT_DIR}"
