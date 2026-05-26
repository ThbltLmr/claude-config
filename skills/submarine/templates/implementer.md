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

{PROJECT_CONVENTIONS — CLAUDE.md, style guides, architecture docs, framework conventions. Apply these to the code you write. If any conflict with the task description, flag the conflict in your report rather than guessing.}

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
