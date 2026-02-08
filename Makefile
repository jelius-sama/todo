.PHONY: run build

BUILD_FLAGS := -Xswiftc -static-stdlib -Xswiftc -parse-as-library
BUILD_PATH := $(shell swift build -c release $(BUILD_FLAGS) --show-bin-path)

APP_NAME := todo
BIN_PATH := ./bin

run:
	swift run $(BUILD_FLAGS)

build:
	swift build -c release $(BUILD_FLAGS) -Xlinker -s
	mkdir -p $(BIN_PATH) && cp $(BUILD_PATH)/$(APP_NAME) $(BIN_PATH)/
