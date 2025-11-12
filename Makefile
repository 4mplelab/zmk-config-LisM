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

.PHONY: all setup-west single matrix clean

all: matrix

matrix:
	@bash scripts/build-matrix.sh

single:
	@bash scripts/build-single.sh

setup-west:
	@bash .devcontainer/setup-west.sh

clean:
	@echo "🧹 Cleaning firmware_builds/"
	@rm -rf "$(ROOT_DIR)/firmware_builds"
	@echo "🧹 To reset workspace: rm -rf $(WEST_WS) && make setup-west"
