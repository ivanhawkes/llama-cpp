# Project instructions for agents

## Performance metrics

When I ask for performance metrics you will summarise the prometheus metrics mentioned in README.md.

## Execution hardware

The LLM that this pi harness talks to runs on the machine documented in `hardware.json`
(fastfetch JSON output). That file is the authoritative specification of the hardware this
agent executes on — read it when you need exact specs.

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
