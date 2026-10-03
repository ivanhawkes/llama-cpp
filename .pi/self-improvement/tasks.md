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
- [x] README: document the observed MTP split (server holds ~10GB on idx0 + ~5.6GB on idx1) — ✅ verified 2026-10-03: `grep -n "idx1" README.md` hits, committed as `3afae7a`
- [x] README: clarify perf-log.md rows are appended manually (carried from pass 2) — ✅ verified 2026-10-03: `grep -n "manually" README.md` hits
- [ ] flake.nix: take `system` from the flake outputs instead of hardcoding `"x86_64-linux"` — carried to pass 4; removed there (blocked in this environment, see Removed)
- [x] Baseline `nix flake check` and record result in Agent notes — ✅ done in pass 4 (exit 0, "all checks passed!")

## Pass 4 (2026-10-03)

Fact sheet: idx0 = RTX 5060 Ti 16311 MiB (4993 free), idx1 = RTX 4060 8188 MiB (2286 free)
(nvidia-smi) — matches run-server's preflight guard; server live (PID 47910, MTP split across
both cards, serving this agent's own inference → e2e smoke-test stays blocked); CPU x86_64-v3
24c; RAM ~67GB; disk ~790GB free; driver nvidia open 615.71.09; hardware.json fresh (Oct 3);
git clean; README covers layout/pitfalls/repro steps.

- [x] Baseline `nix flake check` and record result in Agent notes — ✅ verified 2026-10-03: exit 0, "all checks passed!" (`/tmp/flake-check.log`); recorded in README Agent notes

## Removed

- 2026-10-03: "Add `export CUDA_VISIBLE_DEVICES=0` to run-server" — user instruction: never pin
  the GPU with `CUDA_VISIBLE_DEVICES` in this project (standing rule now in AGENTS.md).
  All references removed from flake.nix and README.md.
- 2026-10-03: "flake.nix: use `finalSystem` instead of hardcoded `x86_64-linux"` — blocked in
  this environment, not deferred: nix 2.34.8 fails both `nix eval` and `nix flake check`
  with "cannot find flake 'flake:finalSystem' in the flake registries" (tries to add a
  lock-file entry for it); `--system` is a restricted setting for untrusted users, so no
  workaround. Reverted; explicit `system = "x86_64-linux"` stays. See README Agent notes.
