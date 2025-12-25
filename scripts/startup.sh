#!/usr/bin/env bash
# Startup Script for Dev Environment
# Orchestrates GitHub sync and user application startup

set -euo pipefail

echo "=========================================="
echo "Dev Environment Starting..."
echo "=========================================="
echo ""

# Marker file used to avoid doing an immediate duplicate sync in github-sync.sh
# We only create it after a successful initial sync (and after we record the
# current commit as already-processed for deploy jobs).
STARTUP_SYNC_MARKER_FILE="/tmp/startup_sync_done"
rm -f "$STARTUP_SYNC_MARKER_FILE" 2>/dev/null || true

# Source bashrc to load all environment variables
# This loads NVM, UV PATH, Go PATH, Rust, and other tools
if [ -f /home/devcontainer/.bashrc ]; then
    source /home/devcontainer/.bashrc
fi

# Display environment configuration
echo "Configuration:"
echo "  Repository: ${GITHUB_REPO_URL:-not set}"
echo "  Branch: ${GITHUB_BRANCH:-default}"
echo "  Workspace: ${WORKSPACE_PATH:-/workspaces/app}"
echo "  Sync Interval: ${GITHUB_SYNC_INTERVAL:-15}s"
echo ""

# Display installed runtimes
echo "Installed Runtimes:"
command -v node &>/dev/null && echo "  ✓ Node.js $(node --version)"
command -v python &>/dev/null && echo "  ✓ Python $(python --version 2>&1)"
command -v go &>/dev/null && echo "  ✓ Go $(go version | awk '{print $3}')"
command -v rustc &>/dev/null && echo "  ✓ Rust $(rustc --version | awk '{print $2}')"
command -v ruby &>/dev/null && echo "  ✓ Ruby $(ruby --version | awk '{print $2}')"
echo ""

# Display installed database clients
echo "Database Clients:"
command -v psql &>/dev/null && echo "  ✓ PostgreSQL"
command -v mongosh &>/dev/null && echo "  ✓ MongoDB"
command -v mysql &>/dev/null && echo "  ✓ MySQL"
echo ""

echo "=========================================="
echo "Starting GitHub Sync Service..."
echo "=========================================="
echo ""

# Do initial sync first (blocking)
echo "Performing initial repository sync..."
REPO_URL="${GITHUB_REPO_URL:-}"
AUTH_TOKEN="${GITHUB_TOKEN:-}"
WORKSPACE="${WORKSPACE_PATH:-/workspaces/app}"

INITIAL_SYNC_OK=false

