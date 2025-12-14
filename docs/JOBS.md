# Pre-Deploy and Post-Deploy Jobs Guide

Complete guide to using PRE_DEPLOY and POST_DEPLOY jobs with the hot-reload template.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [PRE_DEPLOY Jobs](#pre_deploy-jobs)
- [POST_DEPLOY Jobs](#post_deploy-jobs)
- [Configuration Reference](#configuration-reference)
- [Job Patterns](#job-patterns)
- [Execution Flow](#execution-flow)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Examples](#examples)

## Overview

Jobs are shell scripts that execute at deployment lifecycle points. They run **only when git commit changes**, not every 30-second sync cycle.

### Why Use Jobs?

**Without jobs:**
- Manual migrations before deployment
- App crashes if database schema missing
- No automated cache warming
- Manual notification of deployments

**With jobs:**
- Automated migrations before app starts
- Container exits if migrations fail (prevents bad deployments)
- Automatic cache warming after deployment
- Notifications sent automatically

### Key Concepts

**Commit Change Detection**
- Jobs track git commit SHA
- Execute only when SHA changes
- Skip execution when commit unchanged
- Prevents running jobs every 30 seconds

**Two Execution Modes**
- **PRE_DEPLOY (Strict)**: Must succeed or container exits
- **POST_DEPLOY (Lenient)**: Failure logged, app continues

**Three Repository Patterns**
- **Same-repo**: Jobs in main app repository
- **Monorepo**: Jobs in subfolder of monorepo
- **Multi-repo**: Jobs in separate repository

## Quick Start

### 1. Create Job Scripts

```bash
# In your application repository
mkdir -p scripts/pre-deploy scripts/post-deploy

# PRE_DEPLOY: Database migration
cat > scripts/pre-deploy/migrate.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "[PRE-DEPLOY] Running migrations..."
npx prisma migrate deploy
echo "[PRE-DEPLOY] ✓ Migrations complete"
EOF

# POST_DEPLOY: Cache warming
cat > scripts/post-deploy/warm-cache.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "[POST-DEPLOY] Warming cache..."
curl -s http://localhost:8080/api/data > /dev/null
echo "[POST-DEPLOY] ✓ Cache warmed"
EOF

chmod +x scripts/pre-deploy/migrate.sh
chmod +x scripts/post-deploy/warm-cache.sh
```

### 2. Configure App Platform

Add to your `appspec.yaml`:

```yaml
envs:
  # PRE_DEPLOY configuration
  - key: PRE_DEPLOY_FOLDER
    value: scripts/pre-deploy
  - key: PRE_DEPLOY_COMMAND
    value: bash migrate.sh
  - key: PRE_DEPLOY_TIMEOUT
    value: "300"

  # POST_DEPLOY configuration
  - key: POST_DEPLOY_FOLDER
    value: scripts/post-deploy
  - key: POST_DEPLOY_COMMAND
    value: bash warm-cache.sh
  - key: POST_DEPLOY_TIMEOUT
    value: "60"
```

### 3. Deploy

```bash
git add scripts/
git commit -m "Add deploy jobs"
git push

# Jobs will execute automatically on deployment
```

## PRE_DEPLOY Jobs

Runs **before** application starts. Must succeed or deployment fails.

### When to Use

Use PRE_DEPLOY for **critical bootstrap tasks**:

| Task | Why PRE_DEPLOY | Example |
|------|---------------|---------|
| Database migrations | App needs updated schema | `npx prisma migrate deploy` |
| Environment validation | Check required env vars | Verify `DATABASE_URL` exists |
| Schema updates | Alter tables, add indexes | Run SQL scripts |
| Service health checks | Ensure dependencies ready | Test database connection |
| Config generation | Create runtime configs | Generate `config.json` from env |

### Execution Mode: STRICT

```
PRE_DEPLOY fails → Container exits (code 1) → Deployment fails
```

**Why strict?**
- Prevents broken deployments
- Database schema must exist before app starts
- Missing config = app can't function

### Example: Database Migration

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[PRE-DEPLOY] =========================================="
echo "[PRE-DEPLOY] Running Database Migrations"
echo "[PRE-DEPLOY] =========================================="

# Check database connectivity
if ! pg_isready -d "$DATABASE_URL"; then
    echo "[PRE-DEPLOY] ERROR: Cannot connect to database"
    exit 1
fi

# Run migrations
echo "[PRE-DEPLOY] Applying migrations..."
if npx prisma migrate deploy; then
    echo "[PRE-DEPLOY] ✓ Migrations completed successfully"
else
    echo "[PRE-DEPLOY] ERROR: Migration failed"
    exit 1
fi

# Verify schema
echo "[PRE-DEPLOY] Verifying schema..."
npx prisma validate

echo "[PRE-DEPLOY] =========================================="
echo "[PRE-DEPLOY] ✓ Pre-Deploy Completed"
echo "[PRE-DEPLOY] =========================================="
```

### Example: Environment Validation

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[PRE-DEPLOY] Validating environment..."

# Required environment variables
required_vars=(
    "DATABASE_URL"
    "REDIS_URL"
    "API_KEY"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        echo "[PRE-DEPLOY] ERROR: Required variable $var not set"
        exit 1
    fi
    echo "[PRE-DEPLOY]   ✓ $var configured"
done

echo "[PRE-DEPLOY] ✓ Environment validation passed"
```

## POST_DEPLOY Jobs

Runs **after** application starts (background). Failure doesn't stop app.

### When to Use

Use POST_DEPLOY for **optional enhancements**:

| Task | Why POST_DEPLOY | Example |
|------|-----------------|---------|
| Data seeding | Sample data not critical | Create test users |
| Cache warming | Improves performance | Pre-fetch common queries |
| Notifications | Alert team of deployment | Send to Slack |
| Background workers | Start async processes | Launch queue workers |
| Analytics | Track deployment events | Send to monitoring service |

### Execution Mode: LENIENT

```
POST_DEPLOY fails → Warning logged → App continues running
```

**Why lenient?**
- App doesn't depend on these tasks
- Cache warming fails? App still works (just slower initially)
- Notification fails? Team can check logs manually

### Example: Database Seeding

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[POST-DEPLOY] =========================================="
echo "[POST-DEPLOY] Seeding Database"
echo "[POST-DEPLOY] =========================================="

# Check if data exists (idempotency)
USER_COUNT=$(psql "$DATABASE_URL" -tAc "SELECT COUNT(*) FROM users")

if [ "$USER_COUNT" -gt 0 ]; then
    echo "[POST-DEPLOY] Data already exists ($USER_COUNT users). Skipping seed."
    exit 0
fi

echo "[POST-DEPLOY] Database empty. Seeding..."

# Seed data
npx prisma db seed

echo "[POST-DEPLOY] ✓ Seeding completed"
echo "[POST-DEPLOY]   - Created 10 sample users"
echo "[POST-DEPLOY]   - Created 25 sample products"
```

### Example: Cache Warming

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[POST-DEPLOY] Warming application cache..."

# Wait for app to be fully ready
sleep 5

# Pre-fetch common endpoints
endpoints=(
    "/api/products"
    "/api/categories"
    "/api/featured"
)

for endpoint in "${endpoints[@]}"; do
    if curl -sf "http://localhost:8080$endpoint" > /dev/null; then
        echo "[POST-DEPLOY]   ✓ Cached $endpoint"
    else
        echo "[POST-DEPLOY]   ⚠ Failed to cache $endpoint (non-critical)"
    fi
done

echo "[POST-DEPLOY] ✓ Cache warming completed"
```

## Configuration Reference

### Environment Variables

All job configuration is done via environment variables in App Platform.

#### PRE_DEPLOY Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PRE_DEPLOY_COMMAND` | Yes | - | Shell command to execute (e.g., `bash migrate.sh`) |
| `PRE_DEPLOY_FOLDER` | No | - | Subfolder within repo (e.g., `scripts/pre-deploy`) |
| `PRE_DEPLOY_REPO_URL` | No | - | Separate job repository URL (empty = use main repo) |
| `PRE_DEPLOY_TIMEOUT` | No | `300` | Maximum execution time in seconds |

#### POST_DEPLOY Configuration

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `POST_DEPLOY_COMMAND` | Yes | - | Shell command to execute (e.g., `bash seed.sh`) |
| `POST_DEPLOY_FOLDER` | No | - | Subfolder within repo (e.g., `scripts/post-deploy`) |
| `POST_DEPLOY_REPO_URL` | No | - | Separate job repository URL (empty = use main repo) |
| `POST_DEPLOY_TIMEOUT` | No | `300` | Maximum execution time in seconds |

### Complete appspec.yaml Example

```yaml
services:
  - name: my-app
    envs:
      # Application configuration
      - key: GITHUB_REPO_URL
        value: https://github.com/user/my-app
      - key: DEV_START_COMMAND
        value: bash dev_startup.sh

      # PRE_DEPLOY job
      - key: PRE_DEPLOY_FOLDER
        value: scripts/pre-deploy
      - key: PRE_DEPLOY_COMMAND
        value: bash migrate.sh
      - key: PRE_DEPLOY_TIMEOUT
        value: "300"

      # POST_DEPLOY job
      - key: POST_DEPLOY_FOLDER
        value: scripts/post-deploy
      - key: POST_DEPLOY_COMMAND
        value: bash seed.sh
      - key: POST_DEPLOY_TIMEOUT
        value: "60"
```

## Job Patterns

### Pattern 1: Same-Repo (Recommended)

Jobs live in your application repository.

**Structure:**
```
my-app/
├── src/
├── scripts/
│   ├── pre-deploy/
│   │   └── migrate.sh
│   └── post-deploy/
│       └── seed.sh
└── appspec.yaml
```

**Configuration:**
```yaml
envs:
  - key: PRE_DEPLOY_REPO_URL
    value: ""  # Empty = use main app repo
  - key: PRE_DEPLOY_FOLDER
    value: scripts/pre-deploy
  - key: PRE_DEPLOY_COMMAND
    value: bash migrate.sh
```

**Benefits:**
- Jobs versioned with app code
- Easy to test locally
- Single repository to manage

### Pattern 2: Monorepo

Jobs in subfolder of monorepo.

**Structure:**
```
monorepo/
├── apps/
│   └── backend/
│       ├── src/
│       └── scripts/
│           ├── pre-deploy/
│           └── post-deploy/
└── packages/
```

**Configuration:**
```yaml
envs:
  - key: GITHUB_REPO_URL
    value: https://github.com/user/monorepo
  - key: GITHUB_REPO_FOLDER
    value: apps/backend
  - key: PRE_DEPLOY_FOLDER
    value: scripts/pre-deploy
  - key: PRE_DEPLOY_COMMAND
    value: bash migrate.sh
```

**Benefits:**
- All apps in one repo
- Shared scripts possible
- Coordinated deployments

### Pattern 3: Multi-Repo (Advanced)

Jobs in separate repository.

**Structure:**
```
app-repo/          job-repo/
├── src/           ├── migrations/
└── appspec.yaml   │   └── migrate.sh
                   └── seeding/
                       └── seed.sh
```

**Configuration:**
```yaml
envs:
  # Main app
  - key: GITHUB_REPO_URL
    value: https://github.com/user/app-repo

  # Jobs from different repo
  - key: PRE_DEPLOY_REPO_URL
    value: https://github.com/user/job-repo
  - key: PRE_DEPLOY_FOLDER
    value: migrations
  - key: PRE_DEPLOY_COMMAND
    value: bash migrate.sh
```

**Benefits:**
- Shared jobs across multiple apps
- Separate permissions for ops tasks
- Version jobs independently

## Execution Flow

### Initial Startup (First Deploy)

```
1. Container starts
2. Load runtimes (Node.js, Python, etc.)
3. Clone application repository
   ↓
4. Execute PRE_DEPLOY job
   ├─ Job succeeds → Continue
   └─ Job fails → Exit container (code 1)
   ↓
5. Start background github-sync.sh
6. Start health servers
   ↓
7. Execute POST_DEPLOY job (background)
   ├─ Job succeeds → Log success
   └─ Job fails → Log warning (app continues)
   ↓
8. Start application (DEV_START_COMMAND)
```

### Continuous Sync (Every 30 Seconds)

```
1. github-sync.sh wakes up
2. git fetch + pull
3. Show current commit SHA
   ↓
4. Acquire job execution lock
   ├─ Lock held → Skip (another job running)
   └─ Lock acquired → Continue
   ↓
5. Check commit changed?
   ├─ Commit unchanged → Skip jobs, release lock
   └─ Commit changed → Execute jobs
      ↓
      6. Execute PRE_DEPLOY
         ├─ Success → Continue
         └─ Failure → Don't update SHA, retry next sync
         ↓
      7. Execute POST_DEPLOY
         ├─ Success → Log success
         └─ Failure → Log warning
         ↓
      8. Update commit SHA file
      9. Release lock
   ↓
10. Sleep 30 seconds
11. Repeat from step 1
```

### Commit SHA Tracking

Jobs use git commit SHA to detect changes:

```bash
# First run (no SHA file exists)
/tmp/last_job_commit.txt: [doesn't exist]
Current SHA: abc123
Result: Execute jobs, write abc123 to file

# Second run (30s later, no new commits)
/tmp/last_job_commit.txt: abc123
Current SHA: abc123
Result: Skip jobs (SHA unchanged)

# Third run (30s later, new commit pushed)
/tmp/last_job_commit.txt: abc123
Current SHA: def456
Result: Execute jobs, write def456 to file
```

## Best Practices

### 1. Make Jobs Idempotent

Jobs should be safe to run multiple times:

**Bad:**
```bash
# Always inserts, fails on second run
psql $DATABASE_URL -c "INSERT INTO users VALUES (1, 'admin')"
```

**Good:**
```bash
# Check first, safe to run multiple times
psql $DATABASE_URL -c "
INSERT INTO users (id, name)
VALUES (1, 'admin')
ON CONFLICT (id) DO NOTHING
"
```

### 2. Use Descriptive Logging

Prefix all logs with `[PRE-DEPLOY]` or `[POST-DEPLOY]`:

```bash
echo "[PRE-DEPLOY] Starting database migration..."
echo "[PRE-DEPLOY]   → Applying migration 001"
echo "[PRE-DEPLOY]   ✓ Migration 001 applied"
echo "[PRE-DEPLOY] ✓ All migrations completed"
```

### 3. Handle Errors Gracefully

**PRE_DEPLOY (strict):**
```bash
if ! npx prisma migrate deploy; then
    echo "[PRE-DEPLOY] ERROR: Migration failed"
    exit 1  # Stop deployment
fi
```

**POST_DEPLOY (lenient):**
```bash
if ! curl -s "$WEBHOOK_URL" -d "$DATA"; then
    echo "[POST-DEPLOY] ⚠ Notification failed (non-critical)"
    # Don't exit - app should continue
fi
```

### 4. Set Appropriate Timeouts

**Fast jobs (< 1 minute):**
```yaml
- key: POST_DEPLOY_TIMEOUT
  value: "60"  # Cache warming, notifications
```

**Slow jobs (migrations):**
```yaml
- key: PRE_DEPLOY_TIMEOUT
  value: "600"  # 10 minutes for large migrations
```

### 5. Test Jobs Locally

Always test before deploying:

```bash
# Test job script locally
cd scripts/pre-deploy
bash migrate.sh

# Test with Docker
docker run -p 8080:8080 \
  -e GITHUB_REPO_URL=... \
  -e PRE_DEPLOY_FOLDER=scripts/pre-deploy \
  -e PRE_DEPLOY_COMMAND="bash migrate.sh" \
  hot-reload-template:latest
```

### 6. Version Your Job Scripts

Keep jobs in git with your application:

```bash
git add scripts/
git commit -m "Add database migration job"
git push

# Jobs deploy with your code
# No manual intervention needed
```

## Troubleshooting

### Container Exits Immediately

**Symptom:** Container starts then exits after ~30 seconds

**Cause:** PRE_DEPLOY job failed

**Solution:**
1. Check App Platform logs for `[PRE-DEPLOY]` errors
2. Test job locally: `bash scripts/pre-deploy/migrate.sh`
3. Verify database connectivity
4. Check timeout is sufficient

**Example log:**
```
[PRE-DEPLOY] Running migrations...
[PRE-DEPLOY] ERROR: Cannot connect to database
ERROR: Initial PRE_DEPLOY job failed. Container cannot start.
```

### Jobs Not Running

**Symptom:** No job execution in logs

**Causes and solutions:**

**1. Command not configured:**
```yaml
# Missing PRE_DEPLOY_COMMAND
- key: PRE_DEPLOY_FOLDER
  value: scripts/pre-deploy
# Add:
- key: PRE_DEPLOY_COMMAND
  value: bash migrate.sh
```

**2. Script not executable:**
```bash
chmod +x scripts/pre-deploy/migrate.sh
git add scripts/
git commit -m "Make script executable"
git push
```

**3. Commit unchanged:**
```
[INFO] Repository commit unchanged. Skipping deploy jobs.
```
This is normal - jobs only run when code changes.

### Jobs Run Every Time (Not Skipping)

**Symptom:** Jobs execute every 30 seconds

**Cause:** Commit SHA tracking not working

**Debug:**
```bash
# Check if SHA file is being created
docker exec [container] cat /tmp/last_job_commit.txt

# Check if job-manager.sh exists
docker exec [container] ls -la /usr/local/bin/job-manager.sh
```

### Job Timeout

**Symptom:** Job killed after timeout period

**Log example:**
```
[PRE-DEPLOY] Running migrations...
[PRE-DEPLOY] ERROR: Job timed out after 300s
```

**Solutions:**
1. Increase timeout:
   ```yaml
   - key: PRE_DEPLOY_TIMEOUT
     value: "600"  # 10 minutes
   ```

2. Optimize job:
   - Remove unnecessary steps
   - Run migrations incrementally
   - Use indexes to speed up database operations

3. Move to POST_DEPLOY if not critical:
   - Data seeding can be POST_DEPLOY
   - Only migrations need PRE_DEPLOY

### POST_DEPLOY Fails Silently

**Symptom:** POST_DEPLOY errors not obvious

**Cause:** Lenient mode logs warnings, doesn't stop app

**Check logs:**
```
[POST-DEPLOY] Starting seed...
[POST-DEPLOY] ERROR: Cannot connect to database
[WARN] POST_DEPLOY job failed (lenient mode - continuing)
```

**Solutions:**
1. Add error handling to job script
2. Send notification on failure
3. Check logs regularly for warnings

## Examples

### Example 1: Node.js with Prisma

**PRE_DEPLOY: Run migrations**
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[PRE-DEPLOY] Running Prisma migrations..."

# Deploy migrations
npx prisma migrate deploy

# Generate Prisma Client
npx prisma generate

echo "[PRE-DEPLOY] ✓ Migrations completed"
```

**POST_DEPLOY: Seed database**
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[POST-DEPLOY] Seeding database..."

# Only seed if empty
if [ "$(npx prisma db execute --stdin <<< 'SELECT COUNT(*) FROM users')" = "0" ]; then
    npx prisma db seed
    echo "[POST-DEPLOY] ✓ Database seeded"
else
    echo "[POST-DEPLOY] Data exists, skipping seed"
fi
```

### Example 2: Python with Django

**PRE_DEPLOY: Run migrations**
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[PRE-DEPLOY] Running Django migrations..."

# Run migrations
python manage.py migrate --no-input

# Collect static files
python manage.py collectstatic --no-input

echo "[PRE-DEPLOY] ✓ Migrations completed"
```

**POST_DEPLOY: Create superuser**
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[POST-DEPLOY] Creating superuser..."

# Create superuser if doesn't exist
python manage.py shell <<EOF
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', '${ADMIN_PASSWORD}')
    print('[POST-DEPLOY] ✓ Superuser created')
else:
    print('[POST-DEPLOY] Superuser exists')
EOF
```

### Example 3: Go with Database Migrations

**PRE_DEPLOY: Run migrations**
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[PRE-DEPLOY] Running database migrations..."

# Run migrations with golang-migrate
migrate -path ./migrations \
        -database "$DATABASE_URL" \
        up

echo "[PRE-DEPLOY] ✓ Migrations completed"
```

**POST_DEPLOY: Warm cache**
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[POST-DEPLOY] Warming Redis cache..."

# Pre-populate common queries
redis-cli -u "$REDIS_URL" SET "warmup:time" "$(date -Iseconds)"

echo "[POST-DEPLOY] ✓ Cache warmed"
```

## Summary

**Key Takeaways:**

✅ Jobs run only when git commit changes (not every 30s)
✅ PRE_DEPLOY must succeed or deployment fails (strict)
✅ POST_DEPLOY failures don't stop app (lenient)
✅ Use PRE_DEPLOY for critical tasks (migrations)
✅ Use POST_DEPLOY for nice-to-have tasks (seeding)
✅ Make jobs idempotent (safe to run multiple times)
✅ Test jobs locally before deploying
✅ Version jobs in git with your app

**Quick Reference:**

```yaml
# Minimal configuration
envs:
  - key: PRE_DEPLOY_FOLDER
    value: scripts/pre-deploy
  - key: PRE_DEPLOY_COMMAND
    value: bash migrate.sh
  - key: POST_DEPLOY_FOLDER
    value: scripts/post-deploy
  - key: POST_DEPLOY_COMMAND
    value: bash seed.sh
```

For more examples, see:
- `app-examples/nextjs-sample-app/scripts/` - Next.js examples
- `nodejs-hot-reload-job-test/` - Complete test application
- `CUSTOMIZATION.md` - Advanced configuration
