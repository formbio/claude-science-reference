# Artifact System

## What an Artifact Is

An artifact is any named file saved from a session. Artifacts have:
- A stable `artifact_id` that persists across the project
- A `version_id` for each revision (`save_artifacts` returns this)
- Content stored in the SQLite database (`content_snapshots` with content-addressed dedup)
- Lineage tracking (`artifact_versions.lineage_messages`, `dependency_mappings`)

## Saving Artifacts

```python
# python kernel
result = save_artifacts([
    {'path': 'analysis.csv', 'description': 'Variant analysis results'},
    {'path': 'figure1.png', 'description': 'Volcano plot'},
])

for art in result:
    version_id = art['version_id']
    artifact_id = art['artifact_id']
    # Use these IDs for embedding and cross-referencing
```

### Checkpoint artifacts

For intermediate state (expensive to regenerate):
```python
save_artifacts([
    {'path': 'embeddings.npy', 'is_checkpoint': True}
])
```

Checkpoints don't appear in the deliverables tray — they're state, not outputs.

## Embedding Artifacts in Chat

```python
# Inline figure embed (renders in chat)
f"{{{{artifact:{version_id}}}}}"

# Clickable link
f"[analysis.csv]({{{{artifact:{version_id}}}}})"
```

## Referencing Artifacts in Document Artifacts

Inside a `.tex`, `.md`, or `.html` file saved as an artifact:
```latex
% LaTeX — use art_ prefix + artifact_id (not version_id)
\includegraphics{{{artifact:art_abc123def}}}
```

```markdown
<!-- Markdown embed in a saved document -->
![Figure 1]({{artifact:art_abc123def}})
```

The `art_` prefix tells the renderer this is a stable artifact reference (tracks the latest version of that artifact, even after re-running).

## Artifact Types

| Extension | How it renders |
|-----------|---------------|
| `.png`, `.jpg`, `.svg` | Inline image |
| `.pdb`, `.cif`, `.mmcif` | Interactive Mol* 3D viewer |
| `.html` | Embedded iframe (interactive apps) |
| `.pdf` | PDF viewer |
| `.csv`, `.tsv` | Tabular data viewer |
| `.md` | Rendered markdown |
| `.py`, `.r`, `.sh` | Code viewer with syntax highlighting |

## Artifact Provenance

The `artifact_versions` table tracks:
- `lineage_messages` — which conversation turns contributed to this version
- `dependency_mappings` — which other artifacts this one depends on
- `producing_cell_id` → `execution_log.id` — the exact cell that wrote this file
- `environment_snapshot` — the conda env, package versions active at save time

Query the provenance graph:
```python
# repl tool
host.query("""
  SELECT v.id, v.version_number, v.created_at,
         v.producing_cell_id,
         json_array_length(v.lineage_messages) AS n_messages
  FROM artifact_versions v
  JOIN artifacts a ON v.artifact_id = a.id
  WHERE a.filename = 'analysis.csv'
  ORDER BY v.version_number DESC
""")
```

Access full lineage from the `python` kernel:
```python
lineage = host.lineage[version_id]
# {'code': ..., 'messages': [...], 'env': {...}, 'inputs': [...]}
```

## Live Interactive Apps

For browser-rendered interactive applications:
```python
# python kernel — create a live app from an artifact
host.app('plotly-server').serve(artifact_id=artifact_id)
# Returns a <live_interactive_app> context block for chat
```

The app runs as a local process; the UI embeds it in an iframe in the chat.

## Artifact Folders

Artifacts are organized in a folder hierarchy visible in the UI sidebar:
```python
# Create a folder
save_artifacts([...], folder='results/figures/')

# Move an artifact
host.artifacts.move(artifact_id, folder_id='folder-abc')
```

## Artifact Priority

Set priority to control display order in the artifact tray:
```python
save_artifacts([
    {'path': 'main_figure.png', 'priority': 1},     # shown first
    {'path': 'supplemental.png', 'priority': 10},   # shown later
])
```

## Closing a Response

The recommended closing pattern:
```markdown
[analysis_results.csv]({{artifact:ver_abc123}}) — variant effect predictions for 1,234 sites

The figure above shows the distribution of predicted ΔΔG values. Destabilizing variants (> +1 kcal/mol) are highlighted in red.
```

Leave images out of the closing — you've already embedded them inline with `{{artifact:...}}` and they appear in the artifact tray. Don't list all artifacts — only call out deliverables whose purpose isn't obvious from the name.
