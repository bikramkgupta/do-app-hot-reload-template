#!/usr/bin/env bash
# GitHub Repository Sync Script
# Clones or syncs a GitHub repository to the workspace
# Supports monorepos with subfolder syncing
#
# SYNC LOGIC:
# Every SYNC_INTERVAL seconds:
#   1. git fetch (lightweight - only updates refs)
#   2. Compare local commit SHA vs remote commit SHA
#   3. If different: pull changes, rsync (monorepo), execute deploy jobs
#   4. If same: do nothing (no wasted I/O)

set -euo pipefail

# Configuration from environment variables
REPO_URL="${GITHUB_REPO_URL:-}"
AUTH_TOKEN="${GITHUB_TOKEN:-}"
WORKSPACE="${WORKSPACE_PATH:-/workspaces/app}"
SYNC_INTERVAL="${GITHUB_SYNC_INTERVAL:-30}"
REPO_FOLDER="${GITHUB_REPO_FOLDER:-}"
REPO_BRANCH="${GITHUB_BRANCH:-}"
MONOREPO_CACHE="/tmp/monorepo-cache"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Generate unique hash for repo URL
get_repo_hash() {
    echo "$1" | md5sum | cut -d' ' -f1
}

# Sync monorepo subfolder to workspace
sync_monorepo_folder() {
    local cache_dir="$1"
    local folder_path="$2"
    local target_workspace="$3"

    # Check if folder exists in the cloned repo
    if [ ! -d "$cache_dir/$folder_path" ]; then
        log_error "Folder '$folder_path' not found in repository"
        log_info "Available folders in repo root:"
        ls -la "$cache_dir/" || true
        return 1
    fi

    log_info "Syncing folder: $folder_path -> $target_workspace"

    # Create target workspace if it doesn't exist
    mkdir -p "$target_workspace"

    # Use rsync to sync folder contents (not the folder itself)
    # --delete ensures removed files are also removed from workspace
    # -a preserves permissions and timestamps
    # Exclude build artifacts and dependencies that should be managed by dev scripts
    if rsync -a --delete \
        --exclude 'node_modules' \
        --exclude '.next' \
        --exclude '__pycache__' \
        --exclude '*.pyc' \
        --exclude 'storage' \
        --exclude '*.sqlite3' \
        --exclude '*.sqlite3-*' \
        --exclude 'vendor/bundle' \
        --exclude '.bundle' \
        "$cache_dir/$folder_path/" "$target_workspace/"; then
        log_info "Folder sync completed successfully"
        return 0
    else
        log_error "Failed to sync folder"
        return 1
    fi
}

