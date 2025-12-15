#!/bin/bash
#
# Next.js / Node.js Development Startup Script
#
# Features:
# - Handles npm install with legacy-peer-deps for compatibility
# - Auto-detects package.json changes and reinstalls
# - Falls back to hard rebuild if install fails
#

set -e

# Create .npmrc for peer dependency compatibility
echo "legacy-peer-deps=true" > .npmrc

# Track if we need to reinstall
HASH_FILE=".deps_hash"
CURRENT_HASH=$(sha256sum package.json 2>/dev/null | cut -d' ' -f1 || echo "none")
STORED_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "")

install_deps() {
    echo "Installing dependencies..."
    if ! npm install; then
        echo "Standard install failed, trying hard rebuild..."
        rm -rf node_modules package-lock.json
        npm install
    fi
    echo "$CURRENT_HASH" > "$HASH_FILE"
}

# Install if hash changed or node_modules missing
if [ "$CURRENT_HASH" != "$STORED_HASH" ] || [ ! -d "node_modules" ]; then
    install_deps
fi

# Start the dev server
# --hostname 0.0.0.0 makes it accessible from outside the container
# --port 8080 is required for DO App Platform
exec npm run dev -- --hostname 0.0.0.0 --port 8080
