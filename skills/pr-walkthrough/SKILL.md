---
name: pr-walkthrough
description: Build a visual walkthrough artifact of a pull request, showing where each new component lands on screen and how data reaches it.
argument-hint: "[PR number | branch | blank for the current branch] [focus: <area>]"
disable-model-invocation: true
---

# PR walkthrough

One reviewer, ten minutes, before they open the diff. The page answers two questions: **where does this land on screen**, and **how does data get there**. Everything else on it is supporting evidence for those two.

It states what the PR does. It is not a review, and it carries **no decisions or judgment section**. When something in the diff deserves a second look, say so in the handover message where the author can act on it, not on a page their teammates read.

Prose that describes a sequence of components or hops is a diagram you have not drawn yet.

## Step 1 — Pin the range

Never measure the local branch. Measure the commits the PR contains, which is not the same thing: a rebase or a force-push moves the PR head away from the checked-out tip, and a stale local base branch moves the other end. Fetch, resolve both ends to a sha, and reuse those two shas for every command in this skill.

When the user names a PR, or the current branch has one:

```bash
gh pr view <n> --json headRefOid,baseRefName,additions,deletions,changedFiles
git fetch origin "+refs/heads/<baseRefName>:refs/remotes/origin/<baseRefName>" "+refs/pull/<n>/head:refs/pr/<n>"
HEAD_SHA=$(git rev-parse refs/pr/<n>)
BASE_SHA=$(git merge-base origin/<baseRefName> $HEAD_SHA)
```

With no PR, fetch the base branch and use `HEAD_SHA=$(git rev-parse HEAD)` with the same merge-base line. Say in the handover that the page describes an unpushed branch.

Then measure, and check the measurement:

```bash
git log --oneline $BASE_SHA..$HEAD_SHA | cat
git diff --shortstat $BASE_SHA $HEAD_SHA
git diff --stat=200 $BASE_SHA $HEAD_SHA | cat
git diff --name-status $BASE_SHA $HEAD_SHA | awk '{print $1}' | sort | uniq -c
```

`git diff A B` between two pinned shas, never `A..HEAD` or `A...HEAD` against a branch name. The shortstat must equal the `additions`, `deletions` and `changedFiles` that `gh pr view` reported. If it does not, the range is wrong: stop and fix it before reading a single hunk. Two dots against a moved base tip inflates the deletions; three dots against a stale local base replays work that reached the base as a squash commit, because that squash is not an ancestor of the branch, and one earlier slice of a stack can double the whole page's numbers that way.

These counts go in the masthead. They are the cheapest credibility available, and wrong ones are the cheapest way to lose it. Put the two shas in the handover so a reader can rerun the diff.

**Done when** the shortstat matches `gh pr view` exactly, you can name every layer the PR touches (frontend app, BFF, microservice, shared lib, migration, translations), and you can count the components a user can now see.

## Step 2 — Read for the anatomy and the chain

Two passes over the diff, each ending in a list rather than prose. Every command reads `$BASE_SHA $HEAD_SHA`, the range Step 1 pinned. Reading a wider range is how a walkthrough ends up describing a neighbouring PR's feature as if it shipped in this one.

The **anatomy** is the new surface in render order. Read the JSX from the top container down, and for each component record what it renders, the props it takes, what is disabled, and what will own it later. A commit message will never tell you that a card sits above a table. Only the JSX will.

The **chain** is one unbroken path per new field: column, microservice use case, BFF use case, adapter, DTO, query hook, selector, component. Walk every hop. A hop you assume becomes a wrong arrow on the page, and the arrows are what a reader trusts most.

**Done when** the component list is ordered and propped, and every new field has a chain with no gaps in it. An unresolved gap goes on the page as a labelled gap. Never draw a plausible edge in its place.

## Step 3 — Draw

Load `artifact-design`, then `artifact-diagramming`. Copy [`page-scaffold.html`](page-scaffold.html) for the tokens, CSS and figure archetypes. That CSS is the verified version, so change colours and content, not structure.

