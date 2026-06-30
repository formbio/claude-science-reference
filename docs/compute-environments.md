# Compute Environments in Claude Science

Claude Science supports running compute-intensive jobs on remote hardware through a unified SDK surface. Three backend shapes are supported: direct SSH hosts (including SLURM clusters), Modal (managed GPU cloud), and container-via-bridge runners.

## Architecture: Two Kernel Surfaces

Remote compute is orchestrated from the **`repl` tool** (control-plane kernel), not from `python`/`r`. The pattern is always:

```
[python cell]  prepare inputs — write ./in.dat, ./params.json
[repl cell]    create → submit_job → (return immediately)
[brain tool]   wait_for_notification('compute_done')
[python cell]  read harvested hpc/<jobId>/ outputs
```

The daemon's background poller probes the remote, harvests `out.tar.gz` into `hpc/<jobId>/` in the workspace, and emits `compute_done` when done. The `repl` cell never blocks on compute.

## SSH / SLURM Clusters (`remote-compute-ssh`)

Load the `remote-compute-ssh` skill before dispatching.

```python
# repl tool — discovery first
details = compute_details({'provider': 'my-hpc-cluster', 'mode': 'read'})
# Returns a prose doc with known envs, partitions, gotchas

c = host.compute.create('ssh:my-hpc-cluster')

# Probe the cluster if first contact
info = c.call_command(
    'id; module avail 2>&1 | head -40; ls -la ~',
    intent='Discover available modules and home layout',
    login_shell=True
)

# Submit a job
job = c.submit_job(
    command='source activate myenv && python run.py --input ./in.dat --output ./out/',
    inputs=[{'src': 'in.dat', 'dst_filename': 'in.dat'}],
    outputs=['out/**'],
    resources={'partition': 'gpu', 'gpus': 1, 'cpus': 8, 'mem_gb': 32, 'hours': 4},
    intent='Run protein folding job'
)
# Cell ends here — poller takes over
```

Then in the brain tool: `wait_for_notification('compute_done')`.

### SLURM-specific

- `resources.partition`, `resources.account`, `resources.time` are translated to `#SBATCH` directives
- Compute nodes often have **no internet** — pre-stage weights from login or data-transfer node
- Modules: write personal modulefiles under `$HOME/modulefiles/`; `module use $HOME/modulefiles` in job preamble
- Containers: `apptainer pull name.sif docker://ref` preferred over `apptainer build` (many clusters disable unprivileged user namespaces)

## Modal Cloud GPU (`remote-compute-modal`, `byoc:modal`)

Load the `remote-compute-modal` skill. Requires Modal configured under Settings → Compute → Modal.

### Two distinct surfaces

| Surface | Tool | Purpose | Approval card |
|---------|------|---------|---------------|
| Job surface | `repl` → `host.compute.create('byoc:modal', ...)` | Run actual GPU jobs | Tier card (hardware + timeout) |
| Environment surface | `compute_provider` tool | Build images, populate weight volumes, CPU probes | Kernel card (≤30 min, no GPU) |

### Job flow

```python
# repl tool
details = compute_details({'provider': 'byoc:modal', 'mode': 'read'})
# Check ledger for existing env: ### env:<name>@<spec_sha>

c = host.compute.create('byoc:modal', provider_params={
    'modal': {
        'image': 'im-abc123',     # from ledger or build_env() output
        'volumes': ['vol-xyz456'] # model weight volumes
    }
})

job = c.submit_job(
    command='python /app/run_inference.py --input ./in.fa --output ./out/',
    inputs=[{'src': 'input.fa', 'dst_filename': 'in.fa'}],
    outputs=['out/**'],
    resources={
        'gpu': 'A100-40GB',
        'cpu': 8,
        'memory_gb': 32,
        'timeout_seconds': 3600  # job timeout (not container timeout)
    },
    intent='Run AlphaFold2 structure prediction'
)
```

### Two timeout timers

