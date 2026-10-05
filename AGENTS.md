# Project instructions for agents

## Purpose

This repo is a devenv project (not a NixOS configuration). Its dev shell provides a local
GPU inference server — llama.cpp serving Qwen3.8-27B (IQ3_S GGUF) on 127.0.0.1:8080 — which
serves the pi agent in this repo. `README.md` is the primary documentation; read it before
working here (server flags, GPU facts, model/cache layout, pitfalls).

## Starting and checking the server

- `run-server` starts `llama-server` on 127.0.0.1:8080; extra arguments pass through to
  `llama-server`. Output is teed to `/tmp/llama-server.log` (override with `LLAMA_SERVER_LOG`).
- `smoke-test` starts the server, polls `/health` for up to 300 s, then kills it; exit 0 =
  healthy. Full output: `/tmp/llama-smoke-test.log`.
- First start downloads the model (~12 GiB) into `.hf-cache/`; expect a long pause before
  `/health` responds.
- The running server on :8080 serves this agent; killing it ends the current session.

## Performance metrics

When asked for performance metrics, fetch `http://127.0.0.1:8080/metrics` (the server's
Prometheus endpoint, enabled by `--metrics`) and summarise it.

## Execution hardware

`hardware.json` is a fastfetch snapshot of this machine (gitignored; regenerate with
`fastfetch -c all --format json > hardware.json` when stale). It documents CPU, RAM, disk,
and GPU models, but its GPU entries carry no CUDA index. For live GPU identity and index
mapping, `nvidia-smi` is the source of truth.

## GPU ordering

Do not pin the GPU with `CUDA_VISIBLE_DEVICES` in this project, and do not propose adding a
pin as an "improvement". Ordering is established by `CUDA_DEVICE_ORDER=PCI_BUS_ID` (exported
by `run-server`) so CUDA indices follow PCI bus order, matching `nvidia-smi`. The preflight
guard in `run-server` verifies the mapping: CUDA index 0 must be the RTX 5060 Ti with
≥ 12000 MiB free, otherwise it exits before startup.

## Documentation requirements

While working in this repo, record the following in the **Agent notes** section of
`README.md` (create it if missing). Keep entries short and factual: date, context, what
happened, resolution/workaround. Do not silently work around these issues — the note is part
of the task.

1. **Ambiguities** — unclear or conflicting requirements, multiple plausible
   interpretations, missing information. Record what was ambiguous, how you resolved it,
   and why.
2. **Tool deviations** — commands that behave differently than documented, unexpected
   output, silent failures, version-specific quirks. Record the tool/command, expected vs.
   actual behaviour, and the workaround used.
3. **Shell script issues** — syntax errors, quoting pitfalls, Nix `''` interpolation
   surprises. Record the symptom, root cause, and fix.
