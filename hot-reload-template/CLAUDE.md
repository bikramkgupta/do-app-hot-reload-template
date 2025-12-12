# CLAUDE.md - AI Agent Source of Truth

**Last Updated:** 2025-12-10
**Purpose:** Comprehensive reference for AI agents working with the DigitalOcean App Platform hot-reload development template.

This document serves as the master reference. Read this first, then consult linked documents for specific details.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [Critical Files & Their Roles](#critical-files--their-roles)
4. [Deployment Buttons & Branches](#deployment-buttons--branches)
5. [Runtime Configuration](#runtime-configuration)
6. [Deploy Jobs System](#deploy-jobs-system)
7. [Common Issues & Solutions](#common-issues--solutions)
8. [Agent Workflows](#agent-workflows)
9. [Quick Reference](#quick-reference)
10. [Key Principles for AI Agents](#key-principles-for-ai-agents)
11. [Critical Configuration Patterns](#critical-configuration-patterns)
12. [Documentation Map](#documentation-map)

---

## System Overview

### What This Is

A **hot-reload development environment** for DigitalOcean App Platform that:
- Clones a GitHub repository into a running container
- Syncs code changes every 15 seconds (configurable)
- Runs your dev server with hot-reload enabled
- Supports Node.js, Python, Go, Ruby, Rust runtimes
- Executes pre-deploy and post-deploy jobs on git commit changes
- Provides health check endpoints for bootstrap

### Key Principle

**Code lives in user's GitHub repository, not in this template.**
The template is infrastructure that runs their code.

### Use Cases

- Rapid iteration without rebuild cycles
- Testing code changes in cloud environment
- Multi-developer collaboration with shared dev instance
- CI/CD prototyping
- Database migration testing

---

## Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────┐
│  DigitalOcean App Platform Container                    │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │ 1. DOCKERFILE (Build Phase)                    │    │
│  │    - Multi-stage build                         │    │
│  │    - Compile dev-health-server (Go binary)     │    │
│  │    - Install runtimes based on INSTALL_* args  │    │
│  │    - Install database clients                  │    │
│  └────────────────────────────────────────────────┘    │
│                      ↓                                  │
│  ┌────────────────────────────────────────────────┐    │
│  │ 2. STARTUP.SH (Container Start)                │    │
│  │    - Load runtime environments                 │    │
│  │    - Clone GitHub repo → /workspaces/app       │    │
│  │    - Execute PRE_DEPLOY job (strict)           │    │
│  │    - Start github-sync.sh (background)         │    │
│  │    - Start welcome-page server (temp)          │    │
│  │    - Start dev-health server (optional)        │    │
│  │    - Execute POST_DEPLOY job (background)      │    │
│  │    - Run DEV_START_COMMAND                     │    │
│  └────────────────────────────────────────────────┘    │
│                      ↓                                  │
│  ┌────────────────────────────────────────────────┐    │
│  │ 3. CONTINUOUS SYNC (Every 15s)                 │    │
│  │    - git fetch + pull                          │    │
│  │    - Check commit SHA changed                  │    │
│  │    - If changed: Execute deploy jobs           │    │
│  │    - Rsync monorepo folder (if configured)     │    │
│  │    - User's dev server handles hot-reload      │    │
│  └────────────────────────────────────────────────┘    │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │ Running Services                                │    │
│  │  • User App (port 8080)                        │    │
│  │  • Dev Health Server (port 9090, optional)     │    │
│  │  • Welcome Page (port 8080, auto-stops)        │    │
│  │  • GitHub Sync Daemon (background)             │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### Data Flow

```
GitHub Repo
    ↓ (git clone on startup)
/workspaces/app
    ↓ (git pull every 15s)
Code Changes Detected
    ↓ (if commit SHA changed)
Deploy Jobs Execute
    ↓
User's Dev Server Reloads
```

---

## Critical Files & Their Roles

### Core Infrastructure (hot-reload-template/)

| File | Purpose | When to Edit |
|------|---------|--------------|
| **Dockerfile** | Multi-stage build. Installs runtimes based on `INSTALL_*` args. Compiles Go health server. | Add new runtime, change base image |
| **scripts/startup.sh** | Container entrypoint. Orchestrates entire boot sequence. | Change startup flow, add services |
| **scripts/github-sync.sh** | Background daemon. Clones repo, pulls changes every 15s, executes deploy jobs. | Adjust sync logic, add hooks |
| **scripts/job-manager.sh** | Executes PRE_DEPLOY and POST_DEPLOY jobs. Handles monorepo patterns. | Modify job execution logic |
| **scripts/dev-health-server/** | Go binary (compiled during build). Provides `/dev_health` endpoint on port 9090. | Customize health endpoint |
| **scripts/welcome-page-server/** | Go binary. Shows welcome page on port 8080 until user app starts. | Customize welcome page |
| **app.yaml** | App Platform spec template. Defines build args, env vars, health checks. | Configure new deployment |
| **.do/deploy.template.yaml** | Deploy button spec (main branch). | Update deploy button config |

### Deploy Branches (Each has optimized .do/deploy.template.yaml)

| Branch | Runtime | Sample App | Deploy Jobs |
|--------|---------|------------|-------------|
| **deploy-blank** | None (user chooses) | None | Disabled (empty commands) |
| **deploy-nextjs** | Node.js | nextjs-sample-app | ✓ Has scripts |
| **deploy-python** | Python | python-fastapi-sample | ✗ Disabled |
| **deploy-go** | Go | go-sample-app | ✗ Disabled |
| **deploy-rails** | Ruby | ruby-rails-sample | ✓ Has scripts |
| **deploy-nodejs** | Node.js | nodejs-job-test | ✓ Has scripts |

### Sample Applications (hot-reload-template/app-examples/)

Each app demonstrates the hot-reload pattern:

```
app-examples/
├── nextjs-sample-app/
│   ├── dev_startup.sh          # Nodemon + npm install on package.json change
│   ├── scripts/
│   │   ├── pre-deploy/migrate.sh
│   │   └── post-deploy/seed.sh
│   └── README.md
├── python-fastapi-sample/
│   ├── dev_startup.sh          # Uvicorn with auto-reload
│   └── README.md
├── go-sample-app/
│   ├── dev_startup.sh          # Air (hot reload for Go)
│   └── README.md
├── ruby-rails-sample/
│   ├── dev_startup.sh          # Rails server
│   ├── scripts/                # Placeholder scripts
│   └── README.md
└── nodejs-job-test/
    ├── dev_startup.sh
    ├── scripts/
    └── README.md
```

---

## Deployment Buttons & Branches

### How Deploy Buttons Work

Each "Deploy to DO" button points to a specific branch with optimized configuration:

```
Deploy Button URL:
https://cloud.digitalocean.com/apps/new?repo=https://github.com/{user}/{repo}/tree/{branch}

Examples:
- deploy-nextjs  → Next.js app with Node.js runtime
- deploy-python  → FastAPI app with Python runtime
- deploy-go      → Go app with Golang runtime
- deploy-rails   → Rails app with Ruby runtime
- deploy-nodejs  → Express app with Node.js runtime
- deploy-blank   → Empty template (user configures)
```

### Branch Configuration Pattern

Each deploy branch has `.do/deploy.template.yaml` with:

1. **Correct runtime enabled**
   ```yaml
   - key: INSTALL_NODE
     value: "true"
     scope: BUILD_TIME
   - key: INSTALL_RUBY  # Explicitly disable others
     value: "false"
     scope: BUILD_TIME
   ```

2. **Repo folder specified**
   ```yaml
   - key: GITHUB_REPO_FOLDER
     value: "hot-reload-template/app-examples/nextjs-sample-app"
   ```

3. **Deploy jobs configured**
   ```yaml
   - key: PRE_DEPLOY_COMMAND
     value: "bash migrate.sh"  # or "" if no scripts
   ```

### Recent Fixes (2025-12-10)

**Problem:** Ruby was installed by default for all apps (Dockerfile had `INSTALL_RUBY=true`)

**Solution:**
- Main branch: Changed Dockerfile default to `INSTALL_RUBY=false`
- All deploy branches: Added explicit `INSTALL_RUBY=false` (except deploy-rails)
- Python/Go branches: Disabled deploy jobs (scripts don't exist)
- Added rsync exclusions for `node_modules`, `.next`, `__pycache__`

---

## Runtime Configuration

### Dockerfile Build Arguments

**Pattern:** Each runtime is optional, controlled by build args.

```dockerfile
# Defaults (as of 2025-12-10)
ARG INSTALL_NODE=false
ARG INSTALL_PYTHON=false
ARG INSTALL_GOLANG=false
ARG INSTALL_RUST=false
ARG INSTALL_RUBY=false    # Changed from true to false

ARG INSTALL_POSTGRES=true  # Database clients
ARG INSTALL_MONGODB=false
ARG INSTALL_MYSQL=false
```

### Runtime Installation Locations

| Runtime | Install Method | Version Control | User Access |
|---------|---------------|-----------------|-------------|
| **Node.js** | nvm | `NODE_VERSIONS`, `NODE_DEFAULT_VERSION` | `nvm use <version>` |
| **Python** | pyenv | `PYTHON_VERSIONS`, `PYTHON_DEFAULT_VERSION` | `pyenv global <version>` |
| **Go** | Direct install | `GOLANG_VERSION` | Always in PATH |
| **Ruby** | rbenv | `RUBY_VERSIONS`, `DEFAULT_RUBY` | `rbenv global <version>` |
| **Rust** | rustup | Latest stable | `rustup update` |

### Key Principle: No Runtime by Default

**Why?**
- Smaller Docker images (faster builds)
- Only install what you need
- Each deploy branch explicitly enables its runtime

**Example:** Python app must set:
```yaml
- key: INSTALL_PYTHON
  value: "true"
  scope: BUILD_TIME
- key: INSTALL_RUBY
  value: "false"  # Explicit override
  scope: BUILD_TIME
```

---

## Deploy Jobs System

**Full Documentation:** See [docs/JOBS.md](docs/JOBS.md) (comprehensive 850-line guide)

### Quick Summary

**What:** Shell scripts that run at deployment lifecycle points

**When:** Only when git commit SHA changes (not every 15s sync)

**Types:**
- **PRE_DEPLOY (Strict):** Must succeed or container exits
- **POST_DEPLOY (Lenient):** Failure logged, app continues

### Configuration

**Minimal setup:**
```yaml
envs:
  - key: PRE_DEPLOY_FOLDER
    value: "scripts/pre-deploy"
  - key: PRE_DEPLOY_COMMAND
    value: "bash migrate.sh"
  - key: PRE_DEPLOY_TIMEOUT
    value: "300"

  - key: POST_DEPLOY_FOLDER
    value: "scripts/post-deploy"
  - key: POST_DEPLOY_COMMAND
    value: "bash seed.sh"
  - key: POST_DEPLOY_TIMEOUT
    value: "300"
```

### Repository Patterns

1. **Same-repo:** Jobs in `scripts/` of application repo
2. **Monorepo:** Jobs in subfolder (uses `GITHUB_REPO_FOLDER`)
3. **Multi-repo:** Jobs in separate repository (uses `PRE_DEPLOY_REPO_URL`)

### Execution Flow

```bash
# Initial startup
1. Clone repo
2. Execute PRE_DEPLOY → Must succeed
3. Start sync service
4. Execute POST_DEPLOY (background) → Can fail
5. Start app

# Every 15s sync
1. git pull
2. Check commit SHA
3. If changed:
   - Execute PRE_DEPLOY → Must succeed
   - Execute POST_DEPLOY → Can fail
   - Update SHA tracking file
```

### Common Use Cases

| Task | Job Type | Why |
|------|----------|-----|
| Database migrations | PRE_DEPLOY | App needs schema before starting |
| Environment validation | PRE_DEPLOY | Verify required env vars exist |
| Data seeding | POST_DEPLOY | Sample data not critical |
| Cache warming | POST_DEPLOY | Performance optimization |
| Slack notifications | POST_DEPLOY | Nice to have |

### Important: Empty Commands Disable Jobs

```yaml
- key: PRE_DEPLOY_COMMAND
  value: ""  # Empty = job skipped (no error)
```

This is used for apps without deploy scripts (Python, Go samples).

---

## Common Issues & Solutions

### Issue 1: Ruby Installed When Python/Go Expected

**Symptom:** Logs show "✓ Ruby 3.4.7" but app needs Python

**Root Cause:** Dockerfile had `INSTALL_RUBY=true` by default

**Fix Applied (2025-12-10):**
- Dockerfile: `INSTALL_RUBY=false`
- Deploy branches: Explicit `INSTALL_RUBY=false` in appspec

**Verify Fix:**
```bash
# Check Dockerfile
grep "INSTALL_RUBY=" hot-reload-template/Dockerfile
# Should show: ARG INSTALL_RUBY=false

# Check deploy branch appspec
git checkout deploy-python
grep "INSTALL_RUBY" .do/deploy.template.yaml
# Should show: value: "false"
```

### Issue 2: PRE_DEPLOY Directory Not Found

**Symptom:** `ERROR: Initial PRE_DEPLOY job failed. Container cannot start.`

**Root Cause:** PRE_DEPLOY_COMMAND set but scripts directory doesn't exist

**Solutions:**

**Option A:** Disable deploy jobs
```yaml
- key: PRE_DEPLOY_COMMAND
  value: ""
- key: POST_DEPLOY_COMMAND
  value: ""
```

**Option B:** Create placeholder scripts
```bash
mkdir -p scripts/pre-deploy scripts/post-deploy
echo '#!/bin/bash' > scripts/pre-deploy/migrate.sh
echo 'echo "[PRE-DEPLOY] Placeholder"' >> scripts/pre-deploy/migrate.sh
chmod +x scripts/pre-deploy/migrate.sh
```

### Issue 3: Next.js "Permission Denied" on Binary

**Symptom:** `sh: 1: next: Permission denied`

**Root Cause:** rsync corrupts node_modules during continuous sync

**Fix Applied (2025-12-10):**
```bash
# github-sync.sh now excludes:
rsync -a --delete \
    --exclude 'node_modules' \
    --exclude '.next' \
    --exclude '__pycache__' \
    --exclude '*.pyc' \
    "$source/" "$dest/"
```

**Why:** Dev startup scripts handle `npm install`, rsync shouldn't touch node_modules

### Issue 4: Blank Template Crashes

**Symptom:** deploy-blank button creates app that immediately exits

**Root Cause:** Empty `GITHUB_REPO_URL` but deploy jobs still configured

**Fix Applied (2025-12-10):**
```yaml
# deploy-blank branch .do/deploy.template.yaml
- key: GITHUB_REPO_URL
  value: ""
- key: PRE_DEPLOY_COMMAND
  value: ""  # Was "bash migrate.sh"
- key: POST_DEPLOY_COMMAND
  value: ""  # Was "bash seed.sh"
```

### Issue 5: Lock File Conflicts During Sync

**Symptom:** Git pull fails with "package-lock.json would be overwritten"

**Root Cause:** When `npm install` runs (triggered by nodemon detecting package.json changes), it modifies `package-lock.json`. These local modifications prevent git from performing a fast-forward merge.

**Fix Applied (in github-sync.sh):**
- Before pull, check if branch is behind remote
- If branch is behind and can fast-forward, reset lock files that have local modifications
- Lock files reset: `package-lock.json`, `go.sum`, `uv.lock`, `poetry.lock`
- These files are regenerated by dependency managers anyway

### Issue 6: Health Check Port Not in internal_ports

**Symptom:**
```
Error validating app spec field "services.health_check.port":
health check port "9090" not found in internal_ports.
```

**Root Cause:** App Platform requires health check port to be listed in `internal_ports` if not using `http_port`

**Fix:** Either:
1. Add the port to `internal_ports`:
   ```yaml
   internal_ports:
     - 9090
   health_check:
     port: 9090
   ```
2. OR use `http_port` and remove `internal_ports` entirely:
   ```yaml
   http_port: 8080
   health_check:
     port: 8080
   ```

See "Critical Configuration Patterns" section below for detailed guidance.

---

## Agent Workflows

### Workflow 1: Deploy User's Existing App

**See:** [agent.md](agent.md) (complete playbook)

**Quick Steps:**
1. Verify `doctl` authenticated
2. Collect from user:
   - GitHub repo URL + token (if private)
   - Runtimes needed
   - Startup command or confirm `dev_startup.sh` exists
3. Edit `app.yaml`:
   - Set `INSTALL_*` build args
   - Set `GITHUB_REPO_URL`, `GITHUB_TOKEN` (secret)
   - Set `DEV_START_COMMAND`
   - Configure health check
   - **Verify `deploy_on_push: false`**
4. Deploy: `doctl apps create --spec app.yaml`
5. Monitor: `doctl apps logs <id> --type run --follow`
6. Verify health endpoint responds

**Key Reminder:** Git syncs code but doesn't restart app. User's dev server must handle hot-reload.

### Workflow 2: Fix Deployment Errors

**See:** Recent fixes section above + JOBS.md troubleshooting

**Diagnostic Commands:**
```bash
# Check deployment status
doctl apps get <app-id> -o json | jq -r '.[0].active_deployment.phase'

# View build logs
doctl apps logs <app-id> <component> --type build

# View runtime logs
doctl apps logs <app-id> <component> --type run --follow

# Check inside container
cd doctl_remote_exec
python doctl_remote_exec.py <app-id> <component> "ls -la /workspaces/app"
```

**Common Patterns:**
1. Container exits → PRE_DEPLOY job failed
2. Wrong runtime installed → Check INSTALL_* args
3. Health check fails → Verify endpoint and port match
4. Sync not working → Check GITHUB_TOKEN and repo access

### Workflow 3: Create Deploy Button for New Sample App

**Steps:**
1. Create sample app in `app-examples/new-app/`
2. Add `dev_startup.sh` with hot-reload
3. Create deploy branch: `git checkout -b deploy-newapp`
4. Edit `.do/deploy.template.yaml`:
   - Enable correct runtime
   - Disable other runtimes explicitly
   - Set `GITHUB_REPO_FOLDER`
   - Configure or disable deploy jobs
5. Test deployment from branch
6. Add button to README.md
7. Push branch

### Workflow 4: Debug Container Remotely

**Tool:** `doctl_remote_exec/` (Python script using pexpect)

**Usage:**
```bash
cd doctl_remote_exec
uv run python doctl_remote_exec.py <app-id> <component> "<command>"

# Examples
python doctl_remote_exec.py abc123 dev-workspace "env | grep GITHUB"
python doctl_remote_exec.py abc123 dev-workspace "cd /workspaces/app && git log -1"
python doctl_remote_exec.py abc123 dev-workspace "ps aux | grep node"
python doctl_remote_exec.py abc123 dev-workspace "cat /tmp/last_job_commit.txt"
```

**See:** [App_Platform_Commands.md](App_Platform_Commands.md) for full command reference

---

## Quick Reference

### Environment Variables (Most Important)

**Application:**
```bash
GITHUB_REPO_URL         # Required (except blank template)
GITHUB_TOKEN            # Required for private repos (SECRET)
GITHUB_BRANCH           # Default: main
GITHUB_REPO_FOLDER      # For monorepo (e.g., "apps/backend")
GITHUB_SYNC_INTERVAL    # Default: 15 seconds
DEV_START_COMMAND       # Default: "bash dev_startup.sh"
WORKSPACE_PATH          # Default: /workspaces/app
```

**Health:**
```bash
ENABLE_DEV_HEALTH       # Default: true (set false when app has health endpoint)
```

**Deploy Jobs:**
```bash
PRE_DEPLOY_COMMAND      # Empty = disabled
PRE_DEPLOY_FOLDER       # Default: scripts/pre-deploy
PRE_DEPLOY_REPO_URL     # Empty = use main repo
PRE_DEPLOY_TIMEOUT      # Default: 300

POST_DEPLOY_COMMAND     # Empty = disabled
POST_DEPLOY_FOLDER      # Default: scripts/post-deploy
POST_DEPLOY_REPO_URL    # Empty = use main repo
POST_DEPLOY_TIMEOUT     # Default: 300
```

### Ports

- **8080:** User application (HTTP)
- **9090:** Dev health server (bootstrap only, can disable)

### File Paths in Container

```
/usr/local/bin/startup.sh              # Main entrypoint
/usr/local/bin/github-sync.sh          # Sync daemon
/usr/local/bin/job-manager.sh          # Job executor
/usr/local/bin/dev-health-server       # Health binary (Go)
/usr/local/bin/welcome-page-server     # Welcome binary (Go)
/workspaces/app/                       # User's cloned repo
/tmp/last_job_commit.txt               # Commit SHA tracking
/tmp/monorepo-cache/<hash>/            # Monorepo cache
/tmp/job-repos/<hash>/                 # Multi-repo job cache
```

### doctl Commands (Quick Reference)

```bash
# List apps
doctl apps list --format ID,Spec.Name

# Get app details
doctl apps get <app-id>
doctl apps get <app-id> -o json | jq -r '.[0].spec.services[].name'

# Logs
doctl apps logs <app-id> <component> --type run --follow
doctl apps logs <app-id> <component> --type build
doctl apps logs <app-id> <component> --type deploy

# Deploy
doctl apps create --spec app.yaml
doctl apps update <app-id> --spec app.yaml
doctl apps create-deployment <app-id> --force-rebuild

# Monitor
doctl apps get <app-id> -o json | jq -r '.[0].active_deployment.phase'
# Phases: PENDING_BUILD, BUILDING, PENDING_DEPLOY, DEPLOYING, ACTIVE, ERROR
```

**See:** [App_Platform_Commands.md](App_Platform_Commands.md) for complete reference

---

## Documentation Map

### For AI Agents (Start Here)
- **CLAUDE.md** ← You are here (master reference)
- **agent.md** - Deployment playbook for agents
- **App_Platform_Commands.md** - doctl command reference

### For Users
- **README.md** - User-facing introduction with deploy buttons
- **CUSTOMIZATION.md** - How to fork and modify the template
- **docs/JOBS.md** - Complete guide to PRE_DEPLOY and POST_DEPLOY jobs (850 lines)

### For Specific Features
- **doctl_remote_exec/README.md** - Remote container execution
- **scripts/dev-health-server/README.md** - Health server details
- **scripts/welcome-page-server/README.md** - Welcome page details

### Per Sample App
- **app-examples/nextjs-sample-app/README.md**
- **app-examples/python-fastapi-sample/README.md**
- **app-examples/go-sample-app/README.md**
- **app-examples/ruby-rails-sample/README.md**
- **app-examples/nodejs-job-test/README.md**

### Historical/Reference
- Lock file conflict fix is now documented in "Common Issues & Solutions" section above

---

## Recent Changes Log

### 2025-12-10: internal_ports Fix and Documentation Update

**Problem:** Blank template deploy button failed with "health check port not found in internal_ports"

**Root Cause:** Health check on port 9090 but internal_ports not configured

**Changes:**
1. **deploy-blank branch** - Added `internal_ports: [9090]` to all config files
2. **Config file sync** - Synchronized `.do/deploy.template.yaml`, `hot-reload-template/.do/deploy.template.yaml`, and `hot-reload-template/app.yaml`
3. **Documentation** - Added "Critical Configuration Patterns" section to CLAUDE.md
4. **Deleted HOT_RELOAD_FIX.md** - Consolidated into CLAUDE.md

**Key Learning:** When using dev health server (port 9090) for blank template:
- Must add `internal_ports: [9090]`
- When user adds their app, must REMOVE internal_ports and update health_check to port 8080

### 2025-12-10: Deploy Button Fixes

**Problem:** All 6 deploy buttons had runtime mismatches and missing deploy scripts

**Changes:**
1. **Dockerfile** - Changed `INSTALL_RUBY=false` (was true)
2. **github-sync.sh** - Added rsync exclusions (node_modules, .next, etc.)
3. **Rails scripts** - Created placeholder pre-deploy and post-deploy
4. **All deploy branches** - Added explicit runtime overrides

**Files Modified:**
- Main: `Dockerfile`, `github-sync.sh`, `app-examples/ruby-rails-sample/scripts/`
- deploy-blank: Empty PRE_DEPLOY_COMMAND, POST_DEPLOY_COMMAND
- deploy-nextjs: Added INSTALL_RUBY=false
- deploy-python: Added INSTALL_RUBY=false, empty deploy commands
- deploy-go: Added INSTALL_RUBY=false, empty deploy commands
- deploy-rails: No changes (already correct)
- deploy-nodejs: Added INSTALL_RUBY=false

**Result:** All 6 buttons now deploy correctly with appropriate runtimes

---

## Key Principles for AI Agents

1. **Read existing files first** - Never propose changes without reading current state
2. **Test locally when possible** - Use Docker to validate before deploying
3. **User's repo is sacred** - Template runs their code, doesn't replace it
4. **Git sync ≠ app restart** - Dev server must handle hot-reload
5. **deploy_on_push must be false** - Auto-deploy breaks hot-reload pattern
6. **Empty commands disable jobs** - Don't error, just skip
7. **PRE_DEPLOY strict, POST_DEPLOY lenient** - Design pattern for reliability
8. **Explicit runtime overrides** - Always set INSTALL_RUBY=false if not needed
9. **Logs are truth** - Check App Platform logs for diagnostics
10. **Commit SHA tracking** - Jobs run on change, not every sync
11. **Keep config files in sync** - app.yaml, .do/deploy.template.yaml must match
12. **internal_ports for non-http health checks** - Required by App Platform

---

## Critical Configuration Patterns

### File Sync Requirement

**Three files must be kept in sync for each deployment type:**

| File | Purpose | Format |
|------|---------|--------|
| `.do/deploy.template.yaml` | Deploy button (on deploy branches) | `spec:` wrapper |
| `hot-reload-template/.do/deploy.template.yaml` | Reference template | `spec:` wrapper |
| `hot-reload-template/app.yaml` | doctl deployment | Direct YAML |

**When to sync:** After ANY change to deployment configuration, update all three files.

### internal_ports Configuration

**Rule:** Health check port MUST be in `internal_ports` if different from `http_port`.

**Two valid patterns:**

**Pattern A: App provides health endpoint (most templates)**
```yaml
# NO internal_ports needed - health check uses http_port
http_port: 8080
health_check:
  http_path: /health
  port: 8080
```

**Pattern B: Using dev health server (blank template)**
```yaml
# internal_ports REQUIRED - health check on different port
internal_ports:
  - 9090
http_port: 8080
health_check:
  http_path: /dev_health
  port: 9090
```

### Blank Template to Production Workflow

**CRITICAL:** When user deploys blank template then adds their own app:

**Step 1: Initial blank template state**
```yaml
internal_ports:
  - 9090
http_port: 8080
health_check:
  http_path: /dev_health
  port: 9090
ENABLE_DEV_HEALTH: "true"
DEV_START_COMMAND: ""
GITHUB_REPO_URL: ""
```

**Step 2: User configures their app - REQUIRED CHANGES:**
```yaml
# REMOVE internal_ports entirely (or comment out)
# internal_ports:
#   - 9090
http_port: 8080
health_check:
  http_path: /health          # User's health endpoint
  port: 8080                  # Changed from 9090
ENABLE_DEV_HEALTH: "false"    # Changed from true
DEV_START_COMMAND: "bash dev_startup.sh"
GITHUB_REPO_URL: "https://github.com/user/repo"
```

**Checklist for blank-to-production transition:**
- [ ] Remove `internal_ports` section
- [ ] Update `health_check.port` to 8080
- [ ] Update `health_check.http_path` to app's endpoint
- [ ] Set `ENABLE_DEV_HEALTH` to "false"
- [ ] Set `DEV_START_COMMAND` to startup script
- [ ] Set `GITHUB_REPO_URL` to user's repo
- [ ] Set `GITHUB_TOKEN` if private repo (as SECRET)

**Why this matters:** Leaving `internal_ports: [9090]` while changing health check to port 8080 causes validation error.

---

## Getting Help

**For deployment issues:**
1. Check logs: `doctl apps logs <app-id> <component> --type run`
2. Review [docs/JOBS.md](docs/JOBS.md) troubleshooting section
3. Use remote exec to inspect container state
4. Check recent changes in this file

**For customization:**
1. Read [CUSTOMIZATION.md](CUSTOMIZATION.md)
2. Test with Docker locally first
3. Document changes in git commits

**For new sample apps:**
1. Study existing apps in `app-examples/`
2. Follow deploy branch pattern (see Workflow 3)
3. Test thoroughly before adding deploy button

---

**End of CLAUDE.md**
*This is a living document. Update when significant changes occur.*
