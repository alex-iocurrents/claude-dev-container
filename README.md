# Claude Dev Container

Claude Code in a locked-down container. Only `~/git` is mounted — no home
directory, no AWS credentials, no SSH keys.

Uses your existing claude.ai subscription for billing. No API key required.

## Prerequisites

- Docker Desktop (Mac)
- A claude.ai subscription (Pro, Max, or Team/Enterprise)

## Setup

1. Build the image:

   ```sh
   make build
   ```

2. Start a session:

   ```sh
   make run
   ```

3. On first run, Claude Code will ask you to authenticate via browser. Follow
   the URL it prints. Auth is saved to `~/.claude` and `~/.claude.json` on your
   host and reused on subsequent sessions — you won't be asked again unless you
   explicitly log out.

## Shell alias

The team's shared dotfiles define a `cdev` alias so you don't have to `cd`
into this repo every time:

```sh
alias cdev='make -C ~/git/claude-dev-container run'
```

Running `cdev` is equivalent to `make run` — it applies the `restrict-network`
iptables rules (see [Network isolation](#network-isolation)) before starting
the container. Don't replace this with a raw `docker compose run` alias; that
would skip `restrict-network` and start the container without the network
isolation.

The alias assumes this repo is checked out at `~/git/claude-dev-container`. If
your clone lives somewhere else, change the `-C` path to match, e.g.:

```sh
alias cdev='make -C /path/to/your/claude-dev-container run'
```

## Notes

- **Billing**: sessions draw from your existing claude.ai subscription, not a
  separate API account.
- **Auth persistence**: `~/.claude` and `~/.claude.json` are mounted from your
  host so your login survives container restarts.
- **File ownership**: built with your UID/GID so files Claude creates are owned
  by you on the host. No `sudo chown` needed.
- **Not mounted**: `~/.aws`, `~/.ssh`, your home directory — not accessible
  inside the container. Exception: `~/.config/jira-sync/credentials` is mounted
  read-only so the jira-sync script can run inside the container.

## Available tools

In addition to the base Node.js environment, the image includes:

| Tool | Purpose |
|------|---------|
| `python3` / `pip3` / `uv` | Python scripting; `python3 -m venv` also works |
| `ansible` | Ansible CLI for infrastructure repo playbooks |
| `ruff` | Python linter / formatter |
| `pyright` | Python type checker |
| `terraform` | Terraform 1.9.8 (compatible with `~> 1.6` and `~> 1.7`) |
| `jq` | JSON filtering and transformation |
| `shellcheck` | Shell script linter |
| `rg` (ripgrep) | Fast file search |
| `psql` | PostgreSQL client (`postgresql-client`) |
| `csvkit` (`csvstat`, `csvcut`, `in2csv`, …) | CSV inspection and transformation |

## Intentionally excluded tools

| Tool | Reason |
|------|--------|
| `aws` (AWS CLI) | No AWS credentials are mounted into the container |
| `gh` (GitHub CLI) | No GitHub credentials are mounted; GitHub automation is handled via GitHub Actions |

## Network isolation

The goal is to allow general internet access (web search, curl) while blocking
access to AWS, VPN-connected VPCs, and RFC 1918 ranges that would be reachable
through a VPN tunnel on the host.

### What the compose file provides

- A **named Docker network** (`claude-dev-net`) with a fixed subnet
  (`172.30.0.0/24`) and a fixed bridge name (`br-claude-dev`). The stable
  names make host-level iptables rules reliable — without them, Docker assigns
  a random bridge name like `br-a1b2c3d4e5f6` on each `docker compose up`,
  breaking any rules you've written.

- `cap_drop: ALL` already drops `NET_ADMIN` and `NET_RAW`, so the container
  **cannot modify its own routing table or inject iptables rules**. It can reach
  whatever the Docker bridge can reach, but it cannot undo any blocks you apply
  at the host level.

### What requires host-level action

Blocking specific destination CIDRs must be done in the Docker host's iptables
`DOCKER-USER` chain, outside the container. `make run` applies the rules
automatically by calling `make restrict-network` before starting the container.

`restrict-network` uses `docker run --privileged --pid=host --net=host` with
`nsenter` to reach the network namespace where Docker's iptables chains live.
This works on both macOS and Linux:

- **macOS**: Docker Desktop runs a Linux VM; `nsenter -t 1` enters that VM's
  network namespace, which is where the `DOCKER-USER` chain lives.
- **Linux**: `nsenter -t 1` enters the host's network namespace — same result.

On both platforms, `make run` calls this target automatically on every session,
so rules are re-applied after a Docker Desktop restart without any manual step.

**nftables caveat (Linux)**: newer distros (Ubuntu 22.04+, Debian 12+) default
to nftables. If Docker is configured to use the nftables backend rather than
the iptables compatibility layer, the `DOCKER-USER` chain won't exist and the
rules will need to be expressed as nftables rules instead. Check with
`sudo iptables -L DOCKER-USER` — if it errors, you're on the nftables path.

```sh
make run   # restrict-network runs automatically before the container starts
```

This blocks the following destinations from `172.30.0.0/24`:

| CIDR | Reason |
|------|--------|
| `10.0.0.0/8` | RFC 1918 / AWS VPC / VPN ranges |
| `172.16.0.0/12` | RFC 1918 |
| `192.168.0.0/16` | RFC 1918 / common VPN ranges |
| `169.254.169.254/32` | AWS instance metadata service (IMDS) |

**To also block your VPN CIDR**, add a line to the `restrict-network` target in
the Makefile:

```makefile
iptables -I DOCKER-USER -s 172.30.0.0/24 -d <YOUR-VPN-CIDR> -j DROP; \
```

### Verifying the rules are active

```sh
docker run --privileged --pid=host --net=host --rm alpine \
  nsenter -t 1 -m -u -i -n -- iptables -L DOCKER-USER -n --line-numbers
```

## Rebuilding after Dockerfile changes

```sh
make build
```

## Known gap: secrets inside repo directories

Because the entire `~/git` tree is mounted, any `.gitignore`d secret files that
live inside a repo directory (e.g. `config/config.py`, `.secrets`, `database.ini`)
are accessible to Claude Code inside the container.

The proper fix is to move secrets out of the repo tree entirely — for example into
`~/.config/<service>/` or a secrets manager — and have repos reference them by
path or environment variable. Until that migration is done, treat the container as
having the same secret access as your local shell.
