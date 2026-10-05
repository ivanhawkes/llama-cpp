# llama-cpp devenv

Dev shell + one-command GPU inference server for llama.cpp: Qwen3.8-27B (IQ3_S) on an RTX 5060 Ti.
This is a devenv project exposing only a dev shell — not a NixOS system configuration.

## Quick start

```sh
devenv shell       # or just cd here with direnv; .envrc runs `use devenv`
run-server         # starts llama-server on 127.0.0.1:8080 (all layers on GPU)
smoke-test         # starts run-server, polls /health up to 300 s, then kills it; exit 0 = healthy
```

- `run-server` tees all server output to `/tmp/llama-server.log` (truncated per start; override with
  `LLAMA_SERVER_LOG`). Prometheus metrics: `http://127.0.0.1:<port>/metrics` (default port 8080).
  Extra arguments pass through to `llama-server` (e.g. `run-server --port 8081`).
- `smoke-test` honors `SMOKE_TEST_PORT` (default 8080) and `SMOKE_TEST_TIMEOUT` (default 300 s); it
  sets both the bind port and the polled URL. Full server output during the test:
  `/tmp/llama-smoke-test.log`.

## Repo layout

| Path | Purpose |
|---|---|
| `devenv.nix` | devShell + `run-server` / `smoke-test` / `playwright-mcp` scripts |
| `.envrc` | direnv hook (`use devenv`) |
| `devenv.yaml` | inputs (nixpkgs = nixos-unstable) + `allow_unfree: true` |
| `AGENTS.md` | project instructions for agents working in this repo |
| `hardware.json` | fastfetch hardware snapshot (gitignored; field definitions below) |
| `.pi/` | pi agent config: skills, `mcp.json`, npm extensions (`settings.json`) |
| `.pi/mcp.json` | pi MCP config: `web` server (Playwright, headless Chromium) |
| `.hf-cache/` | Hugging Face model cache (gitignored) |
| `result` | symlink to the last built devShell (gitignored) |

`mcp.json` does not expand `${VAR}` in args, so `devenv.nix` ships a `playwright-mcp` wrapper that
pins the store paths. Runtime page snapshots land in `.playwright-mcp/` (gitignored).

## GPU facts

Source of truth for GPU identity and index mapping is `nvidia-smi`, not `hardware.json`
(fastfetch's GPU list order is arbitrary):

```sh
nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader
# 0, NVIDIA GeForce RTX 5060 Ti, 16311 MiB   <- run-server's preflight requires index 0 to be this card
# 1, NVIDIA GeForce RTX 4060, 8188 MiB       <- the model does not fit here
```

The 5060 Ti runs at PCIe Gen4 x8 (the card supports Gen5 x16; the AM4 platform caps at Gen4).
If the index mapping ever changes, `run-server` fails fast with a clear message (preflight guard).

## Model & cache

- Model: `ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF:IQ3_S`, downloaded from Hugging Face on first start.
  The file is ~12 GB; the preflight requires ≥ 12000 MiB free on index 0. The `IQ3_S` entry resolves
  to a single `-mtp` GGUF file — that file *is* the model (it contains the MTP heads), not an add-on.
- Cache: `.hf-cache/` in the repo root (gitignored). `HF_HOME` is set to `$PWD/.hf-cache` in
  `enterShell`; a devenv-level `env` value would stay literal because Nix does not expand `$PWD`.

## hardware.json field definitions

Generate with `fastfetch -c all --format json > hardware.json` (the default preset omits `Disk`).
Do not hand-edit; regenerate when stale (`find hardware.json -mtime +7` prints the path if it is
older than 7 days). Fields this repo's decisions rely on:

- `GPU[].name`, `GPU[].driver` — GPU model and driver (informational only; index mapping comes from nvidia-smi)
- `CPU.march`, `CPU.cores` — microarchitecture and core counts
- `Memory.total` — total RAM in bytes. No DIMM count/speed: fastfetch's PhysicalMemory module fails without root SMBIOS access.
- `Disk[].mountpoint`, `Disk[].bytes` — mount points and sizes in bytes

## Known pitfalls

- Picking the wrong GPU index loads the model onto the 8 GB card → OOM/crash. The preflight guard in
  `run-server` catches this before startup.
- First `run-server` start downloads the model; expect a long pause before `/health` responds
  (smoke-test timeout is 300 s by default).
- In `devenv.nix`, `${...}` inside `''` strings is interpolated by Nix. Escape as `\${...}` where a
  literal shell variable is intended.
- Manual `npm install -g <pkg>` in the dev shell fails with EACCES (the nixpkgs nodejs global prefix
  is a read-only store path). Use pi's package manager (`pi install`) or set `NPM_CONFIG_PREFIX`.

## Reproducing a startup failure

If `smoke-test` (or a manual `run-server`) never reaches `/health`:

1. Read `/tmp/llama-smoke-test.log` — it contains the full `run-server` output, including the
   preflight GPU check and the model-load error.
2. Check contention before blaming the devenv config:
   - **Port** — `curl -s localhost:8080/health`: if something already answers, a second server cannot
     bind 8080 (use `SMOKE_TEST_PORT=<other>` for smoke-test; it sets both the bind port and the
     polled URL).
   - **VRAM** — `nvidia-smi --query-gpu=index,memory.used,memory.free --format=csv,noheader`: index 0
     must be mostly free; a running server holds it and a second load will OOM. If the incumbent
     server is the one serving your session, killing it ends that session — run these checks from
     another terminal.
3. Anything failing *after* the preflight line is a model-load/VRAM problem, not an index-mapping
   problem (the guard already ruled the latter out).

## Agent notes

Per `AGENTS.md`, agents working on this repo must document here: ambiguities encountered whilst
performing tasks, deviations from expected tool behaviour, and issues found when writing shell
scripts. Entries are short and factual: date, context, what happened, resolution/workaround.

<!-- agent notes appended below -->
