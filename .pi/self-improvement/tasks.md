# Self-improvement tasks (2026-10-03 pass)

Fact sheet: GPU idx0 = RTX 5060 Ti 16GB, idx1 = RTX 4060 8GB (nvidia-smi); CPU x86_64-v3 24c;
RAM ~67GB; disk ~804GB free; hardware.json fresh (Oct 3); server currently UP on :8080
(serves this agent's own inference — cannot be restarted); .hf-cache = 13G.

- [ ] smoke-test: pass `--port "$PORT"` to `run-server` (flake.nix) — why: `SMOKE_TEST_PORT` only changes the polled URL; run-server always binds 8080, so setting SMOKE_TEST_PORT makes the test poll a port nothing listens on — verify: grep rebuilt script for `--port "$PORT"` (full e2e blocked while main server holds ~15GB of the 16GB VRAM)
- [ ] `nix flake check` passes — why: baseline reproducibility; no recent run recorded — verify: `nix flake check > /tmp/flake-check.log 2>&1; tail -30 /tmp/flake-check.log`
- [ ] README: add short "Reproducing a startup failure" section (which logs to read, port/VRAM contention with the live server) — why: agent notes record real debugging pain (501 on /metrics, live server unobservable/unrestartable) — verify: `grep -n "Reproducing" README.md`
- [ ] Preflight free-VRAM check in run-server (nvidia-smi memory.free on index 0, fail early with clear message) — why: ~15GB model on 16GB card; a second instance OOMs obscurely at load time while the main server runs — verify: run `run-server` while main server holds VRAM → expect fast, clear error (no model load)
- [ ] README: clarify perf-log.md rows are appended manually (no automation references it) — why: `grep -rn perf-log flake.nix .pi/skills` finds nothing — verify: `grep -n "manually" README.md`

## Removed

- 2026-10-03: "Add `export CUDA_VISIBLE_DEVICES=0` to run-server" — user instruction: never pin
  the GPU with `CUDA_VISIBLE_DEVICES` in this project (standing rule now in AGENTS.md).
  All references removed from flake.nix and README.md.
