# AI Agent Playbook: Hot Reload Dev Environment

**Deploy a dev/staging environment in ~1 minute using pre-built Docker images.**

## The Philosophy

```
┌─────────────────────────────────────────────────────────────────┐
│  GITHUB ACTIONS (Recommended for AI Agents)                     │
│    • Configure once in .do/config.yaml                         │
│    • Deploy with: gh workflow run deploy-app.yml               │
│    • Secrets stay in GitHub - never in conversation logs       │
│    • GITHUB_REPO_URL is auto-detected                          │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  SECRETS (GitHub Secrets → App Platform)                        │
│    • DIGITALOCEAN_ACCESS_TOKEN → Authenticates with DO         │
│    • APP_GITHUB_TOKEN → For private repo access                │
│    • DATABASE_URL, API_KEY, etc. → App secrets                 │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Deploy via GitHub Actions

### Prerequisites
Ensure these GitHub Secrets are configured:
- `DIGITALOCEAN_ACCESS_TOKEN` (required)
- `APP_GITHUB_TOKEN` (if private repo)
- Any app-specific secrets (DATABASE_URL, etc.)

### One-Time Setup: Create .do/config.yaml

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

# Plain-text env vars (type: GENERAL)
# Scope: RUN_TIME (default), BUILD_TIME, or RUN_AND_BUILD_TIME
envs:
  NODE_ENV: development          # Simple format (defaults to RUN_TIME)
  NPM_CONFIG_LEGACY_PEER_DEPS:   # Extended format with scope
    value: "true"
    scope: BUILD_TIME

# Encrypted secrets (type: SECRET) - values from GitHub Secrets
# Scope: RUN_TIME (default), BUILD_TIME, or RUN_AND_BUILD_TIME
secrets:
  - DATABASE_URL                 # Simple format (defaults to RUN_TIME)
  - name: NPM_TOKEN              # Extended format with scope
    scope: BUILD_TIME

# Advanced: Use your own app spec for complex deployments
# app_spec_path: .do/my-custom-app.yaml
```

### Deploy (Simple)

```bash
# Uses config.yaml settings - no arguments needed!
gh workflow run deploy-app.yml -f action=deploy
```

That's it! The workflow reads `.do/config.yaml` and handles everything.

### Deploy (With Overrides)

```bash
gh workflow run deploy-app.yml \
  -f action=deploy \
  -f app_name=my-feature-test \
  -f runtime=python \
  -f region=nyc1
```

### Delete an App

```bash
# Uses app_name from config.yaml
gh workflow run deploy-app.yml -f action=delete

# Or specify explicitly
gh workflow run deploy-app.yml -f action=delete -f app_name=my-dev-app
```

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

## Available Parameters

All parameters are optional—they override `.do/config.yaml` values.

| Parameter | Options | Default |
|-----------|---------|---------|
| `action` | deploy, delete | deploy |
| `app_name` | string | hot-reload-dev |
| `runtime` | node, bun, python, go, ruby, node-python, full | node |
| `region` | nyc1, nyc3, ams3, sfo3, sgp1, lon1, fra1, tor1, blr1, syd1 | syd1 |
| `instance_size` | see pricing docs | apps-s-1vcpu-2gb |
| `branch` | string | (default branch) |
| `repo_folder` | string | (root) |
| `sync_interval` | number | 15 |
| `dev_start_command` | string | bash dev_startup.sh |
| `pre_deploy_command` | string | (none) |
| `post_deploy_command` | string | (none) |

### Instance Sizes

