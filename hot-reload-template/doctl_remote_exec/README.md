# doctl Remote Exec Tool

Python utility to programmatically execute commands on DigitalOcean App Platform containers via `doctl apps console`.

## What It Does

Automates interactive `doctl apps console` sessions using Python's `pexpect` library to:
- Connect to a running App Platform component
- Execute commands
- Capture and return output
- Handle shell interaction automatically

## Requirements

- Python 3.14+
- `pexpect` library (>=4.9.0)
- Authenticated `doctl` CLI

## Installation

**Using uv (recommended):**
```bash
cd doctl_remote_exec
uv sync
uv run python doctl_remote_exec.py <app-id> <component-name> "<command>"
```

**Using virtualenv:**
```bash
cd doctl_remote_exec
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install pexpect>=4.9.0
python doctl_remote_exec.py <app-id> <component-name> "<command>"
```

**Using existing virtual environment:**
```bash
pip install pexpect>=4.9.0
python doctl_remote_exec.py <app-id> <component-name> "<command>"
```

## Usage

```bash
python doctl_remote_exec.py <app-id> <component-name> "<command-to-run>"
```

**Example:**
```bash
python doctl_remote_exec.py e6cd1234-5678-90ab-cdef-1234567890ab dev-workspace "ls -la /workspaces/app"
```

## Important Notes

### Hardcoded vs Configurable

**HARDCODED (specific to this container environment):**
- **Prompt pattern:** `\$ ` (regex: `b'\\$ '`) - Expects shell prompts ending with "$ "
  - This is customized for the dev container's bash shell
  - Located in `doctl_remote_exec.py:24`
- Timeouts: 30 seconds
- PTY delays: 0.05 seconds
- Exit command: "exit"

**CONFIGURABLE (command-line parameters):**
- `app-id` - Your App Platform application ID
- `component-name` - **NOT hardcoded** - Pass any valid component name from your app spec
- `command-to-run` - Any shell command you want to execute

### Component Name Handling

The component name is passed directly to `doctl apps console {app-id} {component-name}` without modification. You must provide a valid component name that exists in your app spec.

**Finding component names:**
```bash
doctl apps get <app-id> -o json | jq -r '.[0].spec.services[].name, .[0].spec.workers[].name'
```

## How It Works

Uses `pexpect` to:
1. Spawn `doctl apps console` process
2. Wait for shell prompt (`$ `)
3. Send your command
4. Capture output between command and next prompt
5. Clean and return output
6. Exit cleanly

## Error Handling

- **TIMEOUT:** Returns `None` if command takes >30 seconds
- **EOF:** Returns partial output if connection closes unexpectedly
- **Other errors:** Prints error and returns `None`

## Limitations

- Only works with bash-compatible shells that end prompts with "$ "
- Requires the container to be running and accessible via `doctl apps console`
- Cannot handle interactive commands that require user input
