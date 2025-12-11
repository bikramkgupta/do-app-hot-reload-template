#!/usr/bin/env bash
# Job Manager for PRE_DEPLOY and POST_DEPLOY hooks
# Handles job execution at deployment lifecycle points
# Only executes jobs when git commit changes (not every sync)

set -euo pipefail

# Configuration from environment variables
WORKSPACE="${WORKSPACE_PATH:-/workspaces/app}"
REPO_URL="${GITHUB_REPO_URL:-}"
REPO_FOLDER="${GITHUB_REPO_FOLDER:-}"
AUTH_TOKEN="${GITHUB_TOKEN:-}"

# Job configuration
PRE_DEPLOY_REPO_URL="${PRE_DEPLOY_REPO_URL:-}"
PRE_DEPLOY_FOLDER="${PRE_DEPLOY_FOLDER:-}"
PRE_DEPLOY_COMMAND="${PRE_DEPLOY_COMMAND:-}"
PRE_DEPLOY_TIMEOUT="${PRE_DEPLOY_TIMEOUT:-300}"

POST_DEPLOY_REPO_URL="${POST_DEPLOY_REPO_URL:-}"
POST_DEPLOY_FOLDER="${POST_DEPLOY_FOLDER:-}"
POST_DEPLOY_COMMAND="${POST_DEPLOY_COMMAND:-}"
POST_DEPLOY_TIMEOUT="${POST_DEPLOY_TIMEOUT:-300}"

# Tracking files
LAST_JOB_COMMIT_FILE="/tmp/last_job_commit.txt"
JOB_REPOS_DIR="/tmp/job-repos"
MONOREPO_CACHE="/tmp/monorepo-cache"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_job() {
    local job_type="$1"
    shift
    echo -e "${GREEN}[${job_type}]${NC} $*"
}

log_job_warn() {
    local job_type="$1"
    shift
    echo -e "${YELLOW}[${job_type}]${NC} $*"
}

log_job_error() {
    local job_type="$1"
    shift
    echo -e "${RED}[${job_type}]${NC} $*"
}

# Generate unique hash for repo URL
get_repo_hash() {
    echo "$1" | md5sum | cut -d' ' -f1
}

# Get current commit SHA from workspace or monorepo cache
get_current_commit_sha() {
    local sha=""

    # Determine where to get SHA from
    if [ -n "$REPO_FOLDER" ]; then
        # Monorepo mode - use cache directory
        local repo_hash=$(get_repo_hash "$REPO_URL")
        local cache_dir="$MONOREPO_CACHE/$repo_hash"

        if [ -d "$cache_dir/.git" ]; then
            sha=$(cd "$cache_dir" && git rev-parse HEAD 2>/dev/null || echo "")
        fi
    else
        # Regular mode - use workspace
        if [ -d "$WORKSPACE/.git" ]; then
            sha=$(cd "$WORKSPACE" && git rev-parse HEAD 2>/dev/null || echo "")
        fi
    fi

    echo "$sha"
}

# Check if commit has changed since last job execution
# Returns 0 (success) if commit changed, 1 if unchanged
check_commit_changed() {
    local current_sha=$(get_current_commit_sha)

    if [ -z "$current_sha" ]; then
        # No git repo found - treat as unchanged to avoid errors
        return 1
    fi

    if [ ! -f "$LAST_JOB_COMMIT_FILE" ]; then
        # No previous commit recorded - treat as changed
        return 0
    fi

    local last_sha=$(cat "$LAST_JOB_COMMIT_FILE" 2>/dev/null || echo "")

    if [ "$current_sha" != "$last_sha" ]; then
        # Commit changed
        return 0
    else
        # Commit unchanged
        return 1
    fi
}

# Update last job commit SHA file
update_last_job_commit() {
    local current_sha=$(get_current_commit_sha)

    if [ -n "$current_sha" ]; then
        echo "$current_sha" > "$LAST_JOB_COMMIT_FILE"
    fi
}

