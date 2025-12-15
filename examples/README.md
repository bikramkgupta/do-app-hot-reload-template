# Example Startup Scripts

These `dev_startup.sh` examples handle dependency management automatically—when you add a new package to `package.json` or `requirements.txt`, the script detects the change and reinstalls before starting your dev server.

## Usage

1. Copy the appropriate script to your repo root as `dev_startup.sh`
2. Make it executable: `chmod +x dev_startup.sh`
3. Set `DEV_START_COMMAND` to `bash dev_startup.sh` in the DO Console

## Available Examples

| Script | Framework | Features |
|--------|-----------|----------|
| `dev_startup_nextjs.sh` | Next.js / Node.js | npm install with change detection, legacy-peer-deps |
| `dev_startup_python.sh` | FastAPI / Python | uv or pip, uvicorn with --reload |
| `dev_startup_go.sh` | Go | go mod tidy, air hot reload |
| `dev_startup_rails.sh` | Ruby on Rails | bundle install, db migrations |

## Why Use These?

The container syncs code from GitHub every 15 seconds. If you add a dependency:

- **Without startup script:** Your app crashes because the new package isn't installed
- **With startup script:** Detects the change, runs install, restarts—automatically

## Customization

These are starting points. Customize for your project:

```bash
#!/bin/bash
# Your custom startup script

# Add any setup steps here
npm install

# Start your dev server
# MUST bind to 0.0.0.0 and port 8080
npm run dev -- --host 0.0.0.0 --port 8080
```
