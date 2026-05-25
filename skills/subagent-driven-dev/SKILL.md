---
name: subagent-driven-dev
description: Execute any markdown plan (plan-mode output, file path, or inline text) by breaking it into tasks and running each through a fresh implementer subagent followed by spec-compliance and code-quality reviewer subagents. Use when the user has a plan and wants it implemented end-to-end without manually dispatching agents.
---

<instructions>

Execute a plan by (1) breaking it into discrete tasks, (2) dispatching a fresh implementer subagent for each task, (3) reviewing its output through a spec-compliance subagent and a code-quality subagent before moving on. Tasks run **sequentially** — never dispatch the next implementer until the current task is fully reviewed and approved.

Arguments: `$ARGUMENTS`

## 1. Resolve the plan input

Detect input mode in this order:

1. **`$ARGUMENTS` is empty** → use the most recent plan from conversation context. This is typically the assistant message that was just approved via `ExitPlanMode`, or a markdown plan the user pasted earlier in the session. If you can't locate one, ask the user where the plan is — don't guess.
2. **`$ARGUMENTS` resolves to an existing file** → read it with `Read`. Treat its contents as the plan.
3. **`$ARGUMENTS` is non-empty but not a file path** → treat the literal string as the inline plan body.

State which mode was detected in one sentence before continuing (e.g. "Using plan from `docs/plans/foo.md`.").

## 2. Break the plan into tasks

The plan was likely written for a human reader, not as a pre-carved task list. Your first job is to carve it.

Read the plan carefully and extract a **flat ordered list of tasks**. Each task must be:
- **Independently implementable** — a fresh subagent with no session context can complete it given only the task text + the context block you assemble.
- **Bounded** — touches a coherent slice (typically 1–3 files). If a "task" touches 8 files across unrelated layers, split it.
- **Sequenced** — if Task B depends on Task A's output, B comes after A.

For each task, capture:
- **Name** — short imperative phrase.
- **Full description** — verbatim or near-verbatim text from the plan that describes this slice. Do not summarize away requirements; the implementer never sees the original plan.
- **Acceptance criteria** — bullets the implementer can self-check against.
- **Files / surfaces** — which files or modules are in scope, if the plan says so.
- **Context** — anything from earlier in the plan (architecture notes, constraints, conventions) that the implementer needs but isn't in the task text itself.

If the plan is genuinely ambiguous about a decision the implementer will hit (e.g. "where do we store config — env var or config file?"), surface the question to the user **once, now**, before dispatching anything. Don't ship questions to the implementer that you should have answered.

### Shared context bundle

Every subagent starts with **zero** session context. Anything you learned by reading project docs, anything a context-priming or onboarding skill loaded into your context, anything the user pointed you at this session — none of it reaches the subagent unless you put it in the prompt.

Before dispatching anything, assemble a single bundle of project-wide documentation that will travel with every implementer and code-quality reviewer this run. Include:

- The repo's `CLAUDE.md` and any onboarding / priming docs that were loaded into your context.
- Style guides, architecture docs, or convention notes the user pointed you to or that other skills surfaced.
- Framework / library conventions the plan implicitly assumes (e.g. "we use Server Components, not Client Components, unless the file is marked").
- Naming, layering, or testing conventions visible from a quick read of the codebase.

This bundle is the `{PROJECT_CONVENTIONS}` placeholder in every template in §6. Treat it as **required input** — never leave it empty, never tell the subagent to "go read CLAUDE.md itself." If you genuinely have no project conventions to pass, write "None provided — apply general best practices for the language/framework in use."

## 3. Register the task list

Call `TaskCreate` to register every task you carved, in order. This gives both you and the user a live progress view as the loop runs. Mark each task `in_progress` when its implementer is dispatched and `completed` only after both reviews pass.

## 4. Per-task execution loop

For each task in order, run this sub-process. **Do not pause for user check-ins between tasks.** Drive straight through unless an implementer reports `BLOCKED` or `NEEDS_CONTEXT` you cannot resolve, or a reviewer finds something that requires a human decision.

### Model selection (applies to 4a, 4c, 4d)

Pass `model: "..."` **explicitly** on every `Agent` call — don't rely on parent-process inheritance, which silently runs every subagent on the caller's (often Opus) model. That is slow and token-hungry.

