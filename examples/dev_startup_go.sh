#!/bin/bash
#
# Go Development Startup Script
#
# Features:
# - Auto-detects go.mod changes and runs go mod tidy
# - Uses air for hot reload if available, falls back to go run
# - Builds and runs on port 8080
#

set -e

HASH_FILE=".deps_hash"
CURRENT_HASH=$(sha256sum go.mod go.sum 2>/dev/null | sha256sum | cut -d' ' -f1 || echo "none")
STORED_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "")

# Update dependencies if changed
if [ "$CURRENT_HASH" != "$STORED_HASH" ]; then
    echo "Updating Go dependencies..."
    go mod tidy
    echo "$CURRENT_HASH" > "$HASH_FILE"
fi

# Check if air is available for hot reload
if command -v air &> /dev/null; then
    echo "Starting with air (hot reload)..."
    # Create air config if not exists
    if [ ! -f ".air.toml" ]; then
        cat > .air.toml << 'EOF'
[build]
cmd = "go build -o ./tmp/main ."
bin = "./tmp/main"
include_ext = ["go", "tpl", "tmpl", "html"]
exclude_dir = ["tmp", "vendor"]
EOF
    fi
    exec air
else
    echo "Starting with go run (no hot reload)..."
    echo "Tip: Install air for hot reload: go install github.com/air-verse/air@latest"
    exec go run .
fi
