# Agent Playbook: do-app-platform-ai-dev-workflow

**Context for AI Assistants:** This document explains the complete workflow structure, navigation, and development process for DigitalOcean App Platform projects using this opinionated workflow.

## Repository Structure

### Root Folder = Complete Workflow
- **Single repository** containing all workflow components
- **NOT a deployable application** - it's a workflow toolkit
- Purpose: Provide complete, hands-free development workflow for AI-assisted development

### Folder Structure

```
do-app-platform-ai-dev-workflow/
├── .devcontainer/          # Local development container setup
├── hot-reload-template/        # Hot-reload template for App Platform testing
│   ├── examples/          # Reusable dev_startup.sh scripts
│   └── app-examples/      # Complete working sample apps
├── build-locally.sh       # Helper: Local build verification
├── workflow-check.sh      # Helper: Context validation
├── README.md              # Human-readable overview
└── agent.md               # This file - AI assistant guide
```

### Component Types

1. **`.devcontainer/`** - Local development environment
   - Devcontainer configuration
   - Database services, tooling
   - Pre-configured for App Platform development
   - Work: Environment setup, tooling improvements

2. **`hot-reload-template/`** - Hot-reload template for testing
   - Dockerfile (for **testing only**, not production)
   - GitHub sync scripts with **monorepo support**
   - Health server
   - Reusable dev_startup.sh scripts
   - Complete sample apps
   - Work: Template improvements, new features
   - **Monorepo deployments:** When working with monorepos, configure:
     - `GITHUB_REPO_FOLDER` - Subfolder path (e.g., `apps/backend`, `hot-reload-template/app-examples/go-sample-app`)
     - `GITHUB_BRANCH` - Branch to track (default: main, use for feature/staging branches)
     - `dockerfile_path` - Always `hot-reload-template/Dockerfile` for all deployments (template or examples)

3. **Helper Scripts** (root)
   - `build-locally.sh` - Wraps `doctl app dev build`
   - `workflow-check.sh` - Validates context

## Workflow Decision Tree

```
START: User wants to work on something
│
├─ What type of work?
│  │
│  ├─ Local development setup?
│  │  └─> Work in .devcontainer/
│  │      └─> Modify docker-compose.yml, post-create.sh, etc.
│  │
│  ├─ Template modification (GitHub sync, health server, etc.)?
│  │  └─> Navigate to hot-reload-template/
│  │      └─> Modify template, test locally, commit changes
│  │
│  ├─ Starting new application?
│  │  └─> Copy from hot-reload-template/app-examples/
│  │      └─> Adapt dev_startup.sh and appspec.yaml
│  │
│  └─ Working on existing application?
│     └─> Navigate to user's app folder (outside this repo)
│         └─> Follow: Local Dev → DO Build → GitHub → Testing → Production
│
└─ Always: Identify folder context FIRST
```

## Complete Development Workflow

### Phase 1: Local Development (DevContainer Sandbox)

**Context:** Working inside devcontainer, using framework's native dev tools

**Actions:**
1. Open workspace in VS Code/Cursor (devcontainer auto-configures)
2. Navigate to user's application folder (or create new from app-examples)
3. Use framework's local dev server:
   - Next.js: `npm run dev`
   - FastAPI: `uvicorn main:app --reload`
   - Express: `nodemon server.js`
   - Go: `air` (live reload)
4. Test changes locally
5. Iterate until satisfied

**When to proceed:** Code works locally, ready to verify production compatibility

### Phase 2: Local Build Verification (DigitalOcean Buildpack Containers)

**Context:** Before pushing to GitHub, verify build will work in production

**Why:** Framework dev tools may work locally but fail in production due to:
- Buildpack-specific requirements
- Version mismatches
- Legacy peer dependencies
- Missing build dependencies

**Actions:**
```bash
# Using helper script (recommended)
./build-locally.sh                    # Build using default spec
./build-locally.sh my-component       # Build specific component
./build-locally.sh --spec app.yaml    # Use custom spec file

# Direct doctl commands
doctl app dev build                    # Build current component
doctl app dev build --spec app.yaml   # Use custom spec
doctl app dev build my-component      # Build specific component
doctl app dev build --build-command "npm install --legacy-peer-deps && npm run build"
```

**What happens:**
- Downloads DigitalOcean's buildpack containers
- Builds using same process as App Platform production
- Creates local container image
- Provides Docker run command for testing

