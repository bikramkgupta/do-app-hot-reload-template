# Agent Playbook: Deploy a User App with This Dev Template

**📖 For comprehensive system reference, see [CLAUDE.md](CLAUDE.md) first.**

Docs map: `CLAUDE.md` = AI agent source of truth, `README.md` = how humans use it, `CUSTOMIZATION.md` = how to fork/extend it, `AGENT.md` = quick deployment playbook.

**Essential Reference:** See [`App_Platform_Commands.md`](App_Platform_Commands.md) for all `doctl` commands needed for deployment, monitoring, and debugging.

## What to Collect from the User

- App repo URL (and GitHub token if private).
- Startup plan: preferred `DEV_START_COMMAND` (default `bash dev_startup.sh`) or confirm repo already has `dev_startup.sh`/`startup.sh`.
- Runtimes to install via build args (`INSTALL_NODE/PYTHON/GOLANG/RUST/RUBY`, DB clients).
- Health check choice: default `/dev_health` on port `9090` is for first deploy only (built-in Go binary, always available); plan to point checks to the app's endpoint/port and disable the built-in server afterward via `ENABLE_DEV_HEALTH=false`.
- App name/region/size (for `app.yaml`), sync interval if they want non-default.

## Execution Flow (Keep It Short)

1) **Verify access:** Ensure `doctl` is authenticated; optionally check `gh auth status` if you need repo management.  
2) **Set expectations:** Remind the user this template container clones their app repo and runs it; code lives in their repo, not here.  
3) **Fill config:** Edit `app.yaml` (or App Platform UI):
   - Build args for runtimes/clients.
   - Envs: `GITHUB_REPO_URL`, `GITHUB_TOKEN` (SECRET), `DEV_START_COMMAND` or rely on repo script, optional `GITHUB_SYNC_INTERVAL`, `WORKSPACE_PATH`.  
   - Health check: keep `/dev_health` on `9090` unless the user prefers their own.
   - Verify that deploy-on-push is NOT enabled. If it is enabled (true), then every git commit will result in app being re-deployed, which is NOT what we want.
   - If the component is static_site, it will not work. Because the hot reload requires a container, and static site is deployed to Spaces object store. Only services and workers type components will work.
4) **Deploy:** `doctl apps create --spec app.yaml` (or update existing). If using the DO button/UI, enter the same values.  
5) **Verify:** Hit health endpoint, check logs (`doctl apps logs <app-id> --type run`), and confirm git sync pulls changes. Note that you can check the latest commit in the logs. For deeper container inspection, use the remote exec tool (see `App_Platform_Commands.md` → "Execute commands in running containers").

## Smart Defaults

- `DEV_START_COMMAND="bash dev_startup.sh"`; repo `dev_startup.sh`/`startup.sh` is used if present and `DEV_START_COMMAND` is empty.
- Built-in `/dev_health` (lightweight Go binary, ~2MB) is just a bootstrap aid. Move health to the app, set `ENABLE_DEV_HEALTH=false`, and disable unused runtimes for smaller images.
- App listens on `8080`; health server listens on `9090`.
- Sync interval: `30` seconds unless the user asks otherwise.

## Reminders

- Git pulls do **not** restart the app; the user's dev server should handle reloads, or they must restart the container after dependency changes.
- Keep tokens as secrets; never commit them. Confirm before creating repos or pushing code.
- For deeper template changes (new runtimes, custom sync/health), hand off to `CUSTOMIZATION.md`.

---

## Blank Template to Production Workflow

**When user starts with deploy-blank and adds their own app, follow this checklist:**

### Initial State (Blank Template)
```yaml
internal_ports:
  - 9090                          # For dev health server
http_port: 8080
health_check:
  http_path: /dev_health
  port: 9090
ENABLE_DEV_HEALTH: "true"
DEV_START_COMMAND: ""
GITHUB_REPO_URL: ""
```

### Required Changes When Adding User's App

**Configuration Checklist:**
- [ ] **REMOVE `internal_ports`** section entirely (critical - causes validation error if left)
- [ ] **Update `health_check.port`** from `9090` to `8080`
- [ ] **Update `health_check.http_path`** to user's endpoint (e.g., `/health`, `/api/health`)
- [ ] **Set `ENABLE_DEV_HEALTH`** to `"false"`
- [ ] **Set `DEV_START_COMMAND`** to `"bash dev_startup.sh"` or user's startup command
- [ ] **Set `GITHUB_REPO_URL`** to user's repository URL
- [ ] **Set `GITHUB_TOKEN`** if private repo (mark as SECRET)
- [ ] **Set appropriate `INSTALL_*`** build args for user's runtime

### Final State (User's App)
```yaml
# internal_ports: REMOVED
http_port: 8080
health_check:
  http_path: /health              # User's endpoint
  port: 8080                      # Changed from 9090
ENABLE_DEV_HEALTH: "false"
DEV_START_COMMAND: "bash dev_startup.sh"
GITHUB_REPO_URL: "https://github.com/user/repo"
```

### Common Error If Misconfigured
```
Error validating app spec field "services.health_check.port":
health check port "9090" not found in internal_ports.
```
**Fix:** Remove `internal_ports` and update `health_check.port` to `8080`.

### File Sync Reminder
When updating configuration, ensure these files stay in sync:
- `.do/deploy.template.yaml` (deploy button)
- `hot-reload-template/.do/deploy.template.yaml` (reference)
- `hot-reload-template/app.yaml` (doctl)
