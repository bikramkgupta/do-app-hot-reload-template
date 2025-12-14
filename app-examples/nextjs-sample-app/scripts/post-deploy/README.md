# POST_DEPLOY Job Scripts

This directory contains scripts that run **after** the application starts.

## When to Use POST_DEPLOY

POST_DEPLOY jobs are for **optional tasks** that enhance the application but aren't critical for startup:

- **Database seeding** - Sample data, initial records
- **Cache warming** - Pre-populate caches for better performance
- **Analytics/notifications** - Send deployment events
- **Background tasks** - Start workers, schedule jobs

## Execution Mode: LENIENT

- Job failure **does not** stop application
- Failures are logged as warnings
- Application continues running normally
- Use for tasks that improve UX but aren't required

## Configuration

Add to your `appspec.yaml`:

```yaml
envs:
  - key: POST_DEPLOY_FOLDER
    value: scripts/post-deploy
  - key: POST_DEPLOY_COMMAND
    value: bash seed.sh
  - key: POST_DEPLOY_TIMEOUT
    value: "300"  # 5 minutes
```

## When Jobs Execute

**Initial startup:** Runs in background after app starts

**Continuous sync (every 30s):**
- Commit changed → Execute job
- Commit unchanged → Skip job

Jobs run asynchronously, so they don't block application startup.

## Example Use Cases

### Database Seeding

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[POST-DEPLOY] Seeding database..."

# Check if data already exists
if [ "$(psql $DATABASE_URL -tAc 'SELECT COUNT(*) FROM users')" -eq 0 ]; then
    echo "[POST-DEPLOY] Database empty, seeding..."
    npx prisma db seed
else
    echo "[POST-DEPLOY] Data exists, skipping seed"
fi

echo "[POST-DEPLOY] ✓ Seeding complete"
```

### Cache Warming

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[POST-DEPLOY] Warming cache..."

# Fetch and cache common queries
curl -s http://localhost:8080/api/products > /dev/null
curl -s http://localhost:8080/api/categories > /dev/null

echo "[POST-DEPLOY] ✓ Cache warmed"
```

### Deployment Notification

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[POST-DEPLOY] Sending notifications..."

# Get current commit info
COMMIT_SHA=$(git rev-parse HEAD)
COMMIT_MSG=$(git log -1 --pretty=%B)

# Send to Slack, Discord, etc.
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "{\"text\": \"Deployed: $COMMIT_MSG ($COMMIT_SHA)\"}"

echo "[POST-DEPLOY] ✓ Notification sent"
```

### Start Background Workers

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[POST-DEPLOY] Starting background workers..."

# Start worker processes
pm2 start worker.js --name email-worker
pm2 start scheduler.js --name task-scheduler

echo "[POST-DEPLOY] ✓ Workers started"
```

## Best Practices

1. **Make jobs idempotent** - Safe to run multiple times
2. **Don't block app startup** - Jobs run in background
3. **Handle failures gracefully** - App continues if job fails
4. **Log clearly** - Use `[POST-DEPLOY]` prefix
5. **Keep timeouts reasonable** - Prevent long-running tasks

## Idempotency Pattern

Always check if work is already done:

```bash
# Check before seeding
if [ "$(redis-cli GET cache:warmed)" = "true" ]; then
    echo "[POST-DEPLOY] Cache already warmed, skipping"
    exit 0
fi

# Do the work
warm_cache

# Mark as done
redis-cli SET cache:warmed true EX 3600
```

## Troubleshooting

**Job not running:**
- Verify `POST_DEPLOY_COMMAND` is set
- Check logs (may appear after app startup)
- Ensure job script is executable

**Job runs but fails silently:**
- Check logs for warnings
- POST_DEPLOY failures don't stop app (by design)
- Add error handling in script if needed

**Job times out:**
- Increase `POST_DEPLOY_TIMEOUT`
- Break into smaller, faster tasks
- Consider running as separate service
