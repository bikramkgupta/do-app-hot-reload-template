# =============================================================================
# DigitalOcean App Platform Development Container
# =============================================================================

# =============================================================================
# Stage 1: Build health server and welcome page server from source
# =============================================================================
FROM golang:1.23-alpine AS health-builder
COPY hot-reload-template/scripts/dev-health-server/main.go /build/health/
COPY hot-reload-template/scripts/welcome-page-server/main.go /build/welcome/
RUN cd /build/health && go build -ldflags="-s -w" -o dev-health-server main.go && \
    cd /build/welcome && go build -ldflags="-s -w" -o welcome-page-server main.go

# =============================================================================
# Stage 2: Main development container
# =============================================================================
# Base image with Ubuntu 24.04
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# =============================================================================
# Build-time Arguments (Runtime/Language Versions)
# =============================================================================
# These ARG values can be overridden during build:
#   - Local builds: docker build --build-arg INSTALL_NODE=false ...
#   - App Platform: Set in app.yaml under 'build_args' section
#   - App Platform UI: Configure in "Build Arguments" during deployment
# =============================================================================
ARG INSTALL_NODE=false
ARG NODE_VERSIONS="24 22"
ARG NODE_DEFAULT_VERSION=24

ARG INSTALL_PYTHON=false
ARG PYTHON_VERSIONS="3.12 3.13"
ARG PYTHON_DEFAULT_VERSION=3.13

ARG INSTALL_GOLANG=false
ARG GOLANG_VERSION=1.23.4

ARG INSTALL_RUST=false

ARG INSTALL_RUBY=false
ARG RUBY_VERSIONS="3.4.7 3.3.6"
ARG DEFAULT_RUBY="3.4.7"

ARG INSTALL_POSTGRES=true
ARG INSTALL_MONGODB=false
ARG INSTALL_MYSQL=false
ARG MONGOSH_VERSION=8.0

# GitHub repo sync configuration
ARG GITHUB_REPO_URL=""
ARG WORKSPACE_PATH=/workspaces/app
ARG GITHUB_SYNC_INTERVAL=15

# =============================================================================
# Install base system dependencies
# =============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    unzip \
    jq \
    less \
    procps \
    build-essential \
    netcat-openbsd \
    iputils-ping \
    wget \
    software-properties-common \
    sudo \
    pkg-config \
    libssl-dev \
    cmake \
    zlib1g-dev \
    rsync \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# =============================================================================
# Install Node.js via NVM (if enabled)
# =============================================================================
RUN if [ "$INSTALL_NODE" = "true" ]; then \
        NVM_VERSION=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r .tag_name) && \
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh | bash \
        && export NVM_DIR="/root/.nvm" \
        && . "$NVM_DIR/nvm.sh" \
        && for version in $NODE_VERSIONS; do \
            nvm install $version; \
        done \
        && nvm alias default ${NODE_DEFAULT_VERSION} \
        && nvm use default \
        && echo "export NVM_DIR=\"\$HOME/.nvm\"" >> /etc/profile.d/nvm.sh \
        && echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"' >> /etc/profile.d/nvm.sh; \
    fi

# Set Node environment variables globally
ENV NVM_DIR=/root/.nvm

# =============================================================================
# Install Python via UV (if enabled)
# =============================================================================
RUN if [ "$INSTALL_PYTHON" = "true" ]; then \
        curl -LsSf https://astral.sh/uv/install.sh | sh \
        && export PATH="/root/.local/bin:$PATH" \
        && for version in $PYTHON_VERSIONS; do \
            uv python install $version; \
        done \
        && uv python pin $PYTHON_DEFAULT_VERSION; \
    fi

# Set UV and Python environment variables
ENV PATH=/root/.local/bin:$PATH

# =============================================================================
# Install Golang (if enabled)
# =============================================================================
RUN if [ "$INSTALL_GOLANG" = "true" ]; then \
        arch="$(uname -m)"; \
        case "$arch" in \
            x86_64) GO_ARCH="amd64" ;; \
            aarch64|arm64) GO_ARCH="arm64" ;; \
            *) GO_ARCH="amd64" ;; \
        esac && \
        wget -q "https://go.dev/dl/go${GOLANG_VERSION}.linux-${GO_ARCH}.tar.gz" -O /tmp/go.tar.gz \
        && rm -rf /usr/local/go \
        && tar -C /usr/local -xzf /tmp/go.tar.gz \
        && rm /tmp/go.tar.gz; \
    fi