See [DigitalOcean Pricing](https://docs.digitalocean.com/products/app-platform/details/pricing/) for current prices.

**Shared CPU (dev/testing):**
- `apps-s-1vcpu-0.5gb`, `apps-s-1vcpu-1gb`, `apps-s-1vcpu-2gb`, `apps-s-2vcpu-4gb`

**Dedicated CPU (production-like):**
- `apps-d-1vcpu-0.5gb` through `apps-d-8vcpu-32gb`

---

## Why GitHub Actions for AI Agents?

| Approach | Secrets Handling | AI-Friendly | Complexity |
|----------|------------------|-------------|------------|
| **GitHub Actions** | ✅ GitHub Secrets | ✅ Single command | Low |
| doctl CLI | ⚠️ Local files | ⚠️ Complex args | Medium |
| DO Console | ✅ Manual entry | ❌ Not automatable | Medium |

**Benefits for AI agents:**
1. **Configure once** - Set `.do/config.yaml`, never re-enter
2. **No secret exposure** - Secrets never appear in conversation
3. **No GITHUB_REPO_URL needed** - Automatically detected
4. **No doctl installation** - Just `gh` CLI
5. **Idempotent** - Same command creates or updates

---

## Environment Variables & Secrets

The workflow dynamically generates env vars from `.do/config.yaml`:

### Plain-text (type: GENERAL)
```yaml
envs:
  NODE_ENV: development     # Simple (defaults to RUN_TIME)
  NPM_CONFIG_LEGACY_PEER_DEPS:
    value: "true"
    scope: BUILD_TIME       # Extended format with scope
```

### Encrypted (type: SECRET)
```yaml
secrets:
  - DATABASE_URL            # Simple (defaults to RUN_TIME)
  - name: NPM_TOKEN
    scope: BUILD_TIME       # Extended format with scope
```

### Scope Options
| Scope | When Available |
|-------|----------------|
| `RUN_TIME` (default) | Only at run-time |
| `BUILD_TIME` | Only at build-time |
| `RUN_AND_BUILD_TIME` | Both build and run-time |

**Steps for secrets:**
1. Add secret to GitHub (Settings → Secrets and variables → Actions)
2. Add name to `secrets:` list in config.yaml (with optional scope)
3. Deploy - the workflow injects it automatically

You can have any number of envs and secrets. The workflow reads your lists and generates the app spec dynamically.

### Advanced: Custom App Spec

For complex deployments (VPC, custom domains, multiple services):

```yaml
# In .do/config.yaml
app_spec_path: .do/my-custom-app.yaml
```

When set, the workflow uses your spec directly instead of generating one.

---

## User's Repository Setup

The user's repo needs a `dev_startup.sh` script:

### dev_startup.sh (required)

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

> **Important:** Use `dev_startup.sh` for dependency installation, NOT `PRE_DEPLOY_COMMAND`. If `PRE_DEPLOY_COMMAND` fails, the container exits and you lose shell access.

See `examples/` for complete scripts for each runtime.

---

## Remote Troubleshooting with do-app-sandbox

**AI agents can remotely control and troubleshoot the running container** using [do-app-sandbox](https://github.com/bikramkgupta/do-app-sandbox).

### Installation

```bash
pip install do-app-sandbox
```

### Get App ID

```bash
doctl apps list --format ID,Name --no-header
```

### Execute Commands in Container

```bash
# Run any command in the running container
sandbox exec $APP_ID "ls -la /workspaces/app"
sandbox exec $APP_ID "ps aux"
sandbox exec $APP_ID "node --version"

# Check git sync status
sandbox exec $APP_ID "cd /workspaces/app && git log -1 --oneline"

# Debug application issues
sandbox exec $APP_ID "tail -100 /tmp/app.log"
sandbox exec $APP_ID "cat /workspaces/app/package.json"
sandbox exec $APP_ID "env | grep DATABASE"
```

### Common Debugging Scenarios

| What to Check | Command |
|---------------|---------|
| Is code synced? | `sandbox exec $APP_ID "cd /workspaces/app && git log -1"` |
| What's running? | `sandbox exec $APP_ID "ps aux"` |
| Check env loaded | `sandbox exec $APP_ID "env \| grep DATABASE"` |
| View app logs | `sandbox exec $APP_ID "cat /tmp/*.log"` |
| Check disk space | `sandbox exec $APP_ID "df -h"` |

---

## Complete AI Agent Workflow

### Step 1: Deploy

```bash
gh workflow run deploy-app.yml -f action=deploy
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
APP_ID=$(doctl apps list --format ID,Name --no-header | grep "my-dev-app" | awk '{print $1}')
sandbox exec $APP_ID "tail -100 /tmp/app.log"
```

### Step 5: Clean up when done

```bash
gh workflow run deploy-app.yml -f action=delete
```

---

## Troubleshooting

| Issue | Check | Fix |
|-------|-------|-----|
| Workflow fails | `gh run view --log` | Check DIGITALOCEAN_ACCESS_TOKEN secret |
| Container not starting | `doctl apps logs $APP_ID --type deploy` | Check image name |
| App not running | `doctl apps logs $APP_ID --type run` | Check dev_startup.sh exists |
| Code not syncing | `sandbox exec $APP_ID "cd /workspaces/app && git status"` | Check branch setting |
| Private repo access denied | Check logs for auth errors | Add APP_GITHUB_TOKEN secret |
| npm install fails | Check instance size | Use apps-s-1vcpu-2gb or larger |

---

## What NOT to Do

1. **Don't expose secrets in commands** - Use GitHub Secrets, not inline values
2. **Don't use `PRE_DEPLOY_COMMAND` for npm install** - It fails → container exits → no shell access
3. **Don't use `dockerfile_path`** - Use pre-built images for ~1 minute deploys
4. **Don't enable `deploy_on_push`** - We want git sync, not full rebuilds
5. **Don't hardcode GITHUB_REPO_URL** - Let the workflow detect it automatically

---

## Files Reference

```
# In repository:
.do/config.yaml                   # Persistent deployment settings
.github/workflows/deploy-app.yml  # GitHub Actions workflow

# In container:
/workspaces/app/                  # User's cloned repo
/tmp/last_job_commit.txt          # Last synced commit
/tmp/app.log                      # Application logs
```

---

## doctl Commands Cheat Sheet

```bash
# List apps
doctl apps list

# Get app details
doctl apps get $APP_ID

# View logs
doctl apps logs $APP_ID dev-workspace --type run
doctl apps logs $APP_ID dev-workspace --type deploy

# Force redeploy
doctl apps create-deployment $APP_ID

# Delete app
doctl apps delete $APP_ID
```
