# Internal SQLite Database Schema

Claude Science stores all session data in SQLite at `~/.claude-science/<project-id>/`. The agent can query it read-only via `host.query(sql)` in the **`repl` tool**.

## Query Interface

```python
# repl tool only
result = host.query(sql, params=[], limit=None, df=False)
# Returns: {'rows': [...], 'columns': [...], 'truncated': bool, 'truncation_reason': str}

# Examples
host.query("SELECT COUNT(*) FROM frames")
host.query("SELECT * FROM artifacts WHERE filename LIKE ?", params=['%.pdb'])
host.query("PRAGMA table_info(frames)")
```

**Dialect:** SQLite. Timestamps in epoch-milliseconds. Booleans as `0`/`1`. JSON columns as TEXT — use `json_extract(col, '$.key')`.

**Limits:** Default 200 rows (max `limit=1000`). Cells >2000 chars clipped with `…[+N chars]`. Total output capped at ~100 KB. 5-second timeout.

**Scoping:** Results are automatically scoped to the current project (and `memories` to the current user) via CTEs. Schema-qualified names (`main.table`) are rejected.

## Tables

### Session / Conversation

**`frames`** — One row per agent frame (root conversation or delegated sub-agent)

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT | Frame ID (`frm_*`) |
| `parent_frame_id` | TEXT | Parent frame (null for root) |
| `root_frame_id` | TEXT | Root of the frame tree |
| `agent_name` | TEXT | `OPERON`, `REVIEWER`, `BOOKMARKER`, etc. |
| `delegate_name` | TEXT | Profile name if delegated |
| `status` | TEXT | `processing`, `completed`, `failed`, `cancelled`, `awaiting_user_response`, `awaiting_plan_approval` |
| `model` | TEXT | Model ID used |
| `effort` | TEXT | Thinking effort level |
| `input_tokens` | INT | |
| `output_tokens` | INT | |
| `cache_read_tokens` | INT | |
| `cache_write_tokens` | INT | |
| `total_cost` | REAL | USD |
| `task_summary` | TEXT | One-line description of what this frame was doing |
| `conversation_type` | TEXT | |
| `name` | TEXT | User-assigned name |
| `project_id` | TEXT | |
| `created_at` | INT | Epoch ms |
| `updated_at` | INT | Epoch ms |
| `completed_at` | INT | Epoch ms |
| `last_user_message_at` | INT | Epoch ms |
| `is_hidden` | BOOL | Whether hidden from UI |
| `input_data` | JSON | What started the frame |
| `output_data` | JSON | `json_extract(output_data,'$.response')` → final response text |
| `context_data` | JSON | Full runner state (see below) |
| `mentioned_artifact_ids` | JSON | |
| `specialists_used` | JSON | |

`context_data` contains: `$._messages` (full conversation array), `$._input_tokens`, `$._output_tokens`, `$._total_cost`, `$._running_children`, `$._plan_json`, `$._compaction_count`, `$._tool_id_to_frame_id`. Select specific keys with `json_extract` — selecting raw will hit the cell cap.

**`compaction_archives`** — Pre-compaction message snapshots

| Column | Type | Description |
|--------|------|-------------|
| `frame_id` | TEXT | |
| `compaction_index` | INT | |
| `message_count` | INT | |
| `token_count` | INT | |
| `summary` | TEXT | Compaction summary |
| `messages` | JSON | Full message array before compaction |
| `created_at` | INT | Epoch ms |

**`notifications`** — Parent↔child messages for delegation

| Column | Type | Description |
|--------|------|-------------|
| `sender_frame_id` | TEXT | |
| `recipient_frame_id` | TEXT | |
| `root_frame_id` | TEXT | |
| `notification_type` | TEXT | `compute_done`, `delegate_result`, etc. |
| `payload` | JSON | |
| `read_at` | INT | Epoch ms |
| `created_at` | INT | Epoch ms |

**`projects`** — One row per project

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT | `proj_*` |
| `name` | TEXT | |
| `description` | TEXT | |
| `context` | TEXT | User-set project context |
| `user_id` | TEXT | |
| `uploads_frame_id` | TEXT | |
| `memory_enabled` | BOOL | |
| `created_at` | INT | |
| `updated_at` | INT | |

### Artifacts

**`artifacts`** — One row per file (multiple versions tracked)

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT | Artifact ID |
| `project_id` | TEXT | |
| `root_frame_id` | TEXT | |
| `frame_id` | TEXT | Frame that created it |
| `filename` | TEXT | |
| `latest_version_id` | TEXT | FK → `artifact_versions.id` |
| `is_user_upload` | BOOL | |
| `is_ephemeral` | BOOL | |
| `folder_id` | TEXT | |
| `sort_order` | INT | |
| `priority` | INT | |
| `created_at` | INT | |

**`artifact_versions`** — One row per saved revision

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT | Version ID (used in `{{artifact:VERSION_ID}}` embeds) |
| `artifact_id` | TEXT | FK → `artifacts.id` |
| `version_number` | INT | |
| `frame_id` | TEXT | |
| `content_type` | TEXT | MIME type |
| `size_bytes` | INT | |
| `checksum` | TEXT | |
| `storage_path` | TEXT | Filesystem path |
| `extracted_code` | TEXT | |
| `code_description` | TEXT | |
| `language` | TEXT | |
| `agent_name` | TEXT | |
| `is_intermediate` | BOOL | |
| `is_checkpoint` | BOOL | |
| `parent_version_id` | TEXT | |
| `producing_cell_id` | TEXT | FK → `execution_log.id` |
| `created_at` | INT | |
| `lineage_messages` | JSON | |
| `dependency_mappings` | JSON | |
| `environment_snapshot` | JSON | |
| `annotations` | JSON | |
| `cell_sources` | JSON | |

