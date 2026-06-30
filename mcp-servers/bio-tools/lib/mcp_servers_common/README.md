# mcp_servers_common — Tier-1 MCP Server Base

Shared infrastructure for all 24 bundled bio-tools MCP servers.

## Architecture: Tier-1 Servers

All bundled science data servers are **Tier-1** — they serve the *exact same schemas* as Anthropic's hosted connectors, loaded from verbatim JSON captures (`schemas.json` in each package). This ensures that:

1. Tool names, parameter names, and schemas match the hosted connector exactly
2. Structured output (`outputSchema`) and error payloads are handled consistently
3. All tools are annotated `readOnlyHint=True` (house rule for bundled retrieval servers)

### `tier1.py` — The Base Class

```python
class Tier1Server:
    def __init__(self, name: str, schemas: list[dict], handlers: Mapping[str, Handler]):
        ...
    def run(self) -> None:
        """Serve on stdio (blocking)."""
```

Handler signature: `(args: dict) -> str` — plain sync callable. Handlers run in worker threads via `anyio.to_thread.run_sync` (fleet packages use synchronous `requests`/`httpx` clients).

Error detection: if the handler returns JSON shaped as `{"error": ...}`, the response has `isError=True` so the MCP client's exception handler fires.

### Schemas from Verbatim Captures

Each server package has a `schemas.json` captured live from the hosted connector:

```
mcp_pubmed/
  schemas.json        ← verbatim tool schemas from the hosted connector
  server.py           ← handlers implementing those tools
  __init__.py
```

Load schemas in `server.py`:

```python
from mcp_servers_common.tier1 import Tier1Server, load_schemas

def build_server() -> Tier1Server:
    schemas = load_schemas(__package__)
    return Tier1Server("mcp_pubmed", schemas, {
        "search_articles": handle_search_articles,
        "get_article_metadata": handle_get_article_metadata,
        ...
    })
```

### Mismatch Detection

`Tier1Server.__init__` raises `ValueError` if the handler keys don't exactly match the schema names (symmetric difference check). This prevents serving a schema with no handler or a handler with no schema.

## License Gate (`gate.py`)

Some tools are **license-gated** — deferred from serving until legal clearance. The gate reads `mcp_bio/deferred.json` and `mcp_bio/domains.json`.

**Currently license-gated tools** (cannot serve without license):

| Tool | Upstream | Reason |
|------|---------|--------|
| `get_kegg_entries`, `search_kegg`, `link_kegg_ids` | KEGG REST | Academic-use-only; commercial use requires Pathway Solutions license |
| `cadd_variant_score`, `cadd_position_scores`, `cadd_range_scores` | CADD | Non-commercial use only |
| `panglaodb_marker_genes`, `panglaodb_cell_types_for_gene`, `panglaodb_options` | PanglaoDB | Redistribution terms unverified; 403s non-browser clients |
| `get_model`, `list_models`, `search_models`, `search_genes`, `gene_dependencies` | Sanger Cell Model Passports | Prohibits commercial use and third-party API use without written consent |

The gate **fails closed**: if `deferred.json` names a tool/domain unknown to `domains.json`, it raises `RuntimeError` rather than silently passing. A server whose every tool is gated refuses to start.

### Applying the Gate (Standalone Servers)

Call `apply_gate_tier1(server)` in `main()` before serving (not at import time — the aggregate dispatcher applies its own gate):

```python
from mcp_servers_common.gate import apply_gate_tier1

def main():
    server = build_server()
    apply_gate_tier1(server)  # removes license-gated tools, adds serialization lock
    server.run()
```

The gate also wraps every handler with a `threading.Lock` — handlers share an `@lru_cache` HTTP client backed by a non-thread-safe `requests.Session`, so calls must be serialized.

### Thread Safety (Standalone vs Aggregate)

The aggregate dispatcher (`mcp_bio`) runs all 24 servers in-process. It applies per-domain serialization using one lock per package. Standalone servers collapse this to one process-wide lock (one domain = one process).

This addresses a prior incident (finding 3406443687) where `pride_search` under concurrent load would block the event loop and wedge health probes.

## Rate Limiting (`ratelimit.py`)

NCBI-specific: enforces the 3 req/s unauthenticated / 10 req/s with API key limit.

## Error Payloads (`errors.py`)

`is_error_payload(obj)` — returns True if a JSON object is shaped as `{"error": ...}`, used by `Tier1Server` to set `isError=True` in the MCP response.

## Writing a New Tier-1 Server

1. Create `lib/mcp_<domain>/` with `__init__.py`, `server.py`, `schemas.json`
2. Capture `schemas.json` from the hosted connector (or define it manually)
3. Implement handlers: one `(args: dict) -> str` function per tool
4. Build a `Tier1Server` in `build_server()`
5. In `main()`: build → apply gate → run
6. Register the package in `run_server.py`'s discovery list

See `mcp_pubmed/server.py` for a complete reference implementation.
