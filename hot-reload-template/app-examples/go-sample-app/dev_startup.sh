#!/usr/bin/env bash
#
# Go Application Development Startup Script
# ==========================================
#
# WHAT IT DOES:
# This script provides automatic hot-reload functionality for Go applications in a
# development environment. It continuously monitors the codebase for changes and
# automatically rebuilds and restarts the application when:
#   - Go source files (*.go) are modified (code changes)
#   - Dependency files (go.mod, go.sum) are modified (dependency changes)
#
# The script uses hash-based change detection to efficiently track modifications
# without constantly polling the filesystem. When changes are detected, it:
#   1. Stops the currently running application process
#   2. Runs 'go mod tidy' if dependencies changed (to update go.sum)
#   3. Rebuilds the application binary
#   4. Starts the new binary on port 8080
#
# WHY IT'S NEEDED:
# In a containerized development environment (like DigitalOcean App Platform), this
# script enables rapid iteration by automatically picking up code changes pushed to
# the GitHub repository. The git sync service pulls changes every 30 seconds, and
# this script detects those changes and restarts the app without manual intervention.
# This eliminates the need to manually rebuild and restart the application after
# each code change, significantly improving developer productivity.
#
# HOW IT'S USED:
# This script is executed by the container's DEV_START_COMMAND as specified in the
# appspec.yaml file. It runs continuously in the foreground, monitoring for
# changes in a loop. The script:
#   - Handles go.sum merge conflicts automatically
#   - Initializes by running 'go mod tidy' and calculating initial hashes
#   - Implements hard rebuild on go mod errors
#   - Starts the Go application server
#   - Enters a monitoring loop that checks for changes every 2 seconds
#   - Automatically handles process cleanup and restart when changes are detected
#
# The script builds the binary to /tmp/go-app for better process control, allowing
# it to reliably kill and restart the application even when dependencies change.
#
set -euo pipefail
cd "$(dirname "$0")"

WATCH_FILES=("go.mod" "go.sum")
HASH_FILE=".deps_hash"
SOURCE_HASH_FILE=".source_hash"

# Hash dependency files (go.mod, go.sum)
hash_files() {
  for f in "${WATCH_FILES[@]}"; do
    [ -f "$f" ] && sha256sum "$f"
  done
}

# Hash all .go source files
hash_source() {
  find . -name "*.go" -type f -exec sha256sum {} \; 2>/dev/null | sort | sha256sum | awk '{print $1}'
}

# Function to detect and resolve go.sum merge conflicts
resolve_lock_conflicts() {
  if [ -f go.sum ]; then
    # Check if go.sum has merge conflict markers
    if grep -q "^<<<<<<< " go.sum 2>/dev/null || \
       grep -q "^======= " go.sum 2>/dev/null || \
       grep -q "^>>>>>>> " go.sum 2>/dev/null; then
      echo "Detected merge conflict in go.sum. Removing and regenerating..."
      rm -f go.sum
      return 0
    fi
  fi
  return 1
}

# Function to perform hard rebuild (clean module cache and re-download)
hard_rebuild() {
  echo "Performing hard rebuild: cleaning module cache and removing go.sum..."
  rm -f go.sum
  # Clean module cache
  go clean -modcache 2>/dev/null || true
  echo "Re-downloading dependencies..."
  go mod download
  go mod tidy
}

# Resolve any existing lock file conflicts
resolve_lock_conflicts || true

# Initial setup with error handling
echo "Setting up modules and verifying checksums..."
if ! go mod tidy; then
  echo "go mod tidy failed. Attempting hard rebuild..."
  hard_rebuild
fi

hash_files | sha256sum | awk '{print $1}' > "$HASH_FILE"
hash_source > "$SOURCE_HASH_FILE"

refresh_deps_if_changed() {
  local current previous
  current=$(hash_files | sha256sum | awk '{print $1}')
  previous=$(cat "$HASH_FILE" 2>/dev/null || true)
  if [ "$current" != "$previous" ]; then
    echo "Dependencies changed. Updating..."
    # Resolve lock conflicts before updating
    resolve_lock_conflicts || true
    # Try tidy, fall back to hard rebuild on error
    if ! go mod tidy; then
      echo "go mod tidy failed. Performing hard rebuild..."
      hard_rebuild
    else
      go mod download
    fi
    echo "$current" > "$HASH_FILE"
    return 0
  fi
  return 1
}

start_server() {
  echo "Starting Go app..."
  # Build first, then run the binary directly for better process control
  go build -o /tmp/go-app . 
  /tmp/go-app &
  SERVER_PID=$!
  echo "Go app started with PID: $SERVER_PID"
}

stop_server() {
  echo "Stopping Go app..."
  # Kill by PID if we have it
  if [ -n "${SERVER_PID:-}" ]; then
    echo "Killing process $SERVER_PID..."
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    sleep 1
    kill -9 "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  # Kill any go-app binary that might be running
  pkill -9 -f "/tmp/go-app" >/dev/null 2>&1 || true
  # Also try to kill anything on port 8080 using fuser (more reliable than lsof)
  fuser -k 8080/tcp >/dev/null 2>&1 || true
  # Fallback to lsof if fuser not available
  lsof -ti:8080 | xargs kill -9 >/dev/null 2>&1 || true
  sleep 2
  echo "Stop complete"
}

trap 'stop_server; exit 0' INT TERM

start_server
PREV_DEP_HASH=$(hash_files | sha256sum | awk '{print $1}')
PREV_SOURCE_HASH=$(hash_source)

while true; do
  sleep 2

  current_dep_hash=$(hash_files | sha256sum | awk '{print $1}')
  current_source_hash=$(hash_source)

  deps_changed=false
  source_changed=false

  if [ "$current_dep_hash" != "$PREV_DEP_HASH" ]; then
    deps_changed=true
    PREV_DEP_HASH="$current_dep_hash"
  fi

  if [ "$current_source_hash" != "$PREV_SOURCE_HASH" ]; then
    source_changed=true
    PREV_SOURCE_HASH="$current_source_hash"
  fi

  if [ "$deps_changed" = true ] || [ "$source_changed" = true ]; then
    stop_server
    if [ "$deps_changed" = true ]; then
      echo "Dependencies changed (go.mod/go.sum). Updating..."
      # Resolve lock conflicts before updating
      resolve_lock_conflicts || true
      # Use 'go mod tidy' to ensure go.sum is updated, fall back to hard rebuild on error
      if ! go mod tidy; then
        echo "go mod tidy failed. Performing hard rebuild..."
        hard_rebuild
      else
        go mod download
      fi
      # Save the new hash to the watched hash file (.deps_hash) for future runs
      echo "$current_dep_hash" > "$HASH_FILE" 
    elif [ "$source_changed" = true ]; then
      echo "Source code changed. Restarting..."
    fi
    start_server
  fi
done