# Clone or update job repository (for multi-repo pattern)
# Args: $1=repo_url, $2=repo_dir
clone_or_update_job_repo() {
    local job_repo_url="$1"
    local job_repo_dir="$2"
    local job_type="$3"

    # Inject auth token if provided
    local job_repo_url_with_auth="$job_repo_url"
    if [ -n "$AUTH_TOKEN" ]; then
        if [[ "$job_repo_url" == https://* ]]; then
            local clean_url="${job_repo_url#https://}"
            clean_url="${clean_url#*@}"
            job_repo_url_with_auth="https://${AUTH_TOKEN}@${clean_url}"
        fi
    fi

    if [ -d "$job_repo_dir/.git" ]; then
        # Repo exists - pull latest
        log_job "$job_type" "Updating job repository..."
        cd "$job_repo_dir"

        if git fetch origin 2>&1; then
            local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
            if git pull origin "$current_branch" 2>&1; then
                log_job "$job_type" "Job repository updated successfully"
                return 0
            else
                log_job_error "$job_type" "Failed to pull job repository"
                return 1
            fi
        else
            log_job_error "$job_type" "Failed to fetch from job repository"
            return 1
        fi
    else
        # Clone for first time
        log_job "$job_type" "Cloning job repository..."
        mkdir -p "$(dirname "$job_repo_dir")"

        if git clone "$job_repo_url_with_auth" "$job_repo_dir" 2>&1; then
            log_job "$job_type" "Job repository cloned successfully"

            # Configure remote URL with auth token for future pulls
            if [ -n "$AUTH_TOKEN" ]; then
                cd "$job_repo_dir"
                git remote set-url origin "$job_repo_url_with_auth" 2>/dev/null || true
            fi

            return 0
        else
            log_job_error "$job_type" "Failed to clone job repository"
            return 1
        fi
    fi
}

# Execute job (PRE_DEPLOY or POST_DEPLOY)
# Args: $1=JOB_TYPE ("PRE_DEPLOY" or "POST_DEPLOY")
execute_job() {
    local job_type="$1"

    # Determine job configuration based on type
    local job_repo_url=""
    local job_folder=""
    local job_command=""
    local job_timeout=""

    if [ "$job_type" = "PRE_DEPLOY" ]; then
        job_repo_url="$PRE_DEPLOY_REPO_URL"
        job_folder="$PRE_DEPLOY_FOLDER"
        job_command="$PRE_DEPLOY_COMMAND"
        job_timeout="$PRE_DEPLOY_TIMEOUT"
    elif [ "$job_type" = "POST_DEPLOY" ]; then
        job_repo_url="$POST_DEPLOY_REPO_URL"
        job_folder="$POST_DEPLOY_FOLDER"
        job_command="$POST_DEPLOY_COMMAND"
        job_timeout="$POST_DEPLOY_TIMEOUT"
    else
        log_job_error "$job_type" "Unknown job type: $job_type"
        return 1
    fi

    # Validate job configuration
    if [ -z "$job_command" ]; then
        log_job_error "$job_type" "Job command not configured"
        return 1
    fi

    log_job "$job_type" "Starting job execution..."
    log_job "$job_type" "Command: $job_command"
    log_job "$job_type" "Timeout: ${job_timeout}s"

    # Determine job execution directory
    local job_exec_dir=""

    # Pattern 1: Multi-repo (job_repo_url is set)
    if [ -n "$job_repo_url" ]; then
        log_job "$job_type" "Using multi-repo pattern (separate job repository)"

        local job_repo_hash=$(get_repo_hash "$job_repo_url")
        local job_repo_dir="$JOB_REPOS_DIR/$job_repo_hash"

        # Clone or update job repository
        if ! clone_or_update_job_repo "$job_repo_url" "$job_repo_dir" "$job_type"; then
            log_job_error "$job_type" "Failed to prepare job repository"
            return 1
        fi

        job_exec_dir="$job_repo_dir"
        if [ -n "$job_folder" ]; then
            job_exec_dir="$job_repo_dir/$job_folder"
        fi

    # Pattern 2: Monorepo (main repo uses GITHUB_REPO_FOLDER)
    elif [ -n "$REPO_FOLDER" ]; then
        log_job "$job_type" "Using monorepo pattern (same repo, cache directory)"

        local repo_hash=$(get_repo_hash "$REPO_URL")
        local cache_dir="$MONOREPO_CACHE/$repo_hash"

        if [ ! -d "$cache_dir" ]; then
            log_job_error "$job_type" "Monorepo cache not found: $cache_dir"
            return 1
        fi

        # Base directory includes REPO_FOLDER for monorepo pattern
        job_exec_dir="$cache_dir/$REPO_FOLDER"

        # Add job folder if specified
        if [ -n "$job_folder" ]; then
            job_exec_dir="$job_exec_dir/$job_folder"
        fi

    # Pattern 3: Same-repo (job_repo_url empty, regular mode)
    else
        log_job "$job_type" "Using same-repo pattern (main application workspace)"

        job_exec_dir="$WORKSPACE"
        if [ -n "$job_folder" ]; then
            job_exec_dir="$WORKSPACE/$job_folder"
        fi
    fi

    # Validate execution directory exists
    if [ ! -d "$job_exec_dir" ]; then
        log_job_error "$job_type" "Job execution directory not found: $job_exec_dir"
        return 1
    fi

    log_job "$job_type" "Execution directory: $job_exec_dir"

    # Execute job with timeout
    log_job "$job_type" "Executing command..."

    local exit_code=0
    cd "$job_exec_dir"

    if timeout "${job_timeout}" bash -c "$job_command" 2>&1; then
        log_job "$job_type" "Job completed successfully"
        return 0
    else
        exit_code=$?

        if [ $exit_code -eq 124 ]; then
            log_job_error "$job_type" "Job timed out after ${job_timeout}s"
        else
            log_job_error "$job_type" "Job failed with exit code $exit_code"
        fi

        return 1
    fi
}

# Main CLI interface
main() {
    local command="${1:-}"

    case "$command" in
        check_commit_changed)
            check_commit_changed
            ;;

        update_last_job_commit)
            update_last_job_commit
            ;;

        execute)
            local job_type="${2:-}"
            if [ -z "$job_type" ]; then
                echo "ERROR: Job type not specified (PRE_DEPLOY or POST_DEPLOY)"
                exit 1
            fi
            execute_job "$job_type"
            ;;

        *)
            echo "Usage: $0 {check_commit_changed|update_last_job_commit|execute PRE_DEPLOY|execute POST_DEPLOY}"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