Sections in this order. Drop any that has nothing to say instead of padding it.

| Section | Carries |
|---|---|
| masthead | title, a one-paragraph lede, the Step 1 numbers |
| Screen | a context figure, then the **anatomy** with numbered badges and an HTML legend naming each file. Add a third figure when the UI branches over states, one mini-layout per state. |
| Data | one lane diagram. Storage at the top, components at the bottom, a lane per service, every arrow labelled with its call or its transform. |
| Logic | only when the PR encodes a rule that is not obvious. Draw both sides of the comparison, strike out any axis left out, and put the verdicts in a table. |
| Wire | one table row per API, model or shared-component change, tagged new, extended or removed. |
| Footprint | reading order for a reviewer, then coverage in one paragraph. |

Spend the most effort on the **anatomy**. It is the one figure a sentence cannot replace. Drawing it needs invented content, names and codes and times, which is fine when it is plausible for the domain and disclosed at handover.

Hand-author every SVG and take its colours from the page tokens so both themes work. Skip any figure whose caption would do the job alone.

## Step 4 — Eyes on

You cannot see the page from a terminal, and this genre's bugs leave no trace in the source. Open the file and look, every run.

```bash
agent-browser open "file://$PWD/<file>.html"

# 1. SVG text overlapping other SVG text
agent-browser eval "const o=[];document.querySelectorAll('svg.dg').forEach((s,i)=>{const t=[...s.querySelectorAll('text')].map(e=>({e,b:e.getBBox()}));for(let a=0;a<t.length;a++)for(let c=a+1;c<t.length;c++){const x=t[a].b,y=t[c].b;if(x.x<y.x+y.width-1&&y.x<x.x+x.width-1&&x.y<y.y+y.height-1&&y.y<x.y+x.height-1)o.push('fig'+(i+1)+': '+t[a].e.textContent+' / '+t[c].e.textContent)}});JSON.stringify(o)"

# 2. labels clipped by the viewBox
agent-browser eval "JSON.stringify([...document.querySelectorAll('svg text')].filter(t=>{const b=t.getBBox(),v=t.ownerSVGElement.viewBox.baseVal;return b.x<-1||b.x+b.width>v.width-1||b.y+b.height>v.height-1}).map(t=>t.textContent))"

# 3. the page scrolling sideways
agent-browser eval "document.documentElement.scrollWidth>document.documentElement.clientWidth"

# then read every figure, in both themes
agent-browser eval "document.documentElement.setAttribute('data-theme','dark')"
agent-browser eval "document.querySelectorAll('figure')[0].scrollIntoView({block:'center'})"
agent-browser screenshot fig1.png
```

The first two must return `[]` and the third `false`.

Four failures that are invisible in source and obvious on screen:

- **Grid on inline flow.** `display: grid` on a container whose children include bare text makes every text run and every `<code>` its own grid item, so a callout list renders one word per line with stretched code boxes. Keep those items in normal flow and place the marker with `position: absolute`.
- **CSS beats presentation attributes.** A rule like `.dg .xs { fill: … }` silently overrides `fill="var(--signal)"` on the same element, so every highlight reverts to body colour with no error anywhere. Style SVG text with a class, and confirm with `getComputedStyle(el).fill`.
- **Leaders through content.** A callout line that crosses something it is not pointing at reads as pointing at it. Route it around, or move the badge.
- **Dead space.** A viewBox taller than its content leaves a large empty plate. Trim it to the drawing.

**Done when** all three checks are clean and you have looked at a screenshot of every figure, not just the first one.

## Step 5 — Unslop, then hand over

Run the `unslop` skill over the page, diagram labels included. This genre attracts three tells above the rest: an em dash in most sentences, bold on every proper noun, and abstract nouns standing in for mechanisms (surface, substrate, hot path).

Publish from the scratchpad directory, and republish the same path for revisions so the URL holds. Hand over the URL, the two shas from Step 1, then say plainly what you inferred rather than verified: invented mock data, hops you could not trace, and anything in the diff worth a second look.
