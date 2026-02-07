.PHONY: run build

BUILD_PATH := $(shell swift build -c release --show-bin-path)
APP_NAME := todo
BIN_PATH := ./bin

run:
	swift run

build:
	swift build -c release
	mkdir -p $(BIN_PATH) && cp $(BUILD_PATH)/$(APP_NAME) $(BIN_PATH)/
