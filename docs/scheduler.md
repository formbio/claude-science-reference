# Routine Schedules (Scheduled Agent Execution)

Claude Science has a built-in scheduler that fires agent sessions on a timer. This is the `routine_schedules` system — discovered from migration `0087_routine_schedules.sql`.

## Schema

```sql
CREATE TABLE `routine_schedules` (
  `id`             TEXT(36) PRIMARY KEY,
  `root_frame_id`  TEXT(36) NOT NULL REFERENCES frames(id) ON DELETE CASCADE,
  `owner_user_id`  TEXT(255) NOT NULL,
  `label`          TEXT(120),
  `on_tick`        TEXT NOT NULL,        -- code to execute on each tick
  `every_minutes`  INTEGER NOT NULL,     -- schedule interval
  `enabled`        INTEGER DEFAULT false,
  `locked_at`      INTEGER,              -- set while a tick is running
  `paused_reason`  TEXT,                 -- why it's paused
  `next_due`       INTEGER NOT NULL,     -- epoch ms of next fire
  `tick_count`     INTEGER DEFAULT 0,
  `missed_ticks`   INTEGER DEFAULT 0,
  `last_fire_at`   INTEGER,
  `last_ok_at`     INTEGER,              -- last successful tick
  `idle_streak`    INTEGER DEFAULT 0,    -- consecutive ticks with no output
  `last_results`   TEXT,                 -- JSON summary of last tick output
  `created_at`     INTEGER NOT NULL,
  `updated_at`     INTEGER NOT NULL
);
-- Only index enabled schedules for due-check efficiency
CREATE INDEX ix_routine_due ON routine_schedules (next_due) WHERE enabled = 1;
-- One schedule per root conversation
CREATE UNIQUE INDEX routine_schedules_root_frame_id_unique ON routine_schedules (root_frame_id);
```

## How It Works

Each schedule is tied to a `root_frame_id` — a specific conversation. When the tick fires, the `on_tick` code runs in the context of that conversation (as if the user sent a message). The session stores its output in `last_results`.

The scheduler tracks:
- `locked_at` — prevents concurrent execution (tick runs until lock releases)
- `missed_ticks` — counts skips if a tick ran long
- `idle_streak` — consecutive ticks that produced no meaningful output (may auto-pause)
- `last_ok_at` — last tick that completed without error

## Use Cases

- Automated literature monitoring (daily PubMed search for new papers)
- Periodic data fetching and artifact updates
- Scheduled analysis pipelines (weekly gene expression report)
- Alert conditions (check if a metric crosses a threshold)

## Relationship to `queued_user_messages`

When a tick fires, the scheduler likely enqueues a message via `queued_user_messages` (migration `0060`) so the main conversation loop picks it up without interrupting an in-progress turn.

```sql
CREATE TABLE queued_user_messages (
  seq        INTEGER PRIMARY KEY,
  frame_id   TEXT(36) NOT NULL REFERENCES frames(id) ON DELETE CASCADE,
  payload    TEXT NOT NULL,     -- the message content
  intent_id  TEXT NOT NULL,     -- dedup key
  state      TEXT DEFAULT 'queued',  -- queued | resolved
  resolved_at INTEGER,
  created_at  INTEGER NOT NULL
);
```
