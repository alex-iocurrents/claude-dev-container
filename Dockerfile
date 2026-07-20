FROM node:22-slim

RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    jq \
    shellcheck \
    python3 \
    python3-pip \
    python3.11-venv \
    unzip \
    ripgrep \
    postgresql-client \
    postgresql \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --break-system-packages csvkit ansible ruff pytest 'litellm[proxy]' \
    && curl -LsSf https://astral.sh/uv/install.sh | UV_INSTALL_DIR=/usr/local/bin sh

# Terraform — pinned to 1.9.8, compatible with ~> 1.6 and ~> 1.7 in iocurrents-services
RUN TERRAFORM_VERSION=1.9.8 \
    && ARCH=$(dpkg --print-architecture) \
    && curl -sSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" \
       -o /tmp/terraform.zip \
    && unzip -q /tmp/terraform.zip -d /usr/local/bin \
    && rm /tmp/terraform.zip

# Set WORKDIR before installing Claude Code to limit filesystem scan
WORKDIR /tmp
RUN npm install -g @anthropic-ai/claude-code pyright

# Create a non-root user matching your host UID/GID so file ownership is correct.
# Build with: HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose build
ARG HOST_UID=501
ARG HOST_GID=20

RUN groupadd -g ${HOST_GID} devgroup 2>/dev/null || true \
 && useradd -m -u ${HOST_UID} -g ${HOST_GID} -s /bin/bash devuser

WORKDIR /workspace
RUN chown ${HOST_UID}:${HOST_GID} /workspace

# devuser is non-root, so the Debian postgresql package's own cluster (owned
# by the postgres system user, managed via pg_ctlcluster/systemd) isn't
# directly usable. Give devuser their own data directory so they can run
# initdb/pg_ctl themselves without sudo, e.g.:
#   /usr/lib/postgresql/*/bin/initdb -D ~/pgdata
#   /usr/lib/postgresql/*/bin/pg_ctl -D ~/pgdata -l ~/pgdata/log start
RUN mkdir -p /home/devuser/pgdata && chown ${HOST_UID}:${HOST_GID} /home/devuser/pgdata

USER devuser

CMD ["bash"]
