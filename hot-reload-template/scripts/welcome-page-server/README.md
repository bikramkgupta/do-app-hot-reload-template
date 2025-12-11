# Welcome Page Server

Simple Go HTTP server that serves an informative welcome page when no application is connected to the dev container template.

## Purpose

This welcome page server serves a helpful HTML page on port 8080 (the main application port) to guide users on how to connect their application to the template. It shows:

- Current configuration status (repository URL, run command, etc.)
- Step-by-step setup instructions
- Example `dev_startup.sh` scripts for different frameworks
- Important notes about port binding and hot reload

## Why Go?

- **Minimal footprint:** Static binary ~2-3MB (vs Node.js ~50-100MB)
- **Zero runtime dependencies:** Self-contained executable
- **Transparent:** Source code included for full auditability
- **Build-time compilation:** Binary built during Docker build, not pre-compiled

## How It Works

The server:
- Listens on port specified by `WELCOME_PAGE_PORT` environment variable (default: 8080)
- Responds to `GET /` with an HTML welcome page showing:
  - Current environment configuration
  - Setup instructions based on current state
  - Example scripts for different frameworks
  - Important notes and warnings
- Returns 404 for all other paths
- Automatically stops when a user's application starts (via DEV_START_COMMAND)

## Building

The binary is automatically built during Docker image build using a multi-stage build:

```dockerfile
FROM golang:1.23-alpine AS health-builder
COPY hot-reload-template/scripts/welcome-page-server/main.go /build/welcome/
RUN cd /build/welcome && go build -ldflags="-s -w" -o welcome-page-server main.go
```

The `-ldflags="-s -w"` flags strip debug info and symbol table for smaller binary size.

## Usage

The welcome page server automatically starts when no application is configured:

- **No app configured:** Welcome page runs on :8080, showing setup instructions
- **App starts:** Server automatically stops when DEV_START_COMMAND executes (to free port 8080)
- **No configuration needed:** Works automatically based on whether DEV_START_COMMAND is set

## Behavior

1. **On container start:** Welcome page server starts on port 8080 (if enabled)
2. **When app starts:** If DEV_START_COMMAND is set, the welcome page server stops to free port 8080 for the user's application
3. **If no app configured:** Welcome page continues running, showing setup instructions

## Local Testing

Build and test locally:

```bash
# Build the binary
go build -o welcome-page-server main.go

# Run with default port (8080)
./welcome-page-server

# Run with custom port
WELCOME_PAGE_PORT=8090 ./welcome-page-server

# Test the endpoint
curl http://localhost:8080/
```

## Security

- Source code is fully visible and auditable
- No external dependencies beyond Go standard library
- Built from source during Docker build (no pre-compiled binaries)
- Minimal attack surface (single endpoint, read-only HTML template)

## File Size

```bash
$ ls -lh welcome-page-server
-rwxr-xr-x  1 user  staff   2.1M Nov 30 12:00 welcome-page-server
```

Typical binary size: 2-3MB after compilation with `-ldflags="-s -w"`.

## Integration with Health Server

The welcome page server works alongside the dev health server:

- **Health server:** Runs on port 9090, serves `/dev_health` endpoint for App Platform health checks
- **Welcome page server:** Runs on port 8080, serves `/` endpoint for user-facing instructions

Both servers can run simultaneously, allowing the container to:
- Pass health checks (via health server on 9090)
- Show helpful instructions (via welcome page on 8080)
- Automatically transition to user's app when configured

