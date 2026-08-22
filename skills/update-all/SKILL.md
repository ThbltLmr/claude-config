---
name: update-all
description: Bring every git repo on this machine up to date with its remote — project repos, and config repos in $HOME — fast-forward only, never discarding local work. User-invoked via /update-all.
disable-model-invocation: true
---

# Update all

Bring every git repo on this machine up to date with its remote, without ever destroying local work.

The prime directive: **fast-forward only**. No `reset --hard`, no force push, no dropped stash, no branch switch behind the user's back. When the safe path is blocked, stop and report — a repo left behind is fine, a repo left damaged is not.

## Scope

Three passes, in order:

1. **Project repos** — everything under the usual code roots (`~/Work`, `~/Projects`, the working directory).
2. **Config repos in `$HOME`** — `~/.claude`, `~/.codex`, `~/.pi`, `~/.config/*`, `~/.scripts/*`, `~/.oh-my-zsh`.
3. **Tool check** — config repos whose tool isn't installed here, and installed tools whose local config isn't linked to its repo.

## 1. Discover

```bash
find ~ -maxdepth 5 -name .git \
  -not -path '*/node_modules/*' -not -path '*/.cargo/*' \
  -not -path '*/.local/share/*' -not -path '*/.cache/*' \
  -not -path '*/vendor/*' 2>/dev/null | sed 's|/.git$||' | sort
```

Exclude checkouts that belong to a tool rather than the user: plugin marketplaces, `.tmp/` trees, tmux plugin-manager clones, vendored imports. Updating those is the tool's job.

A `.git` **file** rather than a directory is a worktree pointer. If the gitdir it names no longer exists, the directory is an orphaned worktree — report it and move on.

## 2. Survey before touching anything

For every repo, record: current branch, upstream, ahead/behind vs the default branch, dirty file count, stash count. Do the whole survey first, so the report is complete and you know what you're walking into.

Resolve the default branch from `refs/remotes/origin/HEAD`, falling back to `origin/main` then `origin/master`. Do not assume `main`.

## 3. Fetch

Fetching is read-only and it is the slow part, so do it for everything, in parallel, up front:

```bash
xargs -P 8 -I{} git -C {} fetch --prune --quiet origin < repos.txt
```

## 4. Update

Decide per repo from the survey:

- **On the default branch, behind** → `git pull --ff-only`.
- **On a feature branch** → do *not* switch branches; the user is mid-task there. Update the default branch ref in place instead: `git fetch origin main:main`. That only works when `main` isn't checked out and only ever fast-forwards, so it's safe. Then fast-forward the feature branch too if it's behind its own upstream.
- **Ahead of upstream** → leave it alone. Report the unpushed commits; never push on the user's behalf.
- **Dirty** → still safe to try: `--ff-only` aborts rather than clobbering local edits. If it aborts, report it.
- **No upstream, unborn branch, or empty remote** → report it, don't guess a remote branch to track.

## 5. Conflicts are the user's call

If the repo has `pull.autostash`/`rebase.autoStash` set, a pull can fast-forward successfully and *then* conflict while reapplying the local changes. Read the state before reacting: `git log -1` shows the fast-forward landed, `git status` shows the unmerged path, and `git stash list` shows the autostash is still there. Nothing is lost yet.

Never resolve a conflict silently. For each one:

1. Work out what each side actually intended — `git log ORIG_HEAD..HEAD -- <file>` shows what upstream changed and why, and the commit subjects usually explain it.
2. Check the consequences. A block that references a file removed upstream is a broken config, not a preference.
3. Present the conflict to the user with concrete options and a recommendation, and let them choose.
4. Apply their choice with `git checkout HEAD -- <file>` (take upstream) or by editing the merge result — and **keep the stash**. Never `git stash drop`; it's their only copy of the discarded work. Say in the report that it's recoverable and how.

## 6. Tool check

Cross-reference config repos against what's actually installed:

- A config repo present locally whose tool isn't on `PATH` → flag it, ask whether to install. Check the real install shapes before declaring it missing: a `gh` extension, a `~/.local/bin` script, and a version-manager shim all count as installed.
- A config repo on the user's remote (`gh repo list`) that isn't cloned here → flag it.
- An installed tool whose config dir exists but **isn't a git repo**, while a matching config repo exists on the remote → flag it, and offer to link.

Link a config dir without overwriting anything:

```bash
git init && git remote add origin <url> && git fetch origin
git update-ref refs/heads/main refs/remotes/origin/main
git symbolic-ref HEAD refs/heads/main
git branch --set-upstream-to=origin/main main
git reset          # index <- HEAD, worktree untouched
```

`git status` then shows the drift with every local file intact. Read that drift before syncing either direction — the two sides may have diverged for a reason (a machine-specific config, a Linux vs macOS split), and which side is canonical is the user's decision, not yours.

## 7. Report

Group by what the user has to act on:

- **Updated** — repo and commit count, one line each.
- **Already current** — a single collapsed line of names. Don't spend a paragraph on repos that did nothing.
- **Resolved conflicts** — what was chosen, and exactly how to recover the other side.
- **Needs attention** — unpushed commits, aborted fast-forwards, orphaned worktrees, missing upstreams.
- **Tools** — missing tools and unlinked configs, with a recommendation.

End with a verification pass over every repo, so the report reflects the state on disk rather than what you believe you did.