Defaults per role:
- **Implementer → `sonnet`.** Capable enough for bounded tasks; much cheaper and faster than Opus.
- **Spec reviewer → `haiku`.** The job is a constrained read-and-compare against an acceptance list. Cheap and fast; if it misses something subtle the code-quality reviewer is the safety net.
- **Code-quality reviewer → `sonnet`.** Needs more nuance than Haiku for judgment calls.

Escalate to `opus` only when:
- A previous dispatch failed for reasoning reasons (see 4b retry path), **or**
- The carving step in §2 flagged this task as high-complexity (cross-cutting refactor, tricky algorithm, dense domain logic, non-obvious concurrency).

If you find yourself reaching for Opus by default, stop — the cost is real and Sonnet handles most carved tasks fine.

### 4a. Dispatch the implementer

Use the `Agent` tool with `subagent_type: general-purpose`, `model: "sonnet"` (see Model selection above), and the **Implementer template** from §6 below. Fill in the placeholders. The subagent must receive the full task text and context block — never tell it to "go read the plan."

### 4b. Handle the implementer's status

Implementers report one of four statuses:

- **DONE** → proceed to 4c (spec review).
- **DONE_WITH_CONCERNS** → read the concerns. If they're about correctness or scope, address them (re-dispatch with guidance) before review. If they're observations ("this file is getting long"), note them and proceed to review.
- **NEEDS_CONTEXT** → provide the missing context and re-dispatch the implementer.
- **BLOCKED** → diagnose:
  1. Context problem → provide more context, re-dispatch.
  2. Reasoning problem → re-dispatch with a more capable model (`model: "opus"` on the `Agent` call).
  3. Task too large → split it in your task list and re-dispatch the first piece.
  4. Plan is wrong → escalate to the user.

  Never re-dispatch the same model with the same prompt and expect a different result.

### 4c. Spec-compliance review

Dispatch a fresh subagent with `subagent_type: general-purpose`, `model: "haiku"`, and the **Spec Reviewer template** from §6. Its job is to read the actual code and verify it matches the task requirements — neither missing pieces nor extra ones. The implementer's self-report is **not** the source of truth.

If the spec reviewer reports issues:
- Re-dispatch the implementer with the reviewer's findings as input. Tell it to fix exactly those gaps.
- Re-run the spec review on the fixed code.
- Loop until the spec reviewer returns ✅.

### 4d. Code-quality review

Once spec compliance is ✅, dispatch the **`code-reviewer`** subagent (`subagent_type: code-reviewer`, `model: "sonnet"`). Provide the task summary, the requirements, and the commit range covering this task's work (`BASE_SHA` = commit before the task started, `HEAD_SHA` = current HEAD). The reviewer returns Strengths / Issues (Critical / Important / Minor) / Assessment.

If the code reviewer finds Critical or Important issues:
- Re-dispatch the implementer to fix them.
- Re-run the code-quality review.
- Loop until approved.

Minor issues are judgment calls — fix them if cheap, otherwise note them on the task and move on.

### 4e. Mark the task complete

Update the task to `completed` via `TaskUpdate`. Move to the next task.

## 5. After all tasks

Once every task is completed, dispatch one final `code-reviewer` subagent over the **entire** implementation (`BASE_SHA` = commit before Task 1, `HEAD_SHA` = current HEAD). This catches cross-task issues that no single per-task review would see — inconsistencies between tasks, integration gaps, drift from the plan's overall intent.

Report a short final summary to the user:
- Tasks completed (count).
- Notable concerns surfaced and how they were resolved.
- Any unresolved minor issues left as follow-ups.

## 6. Subagent prompt templates

Use these verbatim, filling in placeholders. Do not let subagents inherit your session context — every subagent gets exactly the information you give it.

### Implementer template

