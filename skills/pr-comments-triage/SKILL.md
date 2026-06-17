---
name: pr-comments-triage
description: Fetch comments on the PR for the current branch, dispatch parallel Sonnet subagents to check which are already addressed (reaction, reply, or code change), filter out no-action comments (praise/suggestions), and propose an answer or a fix for each remaining one.
---

<instructions>

Triage review comments on the GitHub PR attached to the current branch. Filter out comments already handled or that don't need action; for the rest, propose a reply or a code fix.

## 1. Locate the PR

Run `gh pr view --json number,headRefName,baseRefName,url,author,headRefOid` and `gh repo view --json nameWithOwner`. Capture PR number, `owner/repo`, base ref, and head SHA. If no PR is attached, stop and tell the user.

Comments tied to older commits may be stale — note this when triaging.

## 2. Fetch comments

PRs have THREE comment streams — missing one is a triage bug. Fetch in parallel (one assistant message, three Bash calls):

```bash
# Review comments (inline, line-anchored)
gh api -X GET "repos/<owner>/<repo>/pulls/<N>/comments" --paginate -f per_page=100

# Issue comments (general PR thread)
gh api -X GET "repos/<owner>/<repo>/issues/<N>/comments" --paginate -f per_page=100

# Review summaries (body of each submitted review — often the substantive feedback)
gh api -X GET "repos/<owner>/<repo>/pulls/<N>/reviews" --paginate -f per_page=100
```

Per-comment fields: `id`, `user.login`, `body`, `created_at`, `html_url`, `reactions`. Review comments also need `path`, `line` (or `original_line`), `commit_id`, `in_reply_to_id`, `pull_request_review_id`. For reviews, keep only those with non-empty `body` plus `state`, `submitted_at`.

Skip comments authored by the current user (`gh api user -q .login`).

## 3. Pre-filter mechanically (before dispatching subagents)

### Already-addressed signals

- **Positive reaction from PR author or maintainer**: `reactions.total_count > 0` AND any of `+1`, `rocket`, `hooray`, `heart`. `eyes` does NOT count.
- **Replied to**: this comment's `id` appears as another review comment's `in_reply_to_id`, AND that reply is from the PR author. Capture the reply text — feed it to the subagent.
- **Resolved thread**: review-comment threads don't expose `resolved` via REST. If you need it, query GraphQL `reviewThreads.nodes{isResolved, comments(first:1){nodes{databaseId}}}` and map `databaseId` → `isResolved`. Skip this query unless reactions/replies miss obvious cases — it's niche.

Mark these `[already-addressed: <reason>]` and exclude from subagent dispatch.

### No-action signals

A comment is a candidate for `[no-action: praise]` if it's short (< 200 chars) AND matches praise patterns (`lgtm`, `looks good`, `nice`, `👍`, `🎉`, `great work`, bare `nit:` with nothing after). Be conservative — when in doubt, send to the subagent.

Do **not** pre-filter "suggestion" comments — GitHub ` ```suggestion ` blocks often contain real fixes. The subagent decides.

## 4. Dispatch Sonnet subagents in parallel

For each remaining comment, dispatch one `general-purpose` agent with `model: "sonnet"` using [`templates/triage-comment.md`](templates/triage-comment.md). Substitute the placeholders with the comment's body, author, file:line, html_url, head SHA, base ref, cwd, and any existing PR-author reply.

> **PARALLEL DISPATCH IS LOAD-BEARING.** Send ALL `Agent` calls in a SINGLE assistant message. Sequential dispatch defeats the point of this skill.

Use `description: "Triage PR comment <id>"` so they're distinguishable in the UI.

## 5. Collect and present the unified triage

Group by status, in this order. Expand `needs-fix` and `needs-reply` fully; collapse `already-addressed` and `no-action` to one-liners.

```
# PR Comments Triage — #<N> "<PR title>"
<C> total · <A> addressed · <P> praise/suggestion · <R> needs reply · <F> needs fix

## Needs fix (<F>)
1. <author> · <file>:<line> · <html_url>
   > <comment excerpt>
   Proposed fix: <subagent's PROPOSAL>

## Needs reply (<R>)
1. <author> · <html_url>
   > <comment excerpt>
   Proposed reply: <draft>

## Already addressed (<A>) — collapsed
- #<id> <author>: <reason>

## No-action (<P>) — collapsed
- #<id> <author>: <praise | optional-suggestion>
```

**If a subagent returned malformed output**, mark the comment `needs-review-manually` with the failure cited. Don't guess a status.

**If a subagent claimed `addressed-in-code` without a concrete commit SHA or diff hunk in EVIDENCE**, downgrade to `needs-reply` (ask the reviewer to confirm) rather than silently marking addressed.

## 6. After the report

Use `AskUserQuestion` once with these options:

1. **Apply fixes and post replies** — apply every `needs-fix` and post every `needs-reply` draft.
2. **Pick which to handle** — let the user select by ID. Apply only those.
3. **Just show the report** — stop. No code changes, no posts.

Default-recommend option 2 when there are >3 actionable items, otherwise option 1.

**NEVER POST WITHOUT CONFIRMATION.** Picking option 1 is consent to the workflow, not to specific text. Show each reply draft and ask before sending. Posting uses:
- Review-comment replies: `gh api -X POST repos/<owner>/<repo>/pulls/<N>/comments/<id>/replies -f body=...`
- Issue-thread replies: `gh api -X POST repos/<owner>/<repo>/issues/<N>/comments -f body=...`

## 7. Commit fixes and notify the reviewer

After applying the `needs-fix` changes (and only those the user approved), offer to commit them and report back on each addressed thread.

Use `AskUserQuestion` once:

1. **Commit per-comment and post "done in <hash>"** — for each addressed comment, stage only that comment's fix, commit it with a message referencing the comment, then reply on the thread with `Done in <commit-hash>.`
2. **One commit for all fixes, then post to each thread** — make a single commit covering all applied fixes, then post `Done in <commit-hash>.` to every addressed thread with that same hash.
3. **Don't commit** — leave the changes in the working tree, post nothing.

Default-recommend option 1 — per-comment commits give each reviewer a precise hash to verify.

For each commit, capture the resulting SHA (`git rev-parse --short HEAD`) and post it back to the originating thread using the reply commands above:
- Reply body: `Done in <commit-hash>.` (optionally one line on what changed).
- Use the addressed comment's `id` (review comment) or the issue thread, matching how the comment was fetched.

If the branch needs pushing for the reviewer to see the commit, ask before running `git push`. Confirm each commit message and each reply body before committing/posting — same consent rule as step 6.

</instructions>
