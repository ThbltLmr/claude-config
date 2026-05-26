---
name: submarine
description: Execute any markdown plan (plan-mode output, file path, or inline text) by breaking it into tasks and running each through a fresh implementer subagent followed by spec-compliance and code-quality reviewer subagents. Use when the user has a plan and wants it implemented end-to-end without manually dispatching agents.
---

<instructions>

Execute a plan by (1) breaking it into discrete tasks, (2) dispatching a fresh implementer subagent for each task, (3) reviewing its output through a spec-compliance subagent and a code-quality subagent. Tasks within a wave run in parallel; waves are strictly sequential.

Arguments: `$ARGUMENTS`

## 1. Resolve the plan input

In order:
1. **`$ARGUMENTS` empty** → use the most recent plan from conversation context (typically a just-approved `ExitPlanMode` message or a pasted plan). If you can't locate one, ask the user — don't guess.
2. **`$ARGUMENTS` is an existing file** → `Read` it. Its contents are the plan.
3. **`$ARGUMENTS` is non-empty but not a file** → treat the literal string as the plan body.

State the detected mode in one sentence before continuing.

**Never start implementation on `main`/`master` without explicit consent.** If the current branch is the default branch, stop and ask.

## 2. Carve the plan into tasks

The plan was written for a human, not as a pre-carved task list. Extract a **flat ordered list of tasks**. Each must be:
- **Independently implementable** by a fresh subagent given only the task text + the context block you assemble.
- **Bounded** — typically 1–3 files. If a task touches 8 files across unrelated layers, split it.
- **Sequenced** — if B depends on A's output, B comes after A.

For each task, capture: name, full description (verbatim from the plan — never summarize away requirements), acceptance criteria, files/surfaces, and any earlier-plan context the implementer needs.

If the plan is genuinely ambiguous about a decision the implementer will hit, surface it to the user **once, now**, before dispatching anything.

### Shared context bundle (required)

Every subagent starts with **zero** session context. Assemble one bundle that travels with every implementer and code-quality reviewer:
- The repo's `CLAUDE.md` and any onboarding / priming docs loaded in your context.
- Style guides, architecture docs, convention notes the user pointed you to.
- Framework / library conventions the plan implicitly assumes.
- Naming, layering, testing conventions visible from a quick read.

This is the `{PROJECT_CONVENTIONS}` placeholder in the templates. **Never leave it empty** and **never tell the subagent to "go read CLAUDE.md itself."** If there genuinely are no conventions, write "None provided — apply general best practices for the language/framework in use."

### Dependency analysis & waves

A fully sequential loop is safe but slow. Run implementers **in parallel** wherever the task list allows; be conservative — clobbered files and contract mismatches are real costs.

Two tasks must be **sequential** if any of:
1. **File overlap** — they edit any of the same files.
2. **Contract dependency** — B consumes an interface/schema/type/route A defines.
3. **Implicit ordering** — migrations, scaffolding, env setup that must precede the rest.

Otherwise they can run in parallel. Group into **waves**: Wave N+1 starts only after every task in Wave N is fully reviewed and merged.

Typical fullstack shape: Wave 1 = define shared contract (1 task); Wave 2 = backend handler + frontend client + migration in parallel; Wave 3 = tests, docs, telemetry in parallel.

If the plan resists decomposition, fall back to one task per wave (pure sequential — always correct).

## 3. Register the task list

Call `TaskCreate` for every task, ordered by wave then intra-wave position. Prefix titles with the wave number (`[W1]`, `[W2]`, …) so the user sees what runs in parallel. Mark `in_progress` when its implementer dispatches; `completed` only after both reviews pass.

## 4. Per-wave execution loop

For each wave in order: dispatch all implementers in parallel; the wave is done only when **every** task has passed both reviews. **Don't pause for user check-ins between waves or tasks.** Drive through unless a subagent reports `BLOCKED`/`NEEDS_CONTEXT` you can't resolve, or a reviewer surfaces a human-decision issue.

### Model selection (applies to 4a, 4c, 4d)

Pass `model` **explicitly** on every `Agent` call — never rely on parent inheritance (silently runs everything on Opus).

