#!/bin/bash
#
# Go Development Startup Script
#
# Features:
# - Auto-detects go.mod changes and runs go mod tidy
# - Uses air for hot reload if available, falls back to go run
# - Builds and runs on port 8080
#

set -euo pipefail

HASH_FILE=".deps_hash"
CURRENT_HASH=$(sha256sum go.mod go.sum 2>/dev/null | sha256sum | cut -d' ' -f1 || echo "none")
STORED_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "")

# Update dependencies if changed
if [ "$CURRENT_HASH" != "$STORED_HASH" ]; then
    echo "Updating Go dependencies..."
    go mod tidy
    echo "$CURRENT_HASH" > "$HASH_FILE"
fi

USE_AIR=false
if command -v air &> /dev/null; then
    USE_AIR=true
fi

ensure_air_config() {
    if [ ! -f ".air.toml" ]; then
        cat > .air.toml << 'EOF'
[build]
cmd = "go build -o ./tmp/main ."
bin = "./tmp/main"
include_ext = ["go", "tpl", "tmpl", "html"]
exclude_dir = ["tmp", "vendor"]
EOF
    fi
}

start_server() {
    if [ "$USE_AIR" = "true" ]; then
        echo "Starting with air (hot reload)..."
        ensure_air_config
        air &
    else
        echo "Starting with go run (no hot reload)..."
        echo "Tip: Install air for hot reload: go install github.com/air-verse/air@latest"
        go run . &
    fi
    echo $! > .server_pid
}

stop_server() {
    if [ -f ".server_pid" ]; then
        local pid
        pid=$(cat .server_pid 2>/dev/null || echo "")
        if [ -n "$pid" ]; then
            kill "$pid" 2>/dev/null || true
        fi
        rm -f .server_pid
    fi
}

SYNC_INTERVAL="${GITHUB_SYNC_INTERVAL:-15}"
SYNC_INTERVAL="${SYNC_INTERVAL%.*}"
if [ -z "$SYNC_INTERVAL" ]; then
    SYNC_INTERVAL="15"
fi

trap 'stop_server; exit 0' INT TERM

start_server

# Loop forever:
# - If go.mod/go.sum changes: go mod tidy + restart server
# - If server dies: restart it
while true; do
    sleep "$SYNC_INTERVAL"

    # Restart if server died
    if [ -f ".server_pid" ]; then
        pid=$(cat .server_pid 2>/dev/null || echo "")
        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
            echo "Go server exited; restarting..."
            rm -f .server_pid
            start_server
        fi
    fi

    CURRENT_HASH=$(sha256sum go.mod go.sum 2>/dev/null | sha256sum | cut -d' ' -f1 || echo "none")
    STORED_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "")
    if [ "$CURRENT_HASH" != "$STORED_HASH" ]; then
        echo "go.mod/go.sum changed; running go mod tidy and restarting..."
        go mod tidy
        echo "$CURRENT_HASH" > "$HASH_FILE"
        stop_server
        start_server
    fi
done
