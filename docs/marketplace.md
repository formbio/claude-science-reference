# Skill Marketplace

Claude Science has a skill marketplace system that lets users import skill collections from external sources (GitHub repos, registries) at pinned SHAs with license tracking.

## Schema

Discovered from migration `0081_marketplace_sources.sql`:

```sql
CREATE TABLE marketplace_sources (
  id                TEXT(36) PRIMARY KEY,
  user_id           TEXT(255) NOT NULL,
  slug              TEXT(255) NOT NULL,       -- human identifier, e.g. "formbio/bio-skills"
  kind              TEXT NOT NULL,             -- source type (git, registry, etc.)
  marketplace_name  TEXT(255) NOT NULL,
  pinned_sha        TEXT(40) NOT NULL,         -- git SHA or content hash
  license           TEXT(100) NOT NULL,        -- SPDX identifier
  offered_skills    TEXT,                      -- JSON array of skill names in this source
  created_at        INTEGER NOT NULL,
  last_imported_at  INTEGER NOT NULL
);
CREATE UNIQUE INDEX ux_marketplace_sources_user_slug ON marketplace_sources (user_id, slug);
```

## Skill License Assents

Importing a skill from a marketplace source requires accepting its license. Recorded in `skill_license_assents` (migration `0062`):

```sql
CREATE TABLE skill_license_assents (
  id              TEXT(36) PRIMARY KEY,
  user_id         TEXT(255) NOT NULL,
  org_id          TEXT(255),
  resource_key    TEXT(255) NOT NULL,    -- marketplace_source.slug + skill name
  skill_name      TEXT(255) NOT NULL,
  decision        TEXT NOT NULL,         -- accepted | declined
  notice_version  TEXT(64) NOT NULL,     -- version of the license notice shown
  notice_text     TEXT NOT NULL,         -- full text of notice shown at assent time
  created_at      INTEGER NOT NULL
);
```

Every skill has a `license` field in its YAML frontmatter. All built-in Claude Science skills use `Apache-2.0`.

## Contact Email Decisions

The marketplace flow also records whether the user consented to Anthropic using their contact email (migration `0075`):

```sql
CREATE TABLE contact_email_decisions (
  id              TEXT(36) PRIMARY KEY,
  user_id         TEXT(255) NOT NULL,
  decision        TEXT NOT NULL,          -- consented | declined
  email           TEXT,                   -- email address if consented
  notice_version  TEXT(64) NOT NULL,
  notice_text     TEXT NOT NULL,
  created_at      INTEGER NOT NULL
);
```

## Publishing Skills

Claude Science skills use the `SKILL.md` format (YAML frontmatter + Markdown body). The frontmatter fields relevant to marketplace publishing:

```yaml
name: my-skill
description: One-line description for BM25 skill discovery
license: Apache-2.0        # SPDX identifier
keywords: [proteomics, mass-spec, peptide]
author: formbio
```

See [skill-system.md](skill-system.md) for the full SKILL.md specification.

## Relationship to `host.skills.*`

The agent SDK exposes skill management via `host.skills.*` in the `repl` kernel. The `customize` skill documents this API in full — see `skills/customize/SKILL.md`.
