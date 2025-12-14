# Node.js Job Test

Express.js test application for validating PRE_DEPLOY and POST_DEPLOY job functionality with the hot-reload template.

## Overview

This is a simple Express.js application designed to test the pre/post deploy job feature of the hot-reload template. It demonstrates:

- **PRE_DEPLOY jobs**: Database migration simulation (runs before app starts, strict mode)
- **POST_DEPLOY jobs**: Data seeding simulation (runs after app starts, lenient mode)
- **Hot reload**: Automatic dependency management and server restart
- **Health checks**: Built-in `/health` endpoint for App Platform

## Project Structure

```
nodejs-job-test/
├── index.js                    # Express app (web server)
├── package.json                # Dependencies
├── dev_startup.sh             # Hot-reload startup script
├── .env.example               # Environment variables template
├── scripts/
│   ├── pre-deploy/
│   │   └── migrate.sh         # PRE_DEPLOY job (database migration simulation)
│   └── post-deploy/
│       └── seed.sh            # POST_DEPLOY job (data seeding simulation)
├── appspec.yaml               # App Platform deployment spec
└── README.md                  # This file
```

## Local Testing

### Prerequisites

- Node.js 18+ installed
- Docker installed (for container testing)

### Quick Start (Local)

```bash
# Install dependencies
npm install

# Run the app
npm start

# Or run with hot reload
npm run dev

# Visit http://localhost:8080
```

### Test Job Scripts Locally

```bash
# Test PRE_DEPLOY job
bash scripts/pre-deploy/migrate.sh

# Test POST_DEPLOY job
bash scripts/post-deploy/seed.sh
```

## Docker Testing

### Build Hot-Reload Template Container

```bash
cd /workspaces/app

# Build container with Node.js support
docker build -f the Dockerfile \
  --build-arg INSTALL_NODE=true \
  --build-arg INSTALL_PYTHON=false \
  --build-arg INSTALL_GOLANG=false \
  -t hot-reload-test:latest .
```

### Test Scenarios

#### 1. Baseline (No Jobs)

```bash
docker run -p 8080:8080 \
  -e GITHUB_REPO_URL=https://github.com/bikram20/do-app-platform-ai-dev-workflow \
  -e GITHUB_REPO_FOLDER=app-examples/nodejs-job-test \
  -e DEV_START_COMMAND="bash dev_startup.sh" \
  hot-reload-test:latest
```

Expected: App starts normally, no job execution.

#### 2. PRE_DEPLOY Success

```bash
docker run -p 8080:8080 \
  -e GITHUB_REPO_URL=https://github.com/bikram20/do-app-platform-ai-dev-workflow \
  -e GITHUB_REPO_FOLDER=nodejs-hot-reload-job-test \
  -e DEV_START_COMMAND="bash dev_startup.sh" \
  -e PRE_DEPLOY_FOLDER=scripts/pre-deploy \
  -e PRE_DEPLOY_COMMAND="bash migrate.sh" \
  -e PRE_DEPLOY_TIMEOUT=60 \
  hot-reload-test:latest
```

Expected:
- PRE_DEPLOY job runs before app starts
- Migration logs appear: `[PRE-DEPLOY] ...`
- App starts after job completes

#### 3. PRE_DEPLOY Failure (Container Exits)

```bash
# Modify scripts/pre-deploy/migrate.sh to add "exit 1" at the end
# Then rebuild and run container

docker run -p 8080:8080 \
  -e GITHUB_REPO_URL=... \
  -e PRE_DEPLOY_FOLDER=scripts/pre-deploy \
  -e PRE_DEPLOY_COMMAND="bash migrate.sh" \
  hot-reload-test:latest
```

Expected:
- PRE_DEPLOY job fails
- Error message: "ERROR: Initial PRE_DEPLOY job failed. Container cannot start."
- Container exits with code 1

#### 4. POST_DEPLOY Lenient Mode

```bash
docker run -p 8080:8080 \
  -e GITHUB_REPO_URL=https://github.com/bikram20/do-app-platform-ai-dev-workflow \
  -e GITHUB_REPO_FOLDER=nodejs-hot-reload-job-test \
  -e DEV_START_COMMAND="bash dev_startup.sh" \
  -e PRE_DEPLOY_FOLDER=scripts/pre-deploy \
  -e PRE_DEPLOY_COMMAND="bash migrate.sh" \
  -e POST_DEPLOY_FOLDER=scripts/post-deploy \
  -e POST_DEPLOY_COMMAND="bash seed.sh" \
  -e POST_DEPLOY_TIMEOUT=60 \
  hot-reload-test:latest
```

Expected:
- PRE_DEPLOY runs and succeeds
- App starts
- POST_DEPLOY runs in background
- If POST_DEPLOY fails (modify seed.sh to exit 1), warning is logged but app continues

#### 5. Commit Change Detection

This test requires the repo to be a git repository with commits:

