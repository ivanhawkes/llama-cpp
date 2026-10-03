# TODO

## [ ] Install Context7 MCP server as a pi skill (Option A)

Bridge `@upstash/context7-mcp` (v4.1.1, verified working via stdio in this env) into the pi
harness as a project skill with a bundled stdio JSON-RPC script — pi 0.87.1 has no native MCP
support. Full context for a fresh session: `/tmp/handoff-llama-cpp-context7-mcp.md`.

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
