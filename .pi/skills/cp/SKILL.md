---
name: cp
description: Commit and push changes with a safety gate. Use when asked to "commit and push", "/cp", or to publish the current work. Inspects staged and filesystem changes, warns about anything unexpected, halts for explicit permission, and aborts entirely on a negative reply.
---

## Purpose

Commit and push this repository's working tree — but only after a safety gate confirms what is
staged and changed on disk, and only after the user explicitly grants permission for *this*
commit. A negative or ambiguous reply aborts everything: no commit, no push, no staging changes.

## Phase 1 — Inventory (read-only)

1. `git status --porcelain=v1 -b | head -100`
2. `git diff --cached --stat | tail -30` (staged) and `git diff --stat | tail -30` (unstaged).
3. Establish the **expected change set**: files you created or modified during this session
   (your own edit/write/bash actions), plus anything the user explicitly asked to include.
   If the session made no changes, the user's request defines the expectation — but still
   enumerate everything git reports.

## Phase 2 — Safety gate

Compare the inventory against the expected change set:

- **Staged changes** (`git diff --cached`): every staged file must be in the expected set.
- **Unstaged modifications**: same rule.
- **Untracked files**: any untracked file not created this session is unexpected
  (git-ignored files are fine — `git status` does not list them by default).

Outcomes:

- **Nothing to commit** → report "nothing to commit" and stop. Do not push.
- **Everything expected** → no warning needed; go straight to Phase 3.
- **Anything unexpected** →
  1. **Halt.** Do not stage, commit, or push anything yet.
  2. **Warn** with a precise list: each file, its status (staged / unstaged / untracked), and
     why it is unexpected (e.g. "not modified this session").
  3. Fold the warning into the Phase 3 question: ask whether to proceed **including** these
     changes. Wait for an explicit reply before doing anything else.

## Phase 3 — Permission gate (always, exactly one question)

Ask and then stop, waiting for a reply:

> Ready to commit N file(s) on `<branch>` and push to `<remote>/<branch>`[; this includes the
> unexpected changes listed above]. Proceed? (yes/no)

- **Explicit yes** ("yes", "ok", "proceed", "go ahead", …) → Phase 4.
- **Negative or ambiguous reply** ("no", "abort", "cancel", "wait", a counter-question, silence,
  or anything not clearly affirmative) → **abort**: no commit, no push, and do not alter the
  staging area. Report what remains in the working tree and stop.
- Never infer permission from earlier messages. Only the reply to this specific question counts.

## Phase 4 — Commit and push (only after an explicit yes)

1. Stage exactly the agreed files: `git add <path> …`. Never use blanket `git add -A` while any
   unexpected file exists; if everything is expected, `git add -A` is acceptable.
2. Write a commit message describing the change (imperative subject ≤ 72 chars; body if needed).
3. `git commit -m "…"`.
4. `git push` — use `git push -u origin <branch>` if the branch has no upstream yet.
5. Report: short commit hash, branch, remote, and push result.

## Hard rules

- Never force-push (`--force`, `+ref`). If the push is rejected as non-fast-forward, report it
  and stop — do not rebase, merge, or retry without a new explicit instruction.
- Never `git commit --amend`, `git reset`, or `git clean` as part of this skill.
- If any command fails, stop and report the error; do not retry with different flags.
