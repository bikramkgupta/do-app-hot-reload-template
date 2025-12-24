#!/bin/bash
#
# Next.js Production-Mode Startup Script (optimized runtime)
#
# How it works:
# - Installs deps when package.json changes
# - Runs `npm run build` when source/config changes
# - Runs `npm run start` on port 8080
# - Watches for changes and rebuilds + restarts the server
#
# Notes:
# - This is NOT HMR. It is “rebuild & restart on change”.
# - It can be slower to iterate than `next dev`, but runtime can be closer to production.
#

set -e

echo "legacy-peer-deps=true" > .npmrc

# Dependency install tracking
DEPS_HASH_FILE=".deps_hash"
CURRENT_DEPS_HASH=$(sha256sum package.json 2>/dev/null | cut -d' ' -f1 || echo "none")
STORED_DEPS_HASH=$(cat "$DEPS_HASH_FILE" 2>/dev/null || echo "")

install_deps() {
    echo "Installing dependencies..."
    if ! npm install; then
        echo "Standard install failed, trying hard rebuild..."
        rm -rf node_modules package-lock.json
        npm install
    fi
    echo "$CURRENT_DEPS_HASH" > "$DEPS_HASH_FILE"
}

# Install if hash changed or node_modules missing
if [ "$CURRENT_DEPS_HASH" != "$STORED_DEPS_HASH" ] || [ ! -d "node_modules" ]; then
    install_deps
fi

# Build tracking
BUILD_HASH_FILE=".build_hash"

compute_build_hash() {
    # Include src/ plus common Next.js config files
    local parts=""

    if [ -d "src" ]; then
        local src_files
        src_files=$(find src -type f 2>/dev/null | sort || true)
        if [ -n "$src_files" ]; then
            local src_hash
            src_hash=$(echo "$src_files" | xargs sha256sum 2>/dev/null | sha256sum | cut -d' ' -f1 || echo "")
            parts="${parts}${src_hash}"
        fi
    fi

    for f in next.config.{js,mjs,ts} tsconfig.json package.json; do
        if [ -f "$f" ]; then
            parts="${parts}$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1 || true)"
        fi
    done

    if [ -n "$parts" ]; then
        echo -n "$parts" | sha256sum | cut -d' ' -f1
    else
        echo "none"
    fi
}

build_if_needed() {
    local current_hash
    current_hash=$(compute_build_hash)
    local stored_hash
    stored_hash=$(cat "$BUILD_HASH_FILE" 2>/dev/null || echo "")

    # Build if changed or .next missing
    if [ "$current_hash" != "$stored_hash" ] || [ ! -d ".next" ]; then
        echo "Building Next.js app (production)..."
        npm run build
        echo "$current_hash" > "$BUILD_HASH_FILE"
    fi
}

start_server() {
    echo "Starting Next.js production server..."
    npm run start -- --hostname 0.0.0.0 --port 8080 &
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

# Main loop: build/start and periodically check for changes
SYNC_INTERVAL="${GITHUB_SYNC_INTERVAL:-15}"
SYNC_INTERVAL="${SYNC_INTERVAL%.*}"
if [ -z "$SYNC_INTERVAL" ]; then
    SYNC_INTERVAL="15"
fi

trap 'stop_server; exit 0' INT TERM

build_if_needed
start_server

while true; do
    sleep "$SYNC_INTERVAL"
    # Re-check deps/build; restart if build changed
    CURRENT_DEPS_HASH=$(sha256sum package.json 2>/dev/null | cut -d' ' -f1 || echo "none")
    STORED_DEPS_HASH=$(cat "$DEPS_HASH_FILE" 2>/dev/null || echo "")
    if [ "$CURRENT_DEPS_HASH" != "$STORED_DEPS_HASH" ]; then
        install_deps
    fi

    local_before=$(cat "$BUILD_HASH_FILE" 2>/dev/null || echo "")
    build_if_needed
    local_after=$(cat "$BUILD_HASH_FILE" 2>/dev/null || echo "")

    if [ "$local_before" != "$local_after" ]; then
        echo "Build changed; restarting production server..."
        stop_server
        start_server
    fi
done


