---
name: context7
description: "Fetch current documentation for any library, framework, SDK, API, CLI tool, or cloud service via Context7 (MCP over stdio). Use whenever the user asks how to use a third-party package/library/framework — API syntax, options, configuration, version migration, setup instructions, examples, or library-specific debugging — even well-known ones (React, Next.js, Prisma, Express, Tailwind, Django, Spring Boot) and even when you think you already know the answer: training data may not reflect recent changes. Prefer this over web search for library docs. Do NOT use for refactoring, writing scripts from scratch, debugging business logic, code review, general programming concepts, or questions about this repo's own code."
---

# Context7 — current library docs via MCP

pi has no native MCP support; this skill bridges the `@upstash/context7-mcp` server (installed in
`.pi/npm`) with a bundled stdio JSON-RPC client. Use it to ground answers in *current* upstream
documentation instead of training data.

## Workflow

1. **Resolve the library ID first** — never guess `/org/project` IDs:

   ```sh
   node scripts/call.mjs resolve-library-id '{"query":"<what you need>","libraryName":"<package name>"}'
   ```

   The response lists candidate libraries with their Context7 IDs, descriptions, and snippet
   counts. Pick the best match (exact package name first; check the description for the right
   project — e.g. `llama.cpp` → `/ggml-org/llama.cpp`, not a binding like `/abetlen/llama-cpp-python`).

2. **Query one narrow topic per call:**

   ```sh
   node scripts/call.mjs query-docs '{"libraryId":"/org/project","query":"<one narrow topic>"}'
   ```

   Multiple concepts → multiple calls, each with a single focused question (e.g. "how to set
   the context size flag in llama-server", not "everything about llama-server").

## Keeping output small

The local model has a 48k context window, so fetched docs must stay small:

- Keep each `query` narrow — the server returns a doc slice sized to the query.
- Output is truncated at 12000 chars by default; raise with `--max-chars N` only when needed.
- If a response is truncated or too broad, re-query with a narrower topic instead of raising
  the limit.

## Error handling

Exit codes: `0` ok · `1` tool/JSON-RPC error · `2` timeout (default 120s, override with
`CONTEXT7_TIMEOUT_MS`) · `3` spawn/protocol failure. On a non-zero exit, read the stderr message;
retry once with a narrower query or corrected library ID before giving up. `--verbose` passes
the server's stderr through for debugging.

## When not to use

Per the server's own instructions: do not use for refactoring, writing scripts from scratch,
debugging business logic, code review, or general programming concepts — and never for this
repo's own code (read the source instead).
