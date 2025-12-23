# Hot Reload Dev Environment for DigitalOcean App Platform

> **Experimental**: This is a personal project and is not officially supported by DigitalOcean. APIs may change without notice.

This is part of 3 projects to scale Agentic workflows with DigitalOcean App Platform. The concepts are generic and should work with any PaaS:
- Safe local sandboxing using DevContainers ([do-app-devcontainer](https://github.com/bikramkgupta/do-app-devcontainer))
- Rapid development iteration using hot reload (this repo or [do-app-hot-reload-template](https://github.com/bikramkgupta/do-app-hot-reload-template))
- Disposable environments using sandboxes for parallel experimentation and debugging ([do-app-sandbox](https://github.com/bikramkgupta/do-app-sandbox))

> **Fast deploys. Shell access. AI-assisted debugging.** Test development branches in minutes, not hours. When things break, you have a shell and an AI to fix it.

Pre-built Docker images with Node.js, Python, or Go ready to go. Deploy any codebase to DO App Platform in ~1 minute.

## Quick Start

### Option 1: GitHub Actions (Recommended)

**Best for: AI agents, teams, and anyone who wants secrets managed securely.**

[![Deploy via GitHub Actions](https://img.shields.io/badge/Deploy-GitHub%20Actions-2088FF?logo=github-actions&logoColor=white)](../../actions/workflows/deploy-app.yml)

1. **Fork this repository** (or copy the workflow to your project)

2. **Add GitHub Secrets** (Settings → Secrets and variables → Actions):

   | Secret | Required | Description |
   |--------|----------|-------------|
   | `DIGITALOCEAN_ACCESS_TOKEN` | Yes | Your DO API token |
   | `APP_GITHUB_TOKEN` | If private repo | GitHub PAT for private repos |
   | `DATABASE_URL` | If needed | Database connection string |

3. **Run the workflow**:
   - Go to Actions → "Deploy to DigitalOcean App Platform"
   - Click "Run workflow"
   - Select your runtime (node, python, go, etc.)
   - Click "Run workflow"

That's it! The workflow handles everything—no CLI needed, secrets stay secure.

**Benefits:**
- Secrets never exposed in logs or app specs
- Works with public and private repos
- AI agents can trigger via `gh workflow run`
- No `doctl` installation required
- Automatic `GITHUB_REPO_URL` from repository context

### Option 2: Deploy Button

[![Deploy to DO](https://www.deploytodo.com/do-btn-blue.svg)](https://cloud.digitalocean.com/apps/new?repo=https://github.com/bikramkgupta/do-app-hot-reload-template/tree/main)

### Option 3: CLI with doctl

```bash
# Clone and deploy
doctl apps create --spec app.yaml

# After deployment, set environment variables in DO Console
```

## After Deployment

### 1. Add dev_startup.sh to Your Repo

```bash
#!/bin/bash
npm install
npm run dev -- --hostname 0.0.0.0 --port 8080
```

See [`examples/`](examples/) for startup scripts that handle dependency changes automatically (Next.js, Python, Go, Rails).

### 2. Your Code Syncs Automatically

The container syncs from GitHub every 15 seconds with hot reload.

## Why GitHub Actions?

| Approach | Secrets Handling | AI-Friendly | Setup Complexity |
|----------|------------------|-------------|------------------|
| **GitHub Actions** | ✅ GitHub Secrets | ✅ `gh workflow run` | Low |
| doctl CLI | ⚠️ Local files | ⚠️ Complex commands | Medium |
| DO Console | ✅ Manual entry | ❌ Not automatable | Medium |

**For AI agents**, GitHub Actions is the clear winner:
- Agent runs `gh workflow run deploy-app.yml -f action=deploy -f runtime=node`
- No need to handle secrets or complex CLI arguments
- No risk of exposing secrets in conversation logs

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

The health check runs on **port 8080** where the welcome-page-server responds to `/health` until your app starts. This ensures:

| Component | Port | Purpose |
|-----------|------|---------|
| Your app | 8080 | Your application |
| Welcome server | 8080 | Responds to health checks until app starts |

**Why this matters:**
- If your app crashes, you can shell in with [do-app-sandbox](https://github.com/bikramkgupta/do-app-sandbox) and debug
- AI assistants can connect and help fix issues remotely

## Available Images

| Image | Runtimes | Use Case |
|-------|----------|----------|
| `ghcr.io/bikramkgupta/hot-reload-node` | Node.js 22/24 | Next.js, React, Express |
| `ghcr.io/bikramkgupta/hot-reload-bun` | Bun (latest) | Bun apps, fast bundling |
| `ghcr.io/bikramkgupta/hot-reload-python` | Python 3.12/3.13 | FastAPI, Django, Flask |
| `ghcr.io/bikramkgupta/hot-reload-go` | Go 1.23 | Go APIs, CLI tools |
| `ghcr.io/bikramkgupta/hot-reload-ruby` | Ruby 3.4/3.3 | Rails, Sinatra, Hanami |
| `ghcr.io/bikramkgupta/hot-reload-node-python` | Node.js + Python | Full-stack apps |
| `ghcr.io/bikramkgupta/hot-reload-full` | Node + Python + Go | Multi-language |

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `GITHUB_REPO_URL` | Your application repository (auto-set by Actions) |
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

## Managing Secrets

### With GitHub Actions (Recommended)

Add secrets to GitHub repository settings:
1. Go to Settings → Secrets and variables → Actions
2. Add your secrets (DATABASE_URL, API_KEY, etc.)
3. Reference them in the workflow—they're automatically injected

### With doctl (Alternative)

Create a local spec file with your secrets (never commit!):

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
```

```bash
doctl apps update <app-id> --spec .do/app.local.yaml
```

## Example Startup Scripts

See [`examples/`](examples/) for complete startup scripts for each runtime:
- `dev_startup_nextjs.sh` - Node.js / Next.js
- `dev_startup_python.sh` - Python / FastAPI
- `dev_startup_go.sh` - Go
- `dev_startup_rails.sh` - Ruby / Rails

These scripts handle dependency caching and change detection automatically.

## GitHub Actions Workflow Reference

### Deploy an App

```bash
# Via GitHub CLI
gh workflow run deploy-app.yml \
  -f action=deploy \
  -f app_name=my-dev-app \
  -f runtime=node \
  -f region=syd1

# Or use the GitHub UI: Actions → Deploy to DigitalOcean App Platform → Run workflow
```

### Delete an App

```bash
gh workflow run deploy-app.yml \
  -f action=delete \
  -f app_name=my-dev-app
```

### Workflow Inputs

| Input | Options | Default | Description |
|-------|---------|---------|-------------|
| `action` | deploy, delete | deploy | Action to perform |
| `app_name` | string | hot-reload-dev | App name |
| `runtime` | node, bun, python, go, ruby, node-python, full | node | Runtime image |
| `region` | nyc1, sfo3, ams3, sgp1, lon1, fra1, tor1, blr1, syd1 | syd1 | DO region |
| `instance_size` | apps-s-1vcpu-0.5gb, apps-s-1vcpu-1gb, etc. | apps-s-1vcpu-1gb | Instance size |
| `branch` | string | (default) | Git branch to sync |
| `repo_folder` | string | (root) | Subfolder for monorepos |
| `dev_start_command` | string | bash dev_startup.sh | Startup command |

## Important Notes

- **Port 8080**: Your app must listen on port 8080, bound to `0.0.0.0`
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
| Private repo access | Set `APP_GITHUB_TOKEN` as a GitHub secret |
| Workflow fails | Check `DIGITALOCEAN_ACCESS_TOKEN` is set |

## Files in This Repo

```
├── Dockerfile              # Multi-stage build for all runtimes
├── app.yaml               # Default app spec for doctl
├── .do/
│   └── app.yaml           # App spec template for GitHub Actions
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
    ├── build-and-push-images.yml  # Builds images to GHCR
    └── deploy-app.yml            # Deploy/delete apps via Actions
```

## Contributing

1. Fork this repo
2. Make changes
3. Submit PR

To request a new runtime combination, open an issue.

---

**Questions?** Open an issue or check [agent.md](agent.md) for the AI assistant deployment guide.
