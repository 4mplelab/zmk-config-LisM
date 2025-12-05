YQ := $(shell command -v yq 2> /dev/null)
WEST := $(shell command -v west 2> /dev/null)

ifeq ($(YQ),)
  $(error "yq is not installed.")
endif
ifeq ($(WEST),)
  $(error "west is not installed.")
endif

ROOT_DIR := $(abspath $(CURDIR))
WEST_WS := $(ROOT_DIR)/_west

# 並列数を環境変数 PARALLEL から取得。未設定の場合はCPUコア数を自動検出。
PARALLEL ?= $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 2)

.PHONY: all_p all all_studio_p all_studio setup-west single clean

# studio を含まない全ビルド (並列実行)
all_p:
	@FILTER_MODE=exclude_studio bash scripts/build-matrix.sh --parallel=$(PARALLEL)

# studio を含まない全ビルド (逐次実行)
all:
	@FILTER_MODE=exclude_studio bash scripts/build-matrix.sh


# studio を含む全ビルド (並列実行)
all_studio_p:
	@FILTER_MODE=all bash scripts/build-matrix.sh --parallel=$(PARALLEL)

# studio を含む全ビルド (逐次実行)
all_studio:
	@FILTER_MODE=all bash scripts/build-matrix.sh


single:
	@bash scripts/build-single.sh

setup-west:
	@bash .devcontainer/setup-west.sh

clean:
	@echo "🧹 Cleaning firmware_builds/"
	@rm -rf "$(ROOT_DIR)/firmware_builds"
	@echo "🧹🧹🧹 Cleaned!! 🧹🧹🧹"
	@echo "To reset workspace (optional): rm -rf $(WEST_WS) && make setup-west"
