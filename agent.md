# AI Agent Deployment Guide

Deploy hot-reload dev environments to DigitalOcean App Platform.

## Aha in 5 minutes (80% case)

1. Copy `.github/workflows/deploy-app.yml` and `.do/app.yaml` into the target repo.
2. Copy an example `dev_startup.sh` from `examples/` into the repo root (review/edit for the framework).
3. Add GitHub Secrets: `DIGITALOCEAN_ACCESS_TOKEN`, `APP_GITHUB_TOKEN` (private repos), and any app secrets.
4. Run deploy:

```bash
gh workflow run deploy-app.yml -f action=deploy
```

Why this is useful: ~1 minute deploys and shell access for debugging even if the app fails.

The workflow auto-fills `GITHUB_REPO_URL` for the current repo. Only change it if the workflow runs in a different repo than the app (e.g., a central template) or you use GitHub Enterprise. For monorepos, set `GITHUB_REPO_FOLDER`.

If `GITHUB_REPO_URL` points to this template repo, you will see the welcome page until you point it to your app repo or add your own `dev_startup.sh` here.

## Minimal edits to `.do/app.yaml`

- Set `name`, `region`, and the image `repository` (node/bun/python/go/ruby/full).
- Keep `DEV_START_COMMAND` as `bash dev_startup.sh` (default) or change if needed.
- Add app secrets with `${SECRET_NAME}`.

Example snippet:

```yaml
    envs:
      - key: GITHUB_REPO_URL
        value: "${GITHUB_REPO_URL}"  # auto-filled by the workflow
        scope: RUN_TIME

      - key: DEV_START_COMMAND
        value: "bash dev_startup.sh"
        scope: RUN_TIME
```

## Deploy / Delete

```bash
# Deploy
gh workflow run deploy-app.yml -f action=deploy

# Delete
gh workflow run deploy-app.yml -f action=delete
```

## Details & Reference

### Secrets

1. Add secret to GitHub (Settings → Secrets → Actions)
2. Reference in app spec: `value: "${SECRET_NAME}"`
3. Deploy - the workflow substitutes values

Pre-wired secrets in workflow:
- `APP_GITHUB_TOKEN`, `DATABASE_URL`, `REDIS_URL`, `MONGODB_URI`
- `AUTH_SECRET`, `NEXTAUTH_SECRET`, `JWT_SECRET`, `SESSION_SECRET`
- `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `GOOGLE_API_KEY`
- `STRIPE_SECRET_KEY`, `AWS_ACCESS_KEY_ID`, `SENTRY_DSN`
- `CUSTOM_SECRET_1` through `CUSTOM_SECRET_10`

If your secret is not listed in `.github/workflows/deploy-app.yml`, replace `CUSTOM_SECRET_1..10` (or add new entries) and reference that name in your app spec.

### Runtimes

| Repository | Use Case |
|------------|----------|
| `hot-reload-node` | Node.js, Next.js, React |
| `hot-reload-bun` | Bun apps |
| `hot-reload-python` | FastAPI, Django, Flask |
| `hot-reload-go` | Go APIs |
| `hot-reload-ruby` | Rails, Sinatra |
| `hot-reload-full` | Multi-language |

### Regions

| Code | Location |
|------|----------|
| `nyc1`, `nyc3` | New York |
| `sfo3` | San Francisco |
| `ams3` | Amsterdam |
| `sgp1` | Singapore |
| `lon1` | London |
| `fra1` | Frankfurt |
| `tor1` | Toronto |
| `blr1` | Bangalore |
| `syd1` | Sydney |

### Instance Sizes

| Slug | Specs |
|------|-------|
| `apps-s-1vcpu-0.5gb` | 1 vCPU, 0.5GB |
| `apps-s-1vcpu-1gb` | 1 vCPU, 1GB |
| `apps-s-1vcpu-2gb` | 1 vCPU, 2GB (recommended) |
| `apps-s-2vcpu-4gb` | 2 vCPU, 4GB |

See [pricing](https://docs.digitalocean.com/products/app-platform/details/pricing/).

### Environment Variables

#### Required

| Key | Description |
|-----|-------------|
| `GITHUB_REPO_URL` | Auto-filled by the workflow (current repo); override if deploying a different repo |
| `DEV_START_COMMAND` | Startup command |

#### Optional

| Key | Default | Description |
|-----|---------|-------------|
| `GITHUB_TOKEN` | - | For private repos |
| `GITHUB_BRANCH` | main | Branch to sync |
| `GITHUB_REPO_FOLDER` | - | Monorepo subfolder |
| `GITHUB_SYNC_INTERVAL` | 15 | Sync frequency (seconds) |

#### Scope Options

| Scope | When Available |
|-------|----------------|
| `RUN_TIME` | Only at run-time (default) |
| `BUILD_TIME` | Only at build-time |
| `RUN_AND_BUILD_TIME` | Both |

---

## Remote Troubleshooting with do-app-sandbox

**AI agents can remotely control and troubleshoot the running container** using [do-app-sandbox](https://github.com/bikramkgupta/do-app-sandbox).

### Get App ID

```bash
doctl apps list --format ID,Name --no-header
```

### Execute Commands in Container

```bash
# Run any command in the running container
sandbox exec $APP_ID "ls -la /workspaces/app"
sandbox exec $APP_ID "tail -100 /tmp/app.log"
sandbox exec $APP_ID "env | grep DATABASE"
```

### Common Debugging Scenarios

| What to Check | Command |
|---------------|---------|
| Is code synced? | `sandbox exec $APP_ID "cd /workspaces/app && git log -1"` |
| What's running? | `sandbox exec $APP_ID "ps aux"` |
| Check env loaded | `sandbox exec $APP_ID "env | grep DATABASE"` |
| View app logs | `sandbox exec $APP_ID "cat /tmp/*.log"` |

---

## Full Workflow (Optional)

### Step 1: Deploy

```bash
gh workflow run deploy-app.yml -f action=deploy
```

### Step 2: Wait for deployment

```bash
gh run watch
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

| Issue | Fix |
|-------|-----|
| Workflow fails | Check DIGITALOCEAN_ACCESS_TOKEN secret |
| Private repo fails | Add APP_GITHUB_TOKEN secret |
| App doesn't start | Check dev_startup.sh exists |
| Health check fails | App must listen on port 8080 |

---

## doctl Commands Cheat Sheet

```bash
# List apps
doctl apps list

# View logs
doctl apps logs $APP_ID dev-workspace --type run

# Force redeploy
doctl apps create-deployment $APP_ID

# Delete app
doctl apps delete $APP_ID
```
