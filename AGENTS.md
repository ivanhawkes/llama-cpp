# Project instructions for agents

## Performance metrics

"Performance metrics" (including "your performance metrics") refers to a pair of log files
holding metrics on the LLM that hosts this agent:

- `/tmp/llama-server.log` — full llama-server session log (per-request prompt/eval times,
  TTFT, tokens/s).
- `logs/perf-watch.log` — periodic perf-watch rollups (session totals, MTP acceptance,
  per-request stats, VRAM usage).

These are kept so the user can watch for degradations or improvements in the agent's
performance. When asked about performance metrics, read these files rather than looking
for agent-side instrumentation.

## Execution hardware

The LLM that this pi harness talks to runs on the machine documented in `hardware.json`
(fastfetch JSON output). That file is the authoritative specification of the hardware this
agent executes on — read it when you need exact specs. Summary as of 2026-10-03:

- **OS:** NixOS 26.11 (Zokor), Linux 6.18.54, x86_64
- **CPU:** AMD Ryzen 9 3900X — 12 cores / 24 threads, base 4.1 GHz / max 4.7 GHz
- **GPU:** NVIDIA GeForce RTX 5060 Ti (the inference GPU; CUDA index 0 per the preflight
  guard in `run-server`) plus a second NVIDIA GeForce RTX 4060
- **RAM:** ~67 GB total
- **Disk:** ext4 root on NVMe (~982 GB)

If `hardware.json` disagrees with this summary, trust the file.

## GPU pinning

Do **not** pin the GPU with `CUDA_VISIBLE_DEVICES` in this project (user instruction,
2026-10-03 — it is a mistake here). The preflight guard in `run-server` (CUDA index 0 must
be the RTX 5060 Ti) is the only GPU-ordering contract. Do not propose adding a pin as an
"improvement", and remove any reference that claims one exists.

## Documentation requirements

While working in this repo, you must record the following in `README.md`, under the
**Agent notes** section (create it if missing):

1. **Ambiguities** — any ambiguity encountered whilst performing a task: unclear or
   conflicting requirements, multiple plausible interpretations, missing information.
   Record what was ambiguous, how you resolved it, and why.
2. **Tool deviations** — any deviation from expected tool behaviour: commands that behave
   differently than documented, unexpected output, silent failures, version-specific quirks.
   Record the tool/command, expected vs. actual behaviour, and the workaround used.
3. **Shell script issues** — any issue found when writing or running shell scripts, e.g.
   unexpected syntax errors, quoting pitfalls, Nix `''` string interpolation surprises.
   Record the symptom, root cause, and fix.

Keep entries short and factual: date, context, what happened, resolution/workaround.
Do not silently work around these issues — the note is part of the task.
