---
name: pr-comments-triage
description: Fetch comments on the PR for the current branch, dispatch parallel Sonnet subagents to check which are already addressed (reaction, reply, or code change), filter out no-action comments (praise/suggestions), and propose an answer or a fix for each remaining one.
---

<instructions>

Triage review comments on the GitHub pull request attached to the current branch. Filter out comments that are already handled or don't need action, and for the rest propose either a reply or a code fix.

## 1. Locate the PR

Run `gh pr view --json number,headRefName,baseRefName,url,headRepositoryOwner,headRepository,author` to find the PR attached to the current branch.

- If no PR is attached, stop and tell the user there is no PR for this branch.
- Capture: PR number, owner/repo (from the remote, not just `headRepositoryOwner` — use `gh repo view --json nameWithOwner` for the canonical `owner/repo`), base ref, head SHA.
- Capture the head SHA: `gh pr view --json headRefOid -q .headRefOid`. Comments tied to older commits may be stale — note this when triaging.

## 2. Fetch comments

PRs have THREE distinct comment streams. Fetch all three — missing one is a triage bug.

In parallel (`Bash` with `run_in_background: false`, all in one assistant message):

1. **Review comments** (inline, line-anchored):
   ```
   gh api -X GET "repos/<owner>/<repo>/pulls/<N>/comments" --paginate -f per_page=100
   ```
   Fields to keep per comment: `id`, `user.login`, `body`, `path`, `line` (or `original_line`), `commit_id`, `in_reply_to_id`, `created_at`, `html_url`, `reactions`, `pull_request_review_id`.

2. **Issue comments** (general PR thread):
   ```
   gh api -X GET "repos/<owner>/<repo>/issues/<N>/comments" --paginate -f per_page=100
   ```
   Fields: `id`, `user.login`, `body`, `created_at`, `html_url`, `reactions`.

3. **Review summaries** (the body of each submitted review — often contains the substantive feedback):
   ```
   gh api -X GET "repos/<owner>/<repo>/pulls/<N>/reviews" --paginate -f per_page=100
   ```
   Keep only reviews with non-empty `body`. Fields: `id`, `user.login`, `body`, `state`, `submitted_at`, `html_url`.

Skip comments authored by the current user (`gh api user -q .login`) — those are your own replies, not feedback to triage.

## 3. Pre-filter mechanically (before dispatching subagents)

For each comment, check cheap signals first to avoid burning subagent budget:

### Already-addressed signals

- **Reaction by PR author or any maintainer**: `reactions.total_count > 0` AND any of `+1`, `rocket`, `hooray`, `heart`. A `eyes` reaction means "seen, not yet addressed" — does NOT count as addressed.
- **Replied to**: this comment's `id` appears as another review comment's `in_reply_to_id`, AND that reply is from the PR author. Capture the reply text — it may be the answer the user wants to keep.
- **Resolved thread**: review-comment threads have no direct "resolved" field in the REST API. If you need it, fetch via GraphQL:
  ```
  gh api graphql -f query='query($owner:String!,$repo:String!,$num:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$num){reviewThreads(first:100){nodes{id isResolved comments(first:1){nodes{databaseId}}}}}}}' -F owner=<owner> -F repo=<repo> -F num=<N>
   ```
  Map each `databaseId` of the first comment in the thread to `isResolved`. A resolved thread = addressed.

Mark these as `[already-addressed: <reason>]` and exclude from subagent dispatch.

### No-action signals (regex / keyword pre-pass)

A comment is a candidate for `[no-action: praise]` if it's short (< 200 chars) AND matches praise patterns: `lgtm`, `looks good`, `nice`, `👍`, `🎉`, `nit:`-only-with-nothing-after, `great work`, etc. Be conservative — when in doubt, send to the subagent. The subagent will catch the rest.