```bash
# Initialize git repo
cd app-examples/nodejs-job-test
git init
git add .
git commit -m "Initial commit"

# Run container
docker run -p 8080:8080 \
  -v /workspaces/app/app-examples/nodejs-job-test:/workspaces/app \
  -e GITHUB_REPO_URL="" \
  -e WORKSPACE_PATH=/workspaces/app \
  -e DEV_START_COMMAND="bash dev_startup.sh" \
  -e PRE_DEPLOY_FOLDER=scripts/pre-deploy \
  -e PRE_DEPLOY_COMMAND="bash migrate.sh" \
  hot-reload-test:latest

# In another terminal, make a commit
echo "test change" >> README.md
git add .
git commit -m "Test commit change detection"

# Wait 30s for sync cycle
# Expected: Jobs execute because commit SHA changed
```

#### 6. Timeout Handling

```bash
# Modify scripts/pre-deploy/migrate.sh to add "sleep 30" before migrations

docker run -p 8080:8080 \
  -e GITHUB_REPO_URL=https://github.com/bikram20/do-app-platform-ai-dev-workflow \
  -e GITHUB_REPO_FOLDER=nodejs-hot-reload-job-test \
  -e DEV_START_COMMAND="bash dev_startup.sh" \
  -e PRE_DEPLOY_FOLDER=scripts/pre-deploy \
  -e PRE_DEPLOY_COMMAND="bash migrate.sh" \
  -e PRE_DEPLOY_TIMEOUT=5 \
  hot-reload-test:latest
```

Expected:
- Job starts, sleeps for 30s
- After 5s, timeout kills the job
- Error: "Job timed out after 5s"
- Container exits (PRE_DEPLOY strict mode)

## Deploying to App Platform

### Option 1: Deploy from Monorepo (Current Setup)

The `appspec.yaml` is already configured for monorepo deployment:

```bash
# This repo should be part of the main monorepo
# The hot-reload template will sync from:
# - GITHUB_REPO_URL: https://github.com/bikram20/do-app-platform-ai-dev-workflow
# - GITHUB_REPO_FOLDER: app-examples/nodejs-job-test

# Deploy using doctl
doctl apps create --spec appspec.yaml
```

### Option 2: Deploy as Standalone Repository

If you create a standalone GitHub repository:

1. Create new repo: `gh repo create nodejs-hot-reload-job-test --public`
2. Push this code to the new repo
3. Update `appspec.yaml`:
   ```yaml
   - key: GITHUB_REPO_URL
     value: https://github.com/YOUR_USERNAME/nodejs-hot-reload-job-test
   - key: GITHUB_REPO_FOLDER
     value: ""  # Empty for standalone repo
   ```
4. Deploy: `doctl apps create --spec appspec.yaml`

### Monitoring Deployment

View logs in App Platform UI to see:

```
========================================
Executing Initial PRE_DEPLOY Job...
========================================

[PRE-DEPLOY] ==========================================
[PRE-DEPLOY] Starting Database Migration
[PRE-DEPLOY] ==========================================
...
✓ Initial PRE_DEPLOY job completed successfully

Starting Application...
...
Server is running on http://0.0.0.0:8080

[POST-DEPLOY] ==========================================
[POST-DEPLOY] Starting Database Seed
[POST-DEPLOY] ==========================================
...
```

## How Jobs Work

### PRE_DEPLOY (Strict Mode)

- Executes BEFORE application starts
- Must succeed or container exits
- Use for critical bootstrap tasks:
  - Database migrations
  - Schema updates
  - Environment validation

### POST_DEPLOY (Lenient Mode)

- Executes AFTER application starts (background)
- Failure logged but doesn't stop app
- Use for optional tasks:
  - Data seeding
  - Cache warming
  - Analytics/notifications

### Commit Change Detection

Jobs only execute when git commit SHA changes:

- Initial startup: Jobs always run (no previous SHA)
- Continuous sync (every 30s):
  - Commit changed → Execute jobs
  - Commit unchanged → Skip jobs

This prevents jobs from running every 30 seconds during normal operation.

## Endpoints

- `/` - Homepage with app information
- `/health` - Health check endpoint (JSON)

## Environment Variables

See `appspec.yaml` for full list of environment variables.

**Key variables:**

- `GITHUB_REPO_URL` - Repository URL (or use GITHUB_REPO_FOLDER for monorepo)
- `GITHUB_REPO_FOLDER` - Monorepo subfolder path
- `DEV_START_COMMAND` - Command to start app (`bash dev_startup.sh`)
- `PRE_DEPLOY_COMMAND` - Pre-deploy job command (`bash migrate.sh`)
- `POST_DEPLOY_COMMAND` - Post-deploy job command (`bash seed.sh`)
- `PRE_DEPLOY_TIMEOUT` - Max execution time (default: 300s)
- `POST_DEPLOY_TIMEOUT` - Max execution time (default: 300s)

## Troubleshooting

### Jobs not executing

- Check environment variables are set correctly
- Verify `PRE_DEPLOY_COMMAND` and `POST_DEPLOY_COMMAND` are not empty
- Check logs for commit SHA comparison

### Container exits immediately

- PRE_DEPLOY job likely failed
- Check job script for errors
- Verify job timeout is sufficient

### App starts but POST_DEPLOY doesn't run

- POST_DEPLOY runs in background
- Check logs carefully (may appear after app startup)
- POST_DEPLOY failures don't stop the app (lenient mode)

## License

MIT
