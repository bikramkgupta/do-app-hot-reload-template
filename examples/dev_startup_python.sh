#!/bin/bash
#
# Python / FastAPI Development Startup Script
#
# Features:
# - Uses uv for fast dependency management (falls back to pip)
# - Auto-detects requirements changes and reinstalls
# - Runs uvicorn with --reload for hot reload
#

set -e

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

# Start the dev server
# --reload enables hot reload
# --host 0.0.0.0 makes it accessible from outside the container
# --port 8080 is required for DO App Platform
exec uvicorn main:app --host 0.0.0.0 --port 8080 --reload
