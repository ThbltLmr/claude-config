---
name: update-all
description: Bring this machine's config repos up to date with their remotes — ~/.claude, ~/.codex, ~/.pi/agent, ~/.oh-my-zsh, and the repos under ~/.config and ~/.scripts — fast-forward only, never discarding local work. Project and work repos are out of scope. User-invoked via /update-all.
disable-model-invocation: true
---

# Update all

Bring this machine's **config** repos up to date with their remotes, without ever destroying local work.

The prime directive: **fast-forward only**. No `reset --hard`, no force push, no dropped stash, no branch switch behind the user's back. When the safe path is blocked, stop and report — a repo left behind is fine, a repo left damaged is not.

## Scope

**Config repos only.** Two passes, in order:

1. **Config repos** — `~/.claude`, `~/.codex`, `~/.pi` (the repo may be rooted at `~/.pi` or at `~/.pi/agent`), `~/.oh-my-zsh`, and the git repos directly under `~/.config/` and `~/.scripts/`.
2. **Tool check** — config repos whose tool isn't installed here, and installed tools whose local config isn't linked to its repo.

**Out of scope: project and work repos.** `~/Work`, `~/PersProjects`, `~/OssProjects`, `~/Keikos`, the working directory — leave them alone entirely. Do not survey them, do not fetch them, do not mention them in the report. Updating a work repo is a decision about a task in flight; this skill is for the machine's configuration. If the user wants a project repo updated, they will say so, and that is a different job.

## 1. Discover

```bash
{
  for base in ~/.config ~/.scripts; do
    [ -d "$base" ] && find "$base" -maxdepth 1 -mindepth 1 -type d
  done
  echo ~/.claude; echo ~/.codex; echo ~/.pi; echo ~/.pi/agent; echo ~/.oh-my-zsh
} | sed 's|/$||' | while read -r d; do
  [ -e "$d/.git" ] && echo "$d"
done | sort -u
```

Enumerate with `find`, not a glob. Under zsh a pattern that matches nothing — `~/.scripts/*/` on a machine with no `~/.scripts` — is a fatal `no matches found` that kills the whole command and takes the `~/.config` results with it, so the run silently surveys a handful of repos instead of all of them. `2>/dev/null` does not save you: the failure happens during expansion, before any redirection applies.

Nested clones **inside** a config repo belong to the tool, not the user: tmux plugin-manager clones, `~/.oh-my-zsh/custom/plugins/*`, `.tmp/` trees, vendored imports. The top-level enumeration above already skips them — keep it that way.

Submodules are different: they are part of the config repo, so bring them along with `git submodule update --init --recursive` after a pull that changes them.

A `.git` **file** rather than a directory is a worktree pointer. If the gitdir it names no longer exists, the directory is an orphaned worktree — report it and move on.

## 2. Survey before touching anything

For every repo, record: current branch, upstream, ahead/behind vs the default branch, dirty file count, stash count. Do the whole survey first, so the report is complete and you know what you're walking into.

Resolve the default branch from `refs/remotes/origin/HEAD`, falling back to `origin/main` then `origin/master`. Do not assume `main`.

## 3. Fetch

Fetching is read-only and it is the slow part, so do it for everything, in parallel, up front:

```bash
xargs -P 8 -I{} git -C {} fetch --prune --quiet origin < repos.txt
```

A repo that fails to fetch has **stale** ahead/behind numbers. Say so in the report rather than presenting the last-known figures as current.

## 4. Update

Decide per repo from the survey:

- **On the default branch, behind** → `git pull --ff-only`.
- **On a feature branch** → do *not* switch branches. Update the default branch ref in place with `git fetch origin main:main`, which only ever fast-forwards and only works when `main` isn't checked out. Then fast-forward the feature branch too if it's behind its own upstream.
- **Ahead of upstream** → leave it alone. Report the unpushed commits; never push on the user's behalf unless asked.
- **Dirty** → still safe to try: `--ff-only` aborts rather than clobbering local edits. If it aborts, report it.
- **No upstream, unborn branch, or empty remote** → report it, don't guess a remote branch to track.

When `pull.rebase` or an autostash is configured, `git pull --ff-only` can refuse on a dirty worktree even though the fast-forward itself is safe — and the autostash refuses outright if a tracked directory has been replaced locally by a symlink. `git merge --ff-only @{upstream}` does the same fast-forward without the rebase and stash machinery, and still aborts rather than clobbering a colliding path. Reach for it when the pull balks for a reason unrelated to the incoming commits.

## 5. Conflicts are the user's call

If the repo has `pull.autostash`/`rebase.autoStash` set, a pull can fast-forward successfully and *then* conflict while reapplying the local changes. Read the state before reacting: `git log -1` shows the fast-forward landed, `git status` shows the unmerged path, and `git stash list` shows the autostash is still there. Nothing is lost yet.

Never resolve a conflict silently. For each one:

1. Work out what each side actually intended — `git log ORIG_HEAD..HEAD -- <file>` shows what upstream changed and why, and the commit subjects usually explain it.
2. Check the consequences. A block that references a file removed upstream is a broken config, not a preference.
3. Present the conflict to the user with concrete options and a recommendation, and let them choose.
4. Apply their choice with `git checkout HEAD -- <file>` (take upstream) or by editing the merge result — and **keep the stash**. Never `git stash drop`; it's their only copy of the discarded work. Say in the report that it's recoverable and how.
5. Commit and push the resolved state, so the machine that syncs next picks up the fix instead of hitting the same conflict.

### When the conflict is machine state, don't pick a side

Config repos sync between machines whose `$HOME` layouts differ (`/home/user` vs `/Users/user`). If the colliding file is one the **tool rewrites by itself** — absolute project paths, plugin marketplace caches, hook trusted hashes, changelog versions, window/theme counters — then neither side is canonical and picking one just moves the conflict to the next sync.

The fix is to stop tracking it:

```bash
git rm --cached <file>          # index only; the file on disk is untouched
# add it to .gitignore (mind allowlist-style ignores: remove the `!<file>` line)
git commit -m "chore: stop tracking machine-specific <file>"
```

Back the file up first, and restore it afterwards if the pull replaced it. Recommend this rather than a side, and explain why. Separate genuine preferences (theme, model, keybindings) from machine state and keep tracking those.

Prefer `~`-relative paths over absolute ones in anything tracked, for the same reason.

## 6. Tool check

Cross-reference config repos against what's actually installed:

- A config repo present locally whose tool isn't on `PATH` → flag it, ask whether to install. Check the real install shapes before declaring it missing: a `gh` extension, a `~/.local/bin` script, a version-manager shim, and a shell function sourced from `.zshrc` all count as installed.
- A config repo on the user's remote (`gh repo list <owner>`) that isn't cloned here → flag it. Check every authenticated account; `gh repo list` with no owner only covers the active one.
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
- **Resolved conflicts** — what was chosen, whether it was pushed, and exactly how to recover the other side.
- **Needs attention** — unpushed commits, aborted fast-forwards, orphaned worktrees, missing upstreams, repos that couldn't be fetched.
- **Tools** — missing tools and unlinked configs, with a recommendation.

End with a verification pass over every repo, so the report reflects the state on disk rather than what you believe you did.
