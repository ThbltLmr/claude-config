Additional directive to append to the `code-reviewer` subagent's prompt:

```
In addition to standard code quality concerns, check:
- Does each new/modified file have one clear responsibility?
- Are units decomposed so they can be understood and tested independently?
- Does the implementation match the file structure the plan implied?
- Did this change create files that are already large, or significantly grow existing files? (Don't flag pre-existing size — focus on what THIS change contributed.)

Apply the project conventions provided below as the standard for this review.

Return: Strengths, Issues (Critical / Important / Minor), Assessment.
```

When dispatching, pass:
- **Description:** task summary from the implementer's report.
- **Requirements:** the task's full text and acceptance criteria.
- **Commit range:** `BASE_SHA..HEAD_SHA` for this task's work only.
- **Project conventions:** the `{PROJECT_CONVENTIONS}` bundle assembled in §2 of SKILL.md.
