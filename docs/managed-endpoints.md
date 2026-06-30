# Managed Endpoints

Claude Science skills can register **managed endpoints** — local server processes that a skill starts, monitors, and stops. This is how `ketcher-chemistry` (the Node.js chemical structure editor) is integrated: the skill declares a start/stop script and a liveness path; the app manages the process lifecycle.

## Schema

Discovered from migration `0102_managed_endpoints.sql`:

```sql
CREATE TABLE managed_endpoints (
  name                TEXT(128) PRIMARY KEY,
  url                 TEXT(2048) NOT NULL,      -- e.g. http://localhost:4000
  port                INTEGER NOT NULL,
  credential_name     TEXT(128),                -- optional credential to pass
  skill_name          TEXT(128) NOT NULL,       -- which skill owns this endpoint
  start_script        TEXT NOT NULL,            -- shell command to start
  stop_script         TEXT NOT NULL,            -- shell command to stop
  live_path           TEXT(512) NOT NULL,       -- health-check path (e.g. /health)
  approved_script_hash TEXT(64) NOT NULL,       -- SHA-256 of start_script
  state               TEXT(16) DEFAULT 'stopped',  -- stopped | starting | running | error
  state_changed_at    INTEGER,
  last_error          TEXT,
  transcript          TEXT,                     -- startup log
  created_at          INTEGER NOT NULL
);
```

## Security

The `approved_script_hash` field prevents a compromised skill from running arbitrary scripts. The app only executes a start script whose SHA-256 matches the stored approved hash. Changing the script requires re-approval.

## Lifecycle

1. Skill declares endpoint in its metadata (start script, port, liveness path)
2. App hashes the start script and stores it with `state = 'stopped'`
3. When the skill is needed, app runs `start_script`, polls `live_path`, sets `state = 'running'`
4. When the session ends or skill is detached, app runs `stop_script`

## Example: Ketcher Chemistry

The `ketcher-chemistry` MCP server (`mcp-servers/ketcher-chemistry/`) is the reference implementation. It starts a Node.js Express server on a dynamic port and exposes:
- `/health` — liveness check
- Drawing tools accessible via MCP tool calls proxied to the local HTTP server

## Agent Access

The endpoint URL is injected into the agent's context when the managing skill is attached. The skill's SKILL.md documents which MCP tools correspond to the endpoint.
