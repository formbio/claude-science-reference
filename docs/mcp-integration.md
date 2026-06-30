# MCP Server Integration

## Architecture

Claude Science bundles 24 science-domain MCP servers plus a chemistry structure editor. All MCP calls must be made from the **`repl` tool** — the `python` and `r` kernels have no MCP surface.

```python
# repl tool — correct
results = host.mcp('pubmed', 'search_articles', query='CRISPR Cas9 base editing', max_results=20)

# python tool — WRONG: host has no mcp method
import anthropic  # don't do this
```

## The `host.mcp()` Pattern

```python
# repl tool
result = host.mcp('server-name', 'method-name', param1=value1, param2=value2)

# Looping over records — one repl call, N host round-trips inside
results = [host.mcp('pubmed', 'get_article_metadata', pmids=[pmid]) for pmid in pmid_list]

# Save to handoff for python kernel
import json
json.dump(results, open('./handoff/pubmed_results.json', 'w'))
```

Then in the next `python` cell:
```python
import json
results = json.load(open('./handoff/pubmed_results.json'))
# proceed with pandas/matplotlib/etc.
```

## Bundled Science MCP Servers

All 24 servers are Python packages in `mcp-servers/bio-tools/lib/` and launched via `run_server.py`. They share a common `mcp_servers_common` base class (`Tier1Server`) and serve tool schemas from `schemas.json`.

### Literature

**`mcp_pubmed`** — PubMed/NCBI literature
- `search_articles` — keyword + MeSH search
- `get_article_metadata` — by PMID list
- `get_full_text_article` — by PMC ID (up to 20 per call)
- `find_related_articles` — similarity-based (`pubmed_pubmed`, `pubmed_pmc`, etc.)
- `convert_article_ids` — PMID ↔ DOI ↔ PMC ID conversion
- `get_copyright_status` — open access status check
- `lookup_article_by_citation` — fuzzy citation → PMID resolution (25s timeout, slower)

**`mcp_literature`** — Broad literature access (Europe PMC, CrossRef, arXiv)

**`mcp_biorxiv`** — bioRxiv and medRxiv preprints

### Molecular Biology

**`mcp_bio`** — General biology databases (Entrez, NCBI)

**`mcp_protein_annotation`** — UniProt, InterPro
- Protein sequences, domains, functional annotation, GO terms, PDB cross-references

**`mcp_structures_interactions`** — RCSB PDB, protein-protein interactions
- Structure metadata, coordinate access, interaction databases (STRING, BioGRID)

**`mcp_genes_ontologies`** — Gene Ontology, pathway databases (Reactome, KEGG)
- GO term lookup, enrichment background, pathway membership

### Genomics

**`mcp_genomes`** — Genome databases (NCBI, Ensembl)
- Sequence retrieval, gene coordinates, species annotation

**`mcp_biomart`** — Ensembl BioMart
- Gene/transcript attribute queries, cross-species mapping

**`mcp_expression`** — Gene expression databases
- GEO dataset search and metadata, expression profiles

**`mcp_omics_archives`** — SRA, GEO, ENA bulk archives
- Run/study/sample metadata, download accession resolution

**`mcp_rna`** — RNA databases (miRBase, RNAcentral, Rfam)

**`mcp_regulation`** — Regulatory genomics (ENCODE, JASPAR)
- ChIP-seq peaks, motif databases, regulatory elements

### Human Genetics and Clinical

**`mcp_human_genetics`** — GWAS catalog, gnomAD, ClinVar
- Variant population frequencies, disease associations, pathogenicity classifications

**`mcp_variants`** — Variant databases
- ClinVar clinical significance, structural variants

**`mcp_clinical_genomics`** — Clinical genetics databases

**`mcp_clinical_trials`** — ClinicalTrials.gov
- Trial search by condition/intervention/sponsor, eligibility criteria, endpoints

**`mcp_drug_regulatory`** — FDA, EMA regulatory data
- Drug approval status, labels, adverse events, Orange Book

### Chemistry and Drug Discovery

**`mcp_chembl`** — ChEMBL bioactivity database
- Compound/target search, IC50/EC50/Ki data, mechanism of action, ADMET properties

**`mcp_chemistry`** — Chemical structure and properties
- SMILES manipulation, structure search, physicochemical properties

**`mcp_zinc`** — ZINC purchasable compound database
- Compound search by structure, purchasability filtering

### Cancer and Single-Cell

**`mcp_cancer_models`** — Cancer model databases (CCLE, DepMap)

**`mcp_cellguide`** — CellxGene cell type guide
- Cell type marker genes, ontology, tissue expression

**`mcp_research_resources`** — Research resource databases (RRID lookup, reagent validation)

### Shared Infrastructure

**`mcp_servers_common`** — Base class, shared utilities
- `Tier1Server` class, `load_schemas()`, `original_json()`, gate decorators
- NCBI request pacing, retry logic, MCP transport timeout handling

## Ketcher Chemistry Editor

The `ketcher-chemistry` MCP server provides a JavaScript-rendered chemical structure editor (Ketcher) embedded in the web UI. It enables:
- Draw chemical structures interactively in chat
- Convert between SMILES, InChI, mol formats
- Return structures to the agent as SMILES strings

Unlike the Python bio-tools servers, this is a Node.js process with a widget asset directory.

## Rate Limits and Timeouts

The `mcp_servers_common.gate` module applies per-server rate limiting. Key limits:
- NCBI requests: respect `NCBI_API_KEY` for higher throughput (10 req/s vs 3 req/s)
- Full-text article retrieval: max 20 PMC IDs per call (each costs one full-text XML fetch)
- `lookup_article_by_citation` (ecitmatch): 25s timeout, 1 retry (NCBI's fuzzy resolution takes ~25s server-side on unmatched citations)

MCP transport limit: ~60 seconds. Calls that may approach this limit have internal caps enforced in the server code.

## Network Allowlist

MCP servers in the Python bio-tools package can reach their upstream APIs directly. The Python/R kernels are network-sandboxed — MCP servers run in the host process (outside the sandbox) and have full network access.

Domains the kernels can reach directly (without MCP):
- NCBI/Entrez, Ensembl, UniProt, RCSB PDB, EBI, Reactome, STRING, KEGG
- OpenAlex, CrossRef, openFDA, ClinicalTrials.gov, Open Targets, UCSC, arXiv
- PyPI, conda-forge, CRAN, Bioconductor
- GEO, SRA, ENA, CELLxGENE

Other domains require `request_network_access(domain=...)` → user approval card.

## Adding Custom MCP Servers

Via the `customize` skill:
```python
# repl tool
skill({'skill': 'customize'})
# Then use host.agents.list_connectors(), host.agents.add_connector(), etc.
```

Custom MCP servers can be:
- Remote HTTPS (streamable HTTP or SSE transport)
- Local Python process (same pattern as bio-tools)
- Local Node.js process (same pattern as ketcher-chemistry)
