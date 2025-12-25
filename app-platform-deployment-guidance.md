# App Platform Deployment Strategy: A Guide for AI Assistants

**Context:** This document defines the logic for updating applications on DigitalOcean App Platform. It specifically addresses the "Dev Workspace" pattern used in this project, distinguishing between automatic "hot reloads" and platform-level deployments.

## 0. The "Dev Workspace" Pattern (Read This First)

This project uses a specialized **Dev Workspace** architecture (Image: `hot-reload-node`).

*   **Mechanism:** The running container has an internal agent that polls your GitHub repository every 15 seconds (configurable via `GITHUB_SYNC_INTERVAL`).
*   **Automatic Sync:** If you only change **Application Code** (React components, API logic, etc.), the container detects the change and updates itself automatically.
*   **Action Required:** **NONE.** Do not run any `doctl` commands. Just push to GitHub and wait 15-30 seconds.

**When to trigger a Platform Deployment:**
You only need to interact with the DigitalOcean API/CLI if:
1.  **Plumbing Changes:** You modified `dev_startup.sh` (which only runs on container boot).
2.  **Config Changes:** You modified `.do/app.yaml` (env vars, ports, services).
3.  **Deploy Hooks Changed:** You modified `PRE_DEPLOY_COMMAND` or `POST_DEPLOY_COMMAND` env vars.
4.  **Sync Failure:** The automatic sync is stuck or broken.

---

## 1. Core Concepts: The Two Paths for Platform Updates

When a platform-level update is required (see above), use one of these two paths:

### Path A: `apps update` (The Blueprint Change)
*   **Purpose:** Updates the application **specification (configuration)**.
*   **Trigger:** Changes to `app.yaml` (env vars, instance sizes, adding services, changing image tags).
*   **Behavior:** Applies the new spec.
    *   *If the spec has changed:* It triggers a deployment automatically.
    *   *If the spec is identical:* It does **nothing**.
*   **Command:** `doctl apps update <app_id> --spec app.yaml`

### Path B: `apps create-deployment` (The Restart)
*   **Purpose:** Triggers a **redeployment** of the *existing* configuration.
*   **Trigger:** Changes to the startup plumbing (`dev_startup.sh`) or to force a restart of the Dev Workspace.
*   **Behavior:** Forces the platform to terminate running containers and start new ones. This re-runs the `dev_startup.sh` script from scratch.
*   **Command:** `doctl apps create-deployment <app_id>`

---

## 2. Decision Matrix: How to Choose

When asked to "deploy changes," analyze the nature of the change:

| Change Type | Artifact Modified | Required Action | Command |
| :--- | :--- | :--- | :--- |
| **App Logic** | `src/**/*.ts`, `components/**/*.tsx` | **Wait** (Auto-Sync) | *None (Container syncs automatically)* |
| **Dependencies** | `package.json`, `requirements.txt`, `go.mod` | **Wait** (Auto-Reinstall) | *None (Dev server detects & reinstalls)* |
| **Startup Logic** | `dev_startup.sh` | **Restart** | `doctl apps create-deployment <app_id>` |
| **Deploy Hooks** | `PRE_DEPLOY_COMMAND`, `POST_DEPLOY_COMMAND` | **Restart** | `doctl apps create-deployment <app_id>` |
| **Infra Config** | `.do/app.yaml` | **Update Spec** | `doctl apps update <app_id> --spec .do/app.yaml` |
| **Base Image** | Docker Registry Tag (e.g., `v1`->`v2`) | **Update Spec** | `doctl apps update <app_id> --spec .do/app.yaml` |
| **Sync Broken** | N/A | **Force Restart** | `doctl apps create-deployment <app_id>` |

---

## 3. Flag Reference & Nuances

### `--update-sources`
*   **Used with:** `apps update` or `apps create-deployment`.
*   **Function:** Tells the platform to check external sources (GitHub/Registry) for changes even if the spec looks identical.
*   **Note:** Less relevant for the Dev Workspace (which syncs internally) but critical for standard production builds.

### `--force-rebuild`
*   **Used with:** `apps create-deployment`.
*   **Function:** Clears the build cache.
*   **Note:** Ineffective for the Dev Workspace because it uses a pre-built image. The "build" happened in the registry, not on DigitalOcean.

---

## 4. Summary for the Assistant

**Rule #1:** Check if the change is just application code. If yes, **STOP**. The Dev Workspace handles it.

**Rule #2:** If `app.yaml` changed:
```bash
doctl apps update <app_id> --spec .do/app.yaml
```

**Rule #3:** If `dev_startup.sh` changed OR you need to restart the container:
```bash
doctl apps create-deployment <app_id>
```
