# continue.md — session handoff (2026-10-03)

## Task
Amend the command that runs `llama-server` so its output can be viewed/captured.
Monitor output for performance metrics, keep an internal per-session summary, and
append it to a git-tracked file that tracks overall performance over a month — one
summary per session, terse but insightful, best-suited format.

## User directives (in order)
1. Original task as above.
2. "Don't kill the running server, you are using it for inference. It will kill you too."
   → The live `llama-server` (PID 12237 at session start) is this agent's own inference
   backend (`PI_PROVIDER=llama-cpp`, model matches). NEVER kill/restart it from inside a session.
3. "Take your best guess at the task, write it to the project, and wait for me to advise."
4. "I will restart you after you make the changes; then you can read the llama-server output directly."
5. "Save a summary of my commands this session to continue.md" / "Flush this session to continue.md right now."

## Facts established this session
- `run-server` is a Nix `writeShellScriptBin` script in `flake.nix`; generated script has a
  bash shebang, but keep it POSIX-safe (no brace expansion — Nix `''` interpolates `${...}`).
- Running server: PID 12237, stdout/stderr → `/dev/pts/0` (user terminal) — output NOT readable.
  Started ~09:52 local (≈01:52 UTC). Flags include `-ngl 99 --flash-attn on --spec-type draft-mtp
  --spec-draft-n-max 2 --agent --parallel 1 -c 32000`, model `ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF:IQ3_S`.
- `/metrics` endpoint exists in this build but returns 501 unless started with `--metrics`
  (current server was not). `/health` works: `{"status":"ok"}`.
- Model cached at `~/.cache/huggingface` (22G) — restart won't re-download. (devShell sets
  `HF_HOME=$PWD/.hf-cache`, but that dir doesn't exist; the live server used the default cache.)
- GPU 0 = RTX 5060 Ti 16311 MiB (~10.5G used by server); GPU 1 = RTX 4060 8G.
- `strace` available at `/run/current-system/sw/bin/strace` (fallback: trace writes of PID to
  capture log lines non-invasively — NOT needed after restart).
- Old run-server store path: `/nix/store/i8h0jkinlsrbghxjqin8zmzr967cmb6n-run-server`.

## Changes to make / verify (best guess, per user's "write it to the project")
1. `flake.nix` — replace the `exec ${llamaCppPackage}/bin/llama-server ... "$@"` block in
   `runServer` with (no braces anywhere; `$(` is Nix-safe):

```sh
        # Log the whole session to $LOG (fresh per start) while echoing to the
        # terminal, so output stays viewable and can be monitored after the fact.
        LOG=/tmp/llama-server.log
        [ -n "$LLAMA_SERVER_LOG" ] && LOG=$LLAMA_SERVER_LOG
        echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] run-server: session log -> $LOG"

        ${llamaCppPackage}/bin/llama-server \
          --host 0.0.0.0 -hf ISTA-DASLab/Qwen3.8-27B-GSQ-RCO-GGUF:IQ3_S \
          -ngl 99 \
          -ctk q4_0 \
          -ctv q4_0 \
          -c 32000 \
          --parallel 1 \
          --image-min-tokens 1024 \
          --flash-attn on \
          --agent \
          --spec-type draft-mtp \
          --spec-draft-n-max 2 \
          --temperature 0.1 \
          --top-p 0.95 \
          --min-p 0.05 \
          --repeat-penalty 1.05 \
          --metrics \
          --chat-template-kwargs '{"reasoning_effort":"xhigh"}' "$@" 2>&1 | tee "$LOG"
```

   Notes: `exec` is dropped (invalid in a pipeline); exit status becomes tee's; killing the
   run-server PID does NOT kill llama-server (pipeline children) — kill the process group
   (`setsid` + `kill -- -PGID`) or `pkill -f llama-server`. smoke-test unaffected (polls liveness).
2. `perf-log.md` (new, git-tracked) — Markdown table, one row per session + 30-day rollup line:

```markdown
# llama-server performance log

Per-session performance summaries for `run-server` (Qwen3.8-27B IQ3_S, RTX 5060 Ti).
One row per server session (start → stop), appended as sessions complete; review monthly.
Sources: `prompt eval time` / `eval time` lines in `/tmp/llama-server.log`,
`curl -s localhost:8080/metrics` (Prometheus), `nvidia-smi`.

**Rollup (last 30 days):** _no completed sessions yet_

| started (UTC) | model | reqs | prompt tok/s | gen tok/s | tokens p/g | insight |
|---|---|---|---|---|---|---|
```

3. `README.md` — quick start: note run-server tees to `/tmp/llama-server.log` (fresh per
   session, override `LLAMA_SERVER_LOG`) and serves `/metrics`; repo layout: add `perf-log.md`.
4. `README.md` Agent notes — append entries (AGENTS.md requirement):
   - Ambiguity: "session" undefined → one `run-server` invocation; log truncated per start.
   - Ambiguity: output of the already-running server is unreadable (pts/0) and it cannot be
     restarted (it serves this agent's inference) → tee + `--metrics` for future sessions.
   - Shell issue: `exec cmd | tee` invalid in POSIX sh; pipeline parent/exit-status caveats above.
   - Tool deviation: `/metrics` 501 unless server started with `--metrics`.

## State at flush time
- continue.md written (this file). flake.nix / perf-log.md / README edits: check whether
  already applied (`git status`, `grep -n 'tee' flake.nix`); if not, apply per above.
- Do NOT start a second server (port 8080 taken; live server must stay up).
- After user restarts agent+server: read `/tmp/llama-server.log`, extract timing lines,
  keep internal summary, append one terse row to `perf-log.md` per session; update rollup.
- Then delete continue.md (or keep until task done — user decides).
