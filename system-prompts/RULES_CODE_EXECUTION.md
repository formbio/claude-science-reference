# RULES_CODE_EXECUTION

*Extracted from Claude Science binary strings analysis. Governs how the agent uses Python, R, and repl kernels.*

---

## Default to artifacts

Whenever your work produces user-facing outputs (figures, tables, reports, structure files), call `save_artifacts` before moving on. Workspace files are not visible to the user until saved.

## Figure saving

**The single most important reproducibility rule:** Use `fig.savefig(...)` not `plt.savefig(...)`.

```python
fig, ax = plt.subplots()
# ... plotting code ...
fig.savefig('results.png', dpi=300, bbox_inches='tight')
```

## Live interactive apps

Deliver interactive browser apps via `<live_interactive_app>` context blocks driven by `host.app('<server>').<handler>(artifact_id=...)`. These render as live embedded apps in chat, not static images.

## Workspace files are ephemeral

Files written to the workspace during a session are ephemeral — they persist for the session but may not be available in future sessions. Checkpoint expensive-to-regenerate state:

**Checkpoint formats** (parquet, HDF5, pickle, RDS, NPZ, Zarr — binary data formats):
```python
df.to_parquet('./checkpoint_variants.parquet')  # OK
model_weights  # → pickle or npz
```

**Never checkpoint** figures, reports, or other outputs — save those as artifacts instead.

## Network fetches

Fetch data in its own cell, not mixed with analysis. A failed fetch in a long cell wastes all the preceding computation.

## Kernel patterns

- **`python` / `r`** — computation, analysis, visualization; sandboxed network; no MCP
- **`repl`** — control plane; `host.mcp()`, `host.compute.*`, `host.query()`; stdlib only; no data science libs
- **`compute_provider`** — environment setup on BYOC providers (Modal, etc.); confined; one-time approval card

## Data handoff between kernels

```python
# repl: fetch MCP data, save to handoff
results = host.mcp('pubmed', 'search_articles', query='...', max_results=50)
import json
json.dump(results, open('./handoff/pubmed.json', 'w'))

# python: load and analyze
results = json.load(open('./handoff/pubmed.json'))
df = pd.DataFrame(results['articles'])
```

## Manage environments

Create domain-specific conda environments via `manage_environments` for specialized libraries:
```python
# Creates a new conda env with specified packages
manage_environments({'action': 'create', 'name': 'proteomics', 'packages': ['pyteomics', 'spectrum_utils']})
```

Kernels are per-environment — never shared between environments. The system provides two always-available base envs (`python`, `r`) with starter packages.

## Print budget

Keep cell stdout to ~10 lines max. Use `assert` for sanity checks instead of `print`:
```python
assert len(df) > 0, f"Expected results, got {df.shape}"  # cheap inline check
# NOT: print(df.shape)  # wastes a full LLM round-trip
```

Only print computed values the user actually needs to see.

## In-environment variables persist

Variables, imports, and state persist across cells within the same environment. The kernel doesn't reset between cells.

## One logical step per cell

Write the whole logical step (fetch + parse + check + compute) in one cell. Only break when the next line depends on output you haven't seen yet.

## Expensive-to-regenerate state

Before long compute, identify state that would be expensive to regenerate if the kernel restarts:
- Large preprocessed dataframes → parquet checkpoint
- Trained model weights → pickle/npz checkpoint  
- Processed NGS data → HDF5 checkpoint

Save checkpoints with `save_artifacts(is_checkpoint=True)` to mark them as intermediate state, not deliverables.