| Role | Default | Why |
|------|---------|-----|
| Implementer | `sonnet` | Capable for bounded tasks; cheaper/faster than Opus. |
| Spec reviewer | `haiku` | Read-and-compare against a checklist; code-quality reviewer is the safety net. |
| Code-quality reviewer | `sonnet` | Needs nuance for judgment calls. |

Escalate to `opus` only when a previous dispatch failed for reasoning reasons, or the carving step flagged the task as high-complexity (cross-cutting refactor, tricky algorithm, dense domain logic, non-obvious concurrency).

### 4a. Dispatch the wave's implementers

For every task in the wave, one `Agent` call with `subagent_type: general-purpose`, `model: "sonnet"`, prompt built from [`templates/implementer.md`](templates/implementer.md) (substitute placeholders). Each subagent gets its own full task text, context block, and project conventions — **never** tell it to read the plan file.

**Send all of the wave's `Agent` calls in a single assistant message** so they execute concurrently.

**Worktree isolation for multi-task waves.** When a wave has >1 task, set `isolation: "worktree"` on each `Agent` call — concurrent writes can't clobber each other even if dependency analysis missed a subtle overlap. The tool returns the worktree path and branch for any implementer that made changes. Single-task waves skip worktrees.

### 4b. Handle each implementer's status

Implementers report one of four:
- **DONE** → 4c (spec review).
- **DONE_WITH_CONCERNS** → if correctness/scope, address before review; if observations ("file is getting long"), note and proceed.
- **NEEDS_CONTEXT** → provide missing context, re-dispatch.
- **BLOCKED** → diagnose: (1) context problem → more context, re-dispatch; (2) reasoning problem → re-dispatch with `model: "opus"`; (3) task too large → split, re-dispatch first piece; (4) plan is wrong → escalate to user.

Never re-dispatch the same model with the same prompt expecting a different result.

### 4c. Spec-compliance review

For each implementer that returned DONE, dispatch a fresh subagent (`general-purpose`, `model: "haiku"`) using [`templates/spec-reviewer.md`](templates/spec-reviewer.md). Reviews are read-only — **dispatch all of a wave's spec reviewers in a single message**.

The reviewer reads the actual code (`git diff BASE..HEAD` on the task's branch) and verifies the spec. The implementer's self-report is **not** the source of truth.

If issues: re-dispatch the implementer with the findings as input, then re-run the spec review. Loop until ✅. Never accept "close enough."

### 4d. Code-quality review

Once spec compliance is ✅, dispatch `subagent_type: code-reviewer`, `model: "sonnet"`. For multi-task waves, dispatch all code reviewers in a single message. Pass the task summary, requirements, project conventions bundle, and the commit range (`BASE_SHA` = commit before the task started, `HEAD_SHA` = task's final commit). Use the directive in [`templates/code-reviewer-directive.md`](templates/code-reviewer-directive.md).

Critical/Important issues → re-dispatch implementer, re-review. Minor → fix if cheap, otherwise note and move on.

### 4e. Mark the task complete

`TaskUpdate` → `completed` as soon as both reviews pass for it. Don't wait for the whole wave.

### 4f. Close out the wave

Once every task in the wave is `completed`:

1. If you used worktrees, integrate each branch via **rebase + fast-forward** — never `git merge` (keep linear history). From the working branch, for each task branch:
   ```
   git rebase <working-branch> <task-branch>
   git checkout <working-branch>
   git merge --ff-only <task-branch>
   ```
2. If a rebase conflicts, your dependency analysis missed a file overlap. `git rebase --abort`, redo the affected task sequentially against the new HEAD, continue.
3. Delete merged branches and remove worktrees (`git worktree remove …`, `git branch -d …`).
4. Verify tests still pass on the working branch.
5. Move to the next wave.

## 5. After all tasks

Dispatch one final `code-reviewer` subagent over the **entire** implementation (`BASE_SHA` = commit before Task 1, `HEAD_SHA` = current HEAD). Catches cross-task drift and integration gaps.

Report a short final summary: tasks completed (count), concerns surfaced and how resolved, unresolved minor issues as follow-ups.

## Templates

- [`templates/implementer.md`](templates/implementer.md) — implementer prompt
- [`templates/spec-reviewer.md`](templates/spec-reviewer.md) — spec-compliance reviewer prompt
- [`templates/code-reviewer-directive.md`](templates/code-reviewer-directive.md) — directive appended to the `code-reviewer` agent dispatch

</instructions>
