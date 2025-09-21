DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
DOCKER_IMAGE ?= node:18

.PHONY: build _build test

build:
	@echo "Using DIR=$(DIR)"
	docker run --rm -v "$(DIR)":/usr/src/app -w /usr/src/app $(DOCKER_IMAGE) make _build

_build:
	npm ci
	npm run build

test:
	npm test
