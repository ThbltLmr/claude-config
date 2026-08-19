---
name: atomic-commit
description: Split all staged, unstaged, and untracked changes into small dependency-ordered conventional commits, then push them. Use when the user asks to commit everything, create atomic commits, organize a dirty working tree, or run an atomic commit workflow.
allowed-tools: Bash(git add:*), Bash(git status:*), Bash(git commit:*), Bash(git push:*), Bash(git diff:*), Bash(git log:*), Bash(git rev-parse:*), Bash(git reset HEAD:*), Read
---

# Atomic commit

## Inspect the working tree

1. Run `git status --short --branch`, `git diff HEAD`, and `git log --oneline -10`.
2. Read every changed or untracked file needed to understand the changes.
3. If there are no changes, report that and stop.
4. Preserve unrelated user changes; do not discard or rewrite them.

## Plan the commits

Group changes into the smallest independently useful commits. Keep tests with the
behavior they verify. Put shared types and utilities before their consumers, and
separate refactors from behavior changes when practical.

Use conventional messages in the form `<type>: <description>`, where `type` is
one of `feat`, `fix`, `test`, `refactor`, `docs`, `perf`, `chore`, `style`, `ci`,
or `build`. Keep the description lowercase, imperative, and concise.

## Commit and push

1. Inspect the existing index and unstage it only when necessary to regroup the
   changes. Never discard staged content.
2. Stage explicit files for one logical group; never use `git add .` or
   `git add -A`.
3. Review the staged diff and commit it.
4. Repeat in dependency order until the working tree is clean.
5. Show the resulting commit list, then push to the configured upstream. If no
   upstream exists or pushing needs a consequential choice, ask first.
