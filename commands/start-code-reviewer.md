---
description: Run code review and validate fixes with user
---

<instructions>
1. Use the Task tool with subagent_type="code-reviewer" to review uncommitted changes.

2. If no issues found, report that code passed review and stop.

3. If issues found:
   - For each issue, propose a concrete fix based on the "Should be" guidance
   - If multiple valid approaches exist with different tradeoffs, list them
   - Present critical issues first, then minor issues
   - Use AskUserQuestion to let the user select which issues to fix and which approach to use

4. Apply only the user-approved fixes.
</instructions>