**Reference:** 
- [DigitalOcean: Build Locally](https://docs.digitalocean.com/products/app-platform/how-to/build-locally/)
- [`hot-reload-template/App_Platform_Commands.md`](hot-reload-template/App_Platform_Commands.md)

**When to proceed:** Build succeeds locally → High confidence it will work in production

**If build fails:**
- Check buildpack requirements
- Verify Node.js/Python versions match production
- Use `--build-command` to override
- Check for legacy peer dependencies (use `npm install --legacy-peer-deps`)

### Phase 3: GitHub Push

**Context:** Local build verified, ready to push

**Actions:**
```bash
git add .
git commit -m "Feature: description"
git push origin main  # or feature branch
```

**When to proceed:** Code pushed to repository

### Phase 4: Testing Setup (Hot-Reload on App Platform)

**Context:** Testing environment with GitHub sync for fast feedback

**Configuration:**
- Use `hot-reload-template/` for testing setup
- Configure GitHub sync interval: 15-30 seconds
- Environment pulls changes automatically
- No full rebuild required - just dev server restart

**Setup Steps:**
1. Deploy hot-reload-template to App Platform (testing environment)
   ```bash
   cd hot-reload-template
   doctl apps create --spec app.yaml
   ```
2. Set environment variables:
   - `GITHUB_REPO_URL` = your app repository
   - `GITHUB_TOKEN` = GitHub token (if private)
   - `GITHUB_SYNC_INTERVAL` = "15" or "30" (seconds)
   - `DEV_START_COMMAND` = "bash dev_startup.sh" (or leave blank if script exists in repo)
3. Enable only required runtimes (faster builds)
4. Health check: Use `/dev_health` initially, migrate to app endpoint later

**Important:** The `hot-reload-template/Dockerfile` is **ONLY for testing**. Production uses buildpack or your own Dockerfile.

**See:** [`hot-reload-template/README.md`](hot-reload-template/README.md)

**Benefits:**
- Changes visible in 15-30 seconds
- Test with real databases, Spaces, etc.
- Catch integration issues early
- No 5-10 minute rebuild cycles

**When to proceed:** Testing passes, functionality verified

### Phase 5: Production Deployment

**Context:** High confidence deployment

**Why confident:**
- ✅ Build compatibility verified (Phase 2)
- ✅ Functionality tested in staging (Phase 4)
- ✅ Real services tested (databases, Spaces)

**Critical Understanding: Production vs Testing**

**Testing Environment:**
- Uses `hot-reload-template/Dockerfile`
- GitHub sync every 15-30 seconds
- Dev server with hot-reload
- Fast iteration, not optimized

**Production Environment:**
- **Does NOT use** `hot-reload-template/Dockerfile`
- Uses **either:**
  - **Buildpack** (recommended, automatic) - App Platform detects framework
  - **Your own Dockerfile** - If you have custom build requirements

**Key Points:**
- If you have your own Dockerfile, **keep it for production**
- You don't need to replace your Dockerfile with `hot-reload-template/Dockerfile`
- Create **separate appspec.yaml files:**
  - **Testing:** Uses `hot-reload-template/Dockerfile` (hot-reload)
  - **Production:** Uses buildpack or your Dockerfile (optimized)

**Actions:**
```bash
# Deploy to production (uses buildpack or your Dockerfile)
doctl apps create --spec app.yaml.production

# Or update existing production app
doctl apps update <app-id> --spec app.yaml.production
```

**Monitor deployment:**
```bash
doctl apps get <app-id> -o json | jq -r '.[0].active_deployment.phase'
doctl apps logs <app-id> <component> --type run
```

## Helper Scripts

### `build-locally.sh`
Wraps `doctl app dev build` with helpful defaults and options.

**Usage:**
```bash
./build-locally.sh                    # Build using default spec
./build-locally.sh my-component       # Build specific component
./build-locally.sh --spec app.yaml    # Use custom spec file
./build-locally.sh --env-file .env    # Use environment overrides
./build-locally.sh --verbose          # Verbose output
```

**When to use:** Before pushing to GitHub, verify production build compatibility.

### `workflow-check.sh`
Validates current folder context and workflow state.

**Usage:**
```bash
./workflow-check.sh                   # Check current context
./workflow-check.sh --verbose         # Detailed information
```

**When to use:** When unsure about current folder context or workflow state.

## Common Tasks for AI Assistants

### Task 1: Help User Set Up New Application

**Scenario:** User wants to start a new Next.js app

**Steps:**
1. Identify they want to start new app
2. Suggest copying from `hot-reload-template/app-examples/nextjs-sample-app/`
3. Guide them to:
   - Copy `dev_startup.sh` from `hot-reload-template/examples/dev_startup.sh.nextjs`
   - Adapt `appspec.yaml` for their needs
   - Create separate `appspec.yaml` files for testing and production

**Key Points:**
- Testing appspec.yaml uses `hot-reload-template/Dockerfile`
- Production appspec.yaml uses buildpack or their Dockerfile
- They can keep their own Dockerfile if they have one

### Task 2: Help User Deploy Testing Environment

**Scenario:** User wants hot-reload testing on App Platform

**Steps:**
1. Navigate to `hot-reload-template/`
2. Guide deployment: `doctl apps create --spec app.yaml`
3. Help configure environment variables:
   - `GITHUB_REPO_URL`
   - `GITHUB_SYNC_INTERVAL` (15 or 30)
   - `DEV_START_COMMAND` (if needed)
4. Explain health check setup

**Key Points:**
- This is for **testing only**
- Production will use different configuration

### Task 3: Help User Deploy to Production

**Scenario:** User wants to deploy to production

**Steps:**
1. Verify they have separate production appspec.yaml
2. Ensure production appspec.yaml uses:
   - Buildpack (default) OR their own Dockerfile
   - NOT `hot-reload-template/Dockerfile`
3. Guide deployment: `doctl apps create --spec app.yaml.production`
4. Monitor deployment status

**Key Points:**
- Production does NOT use hot-reload template
- Production uses optimized builds
- Separate appspec.yaml for production

### Task 4: Help User Fix Build Issues

**Scenario:** Build fails locally or in production

**Steps:**
1. Run `./build-locally.sh` to reproduce issue
2. Check build logs for errors
3. Common fixes:
   - Legacy peer deps: Use `--build-command "npm install --legacy-peer-deps && npm run build"`
   - Version mismatch: Update Node.js/Python version in appspec.yaml
   - Missing dependencies: Check buildpack requirements
4. Once fixed, verify with `./build-locally.sh` again

### Task 5: Help User Deploy from Monorepo

**Scenario:** User has multiple apps in one repository

**Steps:**
1. Identify which subfolder contains their app
2. Configure environment variables:
   - `GITHUB_REPO_URL` = monorepo URL
   - `GITHUB_REPO_FOLDER` = subfolder path (e.g., `services/api`)
   - `GITHUB_BRANCH` = branch to track (optional)
3. Set `dockerfile_path: hot-reload-template/Dockerfile`
4. Deploy with configured appspec.yaml

**Key Points:**
- The full repo is cloned, but only the specified folder syncs to workspace
- Useful for feature branches without creating separate apps
- Sync time depends on folder size, not entire monorepo

## Key Principles

1. **Always identify folder context first**
   - Check which folder you're in
   - Understand component type
   - Use `./workflow-check.sh` if unsure

2. **Build locally before pushing**
   - Use `./build-locally.sh` to verify production compatibility
   - Catches build issues early
   - Saves 5-10 minute cycles

3. **Separate testing and production**
   - Testing: Uses `hot-reload-template/Dockerfile` (hot-reload)
   - Production: Uses buildpack or user's Dockerfile (optimized)
   - Different appspec.yaml files for each

4. **Production deployment = high confidence**
   - Build verified locally
   - Functionality tested in staging
   - Real services tested

## Troubleshooting Guide

### "Which folder should I work in?"
- **Check user's request:** What are they trying to do?
- **Template improvement?** → Navigate to `hot-reload-template/`
- **Devcontainer change?** → Work in `.devcontainer/`
- **User's application?** → Navigate to their app folder (outside this repo)

### "Local build fails but framework dev works"
- Check buildpack requirements
- Verify versions match production
- Use `--build-command` override
- Check for legacy peer dependencies
- Use `./build-locally.sh --verbose` for details

### "Testing setup not syncing"
- Verify `GITHUB_SYNC_INTERVAL` is set (15-30s)
- Check GitHub token permissions
- Review logs: `doctl apps logs <app-id> <component> --type run`
- Check git sync script is running

### "User has their own Dockerfile"
- ✅ **Keep it for production**
- ✅ Use `dev_startup.sh` from `hot-reload-template/examples/` (for testing)
- ✅ Create separate appspec.yaml files
- ❌ Don't replace their Dockerfile with `hot-reload-template/Dockerfile`

### "Production deployment confusion"
- Clarify: Production does NOT use `hot-reload-template/Dockerfile`
- Production uses buildpack (automatic) OR user's Dockerfile
- Testing uses `hot-reload-template/Dockerfile` (hot-reload)
- Separate appspec.yaml files for each environment

## Cross-References

### Internal Documentation
- **Root README:** [`README.md`](README.md) - Human-readable overview and quick start
- **This Document:** [`agent.md`](agent.md) - Complete workflow and decision trees for AI assistants

### Template Documentation
- [`hot-reload-template/README.md`](hot-reload-template/README.md) - User guide for rapid iteration setup
- [`hot-reload-template/app-examples/README.md`](hot-reload-template/app-examples/README.md) - Sample apps guide
- [`hot-reload-template/App_Platform_Commands.md`](hot-reload-template/App_Platform_Commands.md) - Comprehensive doctl command reference
- [`hot-reload-template/CUSTOMIZATION.md`](hot-reload-template/CUSTOMIZATION.md) - How to extend/modify the template

### External Documentation
- [DigitalOcean: Build Locally](https://docs.digitalocean.com/products/app-platform/how-to/build-locally/)
- [App Spec Reference](https://docs.digitalocean.com/products/app-platform/reference/app-spec/)
- [doctl CLI Reference](https://docs.digitalocean.com/reference/doctl/)

## Quick Decision Checklist

Before starting work, ask:
- [ ] Which folder am I in? (Check `pwd` or use `./workflow-check.sh`)
- [ ] What is the user trying to accomplish?
- [ ] Which workflow phase applies?
- [ ] Is this for testing or production?
- [ ] Does user have their own Dockerfile? (Keep it for production)
- [ ] Do I need to build locally first?

---

**Remember:** This is a single repository containing a complete workflow toolkit. Users can use components independently or together. Always clarify testing vs production deployment configurations.
