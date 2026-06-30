# Skill System

## What a Skill Is

A skill is a `SKILL.md` file with YAML frontmatter that, when loaded, injects domain-specific instructions into the agent's context. Skills are not plugins or code modules — they are structured markdown documents the agent follows.

## SKILL.md Format

```markdown
---
name: alphafold2
description: >
  Predict 3D protein structures from sequence using AlphaFold2.
  Load when the user wants to predict or analyze protein structures.
license: Apache-2.0
---

# AlphaFold2 — Structure Prediction

[Skill content: step-by-step instructions, code patterns, known pitfalls...]
```

The `description` field is the key to skill discovery — it is what BM25 search runs against. Write it as a rich natural-language statement of when to load the skill and what it enables. Include vocabulary scientists would use.

Skills may include supporting assets as subdirectories:
- `kernel.py` — helper functions pre-loaded into the Python kernel when the skill is active
- `references/` — reference docs, schemas, worked examples
- `agents/` — sub-agent definitions for the skill's delegation patterns
- `assets/` — images, config files, templates
- `evals/` — evaluation test cases and scoring scripts
- `envs/` — compute environment definitions (for compute skills)

## Skill Discovery

The harness runs BM25 keyword search over all skill descriptions at each turn and injects a `<skill_discovery>` block listing likely-relevant skills. The agent then decides whether to load each suggested skill.

**Agent workflow (from RULES_CAPABILITY_GUIDANCE):**
1. User makes a request → search for related skills with `search_skills` before attempting the task
2. Review search results and load promising skills with the `skill` tool
3. Follow the skill's instructions when writing code or running analysis

The `search_skills` tool accepts natural language queries. Multiple searches with different vocabulary catch more relevant skills. When asked about capabilities, always query the catalog rather than answering from training — "knowing a method exists in the literature is not evidence it's installed here."

## Loading a Skill

```python
# In a tool call:
skill({'skill': 'alphafold2'})
# Injects the skill's SKILL.md content into context
# If skill has a kernel.py, its helpers become available in the python kernel
```

The `skill` tool is available in all kernel types.

## Authoring Skills — `skill-creator`

Load the `skill-creator` skill to create or iterate on a skill:

```python
skill({'skill': 'skill-creator'})
```

The authoring API uses `host.skills.*` in the `repl` tool:

```python
# repl tool

# List all skills including drafts
host.skills.list()

# Read a skill's content
host.skills.read('my-skill', 'SKILL.md')  # → {'name', 'path', 'content'}
host.skills.read('my-skill', 'references/schemas.md')

# Create or overwrite
host.skills.edit('my-skill', 'SKILL.md', content='---\nname: my-skill\n...')

# Targeted patch (str_replace style)
host.skills.edit('my-skill', 'SKILL.md', content=new_section, old_string=old_section)

# Promote draft → live skill catalog
host.skills.publish('my-skill', overwrite=False)

# Attach to an agent profile
host.agents.attach_skill('my-profile', 'my-skill')
```

## Skill Creation Process

1. **Capture intent** — what should this skill enable? When should it trigger? What's the expected output format?
2. **Interview edge cases** — input/output formats, dependencies, success criteria
3. **Write draft** — SKILL.md with rich description, step-by-step instructions, code patterns
4. **Write test cases** — 3–5 prompts that should trigger the skill; expected outputs
5. **Run evals** — use the `eval-viewer/generate_review.py` script to review results
6. **Iterate** — refine based on qualitative + quantitative feedback
7. **Optimize description** — run the description improver script for better triggering
8. **Publish** — `host.skills.publish(name)` makes it loadable

## Skill Description Optimization

The skill description is what BM25 searches against. A poor description means the skill never triggers. Key principles:
- Include the vocabulary a scientist would use when requesting the capability
- Include example trigger phrases ("when the user wants to...", "use for...")
- Include the names of the tools/models the skill covers
- Be specific about what the skill does and doesn't do

## Bundled Skills Reference

| Skill | Domain | Key capabilities |
|-------|--------|-----------------|
| `alphafold2` | Structure | AlphaFold2 protein structure prediction |
| `boltz` | Structure | Boltz-1 biomolecular structure (protein, RNA, small molecule) |
| `borzoi` | Genomics | Borzoi sequence-to-expression model |
| `chai1` | Structure | Chai-1 multi-chain structure prediction |
| `compute-env-setup` | Infrastructure | SSH/SLURM/Modal/cloud compute environment setup |
| `customize` | Agent config | Agent profile + skill CRUD via host SDK |
| `diffdock` | Drug discovery | DiffDock molecular docking |
| `esmfold2` | Structure | ESMFold2 fast structure prediction |
| `evo2` | Genomics | Evo2 genomic foundation model |
| `fair-esm2` | Protein | FAIR ESM2 protein language model embeddings |
| `figure-composer` | Visualization | Multi-panel scientific figure composition |
| `figure-style` | Visualization | Publication-grade figure correctness and legibility |
| `indication-dossier` | Clinical | Therapeutic indication research dossier (5-phase) |
| `ligandmpnn` | Drug design | LigandMPNN protein-ligand interface design |
| `literature-review` | Research | Structured scientific literature review |
| `managed-model-endpoints` | Infrastructure | Anthropic-hosted model inference |
| `openfold3` | Structure | OpenFold3 structure prediction |
| `paper-narrative` | Writing | Whole-paper figure arc and narrative planning |
| `pdf-explore` | Research | PDF document exploration and extraction |
| `product-self-knowledge` | Meta | App capabilities and feature reference |
| `proteinmpnn` | Protein design | ProteinMPNN sequence design |
| `remote-compute-modal` | Infrastructure | GPU jobs on Modal (byoc:modal) |
| `remote-compute-ssh` | Infrastructure | Jobs on SSH/SLURM clusters |
| `scgpt` | Single-cell | scGPT single-cell foundation model |
| `scvi-tools` | Single-cell | scVI-tools probabilistic single-cell analysis |
| `self-awareness` | Meta | Claude Science SQLite DB schema + `host.query()` reference |
| `skill-creator` | Meta | Author and iterate new skills |
| `solublempnn` | Protein design | SolubleMPNN solubility-optimized design |
| `using-model-endpoint` | Infrastructure | Custom model API endpoint usage |
