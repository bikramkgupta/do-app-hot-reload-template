# Go Sample App

Minimal Go HTTP server for DigitalOcean App Platform testing.

## Run locally

```bash
go run .
```

## Health endpoint

- Path: `/health`
- Port: `8080`

## Deploy notes

- App Platform build args: enable Go, disable Node/Python.
- Health check: point to `/health` on port `8080`.
