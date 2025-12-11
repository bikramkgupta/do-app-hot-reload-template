#!/usr/bin/env bash
#
# Node.js Express Application Development Startup Script
# =============================================
#
# This script provides automatic hot-reload functionality for the Express test app.
# It monitors package.json for dependency changes and automatically reinstalls npm
# packages when dependencies are modified.
#
set -euo pipefail
cd "$(dirname "$0")"

echo "=========================================="
echo "Starting Node.js Hot Reload Job Test App"
echo "=========================================="
echo ""

# Create .npmrc with legacy-peer-deps to handle peer dependency conflicts
if [ ! -f .npmrc ]; then
  echo "Creating .npmrc with legacy-peer-deps=true..."
  echo "legacy-peer-deps=true" > .npmrc
fi

# Function to detect and resolve package-lock.json merge conflicts
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
echo "Installing dependencies..."
if ! npm install; then
  echo "Initial npm install failed. Attempting hard rebuild..."
  hard_rebuild
fi

echo "Creating package hash for change detection..."
sha256sum package.json | awk '{print $1}' > .package_hash

# Helper to reinstall when package.json changes
install_if_changed() {
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
exec npm run dev
RUN
chmod +x .dev_run.sh

echo ""
echo "Starting nodemon to watch for changes..."
echo "App will be available on http://0.0.0.0:8080"
echo ""

# Start nodemon to watch package.json and rerun .dev_run.sh
exec npx nodemon --watch package.json --ext json --exec "bash .dev_run.sh"
