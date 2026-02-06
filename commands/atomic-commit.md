---
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git push:*), Bash(git diff:*), Bash(git log:*), Bash(git reset HEAD:*), Read
description: Split uncommitted changes into atomic, dependency-ordered conventional commits and push
---

## Context

- Current git status: !`git status`
- Current git diff (staged and unstaged changes): !`git diff HEAD`
- Current branch: !`git branch --show-current`
- Recent commits: !`git log --oneline -10`

## Your task

Split ALL uncommitted changes (staged + unstaged + untracked) into **atomic commits** — small, self-contained, easy-to-review units — then push.

### Rules

1. **Analyze changes**: Read through every changed/added/deleted file in the diff above. Understand what each change does and how files relate to each other (imports, dependencies, type references).

2. **Group into atomic commits**: Each commit should represent ONE logical unit of work. Examples of good atomic splits:
   - A new utility function in its own commit before the feature that uses it
   - Test files committed alongside (or after) the code they test
   - Type definitions before the code that uses them
   - Config/dependency changes separate from feature code
   - Renaming/refactoring separate from behavior changes

3. **Order by dependency**: Commits MUST be ordered so that each commit compiles/type-checks independently without needing content from later commits:
   - If file A imports file B, commit B first
   - If a type definition is used by multiple files, commit the type definition first
   - Shared utilities and helpers before consumers
   - Base/parent components before children

4. **Conventional commit messages**: Each commit message must follow this format exactly:
   ```
   <type>: <description>
   ```
   - **type** is one of: `feat`, `test`, `fix`, `refactor`, `docs`, `perf`, `chore`, `style`, `ci`, `build`
   - **description** is lowercase, imperative mood, max 50 characters total (including type prefix)
   - Examples: `feat: add user avatar component`, `fix: handle null in parser`, `refactor: extract auth middleware`

5. **Execute commits in order**: For each atomic group, in dependency order:
   - `git add` only the specific files for that commit (never `git add .` or `git add -A`)
   - `git commit` with the conventional message
   - Move to the next group

6. **Push**: After all commits are created, run `git push`.

### Important

- If there are no changes to commit, say so and stop.
- Never combine unrelated changes into one commit.
- When in doubt, prefer smaller commits over larger ones.
- Use `git diff HEAD -- <file>` or `Read` to inspect individual files if you need more context about what a change does.
- Reset any existing staging first with `git reset HEAD` to start clean, then stage files per-commit.
