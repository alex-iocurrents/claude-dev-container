FROM node:22-slim

RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set WORKDIR before installing Claude Code to limit filesystem scan
WORKDIR /tmp
RUN npm install -g @anthropic-ai/claude-code

# Create a non-root user matching your host UID/GID so file ownership is correct.
# Build with: HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose build
ARG HOST_UID=501
ARG HOST_GID=20

RUN groupadd -g ${HOST_GID} devgroup 2>/dev/null || true \
 && useradd -m -u ${HOST_UID} -g ${HOST_GID} -s /bin/bash devuser

WORKDIR /workspace
RUN chown ${HOST_UID}:${HOST_GID} /workspace

USER devuser

CMD ["bash"]
