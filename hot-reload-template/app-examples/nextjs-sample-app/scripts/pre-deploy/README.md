# PRE_DEPLOY Job Scripts

This directory contains scripts that run **before** the application starts.

## When to Use PRE_DEPLOY

PRE_DEPLOY jobs are for **critical bootstrap tasks** that must succeed before your application can run:

- **Database migrations** - Schema updates, table creation
- **Environment validation** - Check required env vars exist
- **Dependency verification** - Ensure external services are reachable
- **Configuration setup** - Generate config files from templates

## Execution Mode: STRICT

- Job **must succeed** or container exits
- Failure prevents application from starting
- Use for tasks where app cannot function without completion

## Configuration

Add to your `appspec.yaml`:

```yaml
envs:
  - key: PRE_DEPLOY_FOLDER
    value: scripts/pre-deploy
  - key: PRE_DEPLOY_COMMAND
    value: bash migrate.sh
  - key: PRE_DEPLOY_TIMEOUT
    value: "300"  # 5 minutes
```

## When Jobs Execute

**Initial startup:** Always runs before app starts

**Continuous sync (every 30s):**
- Commit changed → Execute job
- Commit unchanged → Skip job

This ensures migrations run when code changes, not every 30 seconds.

## Example Use Cases

### Database Migrations (Prisma)

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[PRE-DEPLOY] Running Prisma migrations..."

# Deploy migrations to database
npx prisma migrate deploy

echo "[PRE-DEPLOY] ✓ Migrations completed"
```

### Environment Validation

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[PRE-DEPLOY] Validating environment..."

# Check required variables
required_vars=("DATABASE_URL" "API_KEY" "REDIS_URL")
for var in "${required_vars[@]}"; do
    if [ -z "${!var:-}" ]; then
        echo "[PRE-DEPLOY] ERROR: $var not set"
        exit 1
    fi
done

echo "[PRE-DEPLOY] ✓ Environment valid"
```

### Database Connection Test

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[PRE-DEPLOY] Testing database connection..."

# Test PostgreSQL connection
if pg_isready -d "$DATABASE_URL"; then
    echo "[PRE-DEPLOY] ✓ Database reachable"
else
    echo "[PRE-DEPLOY] ERROR: Cannot connect to database"
    exit 1
fi
```

## Best Practices

1. **Keep jobs fast** - Respect the timeout (default 5 min)
2. **Make jobs idempotent** - Safe to run multiple times
3. **Log clearly** - Use `[PRE-DEPLOY]` prefix for visibility
4. **Exit codes matter** - `exit 0` = success, `exit 1` = failure
5. **Test locally** - Run `bash migrate.sh` before deploying

## Troubleshooting

**Container exits immediately:**
- PRE_DEPLOY job failed
- Check logs for error messages
- Test job script locally
- Verify timeout is sufficient

**Job takes too long:**
- Increase `PRE_DEPLOY_TIMEOUT`
- Optimize job (remove unnecessary steps)
- Consider moving tasks to POST_DEPLOY if not critical
