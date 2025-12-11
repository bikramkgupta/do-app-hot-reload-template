#!/usr/bin/env bash
# build-locally.sh
# Wrapper for `doctl app dev build` with common options and helpful defaults
#
# Usage:
#   ./build-locally.sh                    # Build using .do/app.yaml or prompt for app ID
#   ./build-locally.sh my-component        # Build specific component
#   ./build-locally.sh --spec app.yaml     # Use custom spec file
#   ./build-locally.sh --env-file .env     # Use environment file

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
COMPONENT=""
SPEC_FILE=""
ENV_FILE=""
BUILD_COMMAND=""
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --spec)
            SPEC_FILE="$2"
            shift 2
            ;;
        --env-file)
            ENV_FILE="$2"
            shift 2
            ;;
        --build-command)
            BUILD_COMMAND="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [component] [options]"
            echo ""
            echo "Build a DigitalOcean App Platform component locally using buildpack containers."
            echo ""
            echo "Arguments:"
            echo "  component              Component name to build (optional)"
            echo ""
            echo "Options:"
            echo "  --spec FILE           Path to app spec file (default: .do/app.yaml)"
            echo "  --env-file FILE       Path to .env file with environment overrides"
            echo "  --build-command CMD   Override build command"
            echo "  --verbose, -v         Enable verbose output"
            echo "  --help, -h            Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Build using default spec"
            echo "  $0 my-component                        # Build specific component"
            echo "  $0 --spec app.yaml                    # Use custom spec file"
            echo "  $0 --env-file .env.local               # Use environment overrides"
            echo "  $0 --build-command 'npm run build'     # Override build command"
            exit 0
            ;;
        *)
            if [[ -z "$COMPONENT" ]]; then
                COMPONENT="$1"
            else
                echo -e "${RED}Error: Unknown argument: $1${NC}" >&2
                echo "Use --help for usage information"
                exit 1
            fi
            shift
            ;;
    esac
done

# Check if doctl is installed
if ! command -v doctl &> /dev/null; then
    echo -e "${RED}Error: doctl is not installed or not in PATH${NC}" >&2
    echo "Install doctl: https://docs.digitalocean.com/products/app-platform/how-to/install-doctl/"
    exit 1
fi

# Check if doctl is authenticated
if ! doctl auth list &> /dev/null; then
    echo -e "${YELLOW}Warning: doctl may not be authenticated${NC}" >&2
    echo "Run: doctl auth init"
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker is not running${NC}" >&2
    echo "Start Docker and try again"
    exit 1
fi

# Build the doctl command
BUILD_CMD="doctl app dev build"

# Add component if specified
if [[ -n "$COMPONENT" ]]; then
    BUILD_CMD="$BUILD_CMD $COMPONENT"
fi

# Add spec file if specified
if [[ -n "$SPEC_FILE" ]]; then
    if [[ ! -f "$SPEC_FILE" ]]; then
        echo -e "${RED}Error: Spec file not found: $SPEC_FILE${NC}" >&2
        exit 1
    fi
    BUILD_CMD="$BUILD_CMD --spec $SPEC_FILE"
fi

# Add env file if specified
if [[ -n "$ENV_FILE" ]]; then
    if [[ ! -f "$ENV_FILE" ]]; then
        echo -e "${RED}Error: Environment file not found: $ENV_FILE${NC}" >&2
        exit 1
    fi
    BUILD_CMD="$BUILD_CMD --env-file $ENV_FILE"
fi

# Add build command if specified
if [[ -n "$BUILD_COMMAND" ]]; then
    BUILD_CMD="$BUILD_CMD --build-command \"$BUILD_COMMAND\""
fi

# Show what we're doing
echo -e "${GREEN}Building component locally using DigitalOcean buildpack containers...${NC}"
if [[ -n "$COMPONENT" ]]; then
    echo "Component: $COMPONENT"
fi
if [[ -n "$SPEC_FILE" ]]; then
    echo "Spec file: $SPEC_FILE"
elif [[ -f ".do/app.yaml" ]]; then
    echo "Spec file: .do/app.yaml (default)"
fi
if [[ -n "$ENV_FILE" ]]; then
    echo "Environment file: $ENV_FILE"
fi
echo ""

# Execute the build
if [[ "$VERBOSE" == true ]]; then
    eval "$BUILD_CMD"
else
    eval "$BUILD_CMD" 2>&1 | grep -v "^▸" || true
fi

BUILD_EXIT_CODE=${PIPESTATUS[0]}

if [[ $BUILD_EXIT_CODE -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}✓ Build completed successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Test the built container locally (if needed)"
    echo "  2. Push changes to GitHub: git push origin main"
    echo "  3. Changes will appear in testing setup (if using hot-reload-template)"
else
    echo ""
    echo -e "${RED}✗ Build failed with exit code $BUILD_EXIT_CODE${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  - Check build logs above for errors"
    echo "  - Verify Node.js/Python versions match production"
    echo "  - Try: $0 --build-command 'npm install --legacy-peer-deps && npm run build'"
    echo "  - See: https://docs.digitalocean.com/products/app-platform/how-to/build-locally/"
    exit $BUILD_EXIT_CODE
fi

