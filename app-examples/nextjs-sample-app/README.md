# Next.js Sample App

Minimal Next.js app for DigitalOcean App Platform testing.

## Run locally

```bash
npm install
npm run dev -- --hostname 0.0.0.0 --port 8080
```

## Health endpoint

- Path: `/api/health`
- Port: `8080`

## Deploy notes

- App Platform build args: enable Node, disable Python/Go.
- Health check: point to `/api/health` on port `8080`.
