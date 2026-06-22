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

2. Create the bash history file on your host:

   ```sh
   touch ~/.claude_dev_bash_history
   ```

3. Build the image (once, or after Dockerfile changes):

   ```sh
   HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose build
   ```

4. Start a session:

   ```sh
   HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose run --rm dev
   ```

5. On first run, Claude Code will prompt you to authenticate via browser.
   Follow the URL it prints. Auth is saved to `~/.claude` and `~/.claude.json`
   on your host and reused on subsequent sessions — you won't be asked again
   unless you explicitly log out.

## Shell function

Add this to your `~/.zshrc`, replacing the path with wherever you cloned this repo:

```sh
function cdev() {
  HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose -f ~/git/claude-dev-container/docker-compose.yml run --rm dev
}
```

Then just run `cdev` from anywhere.

### tmux users

Running `cdev` inside an existing tmux pane mixes the container's scrollback
with your host shell history. Open the container in a fresh tmux window instead:

```sh
function cdev() {
  tmux new-window -n 'claude' 'HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose -f ~/git/claude-dev-container/docker-compose.yml run --rm dev'
}
```

The window closes automatically when you exit the container.

## Notes

- **Billing**: sessions draw from your existing claude.ai subscription, not a
  separate API account.
- **Auth persistence**: `~/.claude` and `~/.claude.json` are mounted from your
  host so your login survives container restarts.
- **File ownership**: built with your UID/GID so files Claude creates are owned
  by you on the host. No `sudo chown` needed.
- **Not mounted**: `~/.aws`, `~/.ssh`, `~/.config`, your home directory, and
  any credential files — none of these are accessible inside the container.

## Gotchas

### First run: corrupted config warning

On first run you will see:

```
Claude configuration file at /home/devuser/.claude.json is corrupted: JSON Parse error: Unexpected EOF
```

This is expected — `echo '{}'` writes a valid but empty config. When prompted,
select **"Reset with default configuration"**. Claude Code will write a valid
config and you won't see this again.

### tmux scrollback (Claude Code alternate screen)

Claude Code uses the alternate screen buffer by default, which prevents tmux
from capturing its output in scrollback. This is a known upstream issue with
multiple open reports on the Claude Code GitHub.

This container disables the alternate screen via
`CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1`, which restores normal tmux scrollback
behavior. If you ever run Claude Code outside this container and hit the same
issue, set that env var in your shell.

## Rebuilding after Dockerfile changes

```sh
HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose build --no-cache
```

## Known gap: secrets inside repo directories

Because the entire `~/git` tree is mounted, any `.gitignore`d secret files that
live inside a repo directory (e.g. `config/config.py`, `.secrets`, `database.ini`)
are accessible to Claude Code inside the container.

The proper fix is to move secrets out of the repo tree entirely — for example into
`~/.config/<service>/` or a secrets manager — and have repos reference them by
path or environment variable. Until that migration is done, treat the container as
having the same secret access as your local shell.
