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

**`memory_categories`** — User-defined categories for memories (migration 0052)

| Column | Description |
|--------|-------------|
| `name` | Category name (max 64 chars) |
| `guidance` | Instructions for the memory extractor on what to file here |
| `auto_recall` | Whether to surface these memories automatically |
| `user_id` | Owner |

**`transcript_annotations`** — Bookmarker output + user annotations on transcript blocks (migration 0038)

| Column | Description |
|--------|-------------|
| `root_frame_id` | |
| `message_uuid` | Which message the annotation anchors to |
| `message_index` | Position in conversation |
| `block_index` | Position within message (for multi-block messages) |
| `source` | `agent` (BOOKMARKER) or `user` |
| `tool_name` | Which tool call, if anchoring to a tool result |
| `anchor_text` | The exact verbatim quote (60–250 chars per BOOKMARKER spec) |
| `start_offset` | Char offset within block |
| `end_offset` | |
| `kind` | Annotation type |
| `note` | Optional user note |

**`frame_messages`** — Per-message row store for pagination (migration 0036)

| Column | Description |
|--------|-------------|
| `frame_id` | |
| `idx` | Message index |
| `msg_json` | Full message JSON |

An overflow table for `context_data._messages` when the conversation is large. Used for pagination rather than loading the full `context_data` BLOB.

**`annotations`** — Unified annotation store for artifact versions and files (migration 0085, merged from `artifact_versions.annotations` and `file_annotations`)

| Column | Description |
|--------|-------------|
| `target_kind` | `artifact`, `local`, `remote` |
| `target_key` | `av:VERSION_ID` for artifact versions; `file:host:path` for files |
| `label_idx` | Display index (0-based; rendered as ① ② … or (1) (2) …) |
| `content_checksum` | SHA-256 of the annotated content at time of annotation |
| `body` | JSON annotation object |

**`queued_user_messages`** — Async message queue (migration 0060)

| Column | Description |
|--------|-------------|
| `frame_id` | Target conversation frame |
| `payload` | Message content JSON |
| `intent_id` | Dedup key (unique) |
| `state` | `queued` → `resolved` |
| `resolved_at` | When picked up |

Used by the scheduler (routine_schedules) and other async producers to enqueue messages that are processed after the current agent turn completes.

**`session_concurrency`** — Per-session parallelism limits (migration 0093)

| Column | Description |
|--------|-------------|
| `root_frame_id` | One row per root conversation |
| `max_concurrent` | Maximum simultaneous sub-agent frames |

**`routine_schedules`** — Scheduled agent execution (migration 0087) — see [scheduler.md](scheduler.md)

**`safety_feedback`** — User feedback on safety interventions (migration 0095)

| Column | Description |
|--------|-------------|
| `root_frame_id` | |
| `user_id` | |
| `type` | Feedback type (thumbs-down, appeal, etc.) |
| `model` | Model that produced the intervention |
| `reason` | User-provided reason |
| `response_id` | ID of the specific response that triggered feedback |
| `context_snapshot` | JSON snapshot of the conversation context |

Unique constraint on `(root_frame_id, user_id, type)` — one feedback of each type per session per user.

**`marketplace_sources`** — External skill sources (migration 0081) — see [marketplace.md](marketplace.md)

**`skill_license_assents`** — Per-user license acceptance records (migration 0062)

| Column | Description |
|--------|-------------|
| `resource_key` | Marketplace slug + skill name |
| `skill_name` | |
| `decision` | `accepted` or `declined` |
| `notice_version` | Version of license notice shown |
| `notice_text` | Full text of notice at assent time |

**`managed_endpoints`** — Skill-managed local processes (migration 0102) — see [managed-endpoints.md](managed-endpoints.md)

### Additional `frames` Columns (from later migrations)

- **`aux_input_tokens`**, **`aux_output_tokens`**, **`aux_cache_read_tokens`**, **`aux_cache_write_tokens`**, **`aux_cost`** (migration 0073) — Token spend for secondary (aux) LLM calls within a frame: REVIEWER, BOOKMARKER, and other sub-agent calls that don't count toward the main agent's `input_tokens`/`output_tokens`.
- **`token_class_usage`** — JSON breakdown of token usage by class.

### Additional `execution_log` Columns (from later migrations)

- **`detection`** (migration 0057) — If a biosecurity or policy screener triggered on this cell's execution, the detection record is stored here as JSON. Null for clean cells.

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
