# Customizing the Dev Template

**📖 For comprehensive system reference, see [CLAUDE.md](CLAUDE.md) first.**

Docs map: `CLAUDE.md` = AI agent reference, `README.md` = use the template, `CUSTOMIZATION.md` = change the template, `AGENT.md` = automate it.

## When to Fork

- Use as-is if the default runtimes (Node/Python/Go optional/Rust optional) and `/dev_health` flow already fit.
- Fork when you need extra runtimes/tools, different health checks, new sync behavior, or extra services started before your app.

## Key Files to Tweak

- `Dockerfile` — install runtimes/tools; controlled by `INSTALL_*` args. Uses multi-stage build to compile health server from source.
- `scripts/startup.sh` — boot flow: load runtimes → git sync → health server → run user app.
- `scripts/github-sync.sh` — clone/pull loop and interval logic.
- `scripts/dev-health-server/main.go` — default `/dev_health` handler (built as static Go binary during Docker build).
- `app.yaml` — App Platform spec (build args, env vars, health check target).

## Common Edits (Short Recipes)

- **Add a runtime/tool (example: Java):**
  - Add args to `Dockerfile`:
    ```dockerfile
    ARG INSTALL_JAVA=false
    ARG JAVA_VERSION=21
    RUN if [ "$INSTALL_JAVA" = "true" ]; then \
        apt-get update && apt-get install -y openjdk-${JAVA_VERSION}-jdk && rm -rf /var/lib/apt/lists/*; \
    fi
    ```
  - Expose via `app.yaml` build args.

- **Change health check:**
  - Edit `scripts/dev-health-server/main.go` to customize the built-in health server (requires rebuild).
  - Or replace entirely: modify `Dockerfile` to use your own health binary.
  - Update `app.yaml` `health_check.http_path`/`port` if needed.
  - The built-in health is for bootstrap; point checks to your app, set `ENABLE_DEV_HEALTH=false`, and you can disable unused runtimes for smaller images.

## Health Check Configuration

### Understanding internal_ports

**Rule:** If your health check uses a port different from `http_port`, that port MUST be listed in `internal_ports`.

**Pattern A: App provides health endpoint (recommended)**
```yaml
# Health check on same port as app - NO internal_ports needed
http_port: 8080
health_check:
  http_path: /health
  port: 8080
```

**Pattern B: Using dev health server (blank template)**
```yaml
# Health check on different port - internal_ports REQUIRED
internal_ports:
  - 9090
http_port: 8080
health_check:
  http_path: /dev_health
  port: 9090
```

### Transitioning from Blank Template

If you started with the blank template (deploy-blank) and are adding your own app:

**Before (blank template):**
```yaml
internal_ports:
  - 9090
health_check:
  http_path: /dev_health
  port: 9090
ENABLE_DEV_HEALTH: "true"
```

**After (your app):**
```yaml
# REMOVE internal_ports entirely
health_check:
  http_path: /health          # Your app's endpoint
  port: 8080                  # Changed from 9090
ENABLE_DEV_HEALTH: "false"
```

### Common Validation Error

```
Error validating app spec field "services.health_check.port":
health check port "9090" not found in internal_ports.
```

**Fix:** Either:
1. Add the port to `internal_ports`: `internal_ports: [9090]`
2. OR remove `internal_ports` and change `health_check.port` to match `http_port`

See [DigitalOcean Internal Routing docs](https://docs.digitalocean.com/products/app-platform/how-to/manage-internal-routing/) for details.

- **Adjust sync behavior:**
  - Tweak `GITHUB_SYNC_INTERVAL` default in `scripts/github-sync.sh`.
  - Add hooks after successful sync (e.g., run `/workspaces/app/.dev-container/post-sync.sh`).

- **Run extra services before the app:**
  - In `scripts/startup.sh`, start your service before the DEV_START_COMMAND section, e.g.:
    ```bash
    echo "Starting Redis..."
    redis-server --daemonize yes
    ```

## Test Your Changes Quickly

```bash
docker build --build-arg INSTALL_JAVA=true -t dev-env-custom .
docker run --rm -p 9090:9090 -p 8080:8080 dev-env-custom
curl http://localhost:9090/dev_health
```

When satisfied, push your fork and deploy with `doctl apps create --spec app.yaml` (or update an existing app).

## Best Practices

- Keep defaults working; add toggles instead of removing behavior.
- Document new env vars/build args and update `app.yaml`.
- Avoid committing secrets; use App Platform secrets for tokens.
- Prefer simple, observable changes—log what you add to `startup.sh`.
