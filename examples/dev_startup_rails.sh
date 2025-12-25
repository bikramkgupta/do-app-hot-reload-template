#!/bin/bash
#
# Ruby on Rails Development Startup Script
#
# Features:
# - Auto-detects Gemfile changes and runs bundle install
# - Runs database migrations
# - Starts Rails server on port 8080
#

set -euo pipefail

HASH_FILE=".deps_hash"
CURRENT_HASH=$(sha256sum Gemfile Gemfile.lock 2>/dev/null | sha256sum | cut -d' ' -f1 || echo "none")
STORED_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "")

install_deps() {
    echo "Installing gems..."
    if ! bundle install; then
        echo "Standard install failed, trying hard rebuild..."
        rm -rf vendor/bundle Gemfile.lock
        bundle install
    fi
    echo "$CURRENT_HASH" > "$HASH_FILE"
}

# Install if hash changed
if [ "$CURRENT_HASH" != "$STORED_HASH" ]; then
    install_deps
fi

run_migrations() {
    echo "Running database migrations..."
    bundle exec rails db:prepare 2>/dev/null || bundle exec rails db:migrate
}

start_server() {
    echo "Starting Rails server..."
    bundle exec rails server -b 0.0.0.0 -p 8080 &
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

run_migrations
start_server

# Loop forever:
# - If Gemfile/Gemfile.lock changes: bundle install + migrations + restart server
# - If server dies: restart it
while true; do
    sleep "$SYNC_INTERVAL"

    # Restart if server died
    if [ -f ".server_pid" ]; then
        pid=$(cat .server_pid 2>/dev/null || echo "")
        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
            echo "Rails server exited; restarting..."
            rm -f .server_pid
            start_server
        fi
    fi

    CURRENT_HASH=$(sha256sum Gemfile Gemfile.lock 2>/dev/null | sha256sum | cut -d' ' -f1 || echo "none")
    STORED_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "")
    if [ "$CURRENT_HASH" != "$STORED_HASH" ]; then
        echo "Gemfile/Gemfile.lock changed; installing gems and restarting..."
        install_deps
        run_migrations
        stop_server
        start_server
    fi
done