**`artifact_dependencies`** — DAG edges between artifact versions

| Column | Description |
|--------|-------------|
| `artifact_version_id` | |
| `depends_on_version_id` | |
| `reference_name` | |

**`artifact_folders`** — Folder hierarchy for the artifact panel

### Execution History

**`execution_log`** — One row per code cell executed

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT | Cell ID |
| `frame_id` | TEXT | |
| `cell_index` | INT | Monotonic, per frame |
| `kernel_id` | TEXT | |
| `kernel_kind` | TEXT | `analysis`, `operon`, etc. |
| `conda_env` | TEXT | Active conda environment |
| `language` | TEXT | `python`, `r`, `bash`, `repl` |
| `source` | TEXT | Exact submitted code |
| `stdout` | TEXT | |
| `stderr` | TEXT | |
| `exit_status` | TEXT | `ok`, `error`, `kernel_died`, `cancelled` |
| `error_lineno` | INT | |
| `files_written` | JSON | `[{path, sha256}]` |
| `created_at` | INT | |

**`host_call_log`** — One row per `host.*` SDK call inside a cell

| Column | Type | Description |
|--------|------|-------------|
| `id` | TEXT | |
| `execution_log_id` | TEXT | FK → `execution_log.id` |
| `seq` | INT | Order within cell |
| `method` | TEXT | `query_db`, `llm`, `mcp`, `list_frames`, etc. |
| `args_json` | JSON | Call arguments |
| `derivable` | BOOL | |
| `data_inline` | JSON | Result data (small results) |
| `data_ref` | TEXT | Reference to large result |
| `error` | TEXT | Error message if failed |
| `bytes` | INT | Result size |
| `created_at` | INT | |

### Verification

**`session_claims`** — Falsifiable claims extracted for verification (unscoped)

| Column | Description |
|--------|-------------|
| `root_frame_id` | |
| `frame_id` | |
| `step_id` | |
| `claim_text` | The claim in natural language |
| `entities` | JSON extracted entities |
| `source` | `agent` or `haiku_extracted` |

**`verification_checks`** — REVIEWER verdicts (unscoped)

| Column | Description |
|--------|-------------|
| `root_frame_id` | |
| `artifact_version_id` | |
| `claim_id` | |
| `claim` | |
| `verdict` | `pass`, `warn`, `fail`, `inconclusive` |
| `severity` | |
| `evidence` | |
| `rebuttal` | |
| `reviewer_model` | |
| `reviewer_frame_id` | |
| `source_ref` | JSON |
| `status` | `open`, `resolved`, `unaddressed` |
| `reflag_count` | |

**`memories`** — Durable beliefs (user-scoped)

| Column | Description |
|--------|-------------|
| `id` | `mem_*` |
| `body` | Memory content |
| `subject_project_id` | What the memory is about |
| `subject_artifact_id` | |
| `subject_version_id` | |
| `subject_frame_id` | |
| `source_frame_id` | Frame that created it |
| `origin` | `extractor`, `agent_tool`, `user` |
| `evidence` | `stated`, `observed`, `inferred` |
| `superseded_by` | FK to newer memory |
| `last_surfaced_at` | |

### Compute

**`compute_usage`** — Remote compute jobs

| Column | Description |
|--------|-------------|
| `job_id` | |
| `environment` | |
| `tier_type` | `gpu`, `cpu` |
| `provider` | |
| `frame_id` | |
| `project_id` | |
| `started_at` | Epoch ms |
| `ended_at` | Epoch ms (null = still running) |
| `expires_at` | |
| `state` | |
| `remote_workdir` | |
| `submit_cell_id` | |
| `output_specs` | JSON |
| `remote_handle` | JSON |

## Denied Tables

These are blocked from `host.query()` — use the listed SDK accessor instead:

| Blocked table | Use instead |
|--------------|-------------|
| `oauth_tokens` | — |
| `user_secrets` | — |
| `anthropic_api_keys` | — |
| `cloud_credentials` | `host.credentials.list()` / `.get(name)` |
| `user_agents` | `host.agents.list()` |
| `agents` | `host.agents.list()` |
| `custom_mcp_servers` | `host.agents.list_connectors()` |
| `mcp_tool_grants` | — |
| `host_grants` | `list_host_grants` tool |
| `compute_providers` | `list_compute` / `compute_details` tools |

## Example Queries

```python
# repl tool

# Token and cost accounting for all sessions in this project
host.query("""
  SELECT COUNT(*) AS n_frames,
         SUM(input_tokens) AS input_tokens,
         SUM(output_tokens) AS output_tokens,
         SUM(total_cost) AS total_cost_usd
  FROM frames
""")

# Last 10 cells executed
host.query("""
  SELECT cell_index, language, conda_env, exit_status,
         substr(source, 1, 120) AS src
  FROM execution_log
  ORDER BY created_at DESC LIMIT 10
""")

# All artifacts, newest first
host.query("""
  SELECT a.filename, v.content_type, v.size_bytes, v.version_number
  FROM artifacts a
  JOIN artifact_versions v ON a.latest_version_id = v.id
  WHERE a.is_ephemeral = 0
  ORDER BY v.created_at DESC
""")

# Verification verdicts for this project
host.query("""
  SELECT claim, verdict, severity, evidence, status
  FROM verification_checks
  WHERE verdict IN ('fail', 'warn')
  ORDER BY severity DESC
""")

# Context depth per root conversation
host.query("""
  SELECT id, name,
         json_array_length(context_data, '$._messages') AS n_messages,
         json_extract(context_data, '$._compaction_count') AS compactions,
         total_cost
  FROM frames
  WHERE parent_frame_id IS NULL
  ORDER BY updated_at DESC
""")
```
