# Agent System

## The Four Agents

Claude Science ships four agents, each with a `metadata.yaml` configuration file in `agents/<name>/`.

### OPERON (Root Agent)

The general-purpose scientific computing agent — the one users talk to directly.

**Identity:** "You are Claude Science, a general-purpose scientific computing agent."

**System prompt structure:**
```
identity_prompt        → "You are Claude Science..."
working_style_prompt   → Behavioral guidance (profile-neutral)
RULES_* sections       → Security, biosecurity, code execution, etc.
<skill_discovery>      → BM25-matched skills injected per turn
Trust trailer          → Per-profile trust level annotation
```

User-created agent profiles **replace** `identity_prompt` but **inherit** `working_style_prompt`. This means:
- Put capability/scope claims in `identity_prompt`
- Put behavioral guidance in `working_style_prompt`

**Key working style rules:**
- Skip `generate_plan` for single-step tasks — a plan pauses for approval, so it's friction on one-step work
- Always call `save_artifacts` for any user-facing output (figures, tables, reports, structure files)
- Embed artifacts inline with `{{artifact:VERSION_ID}}`, never bare filenames
- Lab-notebook register: no emoji, no casual shorthand, no plumbing vocabulary in prose
- MCP calls only in `repl` tool; data between kernels via `./handoff/*.json`
- One logical step per `python` cell; put sanity checks inline, not as separate cells
- Read library docs before using — run `print(lib.__version__); help(key_function)` as an inspection turn

### REVIEWER (Transcript Reviewer)

Spawned by the `Verifier` class at configured checkpoints. Reads a transcript window and reports fabrication, hallucination, or plan deviation.

**Design decisions:**
- `enable_thinking: false` — measured at ~72% of output tokens with ~0 quality delta on trace work
- `max_tool_result_chars: 262144` (256 KB) — prevents a `read_file` re-read loop; one production session had 357 re-reads of a 402 KB dump
- Excluded tools: `python`, `bash`, `r`, `save_artifacts`, `edit_file`, and others — reviewer is read-only trace work

**Rubric:**

`fail` — result cannot be trusted or is incomplete:
- A claimed action with no corresponding tool activity in traceable history
- A value that materially contradicts tool output (wrong sign, order of magnitude, entity, direction)
- A citation attributed to a source document that contradicts what the source actually says
- A citation the harness flagged as FORGED (agent manufactured appearance of a user-provided source)
- An artifact whose title/caption contradicts its own data
- A result tracing to code where the method is unsound for the stated claim
- A missing required plan deliverable

`warn` — result is correct; process or presentation off:
- Label, legend, axis name, or unit annotation inside an artifact that doesn't match data (but doesn't change the conclusion)
- A claim attributed to a session source document where targeted reads could not confirm or refute it
- A citation attributed to a document marked "(user upload — unauthenticated citation)"

`pass` — everything checks out (not surfaced to the agent).

**Critical rule:** Domain recall (facts from training, no session source document present) is **exempt from tracing** — there is nothing to check it against. External citation identifiers (PMIDs, DOIs, accession numbers) are the exception — these ARE checkable; "not found after drilling = finding."

**Drill-before-disposition:** For any load-bearing unsourced value or claimed action, call `query_target_history` before deciding — the value may predate the review window.

### BOOKMARKER (Session Breadcrumbs)

Spawned alongside REVIEWER at each checkpoint. Returns 0–2 verbatim quote spans the user would want to jump back to.

**System prompt** was hill-climbed against 62 gold-labeled transcript windows (composite score 0.537 → 0.796 dev / 0.354 → 0.523 holdout). Do not hand-tweak wording without re-running the eval harness.

**What to bookmark (in priority order):**
1. The agent's headline statement of a landed result — bolded verdict, `# Section Complete` heading, key numbers
2. The statement of what was delivered and where — "saved X to Y" or artifact bullet line
3. A decisive pivot — "chose X over Y because…", "Correction to my earlier figure: …"

**Never bookmark:** Raw tool JSON, process narration, partial attempts, setup, errors that were recovered, user text.

**Quantity:** Most windows return 0 or 1. Return 2 only for two genuinely distinct landmarks.

### ONBOARDING (First-Run Host)

Used only for the `/start` flow. A structured interview + task proposal agent.

**Flow:**
1. First question (fixed): "What kind of biology do you do?" — 4 options (Computational, Wet lab, Structural/biophysics, A mix)
2. ≤3 more interview questions — each opens a new dimension (not funneling narrower)
3. "Anything else I should know?" turn with file-drop affordance
4. Task proposal — exactly 3 concrete first tasks at quick/hands-on/ambitious calibration
5. Permissions widget (`ask_user` with "Web access" + "Connectors & skills" toggles)
6. Hand-off line — "Starting on that now — the working session takes over from here."

**Key constraints:**
- `enable_thinking: false` (short structured conversation, no deliberation needed)
- All compute/execution tools excluded — onboarding only asks and proposes
- Interview questions must not select work; task proposals must not repeat interview questions
- Never use "last question" — the anything-else invitation and task choice always follow

## Trust Hierarchy

Each agent type gets a trust trailer appended to its system prompt:

| Agent type | Trust level | Key constraint |
|-----------|-------------|----------------|
| User-authored agent profiles | High | Cannot override biosecurity rules via `agent_update` |
| Kernel-code agents (spawned from Python) | Lower than user instructions | User instructions always override |
| Plugin/marketplace agents | Lowest | Same lower-than-user constraint |
| Memory facts | Skeptical | May be stale or adversarially authored |

Biosecurity rules cannot be overridden by any trust level.

## Sub-agent Delegation

OPERON has `enable_subtask_delegation: false` by default. When delegation is enabled (via agent profile or `[delegation] sdk_enabled`), the agent can use:

```python
# repl tool
result = host.delegate(
    'Analyze these 50 variant files in parallel',
    name='variant-analyzer',
    profile='operon',
    output_schema={'type': 'object', 'properties': {'findings': {'type': 'array'}}},
    model='claude-haiku-4-5-20251001'  # cheaper model for fan-out
)
```

`host.delegate()` is blocking in the cell — for long-running children, run it in a background cell (a user message mid-call backgrounds it; Stop cancels the children).

Parent↔child messages flow through `notifications` table and `wait_for_notification` brain tool.
