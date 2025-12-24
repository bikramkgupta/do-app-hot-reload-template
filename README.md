# Hot Reload Dev Environment for DigitalOcean App Platform

> **Experimental**: This is a personal project and is not officially supported by DigitalOcean. APIs may change without notice.

This is part of 3 projects to scale Agentic workflows with DigitalOcean App Platform. The concepts are generic and should work with any PaaS:
- Safe local sandboxing using DevContainers ([do-app-devcontainer](https://github.com/bikramkgupta/do-app-devcontainer))
- Rapid development iteration using hot reload (this repo or [do-app-hot-reload-template](https://github.com/bikramkgupta/do-app-hot-reload-template))
- Disposable environments using sandboxes for parallel experimentation and debugging ([do-app-sandbox](https://github.com/bikramkgupta/do-app-sandbox))

> **Fast deploys. Shell access. AI-assisted debugging.** Test development branches in minutes, not hours. When things break, you have a shell and an AI to fix it.

Pre-built Docker images with Node.js, Python, or Go ready to go. Deploy any codebase to DO App Platform in ~1 minute.

## Aha in 5 minutes (80% case)

1. Copy `.github/workflows/deploy-app.yml` and `.do/app.yaml` into your repo.
2. Copy a `dev_startup.sh` from `examples/` into your repo root (review/edit for your framework).
3. Add GitHub Secrets: `DIGITALOCEAN_ACCESS_TOKEN`, `APP_GITHUB_TOKEN` (private repos), and any app secrets.
4. Run deploy: `gh workflow run deploy-app.yml -f action=deploy` (or via GitHub UI).

Why this is useful: ~1 minute deploys and shell access for debugging even if the app fails.

The workflow auto-fills `GITHUB_REPO_URL` for the current repo. Only change it if the workflow runs in a different repo than the app (e.g., a central template) or you use GitHub Enterprise. For monorepos, set `GITHUB_REPO_FOLDER`.

## Quick Start (details)

### Step 1: Copy Files to Your Repo

Copy these files to your repository:
- `.github/workflows/deploy-app.yml` - The deployment workflow
- `.do/app.yaml` - Your app spec (edit this!)
- `dev_startup.sh` - Your startup script

### Step 2: Edit `.do/app.yaml`

Edit the app spec for your project. AI assistants (Claude, Cursor, Codex) can help you customize it.

Secrets are stored in GitHub and substituted by the workflow. If an env var is not a secret, you can hardcode it here.

```yaml
name: my-dev-app
region: syd1

services:
  - name: dev-workspace
    image:
      registry_type: GHCR
      registry: bikramkgupta
      repository: hot-reload-node  # node, bun, python, go, ruby, full
      tag: latest

    instance_size_slug: apps-s-1vcpu-2gb
    http_port: 8080

    envs:
      - key: GITHUB_REPO_URL
        value: "${GITHUB_REPO_URL}"  # auto-filled by the workflow
        scope: RUN_TIME

      # For secrets: use ${SECRET_NAME} syntax
      - key: DATABASE_URL
        value: "${DATABASE_URL}"
        scope: RUN_TIME
        type: SECRET
```

See [`.do/app.yaml`](.do/app.yaml) for the full template with all options.

### Step 3: Add Secrets to GitHub

Go to Settings → Secrets and variables → Actions and add:

| Secret | Required | Description |
|--------|----------|-------------|
| `DIGITALOCEAN_ACCESS_TOKEN` | Yes | Your DO API token |
| `APP_GITHUB_TOKEN` | If private repo | GitHub PAT for private repos |
| Your app secrets | As needed | DATABASE_URL, AUTH_SECRET, etc. |

### Step 4: Deploy

```bash
# Deploy
gh workflow run deploy-app.yml -f action=deploy

# Delete
gh workflow run deploy-app.yml -f action=delete
```

Or use the GitHub UI: Actions → "Deploy to DigitalOcean App Platform" → Run workflow

Monitor logs via the Actions run, or in DigitalOcean App Platform (or `doctl apps logs`).

## How Secrets Work

1. Add secret to GitHub (e.g., `DATABASE_URL`)
2. Reference in your app spec with `${SECRET_NAME}`:
   ```yaml
   - key: DATABASE_URL
     value: "${DATABASE_URL}"
     type: SECRET
   ```
3. The workflow substitutes the value at deploy time

The workflow has 40+ common secrets pre-wired. Just add them to GitHub Secrets and reference in your app spec.
If your secret is not listed in `.github/workflows/deploy-app.yml`, replace `CUSTOM_SECRET_1..10` (or add new entries) and reference that name in your app spec.

## Create dev_startup.sh (before deploy)

Your repository needs a `dev_startup.sh` script that handles dependency installation and starts your dev server.

**Copy an example from [`examples/`](examples/):**

| Framework | Script | Key Features |
|-----------|--------|--------------|
| Next.js / Node | `dev_startup_nextjs.sh` | Change detection, auto-reinstall |
| Python / FastAPI | `dev_startup_python.sh` | uv or pip, uvicorn with --reload |
| Go | `dev_startup_go.sh` | go mod tidy, air hot reload |
| Rails | `dev_startup_rails.sh` | bundle install, db migrations |

**Simple example:**

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

## Why This Exists

Standard App Platform deploys go through build, push to registry, and deploy—which is great for production. For **development and testing branches** where you need to iterate rapidly, this template offers a faster alternative.

| Use Case | Approach | Deploy Time |
|----------|----------|-------------|
| Production | Standard build + deploy | Reliable, thorough |
| **Dev/Testing** | **Pre-built image** | **~1 minute** |

- **~1 minute deploys** - Pull image, start container, done
- **Shell access** - Debug with [do-app-sandbox](https://github.com/bikramkgupta/do-app-sandbox) when things break
- **AI-ready** - Point your favorite AI assistant at your container and let it fix issues remotely
- **Hot reload** - Code syncs every 15 seconds, your dev server handles the rest

## Critical: Shell Access for Debugging

The health check runs on **port 9090** (separate from your app on port 8080). This is intentional:

| Component | Port | Purpose |
|-----------|------|---------|
| Your app | 8080 | Your application (public HTTP) |
| Health check | 9090 | Keeps container alive (internal) |

**Why this matters:** If your app crashes, the container **stays alive** because health check still responds. You can shell in with [do-app-sandbox](https://github.com/bikramkgupta/do-app-sandbox) and debug.

## Available Images

| Image | Runtimes | Use Case |
|-------|----------|----------|
| `hot-reload-node` | Node.js 22/24 | Next.js, React, Express |
| `hot-reload-bun` | Bun (latest) | Bun apps, fast bundling |
| `hot-reload-python` | Python 3.12/3.13 | FastAPI, Django, Flask |
| `hot-reload-go` | Go 1.23 | Go APIs, CLI tools |
| `hot-reload-ruby` | Ruby 3.4/3.3 | Rails, Sinatra, Hanami |
| `hot-reload-node-python` | Node.js + Python | Full-stack apps |
| `hot-reload-full` | Node + Python + Go | Multi-language |

## Environment Variables

### Required in App Spec

| Variable | Description |
|----------|-------------|
| `GITHUB_REPO_URL` | Auto-filled by the workflow (current repo); override if deploying a different repo |
| `DEV_START_COMMAND` | Startup command (default: `bash dev_startup.sh`) |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `GITHUB_TOKEN` | - | For private repos (use `${APP_GITHUB_TOKEN}`) |
| `GITHUB_BRANCH` | main | Branch to sync |
| `GITHUB_REPO_FOLDER` | - | Subfolder for monorepos |
| `GITHUB_SYNC_INTERVAL` | 15 | Sync frequency (seconds) |

### Scope Options

| Scope | When Available | Use Case |
|-------|----------------|----------|
| `RUN_TIME` | Only at run-time | Database URLs, API keys |
| `BUILD_TIME` | Only at build-time | NPM tokens |
| `RUN_AND_BUILD_TIME` | Both | Shared configs |

## Instance Sizes

See [DigitalOcean Pricing](https://docs.digitalocean.com/products/app-platform/details/pricing/) for current prices.

**Shared CPU (dev/testing):**
- `apps-s-1vcpu-0.5gb` - Basic
- `apps-s-1vcpu-1gb` - Starter
- `apps-s-1vcpu-2gb` - Development (recommended)
- `apps-s-2vcpu-4gb` - Professional

**Dedicated CPU (production-like):**
- `apps-d-1vcpu-0.5gb` through `apps-d-8vcpu-32gb`

## Workflow Reference

### Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `action` | deploy | `deploy` or `delete` |
| `app_spec_path` | .do/app.yaml | Path to your app spec |

### Deploy

```bash
# Uses default .do/app.yaml
gh workflow run deploy-app.yml -f action=deploy

# Use a different app spec
gh workflow run deploy-app.yml -f action=deploy -f app_spec_path=.do/staging.yaml
```

### Delete

```bash
gh workflow run deploy-app.yml -f action=delete
```

## Important Notes

- **Port 8080**: Your app must listen on port 8080, bound to `0.0.0.0`
- **Port 9090**: Reserved for health check—don't use in your app
- **Hot reload**: Use a dev server that supports it (`npm run dev`, `uvicorn --reload`, etc.)
- **Template repo URL**: If `GITHUB_REPO_URL` points at this template repo, you’ll only see the welcome page until you point to your app repo (or add your own `dev_startup.sh` here).
- **Resource sizing**: Ensure your container has enough CPU/memory

## Troubleshooting

| Issue | Solution |
|-------|----------|
| App doesn't start | Check `dev_startup.sh` exists and is executable |
| Health check fails | Ensure app listens on port 8080 (not 9090) |
| Private repo access | Add `APP_GITHUB_TOKEN` to GitHub Secrets |
| Workflow fails | Check `DIGITALOCEAN_ACCESS_TOKEN` is set |
| npm install fails | Use larger instance (2GB+ for large projects) |

## Multi-component Applications

DigitalOcean App Platform lets you run multiple components in one app. Each component can use this template image and its own `GITHUB_REPO_FOLDER` (for monorepos) and `DEV_START_COMMAND`. See an example with Bun + Node + load tester on the dev branch here: https://github.com/bikramkgupta/bun-node-comparison-harness/tree/dev

## Files in This Repo

```
├── .github/workflows/
│   ├── deploy-app.yml         # Deploy/delete apps via Actions
│   └── build-and-push-images.yml
├── .do/
│   └── app.yaml               # Your app spec (edit this!)
├── app-specs/                 # Example specs for each runtime
├── examples/                  # Startup script examples
├── scripts/                   # Container scripts
└── Dockerfile                 # Multi-stage build
```

## Contributing

1. Fork this repo
2. Make changes
3. Submit PR

---

**Questions?** Open an issue or check [agent.md](agent.md) for the AI assistant deployment guide.
