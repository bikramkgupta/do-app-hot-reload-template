# AI Agent Playbook: Hot Reload Dev Environment

**Deploy a dev/staging environment in ~1 minute using pre-built Docker images.**

## The Philosophy

```
┌─────────────────────────────────────────────────────────────────┐
│  GITHUB ACTIONS (Recommended for AI Agents)                     │
│    • One command to deploy: gh workflow run                    │
│    • Secrets stay in GitHub - never in conversation logs       │
│    • No need to handle GITHUB_REPO_URL - auto-detected         │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  SECRETS (GitHub Secrets → App Platform)                        │
│    • DIGITALOCEAN_ACCESS_TOKEN → Authenticates with DO         │
│    • APP_GITHUB_TOKEN → For private repo access                │
│    • DATABASE_URL, API_KEY, etc. → App secrets                 │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Deploy via GitHub Actions (Recommended)

### Prerequisites
Ensure these GitHub Secrets are configured in the repository:
- `DIGITALOCEAN_ACCESS_TOKEN` (required)
- `APP_GITHUB_TOKEN` (if private repo)
- Any app-specific secrets (DATABASE_URL, etc.)

### Deploy a New App

```bash
gh workflow run deploy-app.yml \
  -f action=deploy \
  -f app_name=my-dev-app \
  -f runtime=node \
  -f region=syd1
```

That's it! The workflow handles:
- Setting `GITHUB_REPO_URL` automatically from repository context
- Injecting secrets from GitHub Secrets
- Creating or updating the app

### Delete an App

```bash
gh workflow run deploy-app.yml \
  -f action=delete \
  -f app_name=my-dev-app
```

### Available Parameters

| Parameter | Options | Default |
|-----------|---------|---------|
| `action` | deploy, delete | deploy |
| `app_name` | string | hot-reload-dev |
| `runtime` | node, bun, python, go, ruby, node-python, full | node |
| `region` | nyc1, nyc3, ams3, sfo3, sgp1, lon1, fra1, tor1, blr1, syd1 | syd1 |
| `instance_size` | apps-s-1vcpu-0.5gb, apps-s-1vcpu-1gb, apps-s-1vcpu-2gb, apps-s-2vcpu-4gb | apps-s-1vcpu-1gb |
| `branch` | string | (default branch) |
| `repo_folder` | string | (root) |
| `dev_start_command` | string | bash dev_startup.sh |

### Check Workflow Status

```bash
# List recent runs
gh run list --workflow=deploy-app.yml

# Watch a specific run
gh run watch

# View logs
gh run view --log
```

---

## Why GitHub Actions for AI Agents?

| Approach | Secrets Handling | AI-Friendly | Complexity |
|----------|------------------|-------------|------------|
| **GitHub Actions** | ✅ GitHub Secrets | ✅ Single command | Low |
| doctl CLI | ⚠️ Local files | ⚠️ Complex args | Medium |
| DO Console | ✅ Manual entry | ❌ Not automatable | Medium |

**Benefits for AI agents:**
1. **No secret exposure** - Secrets never appear in conversation
2. **No GITHUB_REPO_URL needed** - Automatically detected
3. **No doctl installation** - Just `gh` CLI
4. **Idempotent** - Same command creates or updates

---

## Alternative: Deploy with doctl CLI

Use this approach only if GitHub Actions is not available.

### 1. Choose the right image

| Runtime | Image |
|---------|-------|
| Node.js | `ghcr.io/bikramkgupta/hot-reload-node` |
| Bun | `ghcr.io/bikramkgupta/hot-reload-bun` |
| Python | `ghcr.io/bikramkgupta/hot-reload-python` |
| Go | `ghcr.io/bikramkgupta/hot-reload-go` |
| Ruby | `ghcr.io/bikramkgupta/hot-reload-ruby` |
| Node + Python | `ghcr.io/bikramkgupta/hot-reload-node-python` |
| All runtimes | `ghcr.io/bikramkgupta/hot-reload-full` |

### 2. Create app spec

```yaml
name: dev-environment
region: syd1

services:
  - name: dev-workspace
    image:
      registry_type: GHCR
      registry: bikramkgupta
      repository: hot-reload-node  # Change for your runtime
      tag: latest
    http_port: 8080
    health_check:
      http_path: /health
      port: 8080
    envs:
      - key: GITHUB_REPO_URL
        value: "https://github.com/USER/REPO"
      - key: DEV_START_COMMAND
        value: "bash dev_startup.sh"
      # Only if private repo:
      - key: GITHUB_TOKEN
        value: ""
        type: SECRET
```

### 3. Deploy

```bash
doctl apps create --spec app.yaml
```

### 4. Add secrets via local spec (never commit!)

Create `.do/app.local.yaml`:

```yaml
name: dev-environment
services:
  - name: dev-workspace
    envs:
      - key: DATABASE_URL
        value: "postgresql://user:pass@host:5432/db"
        scope: RUN_TIME
