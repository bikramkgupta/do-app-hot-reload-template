# Example Startup Scripts

These `dev_startup.sh` examples handle dependency management automatically—when you add a new package to `package.json` or `requirements.txt`, the script detects the change and reinstalls before starting your dev server.

If you're following the quick start, just copy one script to your repo root as `dev_startup.sh` and keep `DEV_START_COMMAND` set to `bash dev_startup.sh`.

> **Important:** Use `dev_startup.sh` for dependency installation, NOT `PRE_DEPLOY_COMMAND`.
>
> `PRE_DEPLOY_COMMAND` runs in strict mode—if it fails (e.g., npm install fails), the container exits and you lose shell access for debugging. With `dev_startup.sh`, failures are handled gracefully and you can always shell in to fix issues.

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
npm run dev -- --hostname 0.0.0.0 --port 8080
```

## Troubleshooting

### Can't shell into container after deployment fails

Make sure your app spec uses port 9090 for health checks:

```yaml
internal_ports:
  - 9090
health_check:
  http_path: /dev_health
  port: 9090  # NOT 8080!
```

This keeps the container alive even if your app crashes, so you can debug with [do-app-sandbox](https://github.com/bikramkgupta/do-app-sandbox).

### npm install fails and container exits

Don't use `PRE_DEPLOY_COMMAND` for npm install. Instead:
1. Add `dev_startup.sh` to your repo
2. Set `DEV_START_COMMAND: "bash dev_startup.sh"`
3. Leave `PRE_DEPLOY_COMMAND` empty

### Runtimes not detected in logs

If you see "Installed Runtimes:" with nothing listed, the container image may not have the runtime installed. Check you're using the correct image (e.g., `hot-reload-node` for Node.js apps).
