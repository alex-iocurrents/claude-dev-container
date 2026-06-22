HOST_UID := $(shell id -u)
HOST_GID := $(shell id -g)
COMPOSE := docker compose -f $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))/docker-compose.yml

.PHONY: build run

build:
	@[ -f ~/.claude.json ] || echo '{}' > ~/.claude.json
	@touch ~/.claude_dev_bash_history
	HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) $(COMPOSE) build

run:
	HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) $(COMPOSE) run --rm dev
