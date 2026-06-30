# RULES_NETWORK_SANDBOX

*Extracted from Claude Science binary strings analysis. Governs network access from Python/R kernels.*

---

## Allowlisted domains

Python and R kernels run behind a network allowlist. The following domains are pre-approved:

**Science APIs:**
- NCBI / Entrez (`eutils.ncbi.nlm.nih.gov`, `pubmed.ncbi.nlm.nih.gov`)
- Ensembl (`rest.ensembl.org`, `useast.ensembl.org`)
- UniProt (`rest.uniprot.org`, `uniprot.org`)
- RCSB PDB (`data.rcsb.org`, `files.rcsb.org`)
- EBI / EMBL (`www.ebi.ac.uk`)
- Reactome (`reactome.org`)
- STRING (`string-db.org`)
- KEGG (`rest.kegg.jp`)
- OpenAlex (`api.openalex.org`)
- CrossRef (`api.crossref.org`)
- openFDA (`api.fda.gov`)
- ClinicalTrials.gov (`clinicaltrials.gov`)
- Open Targets (`api.platform.opentargets.org`)
- UCSC Genome Browser (`api.genome.ucsc.edu`)
- arXiv (`export.arxiv.org`, `arxiv.org`)
- Europe PMC (`europepmc.org`)

**Package Managers:**
- PyPI (`pypi.org`, `files.pythonhosted.org`)
- conda-forge, Bioconductor, CRAN

**Data Repositories:**
- GEO (`ftp.ncbi.nlm.nih.gov/geo/`)
- SRA (`sra-download.ncbi.nlm.nih.gov`)
- ENA (`www.ebi.ac.uk/ena/`)
- CELLxGENE (`cellxgene.cziscience.com`)

## Requesting additional access

To access a domain outside the allowlist:

```python
request_network_access(domain='my-database.example.com')
# Raises an approval card the user clicks Allow on
```

The approval card shows the user the exact domain being requested. Once approved, the domain is accessible for the remainder of the session.

## MCP servers bypass the sandbox

The `bio-tools` and `ketcher-chemistry` MCP servers run in the host process (outside the kernel sandbox) and have full network access. Use `host.mcp()` from the `repl` tool to reach APIs that would otherwise be blocked.

## No block bypass

Do not attempt to bypass the network sandbox by:
- Using a proxy
- Making requests through an allowed domain that proxies to a blocked one  
- Installing a library that routes around the sandbox

If you need access to a domain, use `request_network_access()` and let the user decide.