```

```bash
doctl apps update $APP_ID --spec .do/app.local.yaml
```

---

## User's Repository Setup

Tell users their repo needs:

### dev_startup.sh (required)

```bash
#!/bin/bash
# Environment variables are injected by DO App Platform
# No need to load .env - secrets come from GitHub Secrets

# Install dependencies and start dev server
npm install
npm run dev -- --hostname 0.0.0.0 --port 8080
```

### .env.example (template only - no real values!)

```bash
# Copy to .env.local for local development
# For deployed apps, secrets are managed via GitHub Secrets
DATABASE_URL=
API_KEY=
STRIPE_SECRET=
```

---

## Remote Troubleshooting with do-app-sandbox

**AI agents can remotely control and troubleshoot the running container** using [do-app-sandbox](https://github.com/bikramkgupta/do-app-sandbox).

### Installation

```bash
# Requires Python 3.10.12+ and doctl authenticated
pip install do-app-sandbox
```

### Get App ID

```bash
# List apps
doctl apps list

# Or from workflow output
gh run view --log | grep "App Name"
```

### Execute Commands in Container

```bash
# Run any command in the running container
sandbox exec $APP_ID "ls -la /workspaces/app"
sandbox exec $APP_ID "cat .env"
sandbox exec $APP_ID "ps aux"
sandbox exec $APP_ID "node --version"

# Check git sync status
sandbox exec $APP_ID "cd /workspaces/app && git log -1 --oneline"
sandbox exec $APP_ID "cat /tmp/last_job_commit.txt"

# Debug application issues
sandbox exec $APP_ID "cat /workspaces/app/package.json"
sandbox exec $APP_ID "npm list --depth=0"
sandbox exec $APP_ID "tail -50 /tmp/app.log"
```

### Common Debugging Scenarios

| What to Check | Command |
|---------------|---------|
| Is code synced? | `sandbox exec $APP_ID "cd /workspaces/app && git log -1"` |
| What's running? | `sandbox exec $APP_ID "ps aux"` |
| Check env loaded | `sandbox exec $APP_ID "env \| grep DATABASE"` |
| View app logs | `sandbox exec $APP_ID "cat /tmp/*.log"` |
| Check disk space | `sandbox exec $APP_ID "df -h"` |
| Test connectivity | `sandbox exec $APP_ID "curl -I https://api.example.com"` |

---

## Complete AI Agent Workflow

### Step 1: Deploy

```bash
gh workflow run deploy-app.yml \
  -f action=deploy \
  -f app_name=my-feature-test \
  -f runtime=node
```

### Step 2: Wait for deployment

```bash
# Watch the workflow
gh run watch

# Or poll for completion
while ! gh run list --workflow=deploy-app.yml --limit=1 --json status -q '.[0].status' | grep -q "completed"; do
  sleep 10
done
```

### Step 3: Get app URL

```bash
doctl apps list --format Name,LiveURL
```

### Step 4: Debug if needed

```bash
APP_ID=$(doctl apps list --format ID,Name --no-header | grep "my-feature-test" | awk '{print $1}')
sandbox exec $APP_ID "tail -100 /tmp/app.log"
```

### Step 5: Clean up when done

```bash
gh workflow run deploy-app.yml \
  -f action=delete \
  -f app_name=my-feature-test
```

---

## Troubleshooting

| Issue | Check | Fix |
|-------|-------|-----|
| Workflow fails | `gh run view --log` | Check DIGITALOCEAN_ACCESS_TOKEN secret |
| Container not starting | `doctl apps logs $APP_ID --type deploy` | Check image name |
| App not running | `doctl apps logs $APP_ID --type run` | Check DEV_START_COMMAND |
| Code not syncing | `sandbox exec $APP_ID "cd /workspaces/app && git status"` | Check GITHUB_REPO_URL |
| Private repo access denied | Check logs for auth errors | Add APP_GITHUB_TOKEN secret |

---

## What NOT to Do

1. **Don't expose secrets in commands** - Use GitHub Secrets, not inline values
2. **Don't use `dockerfile_path`** - Use pre-built images for ~1 minute deploys
3. **Don't enable `deploy_on_push`** - We want git sync, not full rebuilds
4. **Don't hardcode GITHUB_REPO_URL** - Let the workflow detect it automatically

---

## Files Reference

```
# In repository:
.github/workflows/deploy-app.yml  # GitHub Actions workflow
.do/app.yaml                      # App spec template with placeholders

# In container:
/workspaces/app/                  # User's cloned repo
/tmp/last_job_commit.txt          # Last synced commit
```

---

## doctl Commands Cheat Sheet

```bash
# List apps
doctl apps list

# Get app details
doctl apps get $APP_ID

# View logs
doctl apps logs $APP_ID COMPONENT --type run
doctl apps logs $APP_ID COMPONENT --type build
doctl apps logs $APP_ID COMPONENT --type deploy

# Get/update spec
doctl apps spec get $APP_ID > spec.yaml
doctl apps update $APP_ID --spec spec.yaml

# Force redeploy
doctl apps create-deployment $APP_ID

# Delete app
doctl apps delete $APP_ID
```
