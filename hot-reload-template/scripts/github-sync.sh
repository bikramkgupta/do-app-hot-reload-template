#!/usr/bin/env bash
# GitHub Repository Sync Script
# Clones or syncs a GitHub repository to the workspace
# Supports monorepos with subfolder syncing

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
    if rsync -a --delete "$cache_dir/$folder_path/" "$target_workspace/"; then
        log_info "Folder sync completed successfully"
        return 0
    else
        log_error "Failed to sync folder"
        return 1
    fi
}

# Function to clone or sync repository
sync_repo() {
    if [ -z "$REPO_URL" ]; then
        log_info "GITHUB_REPO_URL not set. Waiting for configuration..."
        return 0
    fi

    # Inject auth token if provided
    if [ -n "$AUTH_TOKEN" ]; then
        # Handle HTTPS URL: insert token into URL
        # Format: https://token@github.com/user/repo
        if [[ "$REPO_URL" == https://* ]]; then
            # Remove existing protocol and potential auth
            CLEAN_URL="${REPO_URL#https://}"
            CLEAN_URL="${CLEAN_URL#*@}"
            REPO_URL_WITH_AUTH="https://${AUTH_TOKEN}@${CLEAN_URL}"
        else
            REPO_URL_WITH_AUTH="$REPO_URL"
        fi
    else
        REPO_URL_WITH_AUTH="$REPO_URL"
    fi

    log_info "Repository URL: $REPO_URL"

    # Determine target branch
    TARGET_BRANCH="$REPO_BRANCH"

    # MONOREPO MODE: Clone to cache and sync specific folder
    if [ -n "$REPO_FOLDER" ]; then
        log_info "Monorepo mode enabled"
        log_info "Target folder: $REPO_FOLDER"
        log_info "Target branch: ${TARGET_BRANCH:-auto-detect}"

        # Create cache directory based on repo URL hash
        REPO_HASH=$(get_repo_hash "$REPO_URL")
        CACHE_DIR="$MONOREPO_CACHE/$REPO_HASH"

        log_info "Cache directory: $CACHE_DIR"

        # Check if repo already cloned to cache
        if [ -d "$CACHE_DIR/.git" ]; then
            log_info "Monorepo cache exists. Pulling latest changes..."
            cd "$CACHE_DIR"

            # Fetch latest changes
            if git fetch origin 2>&1; then
                # Determine which branch to use
                if [ -n "$TARGET_BRANCH" ]; then
                    CURRENT_BRANCH="$TARGET_BRANCH"
                    log_info "Switching to branch: $CURRENT_BRANCH"
                    git checkout "$CURRENT_BRANCH" 2>&1 || log_warn "Failed to checkout branch: $CURRENT_BRANCH"
                else
                    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
                    log_info "Current branch: $CURRENT_BRANCH"
                fi

                # Check if branch is behind before attempting pull
                LOCAL_COMMIT=$(git rev-parse HEAD)
                REMOTE_COMMIT=$(git rev-parse "origin/$CURRENT_BRANCH" 2>/dev/null || echo "")
                
                if [ -n "$REMOTE_COMMIT" ] && [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
                    if git merge-base --is-ancestor "$LOCAL_COMMIT" "$REMOTE_COMMIT" 2>/dev/null; then
                        log_info "Branch is behind. Preparing for fast-forward..."
                    fi
                fi
                
                # Pull latest changes
                if git pull origin "$CURRENT_BRANCH" 2>&1; then
                    log_info "Successfully pulled latest changes to cache"
                else
                    log_warn "Failed to pull changes. Will attempt folder sync anyway."
                fi
            else
                log_error "Failed to fetch from remote repository"
            fi
        else
            log_info "Cloning monorepo to cache for the first time..."

            # Create cache parent directory
            mkdir -p "$MONOREPO_CACHE"

            # Clone the repository to cache
            if git clone "$REPO_URL_WITH_AUTH" "$CACHE_DIR" 2>&1; then
                log_info "Successfully cloned monorepo to cache"
                cd "$CACHE_DIR"

                # If we used a token, configure the remote to use it for future pulls
                if [ -n "$AUTH_TOKEN" ]; then
                    git remote set-url origin "$REPO_URL_WITH_AUTH"
                fi

                # Checkout specific branch if requested
                if [ -n "$TARGET_BRANCH" ]; then
                    log_info "Checking out branch: $TARGET_BRANCH"
                    git checkout "$TARGET_BRANCH" 2>&1 || log_warn "Failed to checkout branch: $TARGET_BRANCH"
                fi
            else
                log_error "Failed to clone monorepo"
                return 1
            fi
        fi

        # Sync the specific folder to workspace
        if sync_monorepo_folder "$CACHE_DIR" "$REPO_FOLDER" "$WORKSPACE"; then
            log_info "Monorepo folder synced successfully"
        else
            log_error "Failed to sync monorepo folder"
            return 1
        fi

        # Show current commit
        if [ -d "$CACHE_DIR/.git" ]; then
            cd "$CACHE_DIR"
            CURRENT_COMMIT=$(git rev-parse --short HEAD)
            COMMIT_MSG=$(git log -1 --pretty=%B)
            log_info "Current commit: $CURRENT_COMMIT - $COMMIT_MSG"
        fi

    # REGULAR MODE: Clone directly to workspace
    else
        log_info "Regular mode (single repository)"
        log_info "Workspace: $WORKSPACE"
        log_info "Target branch: ${TARGET_BRANCH:-auto-detect}"

        if [ -d "$WORKSPACE/.git" ]; then
            log_info "Repository already exists. Pulling latest changes..."
            cd "$WORKSPACE"

            # Fetch latest changes
            if git fetch origin 2>&1; then
                # Determine which branch to use
                if [ -n "$TARGET_BRANCH" ]; then
                    CURRENT_BRANCH="$TARGET_BRANCH"
                    log_info "Switching to branch: $CURRENT_BRANCH"
                    git checkout "$CURRENT_BRANCH" 2>&1 || log_warn "Failed to checkout branch: $CURRENT_BRANCH"
                else
                    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
                    log_info "Current branch: $CURRENT_BRANCH"
                fi

                # Check if branch is behind before attempting pull
                LOCAL_COMMIT=$(git rev-parse HEAD)
                REMOTE_COMMIT=$(git rev-parse "origin/$CURRENT_BRANCH" 2>/dev/null || echo "")
                
                if [ -n "$REMOTE_COMMIT" ] && [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
                    # Check if we can fast-forward (branch is behind)
                    if git merge-base --is-ancestor "$LOCAL_COMMIT" "$REMOTE_COMMIT" 2>/dev/null; then
                        log_info "Branch is behind. Local changes detected. Preparing for fast-forward..."
                        
                        # Proactively handle lock files since they'll be regenerated anyway
                        # This prevents pull failures due to local modifications
                        LOCK_FILES_MODIFIED=false
                        for lockfile in package-lock.json go.sum uv.lock poetry.lock Gemfile.lock; do
                            if git diff --quiet "$lockfile" 2>/dev/null; then
                                continue  # File not modified
                            fi
                            if [ -f "$lockfile" ]; then
                                log_info "Detected local changes to $lockfile. Removing to allow fast-forward (will be regenerated)..."
                                git checkout -- "$lockfile" 2>/dev/null || rm -f "$lockfile"
                                LOCK_FILES_MODIFIED=true
                            fi
                        done
                        
                        # Also handle other common generated files
                        for genfile in .npmrc node_modules/.package-lock.json; do
                            if [ -f "$genfile" ] && ! git diff --quiet "$genfile" 2>/dev/null 2>&1; then
                                log_info "Resetting local changes to $genfile..."
                                git checkout -- "$genfile" 2>/dev/null || true
                            fi
                        done
                    fi
                fi
                
                # Pull latest changes
                PULL_OUTPUT=$(git pull origin "$CURRENT_BRANCH" 2>&1)
                PULL_EXIT_CODE=$?
                if [ "$PULL_EXIT_CODE" -eq 0 ]; then
                    log_info "Successfully pulled latest changes"
                else
                    # Check if the error is due to merge conflicts in lock files
                    if echo "$PULL_OUTPUT" | grep -q "would be overwritten by merge"; then
                        log_warn "Merge conflict detected in tracked files. Attempting to resolve lock file conflicts..."
                        # Detect and resolve common lock file conflicts
                        if echo "$PULL_OUTPUT" | grep -q "package-lock.json"; then
                            log_info "Resolving package-lock.json conflict..."
                            git checkout -- package-lock.json 2>/dev/null || rm -f package-lock.json 2>/dev/null || true
                        fi
                        if echo "$PULL_OUTPUT" | grep -q "go.sum"; then
                            log_info "Resolving go.sum conflict..."
                            git checkout -- go.sum 2>/dev/null || rm -f go.sum 2>/dev/null || true
                        fi
                        if echo "$PULL_OUTPUT" | grep -q "uv.lock"; then
                            log_info "Resolving uv.lock conflict..."
                            git checkout -- uv.lock 2>/dev/null || rm -f uv.lock 2>/dev/null || true
                        fi
                        if echo "$PULL_OUTPUT" | grep -q "poetry.lock"; then
                            log_info "Resolving poetry.lock conflict..."
                            git checkout -- poetry.lock 2>/dev/null || rm -f poetry.lock 2>/dev/null || true
                        fi
                        if echo "$PULL_OUTPUT" | grep -q "Gemfile.lock"; then
                            log_info "Resolving Gemfile.lock conflict..."
                            git checkout -- Gemfile.lock 2>/dev/null || rm -f Gemfile.lock 2>/dev/null || true
                        fi
                        # Try pull again after resolving conflicts
                        if git pull origin "$CURRENT_BRANCH" 2>&1; then
                            log_info "Successfully pulled after resolving lock file conflicts"
                        else
                            log_warn "Failed to pull changes even after resolving conflicts. Repository may have other local modifications."
                        fi
                    elif echo "$PULL_OUTPUT" | grep -qi "cannot pull with rebase\|cannot pull\|your local changes"; then
                        # Another common error - local changes preventing pull
                        log_warn "Local changes preventing pull. Attempting to reset lock files and retry..."
                        for lockfile in package-lock.json go.sum uv.lock poetry.lock Gemfile.lock; do
                            if [ -f "$lockfile" ] && ! git diff --quiet "$lockfile" 2>/dev/null; then
                                log_info "Resetting $lockfile to allow pull..."
                                git checkout -- "$lockfile" 2>/dev/null || rm -f "$lockfile"
                            fi
                        done
                        # Try pull again
                        if git pull origin "$CURRENT_BRANCH" 2>&1; then
                            log_info "Successfully pulled after resetting lock files"
                        else
                            log_warn "Failed to pull changes. Repository may have other local modifications."
                        fi
                    else
                        log_warn "Failed to pull changes: $PULL_OUTPUT"
                    fi
                fi
            else
                log_error "Failed to fetch from remote repository"
            fi
        else
            log_info "Cloning repository for the first time..."

            # Create workspace directory if it doesn't exist
            mkdir -p "$WORKSPACE"

            # Clean up any existing files (image ships with template sources)
            if [ "$(ls -A "$WORKSPACE")" ]; then
                log_warn "Workspace not empty. Cleaning existing files before cloning..."
                rm -rf "${WORKSPACE:?}/"* "${WORKSPACE:?}"/.[!.]* "${WORKSPACE:?}"/..?*
            fi

            # Clone the repository
            if git clone "$REPO_URL_WITH_AUTH" "$WORKSPACE" 2>&1; then
                log_info "Successfully cloned repository"
                cd "$WORKSPACE"

                # If we used a token, configure the remote to use it for future pulls
                if [ -n "$AUTH_TOKEN" ]; then
                    git remote set-url origin "$REPO_URL_WITH_AUTH"
                fi

                # Checkout specific branch if requested
                if [ -n "$TARGET_BRANCH" ]; then
                    log_info "Checking out branch: $TARGET_BRANCH"
                    git checkout "$TARGET_BRANCH" 2>&1 || log_warn "Failed to checkout branch: $TARGET_BRANCH"
                fi
            else
                log_error "Failed to clone repository"
                return 1
            fi
        fi

        # Check for any remaining merge conflict markers in lock files
        if [ -d "$WORKSPACE/.git" ]; then
            cd "$WORKSPACE"
            for lockfile in package-lock.json go.sum uv.lock poetry.lock Gemfile.lock; do
                if [ -f "$lockfile" ]; then
                    if grep -q "^<<<<<<< " "$lockfile" 2>/dev/null || \
                       grep -q "^======= " "$lockfile" 2>/dev/null || \
                       grep -q "^>>>>>>> " "$lockfile" 2>/dev/null; then
                        log_warn "Detected merge conflict markers in $lockfile. Removing to allow regeneration..."
                        rm -f "$lockfile"
                    fi
                fi
            done
        fi

        # Show current commit
        if [ -d "$WORKSPACE/.git" ]; then
            CURRENT_COMMIT=$(git rev-parse --short HEAD)
            COMMIT_MSG=$(git log -1 --pretty=%B)
            log_info "Current commit: $CURRENT_COMMIT - $COMMIT_MSG"
        fi

        # Auto-install dependencies if dependency files changed
        if [ -d "$WORKSPACE/.git" ]; then
            cd "$WORKSPACE"
            
            # Ruby/Bundler: Check if Gemfile or Gemfile.lock changed
            if [ -f "Gemfile" ]; then
                GEMFILE_HASH_FILE="/tmp/github_sync_gemfile_hash.txt"
                CURRENT_GEMFILE_HASH=$(md5sum Gemfile 2>/dev/null | cut -d' ' -f1 || echo "")
                
                if [ -n "$CURRENT_GEMFILE_HASH" ]; then
                    PREVIOUS_HASH=$(cat "$GEMFILE_HASH_FILE" 2>/dev/null || echo "")
                    # Also check if Gemfile.lock is missing or has conflicts (indicates need for bundle install)
                    NEEDS_BUNDLE_INSTALL=false
                    if [ "$CURRENT_GEMFILE_HASH" != "$PREVIOUS_HASH" ]; then
                        NEEDS_BUNDLE_INSTALL=true
                        log_info "Detected Gemfile changes. Running bundle install..."
                    elif [ ! -f "Gemfile.lock" ]; then
                        NEEDS_BUNDLE_INSTALL=true
                        log_info "Gemfile.lock missing. Running bundle install..."
                    elif grep -q "^<<<<<<< " "Gemfile.lock" 2>/dev/null || \
                         grep -q "^=======$" "Gemfile.lock" 2>/dev/null || \
                         grep -q "^>>>>>>> " "Gemfile.lock" 2>/dev/null; then
                        NEEDS_BUNDLE_INSTALL=true
                        log_info "Gemfile.lock has merge conflicts. Running bundle install..."
                    fi
                    
                    if [ "$NEEDS_BUNDLE_INSTALL" = "true" ]; then
                        
                        # Setup Ruby environment if rbenv is available
                        # Try multiple common locations for rbenv
                        RBENV_ROOT=""
                        for rbenv_path in "$HOME/.rbenv" "/home/devcontainer/.rbenv" "/root/.rbenv"; do
                            if [ -d "$rbenv_path" ] && [ -x "$rbenv_path/bin/rbenv" ]; then
                                RBENV_ROOT="$rbenv_path"
                                break
                            fi
                        done
                        
                        RUBY_READY=false
                        if [ -n "$RBENV_ROOT" ]; then
                            export RBENV_ROOT
                            export PATH="$RBENV_ROOT/bin:$RBENV_ROOT/shims:$PATH"
                            eval "$($RBENV_ROOT/bin/rbenv init - bash)" 2>/dev/null || true
                            
                            # Check if Ruby and bundle actually work (not just exist)
                            if command -v ruby >/dev/null 2>&1 && command -v bundle >/dev/null 2>&1; then
                                # Test that Ruby actually executes (not broken paths)
                                if ruby -v >/dev/null 2>&1 && bundle --version >/dev/null 2>&1; then
                                    RUBY_READY=true
                                fi
                            fi
                        elif command -v ruby >/dev/null 2>&1 && command -v bundle >/dev/null 2>&1; then
                            # System Ruby/bundler - test they work
                            if ruby -v >/dev/null 2>&1 && bundle --version >/dev/null 2>&1; then
                                RUBY_READY=true
                                log_info "Using system Ruby/bundler"
                            fi
                        fi
                        
                        if [ "$RUBY_READY" = "true" ]; then
                            # Handle Gemfile.lock merge conflicts
                            if [ -f "Gemfile.lock" ]; then
                                if grep -q "^<<<<<<< " "Gemfile.lock" 2>/dev/null || \
                                   grep -q "^=======$" "Gemfile.lock" 2>/dev/null || \
                                   grep -q "^>>>>>>> " "Gemfile.lock" 2>/dev/null; then
                                    log_warn "Detected merge conflict markers in Gemfile.lock. Removing to allow regeneration..."
                                    rm -f Gemfile.lock
                                fi
                            fi
                            
                            # Run bundle install
                            if bundle install --jobs=4 --retry=3 2>&1; then
                                log_info "Bundle install completed successfully"
                                echo "$CURRENT_GEMFILE_HASH" > "$GEMFILE_HASH_FILE"
                            else
                                log_warn "Bundle install failed. Attempting hard rebuild..."
                                rm -f Gemfile.lock
                                rm -rf vendor/bundle .bundle 2>/dev/null || true
                                if bundle install --jobs=4 --retry=3 2>&1; then
                                    log_info "Bundle install completed after hard rebuild"
                                    echo "$CURRENT_GEMFILE_HASH" > "$GEMFILE_HASH_FILE"
                                else
                                    log_warn "Bundle install failed even after hard rebuild"
                                    log_warn "  (dev_startup.sh will retry on next app restart)"
                                fi
                            fi
                        else
                            log_warn "Ruby/bundler not ready. Skipping bundle install."
                            log_warn "  (Ruby may still be installing. dev_startup.sh will handle bundle install.)"
                        fi
                    fi
                fi
            fi
        fi
    fi

    # Execute deploy jobs if commit changed
    execute_deploy_jobs
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

    # Check if commit actually changed
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

    # Initial sync
    sync_repo

    # Continuous sync loop
    while true; do
        log_info "Waiting ${SYNC_INTERVAL}s before next sync..."
        sleep "$SYNC_INTERVAL"
        sync_repo
    done
}

# Run main function
main
