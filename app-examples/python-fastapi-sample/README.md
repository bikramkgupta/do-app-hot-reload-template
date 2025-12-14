# Python FastAPI Sample

Minimal FastAPI app using uv for dependency management.

## Run locally

```bash
uv run uvicorn main:app --host 0.0.0.0 --port 8080
```

## Health endpoint

- Path: `/health`
- Port: `8080`

## Deploy notes

- App Platform build args: enable Python, disable Node/Go.
- Health check: point to `/health` on port `8080`.
