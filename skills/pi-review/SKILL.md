---
name: pi-review
description: Get a second-opinion code review from another model by running the `pi` coding agent headlessly (default openai-codex/gpt-6.1-sol, thinking high), then triage its findings. Use when the user asks for a pi review, a second opinion, or a cross-model review of the current changes, a branch, a PR, or specific files.
argument-hint: "[what to focus on / what to review] e.g. 'security only' or 'PR #42, focus on the caching layer'"
---

Ask `pi` to review the code, then triage what it finds.

## 1. Parse the arguments

The arguments (from the user or the calling agent) can carry, in free text:

- **Focus**: what the reviewer should concentrate on. Default: performance, simplicity, correctness, security, and consistency with codebase patterns.
- **Target**: what to review (a PR, branch, commit range, paths). Default: the current branch and working tree.
- **Model / thinking override** (e.g. "use astra", "thinking xhigh"). Otherwise keep the defaults below.

## 2. Run pi

From the repo root:

```bash
pi -p --no-session \
  --model openai-codex/gpt-6.1-sol --thinking high \
  "Review <target>. Do not modify any files.
Focus on: <focus>." < /dev/null
```

A high-thinking review can take several minutes: run it with `run_in_background: true` and wait for the completion notification. Do not poll.

If pi exits nonzero, show stderr and stop; do not fabricate a review.

## 3. Triage and report

Read every finding and check it against the code yourself. Give each a verdict:

- **Agree**: real issue, worth fixing.
- **False positive**: wrong about the code (misread, already handled elsewhere, impossible path). Say why.
- **Push back**: technically accurate but not worth acting on (out of scope, trade-off already made, contradicts codebase conventions). Say why.

Present a summary to the user: one entry per finding with its location, a one-line description, the verdict, and a short justification, most severe agreed findings first. Attribute the review to pi and the model used. Do not apply fixes unless asked.
