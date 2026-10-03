# llama-server performance log

Per-session performance summaries for `run-server` (Qwen3.8-27B IQ3_S, RTX 5060 Ti).
One row per server session (start → stop), appended as sessions complete; review monthly.
Sources: `prompt eval time` / `eval time` lines in `/tmp/llama-server.log`,
`curl -s localhost:8080/metrics` (Prometheus), `nvidia-smi`.

**Rollup (last 30 days):** 1 completed session (2026-10-02T16:34Z–2026-10-03T05:54Z): 7 reqs, ~720 prompt t/s, ~35.8 gen t/s, tokens p/g 1.7

| started (UTC) | model | reqs | prompt tok/s | gen tok/s | tokens p/g | insight |
|---|---|---|---|---|---|---|
| 2026-10-02T16:34Z | Qwen3.8-27B IQ3_S | 7 | ~720 | ~35.8 | 1.7 | MTP draft acceptance ~0.78 (mean len ~2.5) sustains ~36 t/s gen; prompt eval ~720–796 t/s; gen slows on long outputs (33.8 t/s @ 3.6k tok) |
