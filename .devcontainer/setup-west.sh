#!/usr/bin/env bash
set -euo pipefail

# ルートと _west の絶対パス
ROOT_DIR="/workspaces/zmk-config"
WEST_WS="${ROOT_DIR}/_west"
ORIG_MANIFEST_DIR="${ROOT_DIR}/config"
ORIG_MANIFEST_FILE="${ORIG_MANIFEST_DIR}/west.yml"

# ルート側に誤作成された .west をクリーン
if [ -d "${ROOT_DIR}/.west" ]; then
  rm -rf "${ROOT_DIR}/.west"
fi

# _west/config に west.yml のシンボリックリンクを張る（オリジナル変更を自動反映）
mkdir -p "${WEST_WS}/config"
[ -e "${WEST_WS}/config/west.yml" ] && rm -f "${WEST_WS}/config/west.yml"
ln -s ../../config/west.yml "${WEST_WS}/config/west.yml"

# _west をワークスペースとして初期化（manifest はリンクで参照）
cd "${WEST_WS}"
if [ ! -d ".west" ]; then
  west init -l ./config
fi

# 依存取得と環境反映
west update --fetch-opt=--filter=tree:0
west zephyr-export

echo "West workspace ready at: ${WEST_WS}"
echo "Manifest linked from: ${ORIG_MANIFEST_FILE}"