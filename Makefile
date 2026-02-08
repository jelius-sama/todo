.PHONY: run build

APP_NAME := todo
BIN_PATH := ./bin

UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

SWIFT := swift

# Base flags
SWIFT_BUILD_FLAGS := -c release -Xlinker -s
SWIFT_RUN_FLAGS   :=

# Default: dynamic build
BUILD_STATIC_EXECUTABLE ?= 0

ifeq ($(UNAME_S),Linux)
    ifeq ($(BUILD_STATIC_EXECUTABLE),1)

        # -------- Static (musl) build --------
        ifeq ($(UNAME_M),x86_64)
            SWIFT_SDK := x86_64-swift-linux-musl
        else ifeq ($(UNAME_M),aarch64)
            SWIFT_SDK := aarch64-swift-linux-musl
        else
            $(error Unsupported Linux architecture: $(UNAME_M))
        endif

        SWIFT_BUILD_FLAGS += --swift-sdk $(SWIFT_SDK)
        SWIFT_RUN_FLAGS   += --swift-sdk $(SWIFT_SDK)

    else
        # -------- Dynamic (glibc) build --------
    endif
endif

BUILD_PATH := $(shell $(SWIFT) build $(SWIFT_BUILD_FLAGS) --show-bin-path)

run:
	$(SWIFT) run $(SWIFT_RUN_FLAGS)

build:
	STATIC_BUILD=$(BUILD_STATIC_EXECUTABLE) $(SWIFT) build $(SWIFT_BUILD_FLAGS)
	mkdir -p $(BIN_PATH)
	cp $(BUILD_PATH)/$(APP_NAME) $(BIN_PATH)/

