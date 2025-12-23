# AI Agent Deployment Guide

Deploy hot-reload dev environments to DigitalOcean App Platform.

## Quick Deploy

```bash
# Deploy (uses .do/app.yaml)
gh workflow run deploy-app.yml -f action=deploy

# Delete
gh workflow run deploy-app.yml -f action=delete
```

That's it! The workflow reads `.do/app.yaml` and handles everything.

## Setup (One-Time)

### 1. Add GitHub Secrets

Go to Settings → Secrets and variables → Actions:
- `DIGITALOCEAN_ACCESS_TOKEN` (required)
- `APP_GITHUB_TOKEN` (if private repo)
- Any app-specific secrets (DATABASE_URL, etc.)

### 2. Create `.do/app.yaml`

Edit the app spec for your project. Use `${SECRET_NAME}` for secrets:

```yaml
name: my-dev-app
region: syd1

services:
  - name: dev-workspace
    image:
      registry_type: GHCR
      registry: bikramkgupta
      repository: hot-reload-node
      tag: latest

    instance_size_slug: apps-s-1vcpu-2gb
    http_port: 8080
    internal_ports:
      - 9090

    health_check:
      http_path: /dev_health
      port: 9090
      initial_delay_seconds: 10
      period_seconds: 10

    envs:
      - key: GITHUB_REPO_URL
        value: "https://github.com/YOUR_USERNAME/YOUR_REPO"
        scope: RUN_TIME

      - key: GITHUB_TOKEN
        value: "${APP_GITHUB_TOKEN}"
        scope: RUN_TIME
        type: SECRET

      - key: DEV_START_COMMAND
        value: "bash dev_startup.sh"
        scope: RUN_TIME

      # Your secrets
      - key: DATABASE_URL
        value: "${DATABASE_URL}"
        scope: RUN_TIME
        type: SECRET
```

### 3. Create `dev_startup.sh`

```bash
#!/bin/bash
set -e
npm install
exec npm run dev -- --hostname 0.0.0.0 --port 8080
```

## Deploy with Different Specs

```bash
# Production-like environment
gh workflow run deploy-app.yml -f action=deploy -f app_spec_path=.do/staging.yaml
```

## Secrets

1. Add secret to GitHub (Settings → Secrets → Actions)
2. Reference in app spec: `value: "${SECRET_NAME}"`
3. Deploy - the workflow substitutes values

Pre-wired secrets in workflow:
- `APP_GITHUB_TOKEN`, `DATABASE_URL`, `REDIS_URL`, `MONGODB_URI`
- `AUTH_SECRET`, `NEXTAUTH_SECRET`, `JWT_SECRET`, `SESSION_SECRET`
- `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`
- `STRIPE_SECRET_KEY`, `AWS_ACCESS_KEY_ID`, `SENTRY_DSN`
- `CUSTOM_SECRET_1` through `CUSTOM_SECRET_10`

## Runtimes

| Repository | Use Case |
|------------|----------|
| `hot-reload-node` | Node.js, Next.js, React |
| `hot-reload-bun` | Bun apps |
| `hot-reload-python` | FastAPI, Django, Flask |
| `hot-reload-go` | Go APIs |
| `hot-reload-ruby` | Rails, Sinatra |
| `hot-reload-full` | Multi-language |

## Regions

| Code | Location |
|------|----------|
| `nyc1`, `nyc3` | New York |
| `sfo3` | San Francisco |
| `ams3` | Amsterdam |
| `sgp1` | Singapore |
| `lon1` | London |
| `fra1` | Frankfurt |
| `tor1` | Toronto |
| `blr1` | Bangalore |
| `syd1` | Sydney |

## Instance Sizes

| Slug | Specs |
|------|-------|
| `apps-s-1vcpu-0.5gb` | 1 vCPU, 0.5GB |
| `apps-s-1vcpu-1gb` | 1 vCPU, 1GB |
| `apps-s-1vcpu-2gb` | 1 vCPU, 2GB (recommended) |
| `apps-s-2vcpu-4gb` | 2 vCPU, 4GB |

See [pricing](https://docs.digitalocean.com/products/app-platform/details/pricing/).

## Environment Variables

### Required

| Key | Description |
|-----|-------------|
| `GITHUB_REPO_URL` | Your repo URL |
| `DEV_START_COMMAND` | Startup command |

### Optional

| Key | Default | Description |
|-----|---------|-------------|
| `GITHUB_TOKEN` | - | For private repos |
| `GITHUB_BRANCH` | main | Branch to sync |
| `GITHUB_REPO_FOLDER` | - | Monorepo subfolder |
| `GITHUB_SYNC_INTERVAL` | 15 | Sync frequency (seconds) |

### Scope Options

| Scope | When Available |
|-------|----------------|
| `RUN_TIME` | Only at run-time (default) |
| `BUILD_TIME` | Only at build-time |
| `RUN_AND_BUILD_TIME` | Both |

---

## Remote Troubleshooting with do-app-sandbox

**AI agents can remotely control and troubleshoot the running container** using [do-app-sandbox](https://github.com/bikramkgupta/do-app-sandbox).

### Get App ID

```bash
doctl apps list --format ID,Name --no-header
```

### Execute Commands in Container

```bash
# Run any command in the running container
sandbox exec $APP_ID "ls -la /workspaces/app"
sandbox exec $APP_ID "tail -100 /tmp/app.log"
sandbox exec $APP_ID "env | grep DATABASE"
```

### Common Debugging Scenarios

| What to Check | Command |
|---------------|---------|
| Is code synced? | `sandbox exec $APP_ID "cd /workspaces/app && git log -1"` |
| What's running? | `sandbox exec $APP_ID "ps aux"` |
| Check env loaded | `sandbox exec $APP_ID "env \| grep DATABASE"` |
| View app logs | `sandbox exec $APP_ID "cat /tmp/*.log"` |

---

## Complete AI Agent Workflow

### Step 1: Deploy

```bash
gh workflow run deploy-app.yml -f action=deploy
```

### Step 2: Wait for deployment

```bash
gh run watch
```

### Step 3: Get app URL

```bash
doctl apps list --format Name,LiveURL
```

### Step 4: Debug if needed

```bash
APP_ID=$(doctl apps list --format ID,Name --no-header | grep "my-dev-app" | awk '{print $1}')
sandbox exec $APP_ID "tail -100 /tmp/app.log"
```

### Step 5: Clean up when done

```bash
gh workflow run deploy-app.yml -f action=delete
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Workflow fails | Check DIGITALOCEAN_ACCESS_TOKEN secret |
| Private repo fails | Add APP_GITHUB_TOKEN secret |
| App doesn't start | Check dev_startup.sh exists |
| Health check fails | App must listen on port 8080 |

---

## doctl Commands Cheat Sheet

```bash
# List apps
doctl apps list

# View logs
doctl apps logs $APP_ID dev-workspace --type run

# Force redeploy
doctl apps create-deployment $APP_ID

# Delete app
doctl apps delete $APP_ID
```
