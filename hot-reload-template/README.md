# DigitalOcean App Platform Dev Template

**Deploy once, iterate fast.** This template continuously syncs your GitHub repo and runs your dev server—no rebuild loop.

[![Deploy to DO](https://www.deploytodo.com/do-btn-blue.svg)](https://cloud.digitalocean.com/apps/new?repo=https://github.com/bikram20/do-app-platform-ai-dev-workflow/tree/main)

Docs map: `README.md` = use the template, `CUSTOMIZATION.md` = change the template, `AGENT.md` = checklist for automating it.

## Who Needs This?

**Use this dev template if:**
- You make frequent code changes and waiting 4-5 minutes per deployment slows you down
- You develop primarily in the cloud and need fast iteration cycles
- You want hot reload on App Platform without full rebuild loops
- You want cost-effective cloud development—archive your container when not in use (App Platform components are free when archived; databases and storage still billed)

**Use local development if:**
- You develop locally and deploy to the cloud when ready
- You prefer the traditional local → deploy workflow
- → See [appplatform_local_devcontainer](https://github.com/bikram20/appplatform_local_devcontainer) for local dev with App Platform

## Quick Overview

App Platform deploys this dev container → Container clones your app repo → Runs your dev server with hot reload.

```
┌─────────────────────┐
│  Your GitHub Repo   │
│  (app code)         │
└──────────┬──────────┘
           │ git sync (continuous)
           ▼
┌─────────────────────────────────┐
│  Dev Container (this template)  │
│  • Syncs repo every 30s         │
│  • Runs dev_startup.sh          │
│  • Routes :8080 → your app      │
│  • Routes :9090 → health (temp) │
└─────────────────────────────────┘
```

## Get Started in 60 Seconds (No Setup Required)

**One-click deploy:** Use the "Deploy to DO" button → Uses defaults, gets you running
**Then customize:** Add your repo URL, enable only runtimes you need

### First Deploy (Quick Start)

1. Click "Deploy to DO" or create app in App Platform UI
2. Point to this repo (bikram20/appdev-template)
3. Deploy with defaults - starts with built-in health check
4. Container is live!

### Connect Your App (Next Step)

Once the container is running, configure it to run your application:

1. **Set environment variables** (App Platform UI → Settings → Environment Variables):
   - `GITHUB_REPO_URL` = your app repository URL
   - `GITHUB_TOKEN` = GitHub token (for private repos, optional)
   - `DEV_START_COMMAND` = `bash dev_startup.sh` (recommended)

2. **Choose runtimes** (App Platform UI → Settings → Build Arguments):
   - Node.js app? `INSTALL_NODE=true`, others=false
   - Python app? `INSTALL_PYTHON=true`, others=false
   - Go app? `INSTALL_GOLANG=true`, others=false
   - Only enable what you need for faster builds!

3. **Redeploy** to apply changes

4. **Once your app serves health**, point health check to it and set `ENABLE_DEV_HEALTH=false`

## Configuration

### Runtime Environment Variables

Configure these in **App Platform UI → Settings → Environment Variables**. These are available to your app at runtime:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `GITHUB_REPO_URL` | Yes* | - | Your application repository URL |
| `GITHUB_REPO_FOLDER` | No | - | Subfolder within the repo to sync (for monorepos) |
| `GITHUB_BRANCH` | No | auto-detect | Specific branch to sync (default: current or main) |
| `GITHUB_TOKEN` | No | - | GitHub token for private repos (stored as secret) |
| `DEV_START_COMMAND` | No | auto-detect | Command to start your dev server (e.g., `bash dev_startup.sh`) |
| `WORKSPACE_PATH` | No | `/workspaces/app` | Where to sync your repo |
| `GITHUB_SYNC_INTERVAL` | No | `30` | How often to sync repo (seconds) |
| `ENABLE_DEV_HEALTH` | No | `true` | Bootstrap health server; set `false` when your app has health endpoint |

\* Not required for initial deploy, but needed to run your application.

### Build Arguments

Configure these in **App Platform UI → Settings → Build Arguments**. Choose runtimes you need (smaller selection = faster builds):

| Build Arg | Default | When to Enable |
|-----------|---------|----------------|
| `INSTALL_NODE` | `true` | Node.js, Next.js, Remix, Express apps |
| `INSTALL_PYTHON` | `true` | Python, FastAPI, Django, Flask apps |
| `INSTALL_GOLANG` | `false` | Go apps |
| `INSTALL_RUST` | `false` | Rust apps |
| `INSTALL_RUBY` | `false` | Ruby, Rails, Sinatra apps |
| `RUBY_VERSIONS` | `"3.4.7 3.3.6"` | Ruby versions to install (space-separated) |
| `DEFAULT_RUBY` | `"3.4.7"` | Default Ruby version |
| `INSTALL_POSTGRES` | `true` | PostgreSQL client tools (psql, libpq) - not a database server |
| `INSTALL_MONGODB` | `false` | MongoDB client tools (mongosh) - not a database server |
| `INSTALL_MYSQL` | `false` | MySQL client tools (mysql cli) - not a database server |

**Pro tip:** Only enable what you need. Rails app? Set `INSTALL_NODE=false`, `INSTALL_PYTHON=false`, `INSTALL_RUBY=true` for faster builds.

## Monorepo Support

This template supports deploying applications from monorepos by syncing specific subfolders.

**Configuration**:
- `GITHUB_REPO_URL`: Full monorepo URL
- `GITHUB_REPO_FOLDER`: Path to your app within monorepo (e.g., `apps/backend`, `services/api`)
- `GITHUB_BRANCH`: Branch to track (useful for feature branches)

**Example**:
```yaml
envs:
  - key: GITHUB_REPO_URL
    value: https://github.com/myorg/monorepo
  - key: GITHUB_REPO_FOLDER
    value: apps/backend
  - key: GITHUB_BRANCH
    value: feature/new-api
```

**How it works**:
1. Sync script clones the full monorepo to `/tmp/monorepo-cache/`
2. Only the specified folder is synced to `/workspaces/app`
3. Your `dev_startup.sh` runs from within that folder
4. Changes sync every 30 seconds by default (configurable via `GITHUB_SYNC_INTERVAL`)

**Use cases**:
- Multiple services in one repository
- Shared libraries across apps
- Testing feature branches
- Migrating from multi-repo to monorepo

## Working Examples

**Local Examples (in this repository):**

Complete working sample applications are available in [`app-examples/`](app-examples/):

- **`app-examples/go-sample-app/`** - Go application with hot-reload
- **`app-examples/python-fastapi-sample/`** - Python FastAPI application with hot-reload
- **`app-examples/nextjs-sample-app/`** - Next.js application with hot-reload
- **`app-examples/ruby-rails-sample/`** - Rails application with hot-reload

Each example includes:
- Complete `dev_startup.sh` script (from `examples/`)
- `appspec.yaml` configured for **testing/hot-reload** environment
- Working application code

**Working Examples (in this monorepo):**

All examples use the same deploy button. After deploying, configure which app to run using environment variables:

- **Go:** [go-sample-app](https://github.com/bikram20/do-app-platform-ai-dev-workflow/tree/main/hot-reload-template/app-examples/go-sample-app) - See [.env.example](https://github.com/bikram20/do-app-platform-ai-dev-workflow/blob/main/hot-reload-template/app-examples/go-sample-app/.env.example)
- **Python FastAPI:** [python-fastapi-sample](https://github.com/bikram20/do-app-platform-ai-dev-workflow/tree/main/hot-reload-template/app-examples/python-fastapi-sample) - See [.env.example](https://github.com/bikram20/do-app-platform-ai-dev-workflow/blob/main/hot-reload-template/app-examples/python-fastapi-sample/.env.example)
- **Next.js:** [nextjs-sample-app](https://github.com/bikram20/do-app-platform-ai-dev-workflow/tree/main/hot-reload-template/app-examples/nextjs-sample-app) - See [.env.example](https://github.com/bikram20/do-app-platform-ai-dev-workflow/blob/main/hot-reload-template/app-examples/nextjs-sample-app/.env.example)
- **Rails:** [ruby-rails-sample](https://github.com/bikram20/do-app-platform-ai-dev-workflow/tree/main/hot-reload-template/app-examples/ruby-rails-sample)

**Deploy**: Click the deploy button above, then add environment variables from the `.env.example` file for your chosen framework.

**Important:** The `appspec.yaml` in these examples is for **testing/hot-reload**. For **production**, create a separate `appspec.yaml` that uses buildpack or your own Dockerfile (not the `hot-reload-template/Dockerfile`).

**Enhanced dev_startup.sh Examples:**

This template includes production-ready `dev_startup.sh` examples in the `examples/` directory with built-in error handling:

- **`examples/dev_startup.sh.nextjs`** - Handles npm peer deps, package-lock.json conflicts, and hard rebuilds
- **`examples/dev_startup.sh.python`** - Handles uv.lock/poetry.lock conflicts and hard rebuilds
- **`examples/dev_startup.sh.golang`** - Handles go.sum conflicts and hard rebuilds
- **Rails:** See `app-examples/ruby-rails-sample/dev_startup.sh` for Gemfile.lock handling, migrations, and hot-reload

These examples are proven to work and include automatic conflict resolution and error recovery. Copy the appropriate one to your repository as `dev_startup.sh`.


## Write Your dev_startup.sh (in your app repo)

**Recommended:** Copy one of the proven example scripts from the `examples/` directory in this template repository. These examples include:

- **Automatic lock file conflict resolution** - Detects and resolves merge conflicts in `package-lock.json`, `go.sum`, `uv.lock`, and `poetry.lock`
- **Hard rebuild on errors** - Automatically performs clean rebuilds when dependency installation fails
- **npm legacy peer deps** - Next.js example automatically creates `.npmrc` with `legacy-peer-deps=true` to handle React version conflicts
- **Hot reload support** - Built-in monitoring and automatic restarts on code/dependency changes

**Available examples:**
- `examples/dev_startup.sh.nextjs` - Next.js with nodemon, handles npm peer deps and lock conflicts
- `examples/dev_startup.sh.python` - FastAPI with uv, handles uv.lock/poetry.lock conflicts
- `examples/dev_startup.sh.golang` - Go with file watching, handles go.sum conflicts

**Quick start:**
1. Copy the appropriate example to your app repository as `dev_startup.sh`
2. Customize if needed (port, command, etc.)
3. The script will handle errors, conflicts, and hot reload automatically

**Simple examples (for reference only - use examples/ for production):**

**Next.js**
```bash
#!/bin/bash
cd /workspaces/app
npm install
npm run dev -- --hostname 0.0.0.0 --port 8080
```

**FastAPI**
```bash
#!/bin/bash
cd /workspaces/app
uv sync --no-dev
uv run uvicorn main:app --host 0.0.0.0 --port 8080 --reload
```

**Go**
```bash
#!/bin/bash
cd /workspaces/app
go mod tidy
go run main.go
```

Your script should:
- Install dependencies
- Start a dev server that listens on port `8080`
- Support hot reload for fast iteration
- Handle errors gracefully (use examples/ for best practices)

## Migration Path: From Built-in Health to Your App

The container includes a temporary health server to pass initial health checks. Once your app is ready, migrate to your app's health endpoint:

1. **First deploy:** Uses built-in health server (`/dev_health` on :9090)
2. **Add health to your app:** Implement `/health` endpoint on :8080
3. **Update app spec:** Point health check to your app's `/health:8080`
4. **Disable built-in health:** Set `ENABLE_DEV_HEALTH=false`
5. **Optional:** Set `INSTALL_NODE=false` if you don't need Node.js (requires rebuild)

**Working example:** See [go-sample-app/appspec.yaml](https://github.com/bikram20/go-sample-app/blob/main/appspec.yaml) - notice `ENABLE_DEV_HEALTH=false` and health check pointed to app endpoint.

## Key Behaviors to Remember

- **Git sync is continuous** - Your app is NOT auto-restarted. Use a dev server with hot reload (see examples above).
- **Health server is temporary** - Disable via `ENABLE_DEV_HEALTH=false` once your app handles health checks.
- **Runtimes are modular** - Enable only what you need for faster builds and smaller images.
- **Environment variables are runtime** - Changes to env vars take effect on redeploy (no rebuild needed).
- **Build arguments are build-time** - Changes to build args require a full rebuild.
- **Lock file conflicts auto-resolved** - The sync script and example dev_startup.sh scripts automatically detect and resolve merge conflicts in lock files (package-lock.json, go.sum, uv.lock, poetry.lock).
- **Hard rebuild on errors** - Example scripts automatically perform clean rebuilds when dependency installation fails.
- **Blank DEV_START_COMMAND works** - Container stays healthy even when DEV_START_COMMAND is not set, allowing you to configure it later via App Platform UI.

## Deploy Options

**One-click (recommended):**
Use the "Deploy to DO" button and configure via UI after first deploy

**App Platform UI:**
Create App → GitHub → select this repo → configure env vars/build args → deploy

**CLI (advanced):**
Edit `app.yaml` with your values, then: `doctl apps create --spec app.yaml`

**Local smoke test:**
```bash
docker build -t dev-env .
docker run -p 9090:9090 -p 8080:8080 \
  -e GITHUB_REPO_URL=https://github.com/user/your-repo.git \
  -e DEV_START_COMMAND="bash dev_startup.sh" \
  dev-env
```

## Quick Troubleshooting

- **Nothing starts:** Confirm `GITHUB_REPO_URL` is set and accessible, `dev_startup.sh` exists in your repo
- **Health check fails:** Either keep `ENABLE_DEV_HEALTH=true` OR point health checks to your app and set `ENABLE_DEV_HEALTH=false`
- **Changes not visible:** Ensure your dev server supports hot reload (npm run dev, uvicorn --reload, air), or manually restart container
- **Build takes too long:** Disable unused runtimes in build arguments
- **npm peer dependency errors:** Use the Next.js example script which automatically creates `.npmrc` with `legacy-peer-deps=true`
- **Lock file merge conflicts:** The sync script and example dev_startup.sh scripts automatically resolve these. If issues persist, manually delete the lock file and let it regenerate.
- **Dependency installation fails:** Example scripts automatically perform hard rebuilds (clean reinstall) when errors are detected. Check logs for details.
- **DEV_START_COMMAND blank:** Container will stay running and healthy. Configure `GITHUB_REPO_URL` and `DEV_START_COMMAND` (or add `dev_startup.sh` to your repo) to start your app.


## Advanced Customization

For deeper tweaks (new runtimes, custom health/sync logic): see [`CUSTOMIZATION.md`](CUSTOMIZATION.md)

For automation guidance: see [`AGENT.md`](AGENT.md)
