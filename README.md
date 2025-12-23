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

1. **Add GitHub Secrets** (Settings → Secrets and variables → Actions):

   | Secret | Required | Description |
   |--------|----------|-------------|
   | `DIGITALOCEAN_ACCESS_TOKEN` | Yes | Your DO API token |
   | `APP_GITHUB_TOKEN` | If private repo | GitHub PAT for private repos |
   | `DATABASE_URL` | If needed | Database connection string |

2. **Create `.do/config.yaml`** (optional but recommended):

   ```yaml
   app_name: my-dev-app
   runtime: node
   region: syd1
   instance_size: apps-s-1vcpu-2gb
   ```

   See [.do/config.yaml](.do/config.yaml) for all options.

3. **Run the workflow**:
   - Go to Actions → "Deploy to DigitalOcean App Platform"
   - Click "Run workflow"
   - Click "Run workflow" (uses config.yaml defaults)

That's it! Configure once, deploy many times.

**Benefits:**
- **Persistent config** - Set once in `.do/config.yaml`, never re-enter
- **Secrets stay secure** - Never exposed in logs or specs
- **AI-friendly** - Just `gh workflow run deploy-app.yml`
- **No `doctl` needed** - Works from any machine with `gh` CLI

### Option 2: Deploy Button

[![Deploy to DO](https://www.deploytodo.com/do-btn-blue.svg)](https://cloud.digitalocean.com/apps/new?repo=https://github.com/bikramkgupta/do-app-hot-reload-template/tree/main)

### Option 3: CLI with doctl

```bash
doctl apps create --spec app.yaml
```

## After Deployment: Create dev_startup.sh

Your repository needs a `dev_startup.sh` script that handles dependency installation and starts your dev server.

> **Important:** Use `dev_startup.sh` for dependency installation, NOT `PRE_DEPLOY_COMMAND`. If `PRE_DEPLOY_COMMAND` fails, the container exits and you lose shell access. With `dev_startup.sh`, failures are handled gracefully.

**Copy an example from [`examples/`](examples/):**

| Framework | Script | Key Features |
|-----------|--------|--------------|
| Next.js / Node | `dev_startup_nextjs.sh` | Change detection, auto-reinstall, legacy-peer-deps |
| Python / FastAPI | `dev_startup_python.sh` | uv or pip, uvicorn with --reload |
| Go | `dev_startup_go.sh` | go mod tidy, air hot reload |
| Rails | `dev_startup_rails.sh` | bundle install, db migrations |

These scripts automatically detect when you add dependencies (e.g., new package in `package.json`) and reinstall before restarting your app.

**Simple example (customize for your project):**

```bash
#!/bin/bash
set -e

# Detect package.json changes and reinstall
HASH_FILE=".deps_hash"
CURRENT_HASH=$(sha256sum package.json 2>/dev/null | cut -d' ' -f1 || echo "none")
STORED_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "")

if [ "$CURRENT_HASH" != "$STORED_HASH" ] || [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
    echo "$CURRENT_HASH" > "$HASH_FILE"
fi

# Start dev server - MUST bind to 0.0.0.0:8080
exec npm run dev -- --hostname 0.0.0.0 --port 8080
```

## Why GitHub Actions?

| Approach | Secrets Handling | AI-Friendly | Setup Complexity |
|----------|------------------|-------------|------------------|
| **GitHub Actions** | ✅ GitHub Secrets | ✅ `gh workflow run` | Low |
| doctl CLI | ⚠️ Local files | ⚠️ Complex commands | Medium |
| DO Console | ✅ Manual entry | ❌ Not automatable | Medium |

**For AI agents**, GitHub Actions is the clear winner:
- Agent runs `gh workflow run deploy-app.yml` (uses config.yaml)
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

The health check runs on **port 9090** (separate from your app on port 8080). This is intentional:

| Component | Port | Purpose |
|-----------|------|---------|
| Your app | 8080 | Your application (public HTTP) |
| Health check | 9090 | Keeps container alive (internal) |

**Why this matters:**
- If your app crashes, the container **stays alive** because health check still responds
- You can shell in with [do-app-sandbox](https://github.com/bikramkgupta/do-app-sandbox) and debug
- AI assistants can connect and help fix issues remotely

**Do not change the health check to port 8080** for dev environments. That defeats the purpose—a broken app would kill the container and you'd lose access.

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
| `DEV_START_COMMAND` | Startup command (default: `bash dev_startup.sh`) |

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

## Managing Environment Variables & Secrets

The workflow supports two types of environment variables:

### Environment Variables (type: GENERAL)

Plain-text variables defined directly in `.do/config.yaml`:

```yaml
envs:
  NODE_ENV: development
  LOG_LEVEL: debug
  PUBLIC_API_URL: https://api.example.com
```

### Secrets (type: SECRET)

Encrypted variables. Add to GitHub Secrets, then list in config:

1. Go to Settings → Secrets and variables → Actions
2. Add your secret (e.g., `DATABASE_URL`)
3. Add the name to `.do/config.yaml`:

```yaml
secrets:
  - DATABASE_URL
  - AUTH_SECRET
  - STRIPE_SECRET_KEY
```

The workflow reads your lists and generates the app spec dynamically. You can have any number of envs and secrets.

### With doctl (Alternative)

Create a local spec file with your secrets (never commit!):

```yaml
# .do/app.local.yaml (add to .gitignore)
name: my-dev-app
services:
  - name: dev-workspace
    envs:
      - key: DATABASE_URL
        value: "postgresql://user:pass@host:5432/db"
        scope: RUN_TIME
        type: SECRET
```

```bash
doctl apps update <app-id> --spec .do/app.local.yaml
```

## GitHub Actions Workflow Reference

### Configuration File

Create `.do/config.yaml` to save your settings:

```yaml
app_name: my-dev-app
runtime: node
region: syd1
instance_size: apps-s-1vcpu-2gb
branch: main
sync_interval: 15
dev_start_command: bash dev_startup.sh

# Deploy jobs (optional)
pre_deploy_command: ""
post_deploy_command: ""

# Plain-text environment variables
envs:
  NODE_ENV: development
  LOG_LEVEL: debug

# Secrets (values from GitHub Secrets)
secrets:
  - DATABASE_URL
  - AUTH_SECRET

# Advanced: Use your own app spec instead
# app_spec_path: .do/my-custom-app.yaml
```

### Deploy an App

```bash
# Uses config.yaml settings
gh workflow run deploy-app.yml -f action=deploy

# Override specific settings
gh workflow run deploy-app.yml \
  -f action=deploy \
  -f app_name=my-feature-test \
  -f runtime=python \
  -f region=nyc1
```

### Delete an App

```bash
gh workflow run deploy-app.yml \
  -f action=delete \
  -f app_name=my-dev-app
```

### Workflow Inputs

All inputs are optional—they override `.do/config.yaml` values.

| Input | Options | Default | Description |
|-------|---------|---------|-------------|
| `action` | deploy, delete | deploy | Action to perform |
| `app_name` | string | hot-reload-dev | App name |
| `runtime` | node, bun, python, go, ruby, node-python, full | node | Runtime image |
| `region` | nyc1, nyc3, ams3, sfo3, sgp1, lon1, fra1, tor1, blr1, syd1 | syd1 | DO region |
| `instance_size` | see below | apps-s-1vcpu-2gb | Instance size |
| `branch` | string | (default) | Git branch to sync |
| `repo_folder` | string | (root) | Subfolder for monorepos |
| `sync_interval` | number | 15 | Sync interval in seconds |
| `dev_start_command` | string | bash dev_startup.sh | Startup command |
| `pre_deploy_command` | string | (none) | Pre-deploy command |
| `post_deploy_command` | string | (none) | Post-deploy command |

### Instance Sizes

See [DigitalOcean Pricing](https://docs.digitalocean.com/products/app-platform/details/pricing/) for current prices.

**Shared CPU (dev/testing):**
- `apps-s-1vcpu-0.5gb` - Basic
- `apps-s-1vcpu-1gb` - Starter
- `apps-s-1vcpu-2gb` - Development (recommended)
- `apps-s-2vcpu-4gb` - Professional

**Dedicated CPU (production-like):**
- `apps-d-1vcpu-0.5gb` through `apps-d-8vcpu-32gb`

## Important Notes

- **Port 8080**: Your app must listen on port 8080, bound to `0.0.0.0`
- **Port 9090**: Reserved for health check—don't use in your app
- **Hot reload**: Use a dev server that supports it (`npm run dev`, `uvicorn --reload`, etc.)
- **Resource sizing**: Ensure your container has enough CPU/memory. npm install for large projects needs resources.
- **No rebuild needed**: Change env vars and redeploy—your code syncs automatically

## Custom Images

Need a different runtime combo? See [GHCR_SETUP.md](GHCR_SETUP.md) for instructions on building and publishing your own images.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| App doesn't start | Check `dev_startup.sh` exists and is executable |
| Health check fails | Ensure app listens on port 8080 (not 9090) |
| Changes not visible | Use a dev server with hot reload |
| Private repo access | Set `APP_GITHUB_TOKEN` as a GitHub secret |
| Workflow fails | Check `DIGITALOCEAN_ACCESS_TOKEN` is set |
| npm install fails | Check instance size (need 2GB+ for large projects) |

## Files in This Repo

```
├── Dockerfile              # Multi-stage build for all runtimes
├── app.yaml               # Default app spec for doctl
├── .do/
│   ├── config.yaml        # Persistent deployment settings
│   └── app.yaml           # App spec template for GitHub Actions
├── app-specs/             # App specs for each runtime
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
