# Dev Health Server

Simple Go HTTP server for bootstrap health checks in the dev container template.

## Purpose

This health server serves a basic `/dev_health` endpoint to ensure the container passes health checks during initial deployment, before the user's application is running.

## Why Go?

- **Minimal footprint:** Static binary ~1-2MB (vs Node.js ~50-100MB)
- **Zero runtime dependencies:** Self-contained executable
- **Transparent:** Source code included for full auditability
- **Build-time compilation:** Binary built during Docker build, not pre-compiled

## How It Works

The server:
- Listens on port specified by `DEV_HEALTH_PORT` environment variable (default: 9090)
- Responds to `GET /dev_health` with JSON:
  ```json
  {
    "status": "ok",
    "service": "dev-container",
    "timestamp": "2025-11-30T12:00:00Z"
  }
  ```
- Returns 404 for all other paths

## Building

The binary is automatically built during Docker image build using a multi-stage build:

```dockerfile
FROM golang:1.23-alpine AS health-builder
COPY scripts/dev-health-server/main.go /build/
RUN cd /build && go build -ldflags="-s -w" -o dev-health-server main.go
```

The `-ldflags="-s -w"` flags strip debug info and symbol table for smaller binary size.

## Usage

The health server is controlled via the `ENABLE_DEV_HEALTH` environment variable:

- **First deploy:** `ENABLE_DEV_HEALTH=true` (default) - Health server runs on :9090
- **App has health:** `ENABLE_DEV_HEALTH=false` - Health server disabled

## Migration Path

1. Deploy with built-in health server (default)
2. Implement health endpoint in your app (e.g., `/health` on port 8080)
3. Update App Platform health check to point to your app's endpoint
4. Set `ENABLE_DEV_HEALTH=false` to disable this server
5. Optionally disable Node.js installation if not needed

## Local Testing

Build and test locally:

```bash
# Build the binary
go build -o dev-health-server main.go

# Run with default port (9090)
./dev-health-server

# Run with custom port
DEV_HEALTH_PORT=8090 ./dev-health-server

# Test the endpoint
curl http://localhost:9090/dev_health
```

## Security

- Source code is fully visible and auditable
- No external dependencies beyond Go standard library
- Built from source during Docker build (no pre-compiled binaries)
- Minimal attack surface (single endpoint, simple logic)

## File Size

```bash
$ ls -lh dev-health-server
-rwxr-xr-x  1 user  staff   1.8M Nov 30 12:00 dev-health-server
```

Typical binary size: 1.5-2MB after compilation with `-ldflags="-s -w"`.
