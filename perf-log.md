# llama-server performance log

Per-session performance summaries for `run-server` (Qwen3.8-27B IQ3_S, RTX 5060 Ti).
One row per server session (start → stop), appended as sessions complete; review monthly.
Sources: `prompt eval time` / `eval time` lines in `/tmp/llama-server.log`,
`curl -s localhost:8080/metrics` (Prometheus), `nvidia-smi`.

**Rollup (last 30 days):** _no completed sessions yet_

| started (UTC) | model | reqs | prompt tok/s | gen tok/s | tokens p/g | insight |
|---|---|---|---|---|---|---|
