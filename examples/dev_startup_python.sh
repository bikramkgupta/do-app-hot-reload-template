#!/bin/bash
#
# Python / FastAPI Development Startup Script
#
# Features:
# - Uses uv for fast dependency management (falls back to pip)
# - Auto-detects requirements changes and reinstalls (polls every GITHUB_SYNC_INTERVAL seconds)
# - Runs uvicorn with --reload for hot reload
#
# For subfolder apps, set APP_DIR in your app spec:
#   APP_DIR=/workspaces/app/application
#

set -euo pipefail

# Change to app directory (defaults to current dir, set APP_DIR for subfolders)
APP_DIR="${APP_DIR:-$(pwd)}"
cd "$APP_DIR" || exit 1

HASH_FILE=".deps_hash"

# Detect dependency file
if [ -f "pyproject.toml" ]; then
    DEPS_FILE="pyproject.toml"
elif [ -f "requirements.txt" ]; then
    DEPS_FILE="requirements.txt"
else
    echo "No pyproject.toml or requirements.txt found"
    exit 1
fi

CURRENT_HASH=$(sha256sum "$DEPS_FILE" 2>/dev/null | cut -d' ' -f1 || echo "none")
STORED_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "")

install_deps() {
    echo "Installing dependencies..."
    if command -v uv &> /dev/null; then
        # Use uv if available (much faster)
        if [ -f "pyproject.toml" ]; then
            uv sync
        else
            uv pip install -r requirements.txt
        fi
    else
        # Fall back to pip
        pip install -r requirements.txt 2>/dev/null || pip install -e .
    fi
    echo "$CURRENT_HASH" > "$HASH_FILE"
}

# Install if hash changed
if [ "$CURRENT_HASH" != "$STORED_HASH" ]; then
    install_deps
fi

start_server() {
    echo "Starting uvicorn dev server..."
    uvicorn main:app --host 0.0.0.0 --port 8080 --reload &
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
# - If deps file changes: reinstall + restart server
# - If server dies: restart it
while true; do
    sleep "$SYNC_INTERVAL"

    # Restart if server died
    if [ -f ".server_pid" ]; then
        pid=$(cat .server_pid 2>/dev/null || echo "")
        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
            echo "Uvicorn exited; restarting..."
            rm -f .server_pid
            start_server
        fi
    fi

    CURRENT_HASH=$(sha256sum "$DEPS_FILE" 2>/dev/null | cut -d' ' -f1 || echo "none")
    STORED_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "")
    if [ "$CURRENT_HASH" != "$STORED_HASH" ]; then
        echo "$DEPS_FILE changed; reinstalling deps and restarting server..."
        install_deps
        stop_server
        start_server
    fi
done
