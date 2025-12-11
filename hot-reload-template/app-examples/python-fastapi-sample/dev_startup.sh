#!/usr/bin/env bash
#
# Python FastAPI Application Development Startup Script
# ======================================================
#
# WHAT IT DOES:
# This script provides automatic hot-reload functionality for Python FastAPI
# applications in a development environment. It continuously monitors dependency
# files (pyproject.toml and uv.lock) for changes and automatically reinstalls
# dependencies when they are modified. The script uses uv (a fast Python package
# manager) for dependency management and uvicorn for running the FastAPI application.
#
# The script operates with a dual-process architecture:
#   1. Background watcher: Monitors pyproject.toml and uv.lock every 10 seconds
#      for changes. When dependencies change, it runs 'uv sync --no-dev' to update
#      the environment and kills the uvicorn process to trigger a restart.
#   2. Main loop: Runs uvicorn with --reload flag for code hot-reload, and
#      automatically restarts it when the watcher kills it (indicating dependency
#      changes) or if it crashes.
#
# WHY IT'S NEEDED:
# In a containerized development environment (like DigitalOcean App Platform), this
# script enables automatic dependency management when pyproject.toml is updated via
# git sync. When new dependencies are added and pushed to GitHub, the git sync
# service pulls the changes, and this script detects the modification, syncs
# dependencies using uv, and restarts uvicorn automatically. This ensures the
# application always has the correct Python packages installed and the server is
# running the latest code, without requiring manual 'uv sync' commands or server
# restarts. The --reload flag on uvicorn also provides automatic code reloading
# for Python source file changes.
#
# HOW IT'S USED:
# This script is executed by the container's DEV_START_COMMAND as specified in the
# appspec.yaml file. It:
#   - Handles uv.lock and poetry.lock merge conflicts automatically
#   - Runs 'uv sync --no-dev' initially to install all dependencies
#   - Implements hard rebuild on uv sync errors
#   - Creates a hash file (.deps_hash) to track dependency file state
#   - Starts a background process that monitors pyproject.toml and uv.lock
#   - Enters a main loop that runs uvicorn on port 8080 with --reload enabled
#   - When the watcher detects dependency changes, it kills uvicorn, triggering
#     the main loop to restart it with the updated dependencies
#
# The script runs continuously, with the background watcher and main loop
# coordinating to ensure dependencies are always up-to-date and the server
# restarts when needed.
#
set -euo pipefail
cd "$(dirname "$0")"

# Files to watch for dependency changes (uv/pyproject workflow)
WATCH_FILES=("pyproject.toml" "uv.lock")
HASH_FILE=".deps_hash"

hash_files() {
  for f in "${WATCH_FILES[@]}"; do
    [ -f "$f" ] && sha256sum "$f"
  done
}

# Function to detect and resolve lock file merge conflicts
resolve_lock_conflicts() {
  local resolved=false
  # Check for uv.lock conflicts
  if [ -f uv.lock ]; then
    if grep -q "^<<<<<<< " uv.lock 2>/dev/null || \
       grep -q "^======= " uv.lock 2>/dev/null || \
       grep -q "^>>>>>>> " uv.lock 2>/dev/null; then
      echo "Detected merge conflict in uv.lock. Removing and regenerating..."
      rm -f uv.lock
      resolved=true
    fi
  fi
  # Check for poetry.lock conflicts (if using poetry)
  if [ -f poetry.lock ]; then
    if grep -q "^<<<<<<< " poetry.lock 2>/dev/null || \
       grep -q "^======= " poetry.lock 2>/dev/null || \
       grep -q "^>>>>>>> " poetry.lock 2>/dev/null; then
      echo "Detected merge conflict in poetry.lock. Removing and regenerating..."
      rm -f poetry.lock
      resolved=true
    fi
  fi
  if [ "$resolved" = true ]; then
    return 0
  fi
  return 1
}

# Function to perform hard rebuild (clean sync)
hard_rebuild() {
  echo "Performing hard rebuild: removing lock files and virtual environment..."
  rm -f uv.lock poetry.lock
  # Remove .venv if it exists (uv creates it)
  [ -d .venv ] && rm -rf .venv
  echo "Re-syncing dependencies..."
  uv sync --no-dev
}

# Resolve any existing lock file conflicts
resolve_lock_conflicts || true

# Initial install with error handling
echo "Installing dependencies (uv)..."
if ! uv sync --no-dev; then
  echo "Initial uv sync failed. Attempting hard rebuild..."
  hard_rebuild
fi

hash_files | sha256sum | awk '{print $1}' > "$HASH_FILE"

# Background watcher function that monitors dependency files
watch_dependencies() {
  while true; do
    sleep 10  # Check every 10 seconds
    current=$(hash_files | sha256sum | awk '{print $1}')
    previous=$(cat "$HASH_FILE" 2>/dev/null || true)
    if [ "$current" != "$previous" ]; then
      echo "[WATCHER] Dependencies changed. Re-syncing..."
      # Resolve lock conflicts before syncing
      resolve_lock_conflicts || true
      # Try sync, fall back to hard rebuild on error
      if ! uv sync --no-dev; then
        echo "[WATCHER] uv sync failed. Performing hard rebuild..."
        hard_rebuild
      fi
      echo "$current" > "$HASH_FILE"
      # Kill uvicorn to trigger restart by outer loop
      if [ -n "${UVICORN_PID:-}" ]; then
        echo "[WATCHER] Killing uvicorn (PID: $UVICORN_PID) to restart..."
        kill "$UVICORN_PID" 2>/dev/null || true
      fi
    fi
  done
}

# Start background watcher
watch_dependencies &
WATCHER_PID=$!

# Cleanup function for graceful shutdown
cleanup() {
  echo "Shutting down..."
  [ -n "${WATCHER_PID:-}" ] && kill "$WATCHER_PID" 2>/dev/null || true
  [ -n "${UVICORN_PID:-}" ] && kill "$UVICORN_PID" 2>/dev/null || true
}

trap cleanup EXIT INT TERM

# Main loop: uvicorn runs, watcher kills it when deps change, loop restarts it
while true; do
  echo "Starting uvicorn..."
  uv run uvicorn main:app --host 0.0.0.0 --port 8080 --reload &
  UVICORN_PID=$!
  echo "Uvicorn started (PID: $UVICORN_PID)"

  # Wait for uvicorn to exit (either from crash or watcher kill)
  wait "$UVICORN_PID" 2>/dev/null || true

  echo "Uvicorn exited. Restarting in 2 seconds..."
  sleep 2
done