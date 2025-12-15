#!/bin/bash
#
# Ruby on Rails Development Startup Script
#
# Features:
# - Auto-detects Gemfile changes and runs bundle install
# - Runs database migrations
# - Starts Rails server on port 8080
#

set -e

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

# Run migrations (creates db if needed)
echo "Running database migrations..."
bundle exec rails db:prepare 2>/dev/null || bundle exec rails db:migrate

# Start the Rails server
# -b 0.0.0.0 makes it accessible from outside the container
# -p 8080 is required for DO App Platform
exec bundle exec rails server -b 0.0.0.0 -p 8080
