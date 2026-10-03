# Self-improvement tasks (2026-10-03 pass 2)

Fact sheet: GPU idx0 = RTX 5060 Ti 16GB, idx1 = RTX 4060 8GB (nvidia-smi); CPU x86_64-v3 24c;
RAM ~67GB; disk ~790GB free; hardware.json was stale (>7d) → regenerated this pass (uncommitted);
server UP on :8080 holding 10959 MiB on idx0 (4980 MiB free) — serves this agent's own
inference, cannot be restarted.

- [x] Preflight free-VRAM check in run-server (flake.nix) — why: ~13GB model on 16GB card; main
  server currently leaves only 4980 MiB free on idx0, so a second instance OOMs obscurely at
  model-load time — verify: run the rebuilt `run-server` now → expect fast, clear error before
  model load (and `/tmp/llama-server.log` untouched) ✅ verified 2026-10-03: exit 1 with
  "Only 4980 MiB free", log mtime unchanged
- [x] smoke-test: kill llama-server + tee on exit, not just the wrapper PID (flake.nix) — why:
  agent notes record that killing the run-server PID leaves llama-server alive; smoke-test's
  `kill $PID` would orphan a ~13GB server holding VRAM — verify: grep rebuilt script for the
  process-group/pkill kill ✅ verified 2026-10-03 by inspection (cleanup() with `pkill -P $PID`
  then `kill $PID`); e2e of the orphan-kill path still needs a VRAM-free window — do NOT start
  a second instance while the main server runs (it serves this agent's own inference)
- [ ] Commit regenerated hardware.json — why: `find hardware.json -mtime +7` matched before this
  pass's regeneration — verify: `git status --short` clean and `find hardware.json -mtime +7` empty
- [ ] README: clarify perf-log.md rows are appended manually (no automation references it) — why:
  `grep -rn perf-log flake.nix .pi/skills` finds nothing — verify: `grep -n "manually" README.md`

## Removed

- 2026-10-03: "Add `export CUDA_VISIBLE_DEVICES=0` to run-server" — user instruction: never pin
  the GPU with `CUDA_VISIBLE_DEVICES` in this project (standing rule now in AGENTS.md).
  All references removed from flake.nix and README.md.
