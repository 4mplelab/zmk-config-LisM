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

.PHONY: all_exclude_studio all setup-west single clean

# studio を含まない全ビルド
all_exclude_studio:
	@FILTER_MODE=exclude_studio bash scripts/build-matrix.sh

# studio を含む全ビルド
all:
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
