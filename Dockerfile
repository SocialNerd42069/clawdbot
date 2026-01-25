FROM node:22-bookworm

# Install Bun (required for build scripts)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

ARG CLAWDBOT_DOCKER_APT_PACKAGES=""
RUN if [ -n "$CLAWDBOT_DOCKER_APT_PACKAGES" ]; then \
      apt-get update && \
      DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $CLAWDBOT_DOCKER_APT_PACKAGES && \
      apt-get clean && \
      rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*; \
    fi

# Bake required binaries into image (critical for persistence)
# GitHub CLI
RUN curl -fsSL https://github.com/cli/cli/releases/download/v2.86.0/gh_2.86.0_linux_amd64.tar.gz | \
    tar -xz --strip-components=1 -C /tmp && \
    mv /tmp/bin/gh /usr/local/bin/gh && \
    chmod +x /usr/local/bin/gh && \
    rm -rf /tmp/bin /tmp/etc

# Gmail CLI (gogcli) - binary is 'gog' inside tarball
RUN curl -fsSL https://github.com/steipete/gogcli/releases/download/v0.9.0/gogcli_0.9.0_linux_amd64.tar.gz | \
    tar -xz -C /tmp && \
    mv /tmp/gog /usr/local/bin/gog && \
    chmod +x /usr/local/bin/gog && \
    rm -rf /tmp/gog /tmp/CHANGELOG.md /tmp/LICENSE /tmp/README.md

# Google Places CLI (goplaces)
RUN curl -fsSL https://github.com/steipete/goplaces/releases/download/v0.2.1/goplaces_0.2.1_linux_amd64.tar.gz | \
    tar -xz -C /usr/local/bin && chmod +x /usr/local/bin/goplaces

# SSH (for git operations)
RUN apt-get update && apt-get install -y openssh-client && rm -rf /var/lib/apt/lists/*

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY ui/package.json ./ui/package.json
COPY patches ./patches
COPY scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY . .
RUN pnpm build
# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV CLAWDBOT_PREFER_PNPM=1
RUN pnpm ui:install
RUN pnpm ui:build

ENV NODE_ENV=production

CMD ["node","dist/index.js"]
