# Claude Science — Reference Extraction

This repository contains the extracted agents, skills, MCP server sources, system prompt sections, and architecture documentation from the **Claude Science** macOS application (bundle ID `com.anthropic.operon`, version `0.1.0-dev.20260630`).

Claude Science is Anthropic's scientific computing research assistant — a Bun-compiled macOS app that serves a local web UI (at `localhost:8765`) backed by a multi-agent Claude harness with 30 bundled skills and 24 science-domain MCP servers.

## Contents

```
agents/                    # Agent configs (metadata.yaml) for all 4 bundled agents
  operon/                  # Root general-purpose agent ("Claude Science")
  reviewer/                # Transcript hallucination/fabrication reviewer
  bookmarker/              # Session breadcrumb extractor
  onboarding/              # First-run onboarding interview host

skills/                    # 29 bundled skills (SKILL.md + supporting assets)
  alphafold2/              # AlphaFold2 protein structure prediction
  boltz/                   # Boltz-1 structure prediction
  borzoi/                  # Borzoi genomic sequence model
  chai1/                   # Chai-1 biomolecular structure prediction
  compute-env-setup/       # Setting up compute on SSH/Slurm/Modal/cloud
  customize/               # Agent profile + skill CRUD via host SDK
  diffdock/                # DiffDock molecular docking
  esmfold2/                # ESMFold2 protein structure
  evo2/                    # Evo2 genomic foundation model
  fair-esm2/               # FAIR ESM2 protein language model
  figure-composer/         # Multi-panel scientific figure layout
  figure-style/            # Publication-grade figure correctness rules
  indication-dossier/      # Therapeutic indication research dossier
  ligandmpnn/              # LigandMPNN protein-ligand design
  literature-review/       # Structured scientific literature review
  managed-model-endpoints/ # Using Anthropic-hosted inference endpoints
  openfold3/               # OpenFold3 structure prediction
  paper-narrative/         # Whole-paper figure arc planning
  pdf-explore/             # PDF document exploration
  product-self-knowledge/  # App capabilities and feature reference
  proteinmpnn/             # ProteinMPNN protein sequence design
  remote-compute-modal/    # GPU jobs via Modal (byoc:modal)
  remote-compute-ssh/      # Jobs on SSH/SLURM clusters
  scgpt/                   # scGPT single-cell foundation model
  scvi-tools/              # scVI-tools single-cell analysis
  self-awareness/          # Claude Science's own SQLite DB schema + SDK surface
  skill-creator/           # Author new skills iteratively
  solublempnn/             # SolubleMPNN solubility-optimized design
  using-model-endpoint/    # Using custom model API endpoints

mcp-servers/               # Bundled MCP server source code
  bio-tools/               # Python launcher + 24 science-domain servers
    run_server.py          # Launcher — dispatches to lib/mcp_* packages
    lib/
      mcp_pubmed/          # PubMed literature search and fetch
      mcp_bio/             # General biology databases
      mcp_biomart/         # Ensembl BioMart gene/transcript queries
      mcp_biorxiv/         # bioRxiv/medRxiv preprint access
      mcp_cancer_models/   # Cancer model databases
      mcp_cellguide/       # CellxGene cell type guide
      mcp_chembl/          # ChEMBL bioactivity and drug data
      mcp_chemistry/       # Chemical structure and properties
      mcp_clinical_genomics/ # Clinical genomics databases
      mcp_clinical_trials/ # ClinicalTrials.gov access
      mcp_drug_regulatory/ # FDA, EMA regulatory data
      mcp_expression/      # Gene expression databases (GEO, etc.)
      mcp_genes_ontologies/ # Gene Ontology and pathway databases
      mcp_genomes/         # Genome databases (NCBI, Ensembl)
      mcp_human_genetics/  # GWAS, gnomAD, ClinVar
      mcp_literature/      # Broad literature access (Europe PMC etc.)
      mcp_omics_archives/  # SRA, GEO, ENA bulk omics archives
      mcp_protein_annotation/ # UniProt, InterPro annotation
      mcp_regulation/      # Regulatory genomics (ENCODE, JASPAR)
      mcp_research_resources/ # Research resource databases
      mcp_rna/             # RNA databases (miRBase, RNAcentral)
      mcp_servers_common/  # Shared server utilities
      mcp_structures_interactions/ # PDB, protein-protein interactions
      mcp_variants/        # Variant databases (ClinVar, gnomAD)
      mcp_zinc/            # ZINC compound database
  ketcher-chemistry/       # Ketcher chemical structure editor (Node.js widget)

system-prompts/            # Extracted system prompt sections (RULES_*)
  RULES_CORE.md
  RULES_SECURITY.md
  RULES_BIOSECURITY.md
  RULES_CODE_EXECUTION.md
  RULES_NETWORK_SANDBOX.md
  RULES_CAPABILITY_GUIDANCE.md
  RULES_PERSONAL_HEALTH.md
  RULES_SECURITY_SANDBOX.md

docs/
  architecture.md          # Full system architecture
  agent-system.md          # Agent hierarchy, trust model, reviewer/bookmarker
  skill-system.md          # Skill format, search, loading, authoring
  mcp-integration.md       # MCP server patterns, tool call flow
  compute-environments.md  # SSH, SLURM, Modal, HPC — full guide
  artifact-system.md       # Artifact save/embed/provenance
  biosecurity.md           # Biosecurity screener design
  sqlite-schema.md         # Internal metadata database schema
  reuse-guide.md           # How to adapt these patterns for your own agent
```

## Quick Start — Reuse Guide

See [docs/reuse-guide.md](docs/reuse-guide.md) for a practical walkthrough of adapting this agent/skill/MCP pattern for your own Claude-based application.

## License

The skill and agent configuration files in this repository are extracted from the Claude Science application. System prompt content and skill content are copyright Anthropic, PBC. Third-party licenses for the MCP server dependencies are in `skills/THIRD_PARTY_LICENSES.md`.