# Set Go environment variables
ENV PATH=/usr/local/go/bin:$PATH
ENV GOPATH=/go
ENV PATH=$GOPATH/bin:$PATH

# =============================================================================
# Install Rust via rustup (if enabled)
# =============================================================================
RUN if [ "$INSTALL_RUST" = "true" ]; then \
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
        && . "$HOME/.cargo/env"; \
    fi

# Set Rust environment variables
ENV PATH=/root/.cargo/bin:$PATH

# =============================================================================
# Install Ruby build dependencies (if enabled) - Ruby itself installed as devcontainer user
# =============================================================================
RUN if [ "$INSTALL_RUBY" = "true" ]; then \
        apt-get update && apt-get install -y --no-install-recommends \
            libreadline-dev \
            libyaml-dev \
            libz-dev \
            libffi-dev \
            libssl-dev \
        && rm -rf /var/lib/apt/lists/*; \
    fi

# =============================================================================
# Install CLI Tools - always latest
# =============================================================================
# DigitalOcean CLI (doctl)
RUN arch="$(uname -m)"; \
    case "$arch" in \
        x86_64) DOCTL_ARCH="linux-amd64" ;; \
        aarch64|arm64) DOCTL_ARCH="linux-arm64" ;; \
        *) DOCTL_ARCH="linux-amd64" ;; \
    esac && \
    tmpdir="$(mktemp -d)" && \
    DOCTL_VERSION=$(curl -s https://api.github.com/repos/digitalocean/doctl/releases/latest | jq -r .tag_name) && \
    DOCTL_VERSION_CLEAN=$(echo "$DOCTL_VERSION" | sed 's/^v//') && \
    curl -fsSL "https://github.com/digitalocean/doctl/releases/download/${DOCTL_VERSION}/doctl-${DOCTL_VERSION_CLEAN}-${DOCTL_ARCH}.tar.gz" \
        | tar -xz -C "$tmpdir" && \
    install -m 0755 "$tmpdir/doctl" /usr/local/bin/doctl && \
    rm -rf "$tmpdir"

# GitHub CLI (gh)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# =============================================================================
# Install Database Clients (optional)
# =============================================================================
# Install PostgreSQL client (if enabled)
RUN if [ "$INSTALL_POSTGRES" = "true" ]; then \
        apt-get update \
        && apt-get install -y --no-install-recommends postgresql-client \
        && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*; \
    fi

# Install MySQL client (if enabled)
RUN if [ "$INSTALL_MYSQL" = "true" ]; then \
        apt-get update \
        && apt-get install -y --no-install-recommends mysql-client \
        && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*; \
    fi

# Install MongoDB shell (mongosh) (if enabled)
RUN if [ "$INSTALL_MONGODB" = "true" ]; then \
        apt-get update \
        && apt-get install -y --no-install-recommends gnupg \
        && curl -fsSL "https://www.mongodb.org/static/pgp/server-${MONGOSH_VERSION}.asc" | gpg -o "/usr/share/keyrings/mongodb-server-${MONGOSH_VERSION}.gpg" --dearmor \
        && echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-${MONGOSH_VERSION}.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/${MONGOSH_VERSION} multiverse" | tee /etc/apt/sources.list.d/mongodb-org-${MONGOSH_VERSION}.list \
        && apt-get update \
        && apt-get install -y mongodb-mongosh \
        && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*; \
    fi


# =============================================================================
# Create devcontainer user and set up environment
# =============================================================================
RUN useradd -ms /bin/bash devcontainer \
    && echo "devcontainer ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Copy runtime configurations to devcontainer user
RUN if [ "$INSTALL_NODE" = "true" ]; then \
        cp -r /root/.nvm /home/devcontainer/.nvm \
        && chown -R devcontainer:devcontainer /home/devcontainer/.nvm; \
    fi

RUN if [ "$INSTALL_PYTHON" = "true" ]; then \
        cp -r /root/.local /home/devcontainer/.local \
        && chown -R devcontainer:devcontainer /home/devcontainer/.local; \
    fi

RUN if [ "$INSTALL_RUST" = "true" ]; then \
        cp -r /root/.cargo /home/devcontainer/.cargo \
        && cp -r /root/.rustup /home/devcontainer/.rustup \
        && chown -R devcontainer:devcontainer /home/devcontainer/.cargo /home/devcontainer/.rustup; \
    fi

# Switch to devcontainer user
USER devcontainer
WORKDIR /workspaces/app

# =============================================================================
# Set up shell environment for devcontainer user
# =============================================================================
# Node.js (NVM)
RUN if [ "$INSTALL_NODE" = "true" ]; then \
        echo 'export NVM_DIR="$HOME/.nvm"' >> /home/devcontainer/.bashrc \
        && echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"' >> /home/devcontainer/.bashrc \
        && echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"' >> /home/devcontainer/.bashrc; \
    fi

# Python (UV)
RUN if [ "$INSTALL_PYTHON" = "true" ]; then \
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> /home/devcontainer/.bashrc \
        && echo 'eval "$(uv generate-shell-completion bash)"' >> /home/devcontainer/.bashrc; \
    fi

# Golang
RUN if [ "$INSTALL_GOLANG" = "true" ]; then \
        echo 'export PATH="/usr/local/go/bin:$PATH"' >> /home/devcontainer/.bashrc \
        && echo 'export GOPATH="$HOME/go"' >> /home/devcontainer/.bashrc \
        && echo 'export PATH="$GOPATH/bin:$PATH"' >> /home/devcontainer/.bashrc; \
    fi

# Rust
RUN if [ "$INSTALL_RUST" = "true" ]; then \
        echo 'source "$HOME/.cargo/env"' >> /home/devcontainer/.bashrc; \
    fi

# Ruby (rbenv) - Install directly as devcontainer user (Ruby binaries have hardcoded paths)
RUN if [ "$INSTALL_RUBY" = "true" ]; then \
        git clone https://github.com/rbenv/rbenv.git ~/.rbenv \
        && git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build \
        && cd ~/.rbenv && src/configure && make -C src \
        && export PATH="$HOME/.rbenv/bin:$PATH" \
        && eval "$(~/.rbenv/bin/rbenv init - bash)" \
        && ~/.rbenv/bin/rbenv install 3.4.7 \
        && ~/.rbenv/bin/rbenv global 3.4.7 \
        && ~/.rbenv/bin/rbenv rehash \
        && echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc \
        && echo 'eval "$(rbenv init - bash)"' >> ~/.bashrc; \
    fi

# doctl completion
RUN echo 'source <(doctl completion bash)' >> /home/devcontainer/.bashrc

# Update devcontainer user's environment variables
ENV NVM_DIR=/home/devcontainer/.nvm
ENV RBENV_ROOT=/home/devcontainer/.rbenv
ENV PATH=/home/devcontainer/.rbenv/shims:/home/devcontainer/.rbenv/bin:/home/devcontainer/.local/bin:/usr/local/go/bin:/home/devcontainer/.cargo/bin:$PATH

# =============================================================================
# Add GitHub sync and health check scripts
# =============================================================================
USER root

# GitHub sync script
COPY --chown=devcontainer:devcontainer hot-reload-template/scripts/github-sync.sh /usr/local/bin/github-sync.sh
RUN chmod +x /usr/local/bin/github-sync.sh

# Startup script
COPY --chown=devcontainer:devcontainer hot-reload-template/scripts/startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

# Job manager script
COPY --chown=devcontainer:devcontainer hot-reload-template/scripts/job-manager.sh /usr/local/bin/job-manager.sh
RUN chmod +x /usr/local/bin/job-manager.sh

# Dev health check server (built from source in stage 1)
COPY --from=health-builder /build/health/dev-health-server /usr/local/bin/dev-health-server
RUN chmod +x /usr/local/bin/dev-health-server

# Welcome page server (built from source in stage 1)
COPY --from=health-builder /build/welcome/welcome-page-server /usr/local/bin/welcome-page-server
RUN chmod +x /usr/local/bin/welcome-page-server

USER devcontainer

# Set environment variables for GitHub sync
ENV GITHUB_REPO_URL=${GITHUB_REPO_URL}
ENV WORKSPACE_PATH=${WORKSPACE_PATH}
ENV GITHUB_SYNC_INTERVAL=${GITHUB_SYNC_INTERVAL}

# Expose health check port
EXPOSE 8080

# Run startup script
CMD ["/usr/local/bin/startup.sh"]
