# App Examples

This folder contains working sample applications that demonstrate how to use the `hot-reload-template` for hot-reload development on DigitalOcean App Platform.

## What This Folder Does

Each subfolder contains a complete, working sample application that:
- Uses the enhanced `dev_startup.sh` scripts from `hot-reload-template/examples/`
- Demonstrates hot-reload setup for a specific framework (Go, Python/FastAPI, Next.js, Rails)
- Includes a complete `appspec.yaml` configuration for **testing/hot-reload** environment

## Quick Deploy

Deploy any example app to DigitalOcean App Platform with one click. **All examples use the same deploy button** - you configure which app to deploy using environment variables.

### Step 1: Click Deploy Button

[![Deploy to DO](https://www.deploytodo.com/do-btn-blue.svg)](https://cloud.digitalocean.com/apps/new?repo=https://github.com/bikram20/do-app-platform-ai-dev-workflow/tree/main)

### Step 2: Add Environment Variables

After clicking deploy, configure which example to deploy by adding the appropriate environment variables from the `.env.example` files below:

#### Go Sample App
**Copy from**: [go-sample-app/.env.example](go-sample-app/.env.example)
```bash
GITHUB_REPO_URL=https://github.com/bikram20/do-app-platform-ai-dev-workflow
GITHUB_REPO_FOLDER=hot-reload-template/app-examples/go-sample-app
GITHUB_BRANCH=main
INSTALL_NODE=false
INSTALL_PYTHON=false
INSTALL_GOLANG=true
DEV_START_COMMAND=bash dev_startup.sh
GITHUB_SYNC_INTERVAL=15
ENABLE_DEV_HEALTH=false
```

**What you get**:
- Hot-reload development environment with Air for Go
- Changes sync every 15 seconds
- ⚠️ **Testing environment** - NOT for production

---

#### Python FastAPI Sample
**Copy from**: [python-fastapi-sample/.env.example](python-fastapi-sample/.env.example)
```bash
GITHUB_REPO_URL=https://github.com/bikram20/do-app-platform-ai-dev-workflow
GITHUB_REPO_FOLDER=hot-reload-template/app-examples/python-fastapi-sample
GITHUB_BRANCH=main
INSTALL_NODE=false
INSTALL_PYTHON=true
INSTALL_GOLANG=false
DEV_START_COMMAND=bash dev_startup.sh
GITHUB_SYNC_INTERVAL=15
ENABLE_DEV_HEALTH=false
```

**What you get**:
- Hot-reload development environment with uvicorn --reload
- Changes sync every 15 seconds
- ⚠️ **Testing environment** - NOT for production

---

#### Next.js Sample App
**Copy from**: [nextjs-sample-app/.env.example](nextjs-sample-app/.env.example)
```bash
GITHUB_REPO_URL=https://github.com/bikram20/do-app-platform-ai-dev-workflow
GITHUB_REPO_FOLDER=hot-reload-template/app-examples/nextjs-sample-app
GITHUB_BRANCH=main
INSTALL_NODE=true
INSTALL_PYTHON=false
INSTALL_GOLANG=false
DEV_START_COMMAND=bash dev_startup.sh
GITHUB_SYNC_INTERVAL=15
ENABLE_DEV_HEALTH=false
```

**What you get**:
- Hot-reload development environment with Next.js dev server
- Changes sync every 15 seconds
- ⚠️ **Testing environment** - NOT for production

---

#### Ruby on Rails Sample App
Use these values:
```bash
GITHUB_REPO_URL=https://github.com/bikram20/do-app-platform-ai-dev-workflow
GITHUB_REPO_FOLDER=hot-reload-template/app-examples/ruby-rails-sample
GITHUB_BRANCH=main
INSTALL_NODE=false
INSTALL_PYTHON=false
INSTALL_GOLANG=false
INSTALL_RUBY=true
RUBY_VERSIONS="3.4.7"
DEFAULT_RUBY="3.4.7"
DEV_START_COMMAND=bash dev_startup.sh
GITHUB_SYNC_INTERVAL=15
ENABLE_DEV_HEALTH=false
```

**What you get**:
- Hot-reload Rails 8 app with SQLite and `/health` endpoint
- Bundler + migrations handled by `dev_startup.sh`
- ⚠️ **Testing environment** - NOT for production

---

#### Node.js Job Test (PRE/POST Deploy Jobs)
**Copy from**: [nodejs-job-test/.env.example](nodejs-job-test/.env.example)
```bash
GITHUB_REPO_URL=https://github.com/bikram20/do-app-platform-ai-dev-workflow
GITHUB_REPO_FOLDER=hot-reload-template/app-examples/nodejs-job-test
GITHUB_BRANCH=main
INSTALL_NODE=true
INSTALL_PYTHON=false
INSTALL_GOLANG=false
DEV_START_COMMAND=bash dev_startup.sh
GITHUB_SYNC_INTERVAL=15
ENABLE_DEV_HEALTH=false
PRE_DEPLOY_FOLDER=scripts/pre-deploy
PRE_DEPLOY_COMMAND=bash migrate.sh
PRE_DEPLOY_TIMEOUT=300
POST_DEPLOY_FOLDER=scripts/post-deploy
POST_DEPLOY_COMMAND=bash seed.sh
POST_DEPLOY_TIMEOUT=300
```

**What you get**:
- Express.js test app demonstrating PRE_DEPLOY and POST_DEPLOY job functionality
- Database migration simulation (PRE_DEPLOY - strict mode)
- Data seeding simulation (POST_DEPLOY - lenient mode)
- Commit change detection for job execution
- ⚠️ **Testing environment** - NOT for production

**Important Notes**:
- All examples use the **same deploy button** - you choose which app via environment variables
- `deploy_on_push: true` triggers rebuilds when the hot-reload-template changes
- Application code syncs via `github-sync.sh` daemon (no full rebuild needed)
- For production deployment, use separate appspec.yaml with buildpack or your Dockerfile

## Sample Applications

- **go-sample-app/** - Go application with hot-reload
- **python-fastapi-sample/** - Python FastAPI application with hot-reload
- **nextjs-sample-app/** - Next.js application with hot-reload (default)
- **ruby-rails-sample/** - Rails 8 application with hot-reload
- **nodejs-job-test/** - Node.js/Express app demonstrating PRE_DEPLOY and POST_DEPLOY jobs

## Important Notes

### dev_startup.sh Source

The `dev_startup.sh` scripts in these sample apps are copied from `hot-reload-template/examples/` and include:
- Automatic lock file conflict resolution
- Hard rebuild logic on dependency errors
- Framework-specific optimizations (e.g., `.npmrc` for Next.js)

### appspec.yaml is Critical for Hot Reload

The `appspec.yaml` file in each sample is essential for hot-reload functionality:

1. **Health Check Configuration** - Points to your app's health endpoint (not the dev health server)
2. **Environment Variables** - Sets `ENABLE_DEV_HEALTH=false` once your app is ready
3. **Build Arguments** - Enables only the runtimes you need (faster builds)
4. **Port Configuration** - Ensures your app listens on port 8080
5. **Dockerfile Path** - Points to `hot-reload-template/Dockerfile` for the dev container

Without proper `appspec.yaml` configuration, the container may not route traffic correctly or health checks may fail, preventing hot-reload from working.

### Production Deployment is Different

**Important:** The `appspec.yaml` in these examples is configured for **testing/hot-reload** environments. For **production deployment**, you need a separate `appspec.yaml` that:

- **Does NOT use** the `hot-reload-template/Dockerfile`
- **Uses either:**
  - **Buildpack-based build** (default for most frameworks) - App Platform automatically detects and builds
  - **Your own Dockerfile** - If you have custom build requirements

**Key Point:** If you have your own Dockerfile for production, you don't need to replace it. The `hot-reload-template/Dockerfile` is only for the hot-reload testing environment. For production:
- Keep your existing Dockerfile
- Use `dev_startup.sh` from `hot-reload-template/examples/` (if you want hot-reload in testing)
- Create separate `appspec.yaml` files: one for testing (uses hot-reload-template), one for production (uses your Dockerfile or buildpack)

## Usage

These samples serve as reference implementations. Copy the `dev_startup.sh` and adapt the `appspec.yaml` for your own applications. Remember to create separate configurations for testing (hot-reload) and production (optimized build).

