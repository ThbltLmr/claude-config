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