- **Container timeout** (`provider_params.modal.timeout`) — how long the sandbox lives total (default from Settings; ceiling: Modal's 24h platform lifetime minus staging margins)
- **Job timeout** (`timeout_seconds` on `submit_job`) — optional runaway guard for a single job; defaults to container remaining life minus harvest margin

A timed-out job lands as `status: 'timed_out'` with partial outputs already harvested.

### Environment setup (compute_provider kernel)

```python
# compute_provider tool (not repl, not python)
envs = list_envs()  # all bundled env definitions

# Build one (raises kernel approval card first time)
result = build_env('alphafold2_gpu')
# {'image': 'im-...', 'spec_sha': '...', 'volumes': [...], 'env': {...}}

# Inspect env definition without building
# (from repl tool, not compute_provider)
content = host.skills.read('remote-compute-modal', 'envs/alphafold2_gpu.py')['content']
print(content)
```

After building, record in `compute_details` ledger:
```
### env:alphafold2_gpu@<spec_sha>
image: im-abc123
volumes: [vol-xyz456]
notes: A100-tested 2026-01-15; weights at /datavol/alphafold2/
```

## Environment Specification Format

All compute backends use a shared declarative spec format for portable environment definitions:

| Field | Meaning |
|-------|---------|
| `base` | Starting image / Python+CUDA versions |
| `system_pkgs` | OS-level packages (apt/conda-forge) |
| `pip_phases` | **Ordered** list of pip install batches — each inner list is one `pip install` call |
| `env` | Baked environment variables |
| `run_commands` | Shell escape-hatch commands |
| `shim_files` | Small files to place in the env |
| `weight_dirs` | `{name: {path, source, gated?, auth_hint?}}` |
| `import_names` | Import-level smoke probes |
| `gpu_tests` | GPU-level witness probes |
| `cli_checks` | CLI entry-point checks |

`pip_phases` ordering is load-bearing for version conflict resolution. Install conflicting packages in separate phases — pip leaves already-satisfied requirements alone unless asked to upgrade.

## Weight Caching

| Size | Access pattern | Strategy |
|------|----------------|----------|
| < 500 MB, used by every job | Bake into image layer / conda env / `.sif` |
| > 1 GB, tool has a cache env var | Point env var at persistent scratch / read-only volume mount |
| Large, no internet on compute nodes | Download on login/data node, rsync to scratch |

Populate weights by running the **tool's own loader** with `CACHE_VAR` pointed at writable scratch — hand-curling produces a layout the tool may not recognize. Verify by running the actual inference entrypoint once, not just checking that files exist.

## Validation Ladder

Three levels — the gap between them is where most debugging time goes:

1. **Import works** — `python -c "import chai_lab"` → necessary but catches almost nothing
2. **Kernel-dispatch witness** — tiny seeded forward pass, prints sentinel with output shape, device, non-emptiness check
3. **Agent-follows-skill-doc pass** — spawn sub-agent per env, have it read the skill doc and `compute_details`, submit a job using the documented invocation verbatim, diff result against doc claims. Run after any env rebuild or doc edit.

## Common Failure Patterns

| Symptom | Root cause | Fix |
|---------|-----------|-----|
| `no kernel image is available for execution` | torch/jax compiled for older GPU SM | Record `sm_range` per env, route to compatible hardware |
| `AttributeError: module 'numpy' has no attribute 'int'` | Vendored dep predates numpy 1.24 | sed `np.int/float/bool` → builtin in offending file |
| `ImportError: libfoo.so: cannot open shared object file` | Compiled ops `.so` not on loader path | Add dir to `LD_LIBRARY_PATH` |
| Tool re-downloads despite populated weight dir | Tool checks completion marker file, not weights | Bake marker file into image |
| `OSError: Read-only file system` under `$CACHE_VAR` | Container weight mount is RO, tool writes locks there | Symlink leaf blobs into writable `/tmp/<cache>` |
| `--model_dir X` has no effect | Tool's `--config yaml` overwrites CLI flags | Patch yaml at build time, or document the workaround |

## Persisting Compute Knowledge

After any successful run, write what you learned to the `compute_details` ledger:

```
### env:<name>@<spec_sha>
image: <provider-specific ref>
volumes: [...]
notes: GPU tested, weight cache verified, known flags

### gotchas
- Scratch purges after 30 days on this cluster
- Module avail shows cuda/11.8 but 12.1 is in /opt/cuda-12.1/
```

This lets the next session skip the discovery phase entirely.
