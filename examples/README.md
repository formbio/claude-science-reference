# Example Sessions

Four complete, real Claude Science sessions showing the full agent workflow from initial request to deliverables.

Each session includes the conversation manifest (`manifest_*.json`) and all produced artifacts under the named directory.

## Sessions

### CRISPR Screen Design (`crispr_screen/`)

**Task:** Design a genome-wide kinome CRISPR knockout library  
**Manifest:** `manifest_crispr_screen.json`

Complete 8-step workflow:
1. Assembled human kinome gene set (522 kinases, Manning/KinHub)
2. Selected Brunello library guides (4/gene, 2,072 targeting sgRNAs)
3. Genome-wide off-target prediction (Cas-OFFinder vs GRCh38, ≤3 mismatches, NGG PAM)
4. CFD/MIT specificity scoring and annotation
5. Control sgRNA design (1,000 NTC + 68 positive)
6. Oligo synthesis design (83-mer, BsmBI-compatible, Golden Gate cloning)
7. Construction protocol
8. Sequencing depth planning

**Deliverables:**
- `final_kinome_library.csv` — 3,140-sgRNA library
- `oligo_pool_synthesis.csv` — 3,129 synthesis-ready oligos with adapters
- `design_report.html` — self-contained HTML report with all 6 figures
- Off-target reports, QC files, construction protocol, sequencing plan

**Headline numbers:** 522 kinases · 2,072 targeting sgRNAs · 3,140 total · median MIT specificity 97

---

### Enzyme Engineering (`enzyme_engineering/`)

**Manifest:** `manifest_enzyme_engineering.json`

---

### Extremophile Analysis (`extremophile/`)

**Manifest:** `manifest_extremophile.json`

---

### Immunotherapy (`immunotherapy/`)

**Manifest:** `manifest_immunotherapy.json`

---

## Manifest Format

Each manifest is a JSON file representing the complete session state, including:

```json
{
  "frames": [...],       // Conversation frames with full message history
  "artifacts": [...],    // Saved artifact metadata
  "execution_log": [...] // All code cells executed
}
```

Key fields in the root frame's `input_data`:
- `ultra_mode` — enables the REVIEWER + BOOKMARKER verification checkpoint
- `verifier_mode` — standalone verifier
- `memory_mode` — memory extraction enabled
- `auto_mode` — full autonomous execution

Agent output uses `{{artifact:VERSION_ID}}` embed syntax to reference saved files inline.

## Using These as Templates

The CRISPR screen example shows the complete request→plan→execute→verify→deliver lifecycle. It's the reference implementation for multi-step scientific analysis in Claude Science.

To load a seed session into a Claude Science project, place the manifest and asset directory in `~/.claude-science/<project-id>/seed/` and the app will offer to restore it.
