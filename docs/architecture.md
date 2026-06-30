# Claude Science — System Architecture

## Overview

Claude Science is a macOS desktop application (bundle ID `com.anthropic.operon`) built on a Bun-compiled ARM64 binary that serves a local React web UI at `localhost:8765`. The agent harness, kernel management, database, and MCP servers all run inside that single process; the browser is just the UI surface.

```
┌──────────────────────────────────────────────────────────┐
│  Browser (localhost:8765)                                │
│  React UI — chat, artifacts, plan approval, dashboards   │
└──────────────┬───────────────────────────────────────────┘
               │ WebSocket / HTTP
┌──────────────▼───────────────────────────────────────────┐
│  ClaudeScience (Bun process)                             │
│  ┌─────────────────────────────────────────────────────┐ │
│  │ Agent Harness (TypeScript)                          │ │
│  │  • Assembles system prompt (RULES_* sections)       │ │
│  │  • Runs skill discovery (BM25 search)               │ │
│  │  • Injects <skill_discovery> blocks                 │ │
│  │  • Routes tool calls                                │ │
│  │  • Runs REVIEWER + BOOKMARKER at checkpoints        │ │
│  │  • Biosecurity trajectory screen (Opus API call)    │ │
│  └───────────────────┬─────────────────────────────────┘ │
│                      │                                   │
│  ┌───────────────────▼─────────────────────────────────┐ │
│  │ Kernel Pool                                         │ │
│  │  python kernel   r kernel   repl (control-plane)   │ │
│  │  (sandboxed)    (sandboxed)  (host SDK access)      │ │
│  └───────────────────┬─────────────────────────────────┘ │
│                      │                                   │
│  ┌───────────────────▼─────────────────────────────────┐ │
│  │ SQLite metadata DB (~/.claude-science/<project>)    │ │
│  │  frames, artifacts, execution_log, host_call_log,   │ │
│  │  verification_checks, session_claims, memories, …   │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                          │
│  MCP Servers (subprocess or remote HTTPS)               │
│    bio-tools (Python, 24 servers, Tier-1 architecture)  │
│    ketcher-chemistry (Node.js, managed endpoint)         │
│                                                          │
│  Scheduler (routine_schedules)                          │
│    Fires agent turns on a timer; queues via             │
│    queued_user_messages; managed via host SDK            │
└──────────────────────────────────────────────────────────┘
               │ Anthropic API
┌──────────────▼──────────────┐
│  claude-opus-4-8            │  ← primary agent model
│  claude-haiku-4-5           │  ← kernel default for host.llm()
└─────────────────────────────┘
```

## Runtime Layout

On first launch the app stages assets to:

```
~/.claude-science/runtime/<version>/
  agents/          # Agent metadata.yaml configs
  skills/          # SKILL.md files + supporting assets
  mcp-servers/     # bio-tools/ + ketcher-chemistry/
  kernels/         # Conda-managed Python/R environments
  micromamba/      # Bundled micromamba binary for env management
  web-dist/        # Brotli-compressed React bundles
  fonts/           # AnthropicSans, AnthropicSerif, AnthropicMono
  seed/            # Example projects (CRISPR screen, enzyme engineering, etc.)
  drizzle/         # DB migration files (Drizzle ORM)
  writetrace/      # Write-trace audit logs
```

User data lives separately at `~/.claude-science/<project-id>/`.

## System Prompt Assembly

The agent system prompt is dynamically composed at load time from named sections:

```
identity_prompt        (from agent metadata.yaml)
  +
working_style_prompt   (from agent metadata.yaml, inherited by user profiles)
  +
RULES_CORE             Tool call labeling, artifact embedding syntax
RULES_SECURITY         Blast-radius, credential hygiene, anti-prompt-injection
RULES_SECURITY_SANDBOX Sandboxed execution boundaries
RULES_BIOSECURITY      Hazard axis screener, select agent recognition
RULES_PERSONAL_HEALTH  Handling personal health data
RULES_CAPABILITY_GUIDANCE When to search skills vs answer from training
RULES_CODE_EXECUTION   Default-to-artifacts, checkpoint rules, kernel patterns
RULES_NETWORK_SANDBOX  Allowlisted science APIs, block signatures
  +
<skill_discovery> blocks  (BM25 search, injected per turn)
  +
Trust trailer          (per agent trust level — user/kernel/plugin)
```

