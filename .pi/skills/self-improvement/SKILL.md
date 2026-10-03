---
name: self-improvement
description: Review this machine and flake, then propose concrete, verified improvements. Use when asked to "improve the environment/setup", "self-improve", "what can be improved here", or to review this repo's NixOS config, dev shell, or llama.cpp inference setup.
---

## Context budget rules (apply to every step)

This skill must never overflow the context window. Enforce:

- Never read `hardware.json` in full — extract only decision fields with the one-liner below.
- Bound every command's output: pipe through `| head -50` / `| tail -30`, or redirect to `/tmp/<name>.log` and read only the part you need.
- Never run expensive nix commands (`nix flake check`, builds) during the scan phase — defer them to individual tasks.
- One task at a time. Each task must be completable in one short pass: one command, one small edit, one verification.

## Phase 1 — Lightweight scan (bounded reads only)

1. **Fresh hardware facts.** `find hardware.json -mtime +7` → if stale or missing, regenerate: `fastfetch --format json > hardware.json` (commit after).
   Then extract only what decisions need (~5 lines of output):

   ```bash
   python3 -c "
   import json
   d = {m['type']: m.get('result') for m in json.load(open('hardware.json')) if 'result' in m}
   g = d.get('GPU') or []
   if isinstance(g, dict): g = [g]
   print('GPU:', [(x.get('name'), x.get('driver')) for x in g])
   c = d.get('CPU', {})
   print('CPU:', c.get('march'), c.get('cores'))
   print('Mem:', d.get('Memory', {}).get('total'))
   print('Disk:', [(x.get('mountpoint'), x.get('bytes')) for x in d.get('Disk') or []])
   "
   ```

   **GPU ordering/indexing:** fastfetch's GPU list order is arbitrary — never use `hardware.json` to decide CUDA indices. For any GPU order or index-mapping decision, `nvidia-smi --query-gpu=index,name,memory.total --format=csv,noheader` is the single source of truth. Never propose `CUDA_VISIBLE_DEVICES` pinning in this repo (standing rule — see AGENTS.md).

2. **Read `flake.nix`** (small file — fine to read in full). This repo is a devShell + `run-server` flake for llama.cpp inference, *not* a NixOS system configuration. Only suggest `nixos-rebuild`/`nixos-test`-style changes if the flake actually exposes `nixosConfigurations`.

That's it for the scan. No nix commands yet.

## Phase 2 — Break results into small tasks

From the fact sheet + flake, derive at most ~8 candidate improvements (see areas below). Each must be:

- one file or one command in scope,
- justified by a specific fact (a hardware field or a check result),
- verifiable with one bounded command.

Write them to `.pi/self-improvement/tasks.md` as a checklist, highest priority first:

```markdown
- [ ] <what> — why: <fact> — verify: `<bounded command>`
```

Reply with only the fact sheet (a few lines) + the task list. Then continue into Phase 3.

## Phase 3 — Execute tasks sequentially

For each pending task, top to bottom:

1. Run its verification command with bounded output (e.g. `nix flake check > /tmp/flake-check.log 2>&1; tail -30 /tmp/flake-check.log`).
2. Make the change (one small edit).
3. Re-run the verification; confirm it passes.
4. Mark `- [x]` in `tasks.md`; commit if the change is repo-tracked.
5. Move to the next task.

Rules:

- Never batch multiple tasks in one pass.
- If a command's output exceeds ~30 lines, save it to a file and read only the relevant part.
- Stop after 3 tasks or when the user says so; remaining tasks stay in `tasks.md` for the next session.

## Improvement areas (for deriving tasks)

1. **Project (flake / dev environment)** — VRAM vs model size (no `CUDA_VISIBLE_DEVICES` pinning — see AGENTS.md), HF cache location (`HF_HOME`), driver libs on `LD_LIBRARY_PATH`, flake structure, reproducibility, `nix flake check`.
2. **LLM ability to write code** — clearer module boundaries, typed/validated Nix expressions, consistent naming conventions, examples that make generated code easier to verify.
3. **LLM ability to debug** — better error messages, reproducible failure steps (e.g. how to reproduce a `run-server` startup failure), documented known pitfalls.
4. **LLM ability to test** — smoke tests for the actual entry points (e.g. start `llama-server`, curl `/health`), unit tests for Nix modules, a documented way to run them.
5. **LLM ability to document code, documentation, and data definitions** — per-module doc comments, a README explaining repo layout, field definitions for data files like `hardware.json`.

## Task quality bar

Each task in `tasks.md` has:

- **What** — the change, with file path (and line if relevant)
- **Why** — the fact justifying it (cite a hardware field or a check result)
- **How to verify** — one bounded command that proves it works

Keep it concrete and short. No generic NixOS advice that doesn't apply to this repo.

## Guardrails

- Never propose or add `CUDA_VISIBLE_DEVICES` pinning in this repo (standing rule — see
  AGENTS.md). The preflight guard in `run-server` (index 0 must be the RTX 5060 Ti) is the
  only GPU-ordering contract; treat any reference claiming a pin exists as a bug to remove.
- Don't hand-edit `hardware.json`; regenerate it with fastfetch instead.
- Prefer user-level changes in the flake/devShell over system-level (root) changes.
- Verify a nixpkgs package exists before suggesting it: `nix eval nixpkgs#<attr> --raw 2>&1 | head -5` (flake syntax; note some packages live under sub-sets, e.g. `nixpkgs#linuxPackages.nvidia_x11.open`).
