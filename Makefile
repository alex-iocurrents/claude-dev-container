HOST_UID := $(shell id -u)
HOST_GID := $(shell id -g)
COMPOSE := docker compose -f $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))/docker-compose.yml

.PHONY: build build-security run run-security-build restrict-network

build:
	@[ -f ~/.claude.json ] || echo '{}' > ~/.claude.json
	@touch ~/.claude_dev_bash_history
	HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) $(COMPOSE) build dev

# Dockerfile.security is FROM claude-dev:latest, so the base image must exist first.
build-security: build
	$(COMPOSE) build dev-security

run: restrict-network
	HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) $(COMPOSE) run --rm dev

run-no-restrictions:
	HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) $(COMPOSE) run --rm dev

# Rebuilds (cheap after the first run, thanks to layer caching) then runs the
# security image — Python 3.7 legacy toolchain + syft, on top of the base image.
run-security-build: build-security restrict-network
	$(COMPOSE) run --rm dev-security
# Apply host-level iptables rules that block the container from reaching
# our VPCs/VPN (10.0.0.0/8) and the AWS IMDS.
# Deliberately does NOT block 172.16.0.0/12 or 192.168.0.0/16 — none of our
# VPCs live there, and blocking them collides with infra that legitimately
# uses those ranges (e.g. Docker Desktop's own DNS resolver on macOS is
# 192.168.65.7, set as a dns: entry in docker-compose.yml).
# Called automatically by `make run` so rules are always active, even after a
# Docker Desktop restart (which clears iptables state in the Linux VM).
# Uses delete-before-insert so running multiple times produces no duplicates.
# On macOS, Docker Desktop runs a Linux VM; nsenter enters that VM's network
# namespace so the iptables commands take effect in the right place.
# The container subnet 172.30.0.0/24 is fixed in docker-compose.yml.
BLOCK_CIDRS := 10.0.0.0/8 169.254.169.254/32
# Add your VPN CIDR here:
# BLOCK_CIDRS += 100.64.0.0/10
restrict-network:
	@echo "Applying iptables isolation rules for br-claude-dev (172.30.0.0/24)..."
	docker run --privileged --pid=host --net=host --rm alpine \
	  nsenter -t 1 -m -u -i -n -- sh -c ' \
	    for cidr in $(BLOCK_CIDRS); do \
	      iptables -D DOCKER-USER -s 172.30.0.0/24 -d $$cidr -j DROP 2>/dev/null || true; \
	      iptables -I DOCKER-USER -s 172.30.0.0/24 -d $$cidr -j DROP; \
	    done; \
	    echo "Done. Current DOCKER-USER rules:"; \
	    iptables -L DOCKER-USER -n --line-numbers'
