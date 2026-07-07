HOST_UID := $(shell id -u)
HOST_GID := $(shell id -g)
COMPOSE := docker compose -f $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))/docker-compose.yml

.PHONY: build run restrict-network

build:
	@[ -f ~/.claude.json ] || echo '{}' > ~/.claude.json
	@touch ~/.claude_dev_bash_history
	HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) $(COMPOSE) build

run: restrict-network
	HOST_UID=$(HOST_UID) HOST_GID=$(HOST_GID) $(COMPOSE) run --rm dev

# Apply host-level iptables rules that block the container from reaching
# RFC 1918 ranges (VPN/VPC) and the AWS IMDS.
# Called automatically by `make run` so rules are always active, even after a
# Docker Desktop restart (which clears iptables state in the Linux VM).
# Uses delete-before-insert so running multiple times produces no duplicates.
# On macOS, Docker Desktop runs a Linux VM; nsenter enters that VM's network
# namespace so the iptables commands take effect in the right place.
# The container subnet 172.30.0.0/24 is fixed in docker-compose.yml.
BLOCK_CIDRS := 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 169.254.169.254/32
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
