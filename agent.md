# AI Agent Playbook: Hot Reload Dev Environment

**Deploy a dev/staging environment in ~1 minute using pre-built Docker images.**

## The Philosophy

```
┌─────────────────────────────────────────────────────────────────┐
│  CONTAINER CONFIG (app.yaml - committed):                       │
│    • GITHUB_REPO_URL → Where's the code?                       │
│    • DEV_START_COMMAND → How to start it?                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  APP SECRETS (DO Console or local spec - never committed):      │
│    • DATABASE_URL, API_KEY, STRIPE_SECRET, etc.                │
│    • Set via: doctl apps update --spec .do/app.local.yaml      │
│    • Or: DO Console → Settings → Environment Variables         │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Deploy (5 Steps)

### 1. Choose the right image

| Runtime | Image |
|---------|-------|
| Node.js | `ghcr.io/bikramkgupta/hot-reload-node` |
| Python | `ghcr.io/bikramkgupta/hot-reload-python` |
| Go | `ghcr.io/bikramkgupta/hot-reload-go` |
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
    internal_ports:
      - 9090  # Health check port - keeps container alive if app crashes
    health_check:
      http_path: /dev_health
      port: 9090  # Separate from app - ensures shell access for debugging
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

**Critical:** The health check is on port 9090, separate from your app on 8080. This ensures shell access even if your app crashes.

### 3. Deploy

```bash
doctl apps create --spec app.yaml
```

### 4. Verify

```bash
# Get app ID
APP_ID=$(doctl apps list --format ID --no-header | head -1)

# Check deployment status
doctl apps get $APP_ID -o json | jq -r '.active_deployment.phase'
# Should be: ACTIVE

# View logs
doctl apps logs $APP_ID dev-workspace --type run --follow

# Test health endpoint
curl https://YOUR-APP-URL.ondigitalocean.app/health
```

### 5. Done!

The container is now syncing code every 15 seconds. Changes to the user's repo appear automatically.

---

## Iterative Deployment (Recommended Approach)

**Deploy incrementally to catch issues early:**

### Step 1: Deploy the bare image first

Create a minimal spec without secrets:

```yaml
name: dev-environment
region: syd1

services:
  - name: dev-workspace
    image:
      registry_type: GHCR
      registry: bikramkgupta
      repository: hot-reload-node
      tag: latest
    http_port: 8080
    internal_ports:
      - 9090
    health_check:
      http_path: /dev_health
      port: 9090
    envs:
      - key: GITHUB_REPO_URL
        value: "https://github.com/USER/REPO"
      - key: DEV_START_COMMAND
        value: "bash dev_startup.sh"
```

```bash
doctl apps create --spec app.yaml
```

**Verify:** Shell access works, code syncs, welcome page or your app shows.

### Step 2: Add app environment variables

Update the spec to add non-secret env vars:

```bash
doctl apps update $APP_ID --spec app.yaml
```

**Verify:** Deployment succeeds, shell access still works.

### Step 3: Add secrets via local spec

Create `.do/app.local.yaml` with secrets (add to `.gitignore`):

```yaml
name: dev-environment
services:
  - name: dev-workspace
    envs:
      - key: DATABASE_URL
        value: "postgresql://user:pass@host:5432/db"
        scope: RUN_TIME
      - key: NEXTAUTH_SECRET
        value: "your-secret"
        scope: RUN_TIME
      - key: STRIPE_SECRET_KEY
        value: "sk_test_xxx"
        scope: RUN_TIME
```

```bash
doctl apps update $APP_ID --spec .do/app.local.yaml
```

**Verify:** App starts correctly with all services connected.

### Why This Approach Works

At every step:
- You have shell access to debug
- You can see exactly what went wrong
- You're not guessing about multiple issues at once

---

## Managing Secrets

**Never commit secrets to GitHub.** Use a local app spec file:

1. Create `.do/app.local.yaml` with your secrets
2. Add `.do/app.local.yaml` to `.gitignore`
3. Deploy with: `doctl apps update $APP_ID --spec .do/app.local.yaml`

This keeps secrets on your local machine only.

---

## User's Repository Setup

Tell users their repo needs:

### dev_startup.sh (required)

```bash
#!/bin/bash
# Environment variables are injected by DO App Platform
# No need to load .env - secrets come from DO Console

# Install dependencies and start dev server
npm install
npm run dev -- --hostname 0.0.0.0 --port 8080
```

### .env.example (template only - no real values!)

```bash
# Copy to .env.local for local development
# For deployed apps, set these in DO Console or local app spec
DATABASE_URL=
API_KEY=
STRIPE_SECRET=
```

**Key point:** Secrets are injected at runtime via DO Console or `.do/app.local.yaml` (gitignored). Never commit actual secrets to your repo.

---

## Remote Troubleshooting with do-app-sandbox

**AI agents can remotely control and troubleshoot the running container** using [do-app-sandbox](https://github.com/bikramkgupta/do-app-sandbox).

### Installation

```bash
# Requires Python 3.10.12+ and doctl authenticated
pip install do-app-sandbox
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
| Check .env loaded | `sandbox exec $APP_ID "env \| grep DATABASE"` |
| View app logs | `sandbox exec $APP_ID "cat /tmp/*.log"` |
| Check disk space | `sandbox exec $APP_ID "df -h"` |
| Test connectivity | `sandbox exec $APP_ID "curl -I https://api.example.com"` |

### Why This Matters for AI Agents

1. **Verify before changing** - Check container state before updating config
2. **Debug without redeploy** - Inspect logs, env vars, processes live
3. **Fast iteration** - Test commands directly, then add to dev_startup.sh
4. **Validate fixes** - Confirm changes worked without waiting for redeploy

---

## Other Common Tasks

### Force redeploy (if needed)

```bash
doctl apps create-deployment $APP_ID
```

### Update environment variable

```bash
# Get current spec
doctl apps spec get $APP_ID > spec.yaml

# Edit spec.yaml, then:
doctl apps update $APP_ID --spec spec.yaml
```

---

## Troubleshooting

| Issue | Check | Fix |
|-------|-------|-----|
| Container not starting | `doctl apps logs $APP_ID --type deploy` | Check image name |
| App not running | `doctl apps logs $APP_ID --type run` | Check DEV_START_COMMAND |
| Code not syncing | `sandbox exec $APP_ID "cd /workspaces/app && git status"` | Check GITHUB_REPO_URL |
| Health check failing | `curl https://APP-URL/health` | Ensure app listens on 8080 |
| Private repo access denied | Check logs for auth errors | Set GITHUB_TOKEN as secret |

---

## What NOT to Do

1. **Don't commit secrets to your repo** - Use DO Console or gitignored local app spec (`.do/app.local.yaml`)
2. **Don't use `dockerfile_path`** - Use pre-built images for ~1 minute deploys
3. **Don't enable `deploy_on_push`** - We want git sync, not full rebuilds

---

## Files Reference

```
app-specs/
├── app-node.yaml      # Node.js image
├── app-python.yaml    # Python image
├── app-go.yaml        # Go image
└── app-full.yaml      # All runtimes

# In container:
/workspaces/app/       # User's cloned repo
/tmp/last_job_commit.txt  # Last synced commit
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