if [ -n "$REPO_URL" ]; then
    # Inject auth token if provided
    if [ -n "$AUTH_TOKEN" ]; then
        if [[ "$REPO_URL" == https://* ]]; then
            CLEAN_URL="${REPO_URL#https://}"
            CLEAN_URL="${CLEAN_URL#*@}"
            REPO_URL_WITH_AUTH="https://${AUTH_TOKEN}@${CLEAN_URL}"
        else
            REPO_URL_WITH_AUTH="$REPO_URL"
        fi
    else
        REPO_URL_WITH_AUTH="$REPO_URL"
    fi

    # Determine target branch (use GITHUB_BRANCH if set, otherwise default)
    TARGET_BRANCH="${GITHUB_BRANCH:-}"

    if [ -d "$WORKSPACE/.git" ]; then
        echo "Repository exists. Pulling latest changes..."
        cd "$WORKSPACE"
        git fetch origin 2>&1 || true

        # If GITHUB_BRANCH is set, ensure we're on that branch
        if [ -n "$TARGET_BRANCH" ]; then
            CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
            if [ "$CURRENT_BRANCH" != "$TARGET_BRANCH" ]; then
                echo "Switching to branch: $TARGET_BRANCH"
                git checkout "$TARGET_BRANCH" 2>&1 || echo "Warning: Checkout failed, continuing..."
            fi
            git pull origin "$TARGET_BRANCH" 2>&1 || echo "Warning: Pull failed, continuing..."
        else
            CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
            git pull origin "$CURRENT_BRANCH" 2>&1 || echo "Warning: Pull failed, continuing..."
        fi
    else
        echo "Cloning repository..."
        mkdir -p "$WORKSPACE"
        if [ "$(ls -A "$WORKSPACE" 2>/dev/null)" ]; then
            rm -rf "${WORKSPACE:?}/"* "${WORKSPACE:?}/".[!.]* "${WORKSPACE:?}/"..?* 2>/dev/null || true
        fi

        # Clone with specific branch if GITHUB_BRANCH is set
        if [ -n "$TARGET_BRANCH" ]; then
            echo "Cloning branch: $TARGET_BRANCH"
            git clone -b "$TARGET_BRANCH" "$REPO_URL_WITH_AUTH" "$WORKSPACE" 2>&1 || echo "Warning: Clone failed, continuing..."
        else
            git clone "$REPO_URL_WITH_AUTH" "$WORKSPACE" 2>&1 || echo "Warning: Clone failed, continuing..."
        fi

        if [ -n "$AUTH_TOKEN" ] && [ -d "$WORKSPACE/.git" ]; then
            cd "$WORKSPACE"
            git remote set-url origin "$REPO_URL_WITH_AUTH" 2>/dev/null || true
        fi
    fi
    echo "✓ Initial sync completed"

    if [ -d "$WORKSPACE/.git" ]; then
        INITIAL_SYNC_OK=true
    fi
else
    echo "No GITHUB_REPO_URL configured. Skipping sync."
fi
echo ""

# Execute PRE_DEPLOY job if configured (initial bootstrap)
if [ -n "${PRE_DEPLOY_COMMAND:-}" ]; then
    echo "=========================================="
    echo "Executing Initial PRE_DEPLOY Job..."
    echo "=========================================="
    echo ""

    if /usr/local/bin/job-manager.sh execute PRE_DEPLOY; then
        echo "✓ Initial PRE_DEPLOY job completed successfully"
    else
        echo "ERROR: Initial PRE_DEPLOY job failed. Container cannot start."
        exit 1  # Strict mode - must succeed
    fi
    echo ""
fi

# Record current commit as processed so github-sync doesn't immediately re-run
# deploy jobs for the same commit (when startup already ran them).
if [ "$INITIAL_SYNC_OK" = "true" ]; then
    /usr/local/bin/job-manager.sh update_last_job_commit 2>/dev/null || true
    touch "$STARTUP_SYNC_MARKER_FILE" 2>/dev/null || true
fi

# Start GitHub sync loop in background (continuous polling)
echo "Starting continuous sync service..."
/usr/local/bin/github-sync.sh &
GITHUB_SYNC_PID=$!
echo "✓ GitHub sync service started (PID: $GITHUB_SYNC_PID)"
echo ""

# Start dev health check server (built-in Go binary) unless disabled
ENABLE_DEV_HEALTH="${ENABLE_DEV_HEALTH:-true}"
DEV_HEALTH_PORT="${DEV_HEALTH_PORT:-9090}"
if [ "$ENABLE_DEV_HEALTH" = "true" ]; then
    echo "Starting dev health check server..."
    DEV_HEALTH_PORT="$DEV_HEALTH_PORT" /usr/local/bin/dev-health-server &
    HEALTH_PID=$!
    echo "✓ Dev health check server started (PID: $HEALTH_PID) - endpoint: /dev_health on port $DEV_HEALTH_PORT"
    echo ""
else
    echo "Skipping dev health check server (ENABLE_DEV_HEALTH=$ENABLE_DEV_HEALTH)"
    echo "Ensure your application exposes its own health endpoint per your App Spec."
    echo ""
fi

# Start welcome page server (built-in Go binary) on port 8080
# This will automatically stop when the user's app starts via DEV_START_COMMAND
WELCOME_PAGE_PORT="${WELCOME_PAGE_PORT:-8080}"
echo "Starting welcome page server..."
WELCOME_PAGE_PORT="$WELCOME_PAGE_PORT" /usr/local/bin/welcome-page-server &
WELCOME_PID=$!
echo "✓ Welcome page server started (PID: $WELCOME_PID) - endpoint: / on port $WELCOME_PAGE_PORT"
echo "  (Will automatically stop when your application starts)"
echo ""

# Determine workspace path
WORKSPACE="${WORKSPACE_PATH:-/workspaces/app}"
WORKSPACE_REPO_FOLDER="${GITHUB_REPO_FOLDER:-}"
WORKSPACE_REPO_FOLDER="${WORKSPACE_REPO_FOLDER%/}"
APP_WORKDIR="$WORKSPACE"

echo "=========================================="
echo "Starting Application..."
echo "=========================================="
echo ""

# Default to repo-provided dev_startup.sh or startup.sh when DEV_START_COMMAND is not set
if [ -z "${DEV_START_COMMAND:-}" ]; then
    if [ -f "$WORKSPACE/dev_startup.sh" ]; then
        DEV_START_COMMAND="bash dev_startup.sh"
        echo "DEV_START_COMMAND not set; using dev_startup.sh from repository."
    elif [ -f "$WORKSPACE/startup.sh" ]; then
        DEV_START_COMMAND="bash startup.sh"
        echo "DEV_START_COMMAND not set; using startup.sh from repository."
    elif [ -n "$WORKSPACE_REPO_FOLDER" ] && [ -f "$WORKSPACE/$WORKSPACE_REPO_FOLDER/dev_startup.sh" ]; then
        APP_WORKDIR="$WORKSPACE/$WORKSPACE_REPO_FOLDER"
        DEV_START_COMMAND="bash dev_startup.sh"
        echo "DEV_START_COMMAND not set; using dev_startup.sh from legacy subfolder: $WORKSPACE_REPO_FOLDER"
    elif [ -n "$WORKSPACE_REPO_FOLDER" ] && [ -f "$WORKSPACE/$WORKSPACE_REPO_FOLDER/startup.sh" ]; then
        APP_WORKDIR="$WORKSPACE/$WORKSPACE_REPO_FOLDER"
        DEV_START_COMMAND="bash startup.sh"
        echo "DEV_START_COMMAND not set; using startup.sh from legacy subfolder: $WORKSPACE_REPO_FOLDER"
    fi
else
    # Legacy compatibility: if a user kept the default command but the script lives
    # under GITHUB_REPO_FOLDER, run it from that subfolder.
    if [ -n "$WORKSPACE_REPO_FOLDER" ]; then
        if [ "$DEV_START_COMMAND" = "bash dev_startup.sh" ] && [ ! -f "$WORKSPACE/dev_startup.sh" ] && [ -f "$WORKSPACE/$WORKSPACE_REPO_FOLDER/dev_startup.sh" ]; then
            APP_WORKDIR="$WORKSPACE/$WORKSPACE_REPO_FOLDER"
            echo "Legacy: running dev_startup.sh from subfolder $WORKSPACE_REPO_FOLDER"
        elif [ "$DEV_START_COMMAND" = "bash startup.sh" ] && [ ! -f "$WORKSPACE/startup.sh" ] && [ -f "$WORKSPACE/$WORKSPACE_REPO_FOLDER/startup.sh" ]; then
            APP_WORKDIR="$WORKSPACE/$WORKSPACE_REPO_FOLDER"
            echo "Legacy: running startup.sh from subfolder $WORKSPACE_REPO_FOLDER"
        fi
    fi
fi

if [ -n "${DEV_START_COMMAND:-}" ]; then
    echo "Command: $DEV_START_COMMAND"
    echo "Working directory: $APP_WORKDIR"
    echo ""

    # Always show diagnostic info so user can debug even without shell access
    if [ -d "$WORKSPACE/.git" ]; then
        echo "Git Status:"
        echo "  Branch: $(cd "$WORKSPACE" && git rev-parse --abbrev-ref HEAD 2>/dev/null || echo 'unknown')"
        echo "  Commit: $(cd "$WORKSPACE" && git rev-parse --short HEAD 2>/dev/null || echo 'unknown')"
        echo ""
    fi

    echo "Workspace contents ($WORKSPACE):"
    ls -la "$WORKSPACE" 2>/dev/null | head -20
    echo ""

    # If command contains a path to a .sh file, validate it exists
    if [[ "$DEV_START_COMMAND" =~ ([a-zA-Z0-9_/.+-]+\.sh) ]]; then
        SCRIPT_PATH="${BASH_REMATCH[1]}"
        echo "Checking script path: $SCRIPT_PATH"
        if [ -f "$APP_WORKDIR/$SCRIPT_PATH" ]; then
            echo "  ✓ File exists at $APP_WORKDIR/$SCRIPT_PATH"
        elif [ -f "$WORKSPACE/$SCRIPT_PATH" ]; then
            echo "  ✓ File exists at $WORKSPACE/$SCRIPT_PATH"
        else
            echo "  ✗ File NOT found at $APP_WORKDIR/$SCRIPT_PATH"
            echo ""
            echo "Looking for .sh files in workspace..."
            find "$WORKSPACE" -name "*.sh" -type f 2>/dev/null | head -10
        fi
        echo ""
    fi

    echo "Note: Welcome page server will be stopped when your app starts on port 8080"
    cd "$APP_WORKDIR"
    
    # Stop welcome page server (since app will use port 8080)
    if [ -n "${WELCOME_PID:-}" ]; then
        echo "Stopping welcome page server (PID: $WELCOME_PID) to free port 8080 for your app..."
        kill "$WELCOME_PID" 2>/dev/null || true
        sleep 1  # Give the OS time to release the port before app starts
    fi
    
    # Build environment setup command
    ENV_SETUP=""
    
    # Load NVM if Node.js is installed
    if [ -d "$HOME/.nvm" ]; then
        ENV_SETUP="export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" && "
    fi
    
    # Load Python/UV if installed
    if [ -d "$HOME/.local/bin" ]; then
        ENV_SETUP="${ENV_SETUP}export PATH=\"\$HOME/.local/bin:\$PATH\" && "
    fi
    
    # Load Go if installed
    if [ -d "/usr/local/go/bin" ]; then
        ENV_SETUP="${ENV_SETUP}export PATH=\"/usr/local/go/bin:\$PATH\" && export GOPATH=\"\$HOME/go\" && export PATH=\"\$GOPATH/bin:\$PATH\" && "
    fi
    
    # Load Rust if installed
    if [ -f "$HOME/.cargo/env" ]; then
        ENV_SETUP="${ENV_SETUP}source \"\$HOME/.cargo/env\" && "
    fi

    # Load Ruby if installed
    if [ -d "$HOME/.rbenv" ]; then
        ENV_SETUP="${ENV_SETUP}export PATH=\"\$HOME/.rbenv/bin:\$PATH\" && eval \"\$(rbenv init - bash)\" && "
    fi

    # Execute POST_DEPLOY job in background (initial bootstrap)
    if [ -n "${POST_DEPLOY_COMMAND:-}" ]; then
        echo "Executing Initial POST_DEPLOY Job in background..."
        (/usr/local/bin/job-manager.sh execute POST_DEPLOY &)
        echo ""
    fi

    # Execute command with environment loaded
    # NOTE: We do NOT use 'exec' here so that if the command fails, the script
    # continues and keeps the container alive for debugging.
    bash -c "${ENV_SETUP}${DEV_START_COMMAND}"
    EXIT_CODE=$?

    # If command exited (crashed or file not found), keep container alive for debugging
    if [ $EXIT_CODE -ne 0 ]; then
        echo ""
        echo "=========================================="
        echo "Application Failed (exit code: $EXIT_CODE)"
        echo "=========================================="
        echo ""
        echo "Container will stay alive for debugging."
        echo "Health check is running on port 9090."
        echo ""
        echo "Debug options:"
        echo "  - Shell in via: doctl apps console <app-id> <component-name>"
        echo "  - Or use do-app-sandbox for remote access"
        echo "  - Check the diagnostic info printed above"
        echo ""

        # Keep container alive for debugging
        tail -f /dev/null
    fi
else
    echo "=========================================="
    echo "No Application Command Configured"
    echo "=========================================="
    echo ""
    echo "DEV_START_COMMAND is not set and no dev_startup.sh or startup.sh found in repository."
    echo "Container is running and ready for configuration."
    echo ""
    echo "Next steps:"
    echo "  1. Set GITHUB_REPO_URL to point to your application repository"
    echo "  2. Set DEV_START_COMMAND to your application startup command, OR"
    echo "  3. Add a dev_startup.sh script to your repository"
    echo ""
    echo "The container will remain running. You can:"
    echo "  - Configure environment variables in App Platform UI"
    echo "  - Exec into the container to test commands manually"
    echo "  - Visit the welcome page at http://your-app-url/ for setup instructions"
    echo ""
    echo "Health check server is running on port ${DEV_HEALTH_PORT:-9090}"
    echo "Welcome page server is running on port ${WELCOME_PAGE_PORT:-8080}"
    echo "Container will stay alive and healthy while you configure your application."
    echo ""
    tail -f /dev/null
fi