```
You are implementing Task {N} of a multi-task plan: {TASK_NAME}

## Task Description

{FULL_TASK_TEXT}

## Acceptance Criteria

{ACCEPTANCE_CRITERIA}

## Files / Surfaces in Scope

{FILES_OR_SURFACES}

## Context

{CONTEXT_BLOCK — architectural notes, what previous tasks built, task-specific constraints}

## Project Conventions

{PROJECT_CONVENTIONS — the shared bundle from §2: CLAUDE.md, style guides, architecture docs, framework conventions. Apply these to the code you write. If any conflict with the task description, flag the conflict in your report rather than guessing.}

## Working Directory

{ABSOLUTE_PATH}

## Before You Begin

If anything about the requirements, approach, dependencies, or assumptions is unclear, **ask now** — don't guess. Reply with status NEEDS_CONTEXT and your questions.

## Your Job

1. Implement exactly what the task specifies — nothing more, nothing less.
2. Write or update tests as the task requires (follow TDD if the plan calls for it).
3. Run the tests and verify they pass.
4. Commit your work with a clear message referencing the task name.
5. Self-review (see below).
6. Report back.

## Code Organization

- Follow the file structure the plan implies.
- Each file should have one clear responsibility.
- If a file you're creating grows beyond the plan's intent, stop and report DONE_WITH_CONCERNS — don't split files on your own.
- In existing codebases, follow established patterns. Improve code you're touching, but don't restructure outside your task.

## Escalate When Stuck

It is always OK to stop and say "this is too hard." Bad work is worse than no work. Escalate (BLOCKED or NEEDS_CONTEXT) when:
- The task requires architectural decisions with multiple valid approaches.
- You need to understand code beyond what was provided and can't find clarity.
- The task involves restructuring existing code in ways the plan didn't anticipate.

## Self-Review Before Reporting

- Did I fully implement everything in the spec? Any missed requirements or edge cases?
- Are names clear and accurate?
- Did I avoid overbuilding (YAGNI)?
- Do tests actually verify behavior, not just mock interactions?

Fix issues you find before reporting.

## Report Format

- **Status:** DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
- **Implemented:** what you built (or attempted, if blocked)
- **Tested:** what you ran and the results
- **Files changed:** list
- **Commit SHA:** the commit you created
- **Self-review findings:** any issues found and fixed
- **Concerns / questions:** if any
```

### Spec Reviewer template

```
You are reviewing whether an implementation matches its specification. You are NOT reviewing code quality — only spec compliance.

## What Was Requested

{FULL_TASK_TEXT}

## Acceptance Criteria

{ACCEPTANCE_CRITERIA}

## What the Implementer Claims They Built

{IMPLEMENTER_REPORT}

## Commit Range to Review

{BASE_SHA}..{HEAD_SHA}

## CRITICAL: Do Not Trust the Report

The implementer's report may be incomplete, inaccurate, or optimistic. Verify everything by reading the actual code.

**DO NOT:**
- Take their word for what they implemented.
- Trust their claims about completeness.
- Accept their interpretation of requirements.

**DO:**
- Read the actual diff (`git diff {BASE_SHA}..{HEAD_SHA}`).
- Compare the code to the requirements line by line.
- Check for missing pieces they claimed to implement.
- Look for extra features they didn't mention.

## Your Job

Verify three things by reading the code:

**Missing requirements:** Did they implement everything? Anything skipped or stubbed?

**Extra / unneeded work:** Did they build things that weren't requested? Over-engineer? Add "nice to haves"?

**Misunderstandings:** Did they interpret a requirement differently than intended? Solve the wrong problem?

## Report Format

Reply with EXACTLY one of:

- ✅ **Spec compliant** — and a one-line summary of what you verified.
- ❌ **Issues found:** a bulleted list. For each: file:line, what's wrong, what the spec required.

No code-style commentary. That's the next reviewer's job.
```

### Code-Quality Reviewer dispatch

For code quality, use `subagent_type: code-reviewer` (the dedicated agent). Pass it:

- **Description:** the task summary from the implementer's report.
- **Requirements:** the task's full text and acceptance criteria.
- **Commit range:** `BASE_SHA..HEAD_SHA` for this task's work only.
- **Project conventions:** the `{PROJECT_CONVENTIONS}` bundle from §2. The reviewer must check the change against these conventions, not just generic style. State explicitly: "Apply the project conventions below as the standard for this review."

Add this directive to the prompt:

```
In addition to standard code quality concerns, check:
- Does each new/modified file have one clear responsibility?
- Are units decomposed so they can be understood and tested independently?
- Does the implementation match the file structure the plan implied?
- Did this change create files that are already large, or significantly grow existing files? (Don't flag pre-existing size — focus on what THIS change contributed.)

Return: Strengths, Issues (Critical / Important / Minor), Assessment.
```

## Red flags

- **Never** run multiple implementer subagents in parallel — they conflict on shared state.
- **Never** skip the spec review or run code-quality review before spec compliance is ✅.
- **Never** make a subagent read the plan file. Provide the full task text.
- **Never** start implementation on `main` / `master` without explicit user consent. If the current branch is the default branch, stop and ask.
- **Never** accept "close enough" on spec compliance. Reviewer found issues = task is not done.
- **Never** let the implementer's self-review replace the spec reviewer. Both are required.

</instructions>
