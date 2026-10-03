# Self-improvement tasks

## Pass 2 (2026-10-03) — completed

- [x] Preflight free-VRAM check in run-server (flake.nix) — verified: exit 1 with "Only 4980 MiB free"
- [x] smoke-test: kill llama-server + tee on exit, not just the wrapper PID (flake.nix) — verified by inspection; e2e needs a VRAM-free window
- [x] Commit regenerated hardware.json — ✅ committed as `035f75a` (marked done in pass 3; `git status --short` clean, `find hardware.json -mtime +7` empty)
- [ ] README: clarify perf-log.md rows are appended manually (no automation references it) — carried to pass 3

## Pass 3 (2026-10-03)

Fact sheet: idx0 = RTX 5060 Ti 16GB, idx1 = RTX 4060 8GB (nvidia-smi); one llama-server PID
holds 10142 MiB on idx0 + 5578 MiB on idx1 (MTP split live); CPU x86_64-v3 24c; RAM ~67GB;
disk ~790GB free; hardware.json fresh; git clean; server UP on :8080 serving this agent's own
inference (cannot restart, no second instance).

- [x] tasks.md bookkeeping: mark pass-2 "Commit regenerated hardware.json" done — why: `git status --short` clean and commit `035f75a` exists — verify: `grep -n '\[x\] Commit regenerated' .pi/self-improvement/tasks.md`
- [ ] README: document the observed MTP split (server holds ~10GB on idx0 + ~5.6GB on idx1) — why: nvidia-smi compute-apps shows one llama-server PID using both GPUs; flake NOTE says MTP can split across devices but README's GPU-facts section doesn't mention it — verify: `grep -n "idx1" README.md`
- [ ] README: clarify perf-log.md rows are appended manually (carried from pass 2) — why: `grep -rn perf-log flake.nix .pi/skills` finds nothing (no automation) — verify: `grep -n "manually" README.md`
- [ ] flake.nix: take `system` from the flake outputs instead of hardcoding `"x86_64-linux"` — why: hardcoded system limits portability; CPU fact x86_64-v3 means it works here but the flake parameter is standard practice — verify: `nix eval .#devShells.x86_64-linux.default.name --raw 2>&1 | head -5`
- [ ] Baseline `nix flake check` and record result in Agent notes — why: no record of it ever running (absent from agent notes) — verify: `nix flake check > /tmp/flake-check.log 2>&1; tail -30 /tmp/flake-check.log`

## Removed

- 2026-10-03: "Add `export CUDA_VISIBLE_DEVICES=0` to run-server" — user instruction: never pin
  the GPU with `CUDA_VISIBLE_DEVICES` in this project (standing rule now in AGENTS.md).
  All references removed from flake.nix and README.md.