Do NOT pre-filter "suggestion" comments mechanically — GitHub suggestion blocks (` ```suggestion `) often contain real fixes the user wants to apply. The subagent decides.

## 4. Dispatch Sonnet 4.6 subagents in parallel

For each remaining comment (one comment = one subagent), dispatch a `general-purpose` agent with `model: "sonnet"`. Send ALL agent calls in a SINGLE assistant message so they run concurrently.

Each subagent gets a self-contained prompt — it has zero context. Include in the prompt:

- The exact comment body, author, file path, line number (if review comment), and `html_url`.
- The PR head SHA so the subagent diffs against the right tree.
- The base ref so the subagent can see what changed in this PR.
- Any reply text already posted by the PR author (from step 3).
- The repo's working directory (current cwd).
- Exactly what to determine and the output format.

### Subagent prompt template

```
You are triaging ONE PR review comment. Determine its status and propose an action.

## Comment
- Author: <login>
- URL: <html_url>
- File: <path>:<line>          (omit for issue comments / review summaries)
- Posted at: <created_at>, against commit <commit_id>
- PR head is now: <head_sha>
- Body:
<<<
<verbatim comment body>
>>>

## Existing reply from PR author (if any)
<<<
<reply body, or "none">
>>>

## Repo context
- cwd: <absolute path>
- Base branch: <base_ref>
- PR head SHA: <head_sha>

## Your task

Classify the comment into ONE of these categories. Be thorough — read the actual code at the cited file:line on the current head, and compare against the version the comment was posted against (use `git show <commit_id>:<path>` vs `git show <head_sha>:<path>` or just `git log -p <commit_id>..<head_sha> -- <path>`).

1. `addressed-in-code` — the code at `<path>:<line>` (or related code) was changed after the comment in a way that resolves the concern. Cite the commit SHA(s) and quote the relevant diff hunk.
2. `addressed-by-reply` — the existing reply from the PR author substantively answers the comment (not just "thanks"). Quote the part of the reply that answers it.
3. `no-action-praise` — the comment is praise / approval / encouragement with no actionable request.
4. `no-action-suggestion` — the comment is a soft suggestion the reviewer explicitly marked as optional ("feel free to ignore", "nit, up to you", "non-blocking"). Pure `nit:` prefix is NOT enough — many nits are still actionable.
5. `needs-reply` — the comment asks a question or raises a concern that's best resolved with an explanation rather than a code change. Draft a 1–3 sentence reply.
6. `needs-fix` — the comment requests a code change that has not been made. Identify the exact file:line(s) to change and describe the fix in 1–3 sentences. If the comment includes a ` ```suggestion ` block, quote it.

## Output format (strict)

Return EXACTLY this, nothing else:

```
STATUS: <one of the 6 categories above>
EVIDENCE: <one paragraph citing file:line, commit SHAs, or quoted reply text that justifies the status>
PROPOSAL: <for needs-reply: the draft reply. For needs-fix: file:line + fix description. For everything else: "n/a">
```
```

Use `description: "Triage PR comment <id>"` for each agent call so they're distinguishable in the UI.

## 5. Collect and present the unified triage

Once all subagents return, build the report. Group by status, in this order:

```
# PR Comments Triage — #<N> "<PR title>"

<C> total comments · <A> addressed · <P> praise/suggestion · <R> needs reply · <F> needs fix

## Needs fix (<F>)
1. <author> · <file>:<line> · <html_url>
   > <comment body, truncated to 2 lines if longer — link to full>
   Proposed fix: <subagent's PROPOSAL>

## Needs reply (<R>)
1. <author> · <html_url>
   > <comment body excerpt>
   Proposed reply: <draft>

## Already addressed (<A>) — collapsed
- #<id> <author>: <reason — code change at <sha>, reply at <url>, reaction, or resolved thread>
- ...

## No-action (<P>) — collapsed
- #<id> <author>: <praise | optional-suggestion>
- ...
```

Keep "Already addressed" and "No-action" as one-line bullets — the user only needs the headline. Expand only the actionable buckets.

## 6. After the report

Use `AskUserQuestion` once with these options:

1. `Apply fixes and post replies` — apply every `needs-fix` and post every `needs-reply` draft. Confirm each reply text individually before posting (`gh api -X POST repos/<owner>/<repo>/pulls/<N>/comments/<id>/replies -f body=...` for review-comment replies; `gh api -X POST repos/<owner>/<repo>/issues/<N>/comments -f body=...` for issue-thread replies).
2. `Pick which to handle` — let the user select by ID (e.g. "fix #1, #3; reply #2"). Apply only those.
3. `Just show the report` — stop here. Do not modify code or post anything.

Default-recommend option 2 when there are more than 3 actionable items, otherwise option 1.

### Non-negotiable rules

> **PARALLEL DISPATCH.** Step 4's subagent calls MUST be in a single assistant message. Sequential dispatch defeats the point of this skill.

> **NEVER POST WITHOUT CONFIRMATION.** Posting a reply on GitHub is visible to others — always confirm the exact text with the user before calling `gh api -X POST`. A user picking option 1 in step 6 is consent to the workflow, not to specific text — show each draft and ask before sending.

> **DON'T FABRICATE STATUSES.** If a subagent returns malformed output or errors, mark that comment as `needs-review-manually` in the report rather than guessing. Cite the failure.

> **TRUST CODE-CHANGE EVIDENCE.** When the subagent claims `addressed-in-code`, the EVIDENCE must include a concrete commit SHA or diff hunk. If it doesn't, downgrade to `needs-reply` (ask the reviewer to confirm) rather than silently marking addressed.

</instructions>
