# Claude Dev Container

Claude Code in a locked-down container. Only `~/git` is mounted — no home
directory, no AWS credentials, no other host secrets.

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

Add a shell alias for convenience:

```sh
alias cdev='HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose -f ~/git/claude-dev-container/docker-compose.yml run --rm dev'
```

Then just run `cdev` from anywhere.

## Notes

- **Billing**: sessions draw from your existing claude.ai subscription, not a
  separate API account.
- **Auth persistence**: `~/.claude` and `~/.claude.json` are mounted from your
  host so your login survives container restarts.
- **File ownership**: built with your UID/GID so files Claude creates are owned
  by you on the host. No `sudo chown` needed.
- **Not mounted**: `~/.aws`, `~/.ssh`, `~/.config`, your home directory, and
  any credential files — none of these are accessible inside the container.

## Rebuilding after Dockerfile changes

```sh
HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose build --no-cache
```
