#!/usr/bin/env bash
#
# Next.js Application Development Startup Script
# =============================================
#
# WHAT IT DOES:
# This script provides automatic hot-reload functionality for Next.js applications
# in a development environment. It monitors package.json for dependency changes
# and automatically reinstalls npm packages when dependencies are modified. The
# script uses nodemon to watch for changes and restart the Next.js development
# server accordingly.
#
# The script works in two stages:
#   1. Initial setup: Installs all dependencies and creates a hash of package.json
#   2. Continuous monitoring: Uses nodemon to watch package.json and restart the
#      dev server when dependencies change. The .dev_run.sh helper script checks
#      if package.json changed and reinstalls dependencies before starting the server.
#
# WHY IT'S NEEDED:
# In a containerized development environment (like DigitalOcean App Platform), this
# script enables automatic dependency management when package.json is updated via
# git sync. When new dependencies are added to package.json and pushed to GitHub,
# the git sync service pulls the changes, and this script detects the modification,
# reinstalls dependencies, and restarts the Next.js dev server automatically.
# This ensures the application always has the correct dependencies installed and
# running, without requiring manual npm install commands or server restarts.
#
# HOW IT'S USED:
# This script is executed by the container's DEV_START_COMMAND as specified in the
# appspec.yaml file. It:
#   - Creates .npmrc with legacy-peer-deps=true to handle peer dependency conflicts
#   - Handles package-lock.json merge conflicts automatically
#   - Runs 'npm install' initially to set up dependencies
#   - Creates a hash file (.package_hash) to track package.json state
#   - Generates a helper script (.dev_run.sh) that nodemon will execute
#   - Launches nodemon to watch package.json and execute .dev_run.sh on changes
#   - The helper script checks if package.json changed, reinstalls if needed, and
#     starts the Next.js dev server on port 8080
#   - Implements hard rebuild on npm install errors
#
# The script runs continuously, with nodemon handling the process lifecycle and
# automatic restarts when package.json changes are detected.
#
set -euo pipefail
cd "$(dirname "$0")"

# Create .npmrc with legacy-peer-deps to handle peer dependency conflicts
# This allows npm to install packages even when there are peer dependency mismatches
# (e.g., React 19 with dependencies requiring React 18)
if [ ! -f .npmrc ]; then
  echo "Creating .npmrc with legacy-peer-deps=true..."
  echo "legacy-peer-deps=true" > .npmrc
fi

# Function to detect and resolve package-lock.json merge conflicts
resolve_lock_conflicts() {
  if [ -f package-lock.json ]; then
    # Check if package-lock.json has merge conflict markers
    if grep -q "^<<<<<<< " package-lock.json 2>/dev/null || \
       grep -q "^======= " package-lock.json 2>/dev/null || \
       grep -q "^>>>>>>> " package-lock.json 2>/dev/null; then
      echo "Detected merge conflict in package-lock.json. Removing and regenerating..."
      rm -f package-lock.json
      return 0
    fi
  fi
  return 1
}

# Function to perform hard rebuild (clean install)
hard_rebuild() {
  echo "Performing hard rebuild: removing node_modules and package-lock.json..."
  rm -rf node_modules package-lock.json
  echo "Reinstalling dependencies..."
  npm install
}

# Resolve any existing lock file conflicts
resolve_lock_conflicts || true

# Initial install with error handling
if ! npm install; then
  echo "Initial npm install failed. Attempting hard rebuild..."
  hard_rebuild
fi

sha256sum package.json | awk '{print $1}' > .package_hash

# Helper to reinstall when package.json changes
install_if_changed() {
  current=$(sha256sum package.json | awk '{print $1}')
  previous=$(cat .package_hash 2>/dev/null || true)
  if [ "$current" != "$previous" ]; then
    echo "package.json changed. Reinstalling..."
    # Resolve lock conflicts before installing
    resolve_lock_conflicts || true
    # Try install, fall back to hard rebuild on error
    if ! npm install; then
      echo "npm install failed. Performing hard rebuild..."
      hard_rebuild
    fi
    echo "$current" > .package_hash
  else
    echo "package.json unchanged. Skipping npm install."
  fi
}

# Runner invoked by nodemon
cat > .dev_run.sh <<'RUN'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# Function to resolve lock conflicts
resolve_lock_conflicts() {
  if [ -f package-lock.json ]; then
    if grep -q "^<<<<<<< " package-lock.json 2>/dev/null || \
       grep -q "^======= " package-lock.json 2>/dev/null || \
       grep -q "^>>>>>>> " package-lock.json 2>/dev/null; then
      echo "Detected merge conflict in package-lock.json. Removing and regenerating..."
      rm -f package-lock.json
      return 0
    fi
  fi
  return 1
}

# Function for hard rebuild
hard_rebuild() {
  echo "Performing hard rebuild: removing node_modules and package-lock.json..."
  rm -rf node_modules package-lock.json
  echo "Reinstalling dependencies..."
  npm install
}

current=$(sha256sum package.json | awk '{print $1}')
previous=$(cat .package_hash 2>/dev/null || true)
if [ "$current" != "$previous" ]; then
  echo "package.json changed. Reinstalling..."
  resolve_lock_conflicts || true
  if ! npm install; then
    echo "npm install failed. Performing hard rebuild..."
    hard_rebuild
  fi
  echo "$current" > .package_hash
else
  echo "package.json unchanged. Skipping npm install."
fi
exec npm run dev -- --hostname 0.0.0.0 --port 8080
RUN
chmod +x .dev_run.sh

# Start nodemon to watch package.json and rerun .dev_run.sh
exec npx nodemon --watch package.json --ext json --exec "bash .dev_run.sh"