# Project instructions for agents

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
