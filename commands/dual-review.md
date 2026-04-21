---
description: Run Claude code-reviewer and Codex review in parallel, present unified P1/P2/P3 report
argument-hint: [--base <ref>] [--scope <auto|working-tree|branch>] [--json]
---

<instructions>

Run a dual code review: dispatch Claude's `code-reviewer` subagent AND the Codex `review` command in parallel, then merge their findings into a single P1/P2/P3 report.

Arguments: `$ARGUMENTS`

## 1. Parse arguments

Accept the same flags as `/codex:review`:

- `--base <ref>` — git ref to diff against (e.g. `main`, `origin/main`, `HEAD~3`).
- `--scope <auto|working-tree|branch>` — default `auto`.
- `--json` — forwarded to Codex only.

Reject `--background` / `--wait` with a usage message — this command is always synchronous (it must have both results in hand to synthesize).

## 2. Resolve the review target

Determine what the reviewers should look at:

- If `--base <ref>` is provided → scope becomes `branch`, base = `<ref>`.
- Else if `--scope branch` → scope = `branch`, base = detected default branch (`git symbolic-ref refs/remotes/origin/HEAD` stripped to a branch name, fallback to `main`).
- Else if `--scope working-tree` → scope = `working-tree`.
- Else (`auto` / unset) → if `git status --porcelain` is non-empty, scope = `working-tree`; else scope = `branch` with the detected default base.

Compute the exact git diff command the Claude reviewer should use:

- `working-tree` → `git diff HEAD` (plus `git status --porcelain` for untracked files).
- `branch` → `git diff <base>...HEAD`.

## 3. Dispatch BOTH reviewers IN PARALLEL

**IMPORTANT — Claude Code serializes `Task` and foreground `Bash`.** If you emit both in one message as foreground calls, the Bash stays queued until the subagent finishes (which defeats the whole point of this command). Work around it by running the Bash in the background: it spawns detached and returns an ID in milliseconds, clearing the tool queue so the subagent starts immediately alongside it.

**In a single assistant message, emit these two tool calls in this order:**

### Tool call 1 — `Bash` with `run_in_background: true` (Codex reviewer)

Put this FIRST so it exits the queue before `Task` takes it over.

- `command`:
  ```
  node "/Users/thibaultlemery/.claude/plugins/marketplaces/openai-codex/plugins/codex/scripts/codex-companion.mjs" review --wait [--base <ref>] [--scope <scope>] [--json]
  ```
  Forward `--base`, `--scope`, `--json` as provided. After the `auto`-resolution in step 2, pass the resolved scope so Codex matches what Claude is reviewing.
- `run_in_background`: `true`
- `timeout`: `600000` (10 minutes — full reviews can be slow)
- `description`: `Codex review (background)`

This returns a `bash_id` immediately. Remember it.

### Tool call 2 — `Task` (Claude reviewer)

- `subagent_type`: `code-reviewer`
- `description`: `Claude code review (<scope>)`
- `prompt`: tell the agent what to review instead of letting it default to uncommitted changes. Include:
  - The resolved scope and base ref.
  - The exact git command to use for the diff (from step 2).
  - An explicit reminder: "Output findings using the P1 / P2 / P3 scheme defined in your agent instructions. List every issue — do not truncate P3."

## 4. Collect the Codex output

After the `Task` call returns with the Claude reviewer's findings, fetch the Codex result. The background Bash has been running in parallel the whole time — it may already be done.

Use the `BashOutput` tool with the `bash_id` from step 3. Two cases:

- **Status `completed`** → the full Codex review output is there; proceed to step 5.
- **Status `running`** → Codex is still going. Claude Code notifies you automatically when a background Bash completes, so **just wait** — do NOT sleep, do NOT poll in a tight loop. When the completion notification arrives, call `BashOutput` once more to read the final output, then proceed to step 5.

If the background Bash failed (non-zero exit, missing output), report the error clearly and still present the Claude reviewer's findings alone, clearly labeled as "Codex review unavailable: <reason>".

## 5. Synthesize the unified report

Once both tool calls return, produce exactly this format. Nothing else. No raw-output dump, no transcripts, no "Claude said X, Codex said Y" paraphrase sections.

```
# Dual Review — base: <ref or "working-tree">  scope: <scope>

## Summary
- Claude reviewer: <N> issues (P1: a, P2: b, P3: c)
- Codex reviewer:  <M> issues (P1: a, P2: b, P3: c)
- Unified total:   <total, after merging duplicates> issues

## P1 — Critical (must fix)
1. [claude] path/to/file.ts:42 — <issue title> — <why it matters> — <fix>
2. [codex]  path/to/file.ts:88 — <issue title> — <why it matters> — <fix>
...

## P2 — Important (should fix)
...

## P3 — Minor (nice to have)
...
```

### Priority assignment

- **Claude findings** already come tagged `P1` / `P2` / `P3` — keep them as-is.
- **Codex findings** — map by severity when structured (`critical`→P1, `high`→P2, `medium`→P3, `low`→P3). If Codex returned unstructured prose, infer priority from the language: crash/security/data-loss/"must fix" → P1; "should"/missing error handling → P2; nits/style/optional → P3.

### Source tags

- `[claude]` if only Claude raised it.
- `[codex]` if only Codex raised it.
- `[claude+codex]` for duplicates (same file, same line range, same underlying issue). Merge into one bullet — the fact that both caught it is signal, not noise.

### NON-NEGOTIABLE RULES

> **LIST EVERY ISSUE.** Every finding from both reviewers must appear in the unified report.
> - Do NOT drop P3 items to keep the output short.
> - Do NOT write "plus N minor issues omitted for brevity".
> - Do NOT collapse multiple similar findings into a single "various nits" bullet.
> - If the reviewers surfaced 47 issues between them, the unified report has 47 bullets (or fewer only when genuine duplicates are merged into `[claude+codex]` entries).
> - Truncating is a bug in this command.

> **NO RAW DUMP.** Do not append the raw Claude output or raw Codex output after the unified report. The unified list IS the output.

## 6. After presenting the report

Stop. Do NOT auto-apply any fixes (this matches the `codex:codex-result-handling` contract and the `/start-code-reviewer` pattern).

Ask the user which issues they want fixed (an `AskUserQuestion` works well if the list is short; for long lists, invite them to point at IDs like "fix P1 #1, #2 and P2 #4"). Only apply fixes the user explicitly selects.

</instructions>
