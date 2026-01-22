---
description: Review all changes since the last merge commit
---

# Catchup

Review all files changed since the last merge commit and provide a concise summary.

## Process

1. **Find the last merge commit**:
   ```bash
   git log --merges -1 --format="%H"
   ```

2. **Get all changed files** (committed and uncommitted since that merge):
   ```bash
   # Committed changes since merge
   git diff --name-only <merge_commit>..HEAD

   # Uncommitted changes (staged and unstaged)
   git diff --name-only HEAD
   git diff --name-only --cached
   ```

3. **Read each changed file** to understand the modifications:
   - For committed changes: use `git diff <merge_commit>..HEAD -- <file>`
   - For uncommitted changes: use `git diff HEAD -- <file>`

4. **Respond with a concise bullet point list** of the changes:
   - Group changes by feature/area when logical
   - Focus on WHAT changed and WHY (if discernible from context)
   - Keep each bullet point to 1-2 lines max
   - Use file:line references for key changes
