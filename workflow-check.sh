#!/usr/bin/env bash
# workflow-check.sh
# Validates current folder context and workflow state
#
# Usage:
#   ./workflow-check.sh                    # Check current folder context
#   ./workflow-check.sh --verbose           # Detailed information

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Validates current folder context and workflow state."
            echo ""
            echo "Options:"
            echo "  --verbose, -v         Show detailed information"
            echo "  --help, -h            Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown argument: $1${NC}" >&2
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Workflow Context Check${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Get current directory
CURRENT_DIR=$(pwd)
echo -e "${GREEN}Current Directory:${NC} $CURRENT_DIR"
echo ""

# Check if we're in the root workspace
WORKSPACE_ROOT="/workspaces/app"
if [[ "$CURRENT_DIR" == "$WORKSPACE_ROOT" ]] || [[ "$CURRENT_DIR" == "$WORKSPACE_ROOT"/* ]]; then
    # Extract relative path from workspace root
    if [[ "$CURRENT_DIR" == "$WORKSPACE_ROOT" ]]; then
        RELATIVE_PATH="."
        FOLDER_NAME="root workspace"
    else
        RELATIVE_PATH="${CURRENT_DIR#$WORKSPACE_ROOT/}"
        FOLDER_NAME=$(basename "$RELATIVE_PATH")
    fi
else
    # Not in workspace, use actual path
    RELATIVE_PATH=$(basename "$CURRENT_DIR")
    FOLDER_NAME="$RELATIVE_PATH"
fi

# Determine folder type
FOLDER_TYPE="unknown"
HAS_APP_YAML=false
HAS_DOCKERFILE=false
HAS_PACKAGE_JSON=false
HAS_REQUIREMENTS_TXT=false
HAS_GO_MOD=false
HAS_DEVCONTAINER=false

if [[ -f "app.yaml" ]] || [[ -f ".do/app.yaml" ]]; then
    HAS_APP_YAML=true
fi

if [[ -f "Dockerfile" ]]; then
    HAS_DOCKERFILE=true
fi

if [[ -f "package.json" ]]; then
    HAS_PACKAGE_JSON=true
fi

if [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
    HAS_REQUIREMENTS_TXT=true
fi

if [[ -f "go.mod" ]]; then
    HAS_GO_MOD=true
fi

if [[ -d ".devcontainer" ]] || [[ -f "devcontainer.json" ]]; then
    HAS_DEVCONTAINER=true
fi

# Determine folder type based on contents
if [[ "$FOLDER_NAME" == "." ]] || [[ "$FOLDER_NAME" == "root workspace" ]]; then
    FOLDER_TYPE="root"
    echo -e "${YELLOW}⚠ Folder Type:${NC} Root workspace (umbrella container)"
    echo -e "${YELLOW}  Note:${NC} This is not a deployable application"
    echo -e "${YELLOW}  Action:${NC} Navigate to a subfolder to work on a specific project"
elif [[ "$FOLDER_NAME" == "hot-reload-template" ]]; then
    FOLDER_TYPE="template"
    echo -e "${GREEN}✓ Folder Type:${NC} App Dev Template"
    echo -e "${GREEN}  Purpose:${NC} Rapid iteration template for App Platform"
elif [[ -f "app.yaml" ]] && [[ -f "Dockerfile" ]] && [[ -d "scripts" ]]; then
    FOLDER_TYPE="template"
    echo -e "${GREEN}✓ Folder Type:${NC} App Dev Template (detected)"
elif [[ -f "app.yaml" ]] || [[ -f ".do/app.yaml" ]]; then
    if [[ -f "package.json" ]] || [[ -f "requirements.txt" ]] || [[ -f "go.mod" ]]; then
        FOLDER_TYPE="end-user-app"
        echo -e "${GREEN}✓ Folder Type:${NC} End-User Application"
    else
        FOLDER_TYPE="template"
        echo -e "${GREEN}✓ Folder Type:${NC} Template or Configuration"
    fi
elif [[ "$HAS_DEVCONTAINER" == true ]]; then
    FOLDER_TYPE="devcontainer"
    echo -e "${BLUE}ℹ Folder Type:${NC} DevContainer Configuration"
else
    echo -e "${YELLOW}⚠ Folder Type:${NC} Unknown or incomplete project"
fi

echo ""

# Check for key files
echo -e "${BLUE}Project Files:${NC}"
if [[ "$HAS_APP_YAML" == true ]]; then
    if [[ -f "app.yaml" ]]; then
        echo -e "  ${GREEN}✓${NC} app.yaml found"
    elif [[ -f ".do/app.yaml" ]]; then
        echo -e "  ${GREEN}✓${NC} .do/app.yaml found"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} No app.yaml found (may need to specify --app ID)"
fi

if [[ "$HAS_DOCKERFILE" == true ]]; then
    echo -e "  ${GREEN}✓${NC} Dockerfile found"
fi

if [[ "$HAS_PACKAGE_JSON" == true ]]; then
    echo -e "  ${GREEN}✓${NC} package.json found (Node.js project)"
fi

if [[ "$HAS_REQUIREMENTS_TXT" == true ]]; then
    echo -e "  ${GREEN}✓${NC} Python project detected"
fi

if [[ "$HAS_GO_MOD" == true ]]; then
    echo -e "  ${GREEN}✓${NC} go.mod found (Go project)"
fi

echo ""

# Check git status
if [[ -d ".git" ]]; then
    echo -e "${BLUE}Git Status:${NC}"
    if command -v git &> /dev/null; then
        BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
        echo -e "  Branch: $BRANCH"
        
        if [[ "$VERBOSE" == true ]]; then
            STATUS=$(git status --short 2>/dev/null || echo "")
            if [[ -n "$STATUS" ]]; then
                echo -e "  ${YELLOW}Uncommitted changes:${NC}"
                echo "$STATUS" | sed 's/^/    /'
            else
                echo -e "  ${GREEN}✓${NC} Working directory clean"
            fi
        fi
    fi
else
    echo -e "${YELLOW}⚠${NC} Not a git repository"
fi

echo ""

# Check for required tools
echo -e "${BLUE}Required Tools:${NC}"

if command -v doctl &> /dev/null; then
    DOCTL_VERSION=$(doctl version --format Version 2>/dev/null || echo "unknown")
    echo -e "  ${GREEN}✓${NC} doctl installed (version: $DOCTL_VERSION)"
    
    # Check authentication
    if doctl auth list &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} doctl authenticated"
    else
        echo -e "  ${RED}✗${NC} doctl not authenticated (run: doctl auth init)"
    fi
else
    echo -e "  ${RED}✗${NC} doctl not installed"
    echo -e "    Install: https://docs.digitalocean.com/products/app-platform/how-to/install-doctl/"
fi

if command -v docker &> /dev/null; then
    if docker info &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Docker installed and running"
    else
        echo -e "  ${RED}✗${NC} Docker installed but not running"
    fi
else
    echo -e "  ${RED}✗${NC} Docker not installed"
fi

echo ""

# Workflow recommendations
echo -e "${BLUE}Workflow Recommendations:${NC}"

if [[ "$FOLDER_TYPE" == "root" ]]; then
    echo -e "  ${YELLOW}→${NC} Navigate to a project subfolder to start working"
    echo -e "  ${YELLOW}→${NC} Each subfolder represents a separate GitHub repository"
elif [[ "$FOLDER_TYPE" == "end-user-app" ]]; then
    echo -e "  ${GREEN}→${NC} Ready for local development"
    echo -e "  ${GREEN}→${NC} Workflow: Local Dev → DO Build → GitHub → Testing → Production"
    if [[ "$HAS_APP_YAML" == true ]]; then
        echo -e "  ${GREEN}→${NC} Build locally: ./build-locally.sh"
    fi
elif [[ "$FOLDER_TYPE" == "template" ]]; then
    echo -e "  ${GREEN}→${NC} Template development mode"
    echo -e "  ${GREEN}→${NC} Modify template files, test locally, push to template repo"
    if [[ "$HAS_APP_YAML" == true ]]; then
        echo -e "  ${GREEN}→${NC} Build locally: ./build-locally.sh"
    fi
elif [[ "$FOLDER_TYPE" == "devcontainer" ]]; then
    echo -e "  ${BLUE}→${NC} DevContainer configuration"
    echo -e "  ${BLUE}→${NC} Modify docker-compose.yml, post-create.sh, etc."
    echo -e "  ${BLUE}→${NC} Rebuild container to apply changes"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Exit with appropriate code
if [[ "$FOLDER_TYPE" == "unknown" ]]; then
    exit 1
else
    exit 0
fi