# Get authenticated repo URL
get_auth_url() {
    local repo_url="$1"
    local auth_token="${2:-}"

    if [ -n "$auth_token" ] && [[ "$repo_url" == https://* ]]; then
        local clean_url="${repo_url#https://}"
        clean_url="${clean_url#*@}"
        echo "https://${auth_token}@${clean_url}"
    else
        echo "$repo_url"
    fi
}

# Check if remote has new commits (fetch + compare)
# Returns 0 if changes detected, 1 if no changes
# Sets REMOTE_COMMIT variable with the remote commit SHA
check_for_changes() {
    local git_dir="$1"
    local branch="$2"

    cd "$git_dir"

    # Fetch latest refs (lightweight operation)
    if ! git fetch origin 2>&1; then
        log_error "Failed to fetch from remote"
        return 1
    fi

    # Get current local commit
    local local_commit=$(git rev-parse HEAD 2>/dev/null || echo "")

    # Determine branch name
    local target_branch="$branch"
    if [ -z "$target_branch" ]; then
        target_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    fi

    # Get remote commit
    REMOTE_COMMIT=$(git rev-parse "origin/$target_branch" 2>/dev/null || echo "")

    if [ -z "$REMOTE_COMMIT" ]; then
        log_warn "Could not determine remote commit for branch $target_branch"
        return 1
    fi

    if [ "$local_commit" = "$REMOTE_COMMIT" ]; then
        log_info "No changes detected (commit: ${local_commit:0:7})"
        return 1  # No changes
    else
        log_info "Changes detected: ${local_commit:0:7} -> ${REMOTE_COMMIT:0:7}"
        return 0  # Changes detected
    fi
}

# Pull changes after confirming there are updates
pull_changes() {
    local git_dir="$1"
    local branch="$2"

    cd "$git_dir"

    local target_branch="$branch"
    if [ -z "$target_branch" ]; then
        target_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    fi

    # Ensure we're on the right branch
    git checkout "$target_branch" 2>&1 || true

    # Handle lock files that might block pull
    for lockfile in package-lock.json go.sum uv.lock poetry.lock Gemfile.lock; do
        if [ -f "$lockfile" ] && ! git diff --quiet "$lockfile" 2>/dev/null; then
            log_info "Resetting local changes to $lockfile..."
            git checkout -- "$lockfile" 2>/dev/null || rm -f "$lockfile"
        fi
    done

    # Pull changes
    if git pull origin "$target_branch" 2>&1; then
        log_info "Successfully pulled changes"
        return 0
    else
        log_warn "Pull failed, attempting reset..."
        git reset --hard "origin/$target_branch" 2>&1 || true
        return 0
    fi
}

# Initial clone of repository
initial_clone() {
    local repo_url="$1"
    local target_dir="$2"
    local branch="$3"
    local auth_token="${4:-}"

    local auth_url=$(get_auth_url "$repo_url" "$auth_token")

    log_info "Cloning repository for the first time..."

    # Create parent directory
    mkdir -p "$(dirname "$target_dir")"

    # Clone
    if git clone "$auth_url" "$target_dir" 2>&1; then
        log_info "Successfully cloned repository"
        cd "$target_dir"

        # Configure remote with auth for future pulls
        if [ -n "$auth_token" ]; then
            git remote set-url origin "$auth_url"
        fi

        # Checkout specific branch if requested
        if [ -n "$branch" ]; then
            log_info "Checking out branch: $branch"
            git checkout "$branch" 2>&1 || log_warn "Failed to checkout branch: $branch"
        fi

        return 0
    else
        log_error "Failed to clone repository"
        return 1
    fi
}

# Clean up merge conflict markers in lock files
cleanup_lock_files() {
    local workspace="$1"

    cd "$workspace"
    for lockfile in package-lock.json go.sum uv.lock poetry.lock Gemfile.lock; do
        if [ -f "$lockfile" ]; then
            if grep -q "^<<<<<<< " "$lockfile" 2>/dev/null || \
               grep -q "^======= " "$lockfile" 2>/dev/null || \
               grep -q "^>>>>>>> " "$lockfile" 2>/dev/null; then
                log_warn "Detected merge conflict markers in $lockfile. Removing..."
                rm -f "$lockfile"
            fi
        fi
    done
}

# Show current commit info
show_commit_info() {
    local git_dir="$1"

    if [ -d "$git_dir/.git" ]; then
        cd "$git_dir"
        local commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        local msg=$(git log -1 --pretty=%B 2>/dev/null | head -1 || echo "")
        log_info "Current commit: $commit - $msg"
    fi
}

# Execute deploy jobs when commit changes
execute_deploy_jobs() {
    # Acquire lock to prevent concurrent job execution
    local lock_dir="/tmp/job-execution.lock"

    if ! mkdir "$lock_dir" 2>/dev/null; then
        log_info "Job execution in progress by another process. Skipping."
        return 0
    fi

    trap 'rm -rf "$lock_dir"' EXIT

    # Check if commit actually changed (via job-manager)
    if ! /usr/local/bin/job-manager.sh check_commit_changed; then
        log_info "Repository commit unchanged. Skipping deploy jobs."
        rm -rf "$lock_dir"
        trap - EXIT
        return 0
    fi

    log_info "Repository commit changed. Executing deploy jobs..."

    # Execute PRE_DEPLOY (strict mode)
    if [ -n "${PRE_DEPLOY_COMMAND:-}" ]; then
        log_info "Executing PRE_DEPLOY job..."
        if /usr/local/bin/job-manager.sh execute PRE_DEPLOY; then
            log_info "PRE_DEPLOY job completed successfully"
        else
            log_error "PRE_DEPLOY job failed. Not updating commit SHA (will retry on next sync)."
            rm -rf "$lock_dir"
            trap - EXIT
            return 1
        fi
    fi

    # Execute POST_DEPLOY (lenient mode)
    if [ -n "${POST_DEPLOY_COMMAND:-}" ]; then
        log_info "Executing POST_DEPLOY job..."
        if /usr/local/bin/job-manager.sh execute POST_DEPLOY; then
            log_info "POST_DEPLOY job completed successfully"
        else
            log_warn "POST_DEPLOY job failed (lenient mode - continuing)"
        fi
    fi

    # Update commit tracking only after successful execution
    /usr/local/bin/job-manager.sh update_last_job_commit
    log_info "Deploy jobs completed. Commit SHA updated."

    rm -rf "$lock_dir"
    trap - EXIT
}

# Main sync function - called every SYNC_INTERVAL
sync_repo() {
    if [ -z "$REPO_URL" ]; then
        log_info "GITHUB_REPO_URL not set. Waiting for configuration..."
        return 0
    fi

    local auth_url=$(get_auth_url "$REPO_URL" "$AUTH_TOKEN")
    log_info "Repository URL: $REPO_URL"

    # ========================================
    # MONOREPO MODE
    # ========================================
    if [ -n "$REPO_FOLDER" ]; then
        log_info "Monorepo mode enabled"

        local repo_hash=$(get_repo_hash "$REPO_URL")
        local cache_dir="$MONOREPO_CACHE/$repo_hash"

        # Initial clone if cache doesn't exist
        if [ ! -d "$cache_dir/.git" ]; then
            if ! initial_clone "$REPO_URL" "$cache_dir" "$REPO_BRANCH" "$AUTH_TOKEN"; then
                return 1
            fi

            # First time: always sync folder
            if ! sync_monorepo_folder "$cache_dir" "$REPO_FOLDER" "$WORKSPACE"; then
                log_error "Failed to sync monorepo folder"
                return 1
            fi

            show_commit_info "$cache_dir"
            execute_deploy_jobs
            return 0
        fi

        # Check for changes (fetch + compare commits)
        if check_for_changes "$cache_dir" "$REPO_BRANCH"; then
            # Changes detected - pull and sync
            log_info "Pulling changes..."
            pull_changes "$cache_dir" "$REPO_BRANCH"

            # Sync the specific folder to workspace
            if ! sync_monorepo_folder "$cache_dir" "$REPO_FOLDER" "$WORKSPACE"; then
                log_error "Failed to sync monorepo folder"
                return 1
            fi

            show_commit_info "$cache_dir"
            execute_deploy_jobs
        fi
        # If no changes, do nothing (already logged in check_for_changes)

    # ========================================
    # REGULAR MODE (single repository)
    # ========================================
    else
        log_info "Regular mode (single repository)"

        # Initial clone if workspace doesn't exist
        if [ ! -d "$WORKSPACE/.git" ]; then
            # Clean up any existing files
            if [ -d "$WORKSPACE" ] && [ "$(ls -A "$WORKSPACE" 2>/dev/null)" ]; then
                log_warn "Workspace not empty. Cleaning before clone..."
                rm -rf "${WORKSPACE:?}/"* "${WORKSPACE:?}"/.[!.]* "${WORKSPACE:?}"/..?* 2>/dev/null || true
            fi

            if ! initial_clone "$REPO_URL" "$WORKSPACE" "$REPO_BRANCH" "$AUTH_TOKEN"; then
                return 1
            fi

            cleanup_lock_files "$WORKSPACE"
            show_commit_info "$WORKSPACE"
            execute_deploy_jobs
            return 0
        fi

        # Check for changes (fetch + compare commits)
        if check_for_changes "$WORKSPACE" "$REPO_BRANCH"; then
            # Changes detected - pull
            log_info "Pulling changes..."
            pull_changes "$WORKSPACE" "$REPO_BRANCH"

            cleanup_lock_files "$WORKSPACE"
            show_commit_info "$WORKSPACE"
            execute_deploy_jobs
        fi
        # If no changes, do nothing (already logged in check_for_changes)
    fi
}

# Main sync loop
main() {
    log_info "GitHub Sync Service Starting..."
    log_info "Sync interval: ${SYNC_INTERVAL}s"

    # Display monorepo configuration if enabled
    if [ -n "$REPO_FOLDER" ]; then
        log_info "Monorepo configuration detected:"
        log_info "  - Repository: ${REPO_URL:-not set}"
        log_info "  - Folder: $REPO_FOLDER"
        log_info "  - Branch: ${REPO_BRANCH:-auto-detect}"
    fi

    # Initial sync (always runs on startup)
    sync_repo

    # Continuous sync loop
    while true; do
        log_info "Waiting ${SYNC_INTERVAL}s before next sync..."
        sleep "$SYNC_INTERVAL"
        sync_repo
    done
}

# Create or update monorepo cache (exported for use by startup.sh)
# This function ensures the cache exists and is up to date
create_or_update_monorepo_cache() {
    local repo_url="$1"
    local repo_folder="$2"
    local target_branch="${3:-}"
    local auth_token="${GITHUB_TOKEN:-}"

    log_info "Monorepo cache creation/update requested"
    log_info "Repository: $repo_url"
    log_info "Folder: $repo_folder"
    log_info "Branch: ${target_branch:-auto-detect}"

    local auth_url=$(get_auth_url "$repo_url" "$auth_token")
    local repo_hash=$(get_repo_hash "$repo_url")
    local cache_dir="$MONOREPO_CACHE/$repo_hash"

    log_info "Cache directory: $cache_dir"

    if [ -d "$cache_dir/.git" ]; then
        log_info "Monorepo cache exists. Pulling latest changes..."
        cd "$cache_dir"

        git fetch origin 2>&1 || true

        local branch="$target_branch"
        if [ -z "$branch" ]; then
            branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
        fi

        git checkout "$branch" 2>&1 || true
        git pull origin "$branch" 2>&1 || log_warn "Pull failed, using current state"

        log_info "Successfully pulled latest changes to cache"
    else
        log_info "Cloning monorepo to cache for the first time..."
        mkdir -p "$MONOREPO_CACHE"

        if git clone "$auth_url" "$cache_dir" 2>&1; then
            log_info "Successfully cloned monorepo to cache"
            cd "$cache_dir"

            if [ -n "$auth_token" ]; then
                git remote set-url origin "$auth_url"
            fi

            if [ -n "$target_branch" ]; then
                log_info "Checking out branch: $target_branch"
                git checkout "$target_branch" 2>&1 || true
            fi
        else
            log_error "Failed to clone monorepo"
            return 1
        fi
    fi

    # Validate folder exists
    if [ ! -d "$cache_dir/$repo_folder" ]; then
        log_error "Folder '$repo_folder' not found in repository"
        ls -la "$cache_dir/" || true
        return 1
    fi

    MONOREPO_CACHE_DIR="$cache_dir"
    log_info "Monorepo cache ready at: $MONOREPO_CACHE_DIR"
    return 0
}

# Run main function (only if not being sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main
fi
