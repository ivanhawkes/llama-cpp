# llama-cpp devenv

Dev shell (a devenv project — not a NixOS system configuration) providing a one-command
local GPU inference server: llama.cpp 0.5.0 (build 11146) serving Qwen3.8-27B (IQ3_S GGUF),
all layers on GPU, split 2:1 across an RTX 5060 Ti and an RTX 4060. This server is the one
serving the pi agent in this repo.

## Quick start

```sh
devenv shell       # or just cd here; .envrc runs `use devenv` under direnv
run-server         # starts llama-server on 127.0.0.1:8080
smoke-test         # starts run-server, polls /health up to 300 s, then kills it; exit 0 = healthy
```

- `run-server` tees all server output to `/tmp/llama-server.log` (truncated per start; override
  with `LLAMA_SERVER_LOG`). Extra arguments pass through to `llama-server` (e.g. `run-server --port 8081`).
- Prometheus metrics: `http://127.0.0.1:<port>/metrics` (default port 8080).
- `smoke-test` honors `SMOKE_TEST_PORT` (default 8080) and `SMOKE_TEST_TIMEOUT` (default 300 s); it
  sets both the bind port and the polled URL. Full server output during the test:
  `/tmp/llama-smoke-test.log`.

## Server configuration

`run-server` exports `CUDA_DEVICE_ORDER=PCI_BUS_ID` so CUDA device indices follow PCI bus order
(matching `nvidia-smi`'s default ordering), then runs `llama-server` with:

| Flag | Effect |
|---|---|
| `-hf ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF:IQ3_S` | model; auto-downloaded to `.hf-cache/` on first start |
| `-ngl 99` | all layers on GPU (no CPU offload) |
| `-ts 2,1 -sm tensor` | tensor split: 2/3 of the layers on CUDA index 0 (5060 Ti), 1/3 on index 1 (4060) |
| `-c 90000` | context size |
| `-ctk q4_0 -ctv q4_0` | KV cache quantization |
| `--flash-attn on` | flash attention |
| `--spec-type draft-mtp --spec-draft-n-max 2` | MTP speculative decoding using the model's built-in MTP heads; up to 2 draft tokens per step |
| `--temperature 0.1 --top-p 0.95 --min-p 0.05 --repeat-penalty 1.05` | sampling parameters |
| `--agent` | enables llama.cpp's built-in agent tools (read_file, grep_search, …) and a CORS proxy; for security this limits `--cors-origins` to localhost by default |
| `--metrics` | Prometheus endpoint at `/metrics` |
| `--image-min-tokens 1024` | minimum token budget per image (the model is multimodal; see Model & cache) |
| `--chat-template-kwargs '{"reasoning_effort":"xhigh"}'` | reasoning effort for the chat template |

## GPU facts

`nvidia-smi` is the source of truth for live GPU identity and index mapping. fastfetch's GPU
entries carry no CUDA index (`index: null`), and on this machine its list order does not match
nvidia-smi's (4060 first, 5060 Ti second).

```sh
nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader
# 0, NVIDIA GeForce RTX 5060 Ti, 16311 MiB
# 1, NVIDIA GeForce RTX 4060, 8188 MiB
```

Preflight (in `run-server`, before startup): CUDA index 0 must be the RTX 5060 Ti and have
≥ 12000 MiB free, otherwise it exits with a message. If the index mapping ever changes, this
guard fails fast — with the mapping reversed, the 2/3 tensor-split share would land on the
8 GB card and OOM.

PCIe: both cards run at Gen4 x8. The 5060 Ti supports Gen5 x16, but the AM4 (X570) platform
caps at Gen4.

## Model & cache

- Model: `ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF`, tag `IQ3_S` → `Qwen3.8-27B-GSQ-RCO-IQ3_S-mtp.gguf`
  (~12 GiB). The `-mtp` file *is* the model (it contains the MTP heads used by
  `--spec-type draft-mtp`), not an add-on.
- The same HF repo also contains a vision projector (`mmproj-Qwen3.8-27B-BF16.gguf`, ~890 MB);
  the server passes `--image-min-tokens 1024` for image inputs.
- Cache: `.hf-cache/` in the repo root (gitignored). `HF_HOME` is set to `$PWD/.hf-cache` in
  `enterShell`; a devenv-level `env` value would stay literal because Nix does not expand `$PWD`.

## Repo layout

| Path | Purpose |
|---|---|
| `devenv.nix` | devShell packages/env + `run-server`, `smoke-test`, `playwright-mcp` scripts |
| `.envrc` | direnv hook (`use devenv`) |
| `devenv.yaml` | inputs (nixpkgs = nixos-unstable) + `allow_unfree: true` |
| `AGENTS.md` | project instructions for agents working in this repo |
| `TODO.md` | task list |
| `hardware.json` | fastfetch hardware snapshot (gitignored; field definitions below) |
| `skills-lock.json` | pi skill lockfile; pins the `.agents/skills/` sources (mattpocock/skills) |
| `.agents/skills/` | canonical project skills: handoff, implement, implement-spec, to-spec, to-tickets |
| `.pi/` | pi agent config: `settings.json` (npm extensions), `mcp.json` (web server), `skills/` (symlinks into `.agents/skills/` + local `self-improvement`), `npm/` (installed extensions) |
| `.hf-cache/` | Hugging Face model cache (gitignored) |
| `result` | symlink to the last built devShell (gitignored) |

Dev shell contents: Node.js 24, Python 3, Go, git (+ LFS), curl, gh, fastfetch,
`pi-coding-agent`, `nvidia_x11.open` (driver), wl-clipboard. `env` sets `WAYLAND_DISPLAY`/`DISPLAY`
so pi's TUI can use the Wayland clipboard.

`mcp.json` does not expand `${VAR}` in args, so `devenv.nix` ships a `playwright-mcp` wrapper that
pins the store paths. Runtime page snapshots land in `.playwright-mcp/` (gitignored).

## hardware.json field definitions

Generate with `fastfetch -c all --format json > hardware.json` (the default preset omits `Disk`).
Do not hand-edit; regenerate when stale (`find hardware.json -mtime +7` prints the path if it is
older than 7 days). Fields this repo's decisions rely on:

- `GPU[].name`, `GPU[].driver` — GPU model and driver (informational only; no index field, live mapping from nvidia-smi)
- `CPU.march`, `CPU.cores` — microarchitecture level (`x86_64-v3`) and physical/logical core counts
- `Memory.total` — total RAM in bytes (~62.7 GiB). No DIMM count/speed: fastfetch's PhysicalMemory module returns null without root SMBIOS access.
- `Disk[].mountpoint`, `Disk[].bytes` — mount points and sizes in bytes

## Known pitfalls

- Picking the wrong GPU index puts most of the model on the 8 GB card → OOM/crash. The preflight
  guard in `run-server` catches this before startup.
- First `run-server` start downloads the model (~12 GiB); expect a long pause before `/health`
  responds (smoke-test timeout is 300 s by default).
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

- 2026-10-05 — README rewrite: the instruction "remove logs of previous changes" was ambiguous
  because the current README contains no change log; verified via git history (commit 8bc1e17)
  that stale notes were already dropped, so nothing to remove.
- 2026-10-05 — `du -h` on the symlinked GGUF files in `.hf-cache/` reported 4K (the size of the
  symlink itself); used `du -Lh` to get the real blob sizes (~12 GiB model, ~890 MB mmproj).

<!-- agent notes appended below -->