User-created agent profiles replace `identity_prompt` but inherit `working_style_prompt`, keeping capability claims separate from behavioral guidance.

## Three Kernel Types

The harness maintains a pool of persistent kernel processes:

| Kernel | Tool Name | Capabilities | Restrictions |
|--------|-----------|--------------|--------------|
| `python` | `python` | NumPy, pandas, matplotlib, science libs; `host.artifacts()`, `host.llm()` | No MCP surface; no network (sandbox) |
| `r` | `r` | R runtime + bioinformatics packages | Same restrictions as python |
| `repl` | `repl` | `host.mcp()`, `host.compute.*`, `host.query()`, `host.delegate()` | stdlib only (`python -I -S`); data passed via `./handoff/*.json` |

The repl kernel is the **host SDK surface** — it is the only kernel that can make MCP calls, spawn compute jobs, query the internal DB, or delegate to sub-agents. Passing data between kernels happens via the shared workspace directory (`./handoff/`).

## Plan Mode

When plan mode is active (either globally or triggered by `generate_plan`):

1. Agent calls `generate_plan` tool with a markdown plan
2. Plan UI renders in the browser for user review/edit
3. Agent is blocked at `awaiting_plan_approval` status
4. On approval, execution proceeds; on rejection, agent re-plans

The OPERON agent's `working_style_prompt` instructs it to skip planning for single-step tasks and only invoke `generate_plan` for genuinely multi-stage work.

## Verification Checkpoints

At configurable checkpoints (measured by step count or cost), the harness spawns two sub-agents in parallel against the current transcript window:

- **REVIEWER** — reads the transcript, reports fabrication/hallucination/plan-deviation via `submit_output`. Verdicts (`fail`/`warn`/`pass`) are stored in `verification_checks`.
- **BOOKMARKER** — selects 0–2 verbatim quote spans worth bookmarking; stored in `transcript_annotations`.

Both have `enable_thinking: false` — measured at 72% of output tokens with ~0 quality delta on trace/select work. REVIEWER uses `max_tool_result_chars: 262144` (256 KB inline vs default 16 KB) to avoid a read-loop spiral on large transcripts.

## Biosecurity Screener

Every N turns (or on hazard keywords), a separate `claude-opus-4-8` API call reads the **full conversation** and classifies composite intent against 10+ biosecurity hazard axes:

- Scale, stability, aerosolization
- Defeating safety controls
- Acquiring regulated precursors
- Designing novel variants for enhanced transmissibility/host range/immune evasion
- Computing casualty/lethal-area footprint

Framing overrides (educational, defensive, historical, peer-review) are explicitly non-escaping — the screener is instructed that "no framing overrides" and "unverifiable assertions never lower assessment." Recognition of select-agent or CWC material causes the agent to stop.

## Network Sandbox

Python/R kernels run behind a network allowlist. Approved domains include:

**Science APIs:** NCBI/Entrez, Ensembl, UniProt, RCSB PDB, EBI, Reactome, STRING, KEGG, OpenAlex, CrossRef, openFDA, ClinicalTrials.gov, Open Targets, UCSC, arXiv

**Package managers:** PyPI, conda-forge, Bioconductor, CRAN

**Data archives:** GEO, SRA, ENA, CELLxGENE

Domains outside the allowlist require `request_network_access(domain=...)` which raises a user approval card.

## Authentication

- OAuth via `claude.ai/oauth/authorize` and `platform.claude.com/v1/oauth/token`
- API key stored encrypted in SQLite `anthropic_api_keys` table (blocked from agent query access)
- Cloud credentials exposed to agents only via `host.credentials.list()` / `.get()` — never via DB query
- User email only via `host.get_user_email()` — never fabricated or copied from documents

## Data Storage

All session data is in SQLite at `~/.claude-science/<project>/`. The schema is accessible to the agent via `host.query()` in the `repl` tool (read-only `SELECT`/`WITH`/`PRAGMA` only). See [sqlite-schema.md](sqlite-schema.md) for the full table reference.
