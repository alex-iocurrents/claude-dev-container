# Claude Dev Container

Claude Code in a locked-down container. Only `~/git` is mounted — no home
directory, no AWS credentials, no SSH keys.

Uses your existing claude.ai subscription for billing. No API key required.

## Prerequisites

- Docker Desktop (Mac)
- A claude.ai subscription (Pro, Max, or Team/Enterprise)

## Setup

1. Create the Claude Code config file on your host (must exist before first run
   or Docker will create it as a directory instead of a file):

   ```sh
   echo '{}' > ~/.claude.json
   ```

2. Build the image (once, or after Dockerfile changes):

   ```sh
   HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose build
   ```

3. Start a session:

   ```sh
   HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose run --rm dev
   ```

4. On first run, Claude Code will prompt you to authenticate via browser.
   Follow the URL it prints. Auth is saved to `~/.claude` and `~/.claude.json`
   on your host and reused on subsequent sessions — you won't be asked again
   unless you explicitly log out.

Add a shell alias for convenience, replacing the path with wherever you cloned this
repo:

```sh
alias cdev='HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose -f ~/git/claude-dev-container/docker-compose.yml run --rm dev'
```

Then just run `cdev` from anywhere.

### tmux users: use `-i` instead of `-t`

`docker compose run` allocates a PTY (`-t`) by default, which is the right choice
for most terminals. However, if you run this container inside a **tmux session**,
the nested PTY prevents tmux from capturing output in its scrollback buffer —
`Prefix + [` will show `[0/0]` and you cannot scroll back through Claude's output.

The fix is to pass `-T` to `docker compose run`, which disables PTY allocation and
lets tmux own the terminal:

```sh
alias cdev='HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose -f ~/git/claude-dev-container/docker-compose.yml run --rm -T dev'
```

tmux then captures all output normally and scrollback works as expected. Colors and
interactivity are preserved because tmux itself provides the PTY.

## Notes

- **Billing**: sessions draw from your existing claude.ai subscription, not a
  separate API account.
- **Auth persistence**: `~/.claude` and `~/.claude.json` are mounted from your
  host so your login survives container restarts.
- **File ownership**: built with your UID/GID so files Claude creates are owned
  by you on the host. No `sudo chown` needed.
- **Not mounted**: `~/.aws`, `~/.ssh`, `~/.config`, your home directory, and
  any credential files — none of these are accessible inside the container.

## Known gap: secrets inside repo directories

Because the entire `~/git` tree is mounted, any `.gitignore`d secret files that
live inside a repo directory (e.g. `config/config.py`, `.secrets`, `database.ini`)
are accessible to Claude Code inside the container.

The `.dockerignore` in this repo prevents these patterns from being baked into the
image, but it does not protect against the volume mount.

The proper fix is to move secrets out of the repo tree entirely — for example into
`~/.config/ioc/<service>/` or a secrets manager — and have repos reference them by
path or environment variable. Until that migration is done, treat the container as
having the same secret access as your local shell.

## Rebuilding after Dockerfile changes

```sh
HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose build --no-cache
```
