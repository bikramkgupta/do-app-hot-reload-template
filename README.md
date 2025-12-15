# Hot Reload Dev Environment for DigitalOcean App Platform

> **Experimental**: This is a personal project and is not officially supported by DigitalOcean. APIs may change without notice.

This is part of 3 projects to scale Agentic workflows with DigitalOcean App Platform. The concepts are generic and should work with any PaaS:
- Safe local sandboxing using DevContainers ([do-app-devcontainer](https://github.com/bikramkgupta/do-app-devcontainer))
- Rapid development iteration using hot reload (this repo or [do-app-hot-reload-template](https://github.com/bikramkgupta/do-app-hot-reload-template))
- Disposable environments using sandboxes for parallel experimentation and debugging ([do-app-sandbox](https://github.com/bikramkgupta/do-app-sandbox))

> **Fast deploys. Shell access. AI-assisted debugging.** Test development branches in minutes, not hours. When things break, you have a shell and an AI to fix it.

Pre-built Docker images with Node.js, Python, or Go ready to go. Deploy any codebase to DO App Platform in ~1 minute.

## Quick Start

[![Deploy to DO](https://www.deploytodo.com/do-btn-blue.svg)](https://cloud.digitalocean.com/apps/new?repo=https://github.com/bikramkgupta/do-app-hot-reload-template/tree/main)

### 1. Deploy the Container (~1 minute)

```bash
# Using doctl CLI
doctl apps create --spec app.yaml
```

Or use the DO Console:
1. Create App → Deploy from Container Registry
2. Registry: `ghcr.io`
3. Image: `bikramkgupta/hot-reload-node` (or python, go, etc.)
4. Tag: `latest`

### 2. Configure Your App (DO Console)

After deployment, set environment variables:

| Variable | Value | Required |
|----------|-------|----------|
| `GITHUB_REPO_URL` | `https://github.com/you/your-app` | Yes |
| `GITHUB_TOKEN` | Your PAT (for private repos) | If private |
| `DEV_START_COMMAND` | `bash dev_startup.sh` | Recommended |

### 3. Add dev_startup.sh to Your Repo

```bash
#!/bin/bash
npm install
npm run dev -- --hostname 0.0.0.0 --port 8080
```

See [`examples/`](examples/) for startup scripts that handle dependency changes automatically (Next.js, Python, Go, Rails).

That's it! Your app syncs from GitHub every 15 seconds with hot reload.

## Why This Exists

Standard App Platform deploys go through build, push to registry, and deploy—which is great for production stability. For **development and testing branches** where you need to iterate rapidly, this template offers a faster alternative.

**Pre-built images skip the build phase entirely:**

| Use Case | Approach | Deploy Time |
|----------|----------|-------------|
| Production | Standard build + deploy | Reliable, thorough |
| **Dev/Testing** | **Pre-built image** | **~1 minute** |

- **~1 minute deploys** - Pull image, start container, done
- **Shell access** - Debug with [do-app-sandbox](https://github.com/bikramkgupta/do-app-sandbox) when things break
- **AI-ready** - Point your favorite AI assistant at your container and let it fix issues remotely
- **Hot reload** - Code syncs every 15 seconds, your dev server handles the rest

> **Note:** If you don't configure anything, the container still works—you'll see the welcome page and can shell in to explore.

## Critical: Shell Access for Debugging

**An important feature of this template is shell access when things break.**

The health check runs on **port 9090** (separate from your app on port 8080). This is intentional:

| Component | Port | Purpose |
|-----------|------|---------|
| Your app | 8080 | Your application |
| Health check | 9090 | Keeps container alive |

**Why this matters:**
- If your app crashes, the container **stays alive** because health check still responds
- You can shell in with [do-app-sandbox](https://github.com/bikramkgupta/do-app-sandbox) and debug
- AI assistants can connect and help fix issues remotely

**Do not change the health check to port 8080** for dev environments. That defeats the purpose—a broken app would kill the container and you'd lose access.

## Available Images

| Image | Runtimes | Use Case |
|-------|----------|----------|
| `ghcr.io/bikramkgupta/hot-reload-node` | Node.js 22/24 | Next.js, React, Express |
| `ghcr.io/bikramkgupta/hot-reload-python` | Python 3.12/3.13 | FastAPI, Django, Flask |
| `ghcr.io/bikramkgupta/hot-reload-go` | Go 1.23 | Go APIs, CLI tools |
| `ghcr.io/bikramkgupta/hot-reload-ruby` | Ruby 3.4/3.3 | Rails, Sinatra, Hanami |
| `ghcr.io/bikramkgupta/hot-reload-node-python` | Node.js + Python | Full-stack apps |
| `ghcr.io/bikramkgupta/hot-reload-full` | Node + Python + Go | Multi-language |

## App Spec Example

```yaml
name: my-dev-app
region: syd1

services:
  - name: dev-workspace
    image:
      registry_type: GHCR
      repository: bikramkgupta/hot-reload-node
      tag: latest
    http_port: 8080
    internal_ports:
      - 9090  # Health check port (keeps container alive if app crashes)
    health_check:
      http_path: /dev_health
      port: 9090  # Separate from app - ensures shell access for debugging
    envs:
      - key: GITHUB_REPO_URL
        value: "https://github.com/you/your-app"
      - key: DEV_START_COMMAND
        value: "bash dev_startup.sh"
```

See `app-specs/` for complete examples.

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│  Your Deploy (~1 min)                                        │
│                                                              │
│  1. Pull pre-built image from GHCR (30 sec)                 │
│  2. Start container                                          │
│  3. Clone your repo from GitHub                             │
│  4. Run your dev_startup.sh                                 │
│  5. Your app is live!                                       │
│                                                              │
│  Continuous: Git sync every 15 seconds                      │
│              Your dev server handles hot reload             │
└─────────────────────────────────────────────────────────────┘
```

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `GITHUB_REPO_URL` | Your application repository |
| `DEV_START_COMMAND` | Startup command (or add `dev_startup.sh` to repo) |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `GITHUB_TOKEN` | - | For private repos (set as secret) |
| `GITHUB_BRANCH` | main | Branch to sync |
| `GITHUB_REPO_FOLDER` | - | Subfolder for monorepos |
| `GITHUB_SYNC_INTERVAL` | 15 | Sync frequency (seconds) |

### Deploy Jobs (Optional)

Run commands when code changes are detected (on git commit change, not every sync):

| Variable | Default | Description |
|----------|---------|-------------|
| `PRE_DEPLOY_COMMAND` | - | Runs before app starts (e.g., `bash scripts/migrate.sh`) |
| `PRE_DEPLOY_TIMEOUT` | 300 | Timeout in seconds |
| `POST_DEPLOY_COMMAND` | - | Runs after app starts (e.g., `bash scripts/seed.sh`) |
| `POST_DEPLOY_TIMEOUT` | 300 | Timeout in seconds |

### Managing Secrets

**Never commit secrets to GitHub** (public or private repos). Instead, use a local app spec file:

1. Create a local spec file with your secrets:
   ```bash
   # .do/app.local.yaml (add to .gitignore)
   ```

   ```yaml
   name: my-dev-app
   services:
     - name: dev-workspace
       envs:
         - key: DATABASE_URL
           value: "postgresql://user:pass@host:5432/db"
           scope: RUN_TIME
         - key: NEXTAUTH_SECRET
           value: "your-secret-here"
           scope: RUN_TIME
         # ... other secrets
   ```

2. Add to `.gitignore`:
   ```
   .do/app.local.yaml
   ```

3. Deploy with your local spec:
   ```bash
   doctl apps update <app-id> --spec .do/app.local.yaml
   ```

This keeps secrets on your local machine, never in version control. You can have different local specs for different environments.

> **Note:** The [AI agent playbook](agent.md) follows this same approach for secrets management.

## Example Startup Scripts

See [`examples/`](examples/) for complete startup scripts for each runtime:
- `dev_startup_nextjs.sh` - Node.js / Next.js
- `dev_startup_python.sh` - Python / FastAPI
- `dev_startup_go.sh` - Go
- `dev_startup_rails.sh` - Ruby / Rails

These scripts handle dependency caching and change detection automatically.

## Important Notes

- **Port 8080**: Your app must listen on port 8080, bound to `0.0.0.0`
- **Health check on 9090**: The dev health server runs on port 9090, separate from your app. This keeps the container alive even if your app crashes, giving you shell access to debug.
- **Hot reload**: Use a dev server that supports it (`npm run dev`, `uvicorn --reload`, etc.)
- **Resource sizing**: Ensure your container has enough CPU/memory. npm install for large projects needs resources.
- **No rebuild needed**: Change env vars and redeploy—your code syncs automatically

## Custom Images

Need a different runtime combo? See [GHCR_SETUP.md](GHCR_SETUP.md) for instructions on building and publishing your own images.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| App doesn't start | Check `GITHUB_REPO_URL` is set, `dev_startup.sh` exists |
| Health check fails | Ensure app listens on port 8080 |
| Changes not visible | Use a dev server with hot reload |
| Private repo access | Set `GITHUB_TOKEN` as a secret |

## Files in This Repo

```
├── Dockerfile              # Multi-stage build for all runtimes
├── app.yaml               # Default app spec (Node.js)
├── app-specs/             # App specs for each runtime
│   ├── app-node.yaml
│   ├── app-python.yaml
│   ├── app-go.yaml
│   ├── app-ruby.yaml
│   └── app-full.yaml
├── examples/              # Startup script examples
│   ├── dev_startup_nextjs.sh
│   ├── dev_startup_python.sh
│   ├── dev_startup_go.sh
│   └── dev_startup_rails.sh
├── scripts/
│   ├── startup.sh         # Container entrypoint
│   ├── github-sync.sh     # Continuous sync daemon
│   └── welcome-page-server/  # Welcome page + health endpoint
└── .github/workflows/
    └── build-and-push-images.yml  # Builds images to GHCR
```

## Contributing

1. Fork this repo
2. Make changes
3. Submit PR

To request a new runtime combination, open an issue.

---

**Questions?** Open an issue or check [agent.md](agent.md) for the AI assistant deployment guide.
