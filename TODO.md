# TODO

## [x] Install Context7 MCP server as a pi skill (Option A) — superseded 2026-10-03

Original plan: bridge `@upstash/context7-mcp` (v4.1.1, verified working via stdio in this env)
into the pi harness as a project skill with a bundled stdio JSON-RPC script — pi 0.87.1 has no
native MCP support. Full context for a fresh session: `/tmp/handoff-llama-cpp-context7-mcp.md`.

**Superseded:** Upstream now publishes an official pi extension, `@upstash/context7-pi`
(installed project-locally via `pi install -l npm:@upstash/context7-pi`). It registers the same
two tools (`resolve-library-id`, `query-docs`) natively, plus a `context7-docs` skill and a
`/c7-docs <library> <question>` prompt command. The hand-rolled bridge (`.pi/skills/context7/`
SKILL.md + `scripts/call.mjs`) and the `@upstash/context7-mcp` dependency in `.pi/npm` were
retired. Verified end-to-end in a fresh `pi -p` session: resolved `/ggml-org/llama.cpp`,
`query-docs` returned `--ctx-size`. Note: the official tools return API output untruncated
(the old bridge capped at 12000 chars for the 48k window) — keep queries to one narrow topic.

- [x] `cd .pi/npm && npm install @upstash/context7-mcp` (NPM_CONFIG_PREFIX isolates installs to
      `.pi/npm`; its `bin/` is already on PATH)
- [x] Create `.pi/skills/context7/SKILL.md` — frontmatter with `name` + pushy `description`
      (trigger on library/framework/API doc questions); workflow: call `resolve-library-id`
      first, then `query-docs` with one narrow topic per call; keep fetched output small
      (48k context window on the local 27B model)
- [x] Create `.pi/skills/context7/scripts/call.mjs` — spawn the server over stdio, speak MCP
      JSON-RPC (`initialize` → `notifications/initialized` → `tools/call`), print result text;
      handle timeout/error cases
- [x] Test end-to-end: resolve a library (e.g. `llama.cpp`) and fetch one small topic slice;
      confirm output is usable and trimmed
- [x] Validate per harness Phase 6 (frontmatter/trigger checks); record any issues in README
      Agent notes
- [x] Commit & push via `/skill:cp`
