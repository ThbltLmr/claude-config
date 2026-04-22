---
name: dual-review-triage
description: Triage a dual-review unified report — annotate each finding as keep / false-positive / YAGNI / premature-optimization with cited evidence, then ask which keepers to fix. Use after dual-review when the report has nits worth filtering.
---

<instructions>

Triage the unified P1/P2/P3 report from a prior `dual-review` turn. Filter false positives, YAGNI suggestions, and premature optimizations BEFORE the user picks fixes — but bias toward keep, and verify every dismissal.

## 1. Locate the input

The unified report from the prior `dual-review` turn is already in conversation context. Do not re-run reviewers. Do not re-read the diff for findings the report did not raise. Work from the existing report.

If the prior turn's report is not visible (e.g. context was compressed, or the user invoked this skill standalone), ask the user to paste the report or re-run `dual-review` first. Do not fabricate findings.

## 2. Triage each finding

For every bullet in every priority bucket, run these checks against the actual code at the cited `file:line`. Use `Read`, `Grep`, and `Glob` as needed. Modeled on `superpowers:receiving-code-review` (`plugins/cache/claude-plugins-official/superpowers/5.0.7/skills/receiving-code-review/SKILL.md` lines 67–98).

### Check 1 — False-positive

Open the cited file and read the actual code around the cited line range. Ask:

- Does the issue described actually exist in the code as written?
- Did the reviewer misread the logic, miss surrounding context, miss a guard that already exists, or assume behavior that the framework/runtime guarantees?
- Is the cited `file:line` even the right location?

If the finding is contradicted by the code, mark `false-positive` and cite the specific evidence (file:line of the contradicting code, or quote the line that already handles the case).

### Check 2 — YAGNI

If the finding suggests adding code that does not yet exist (input validation, a new error branch, a hook, an abstraction, a fallback, "implement properly"), grep the codebase for whether anything actually needs the suggested addition:

- Does any caller pass input that could trigger the missing case?
- Is the suggested feature reachable from a real entry point?
- Is the function/endpoint/code path even used by current callers? (`Grep` for the symbol.)

If nothing in the current codebase would benefit from the addition, mark `yagni` and cite the grep result (e.g. "only caller is X at file:line, which passes a typed value the suggested validation cannot fail on").

### Check 3 — Premature-optimization

If the finding is a performance suggestion (caching, batching, switching data structures, avoiding allocations, micro-optimizing a loop), ask:

- Is there evidence this code is hot? Benchmarks, profiling data, scale claims, or an obvious tight inner loop?
- What is the realistic call frequency? (One-off init, per-request, per-row, per-frame?)
- Would the suggested optimization meaningfully change anything at the realistic scale?

If there is no evidence of a hotspot and the code is not in an obvious tight path, mark `premature-opt` and state the absent evidence (e.g. "called once at startup", "request-scoped, ~10 calls/req, not on the critical path").

### Default — Keep

If none of the three checks fire, mark `keep`. **Bias toward keep.** Triage filters obvious noise — it does not second-guess the reviewers on judgment calls. When in doubt, keep.

## 3. Re-emit the annotated report

Reproduce the unified report verbatim, with each bullet prefixed by exactly one tag. Preserve original IDs, source tags (`[claude]` / `[codex]` / `[claude+codex]`), file paths, and line numbers.

```
# Triaged Dual Review

## P1 — Critical (must fix)
1. [keep] [claude] path/to/file.ts:42 — <original title> — <original why> — <original fix>
2. [false-positive: the null check exists at file.ts:38; reviewer missed the `if (x == null) return` guard] [codex] path/to/file.ts:88 — <original title>
3. [yagni: only caller is handleRequest at routes.ts:120, which passes a typed `User` from auth middleware — the suggested null check cannot fire] [claude+codex] ...

## P2 — Important (should fix)
4. [keep] [claude] ...
5. [premature-opt: this loop runs once per request over ≤10 items, not a hot path; no profiling evidence cited] [codex] ...

## P3 — Minor (nice to have)
...
```

End with a one-line summary:

```
Kept: <N> · False positives: <M> · YAGNI: <K> · Premature opt: <L>
```

## 4. Non-negotiable rules

> **TAG EVERY FINDING.** No bullet may appear without exactly one `[keep|false-positive|yagni|premature-opt: …]` prefix. Every finding from the input report must appear in the output, in the same order, in the same priority bucket.

> **VERIFY BEFORE DISMISSING.** Each `[false-positive]` tag must cite the file:line of the contradicting code (or quote the contradicting line). Each `[yagni]` must cite the grep result that proves nothing depends on the suggested addition. Each `[premature-opt]` must state the absent evidence and the realistic call frequency. Unsupported dismissals are forbidden — when in doubt, mark `keep`.

> **DO NOT EDIT FINDINGS.** Keep the original title, reasoning, and fix text from the input report unchanged. Only add the tag prefix. The user needs to compare the original finding against your dismissal reasoning.

> **DO NOT FIX YET.** Triage produces an annotated report and a fix-selection prompt. It does not apply changes.

## 5. After the triaged report

Use `AskUserQuestion` (or invite ID-style selection like "fix #1, #4, #7" if the keep list has more than ~6 items) to let the user pick which `[keep]` items to fix.

- Only `[keep]` items are valid fix candidates.
- If the user wants to fix something you marked `false-positive` / `yagni` / `premature-opt`, treat that as them overriding triage — apply the fix, and on the next finding be slightly more conservative about dismissing.
- Apply only the fixes the user explicitly selects. Do not auto-fix anything.

</instructions>
