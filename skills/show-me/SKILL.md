---
name: show-me
description: Show the current topic instead of describing it — pseudocode, call trees, component trees, file trees, diffs, or one focused HTML page. Use when the user says "show me" or asks for a diagram, when they say an explanation is hard to follow, or when another skill needs to render a structure rather than describe it.
---

# Show Me

Skip the preamble and keep prose brief. Pick the **smallest view** that makes the key point clear — one of the forms below, sometimes several, rarely all of them.

## The views

- Show logic or an algorithm as **pseudocode**:

```text
on(save)
  if content is unchanged
    return cached result
  write new content
  return fresh result
```

- Show runtime control flow as a **call tree**:

```text
submitForm
  createSession
    persistPrompt
    launchAgent
  navigateToSession
```

- Show UI structure as a **component tree**, including state and module boundaries that matter:

```tsx
<SessionPage> (apps/example/src/routes/session.tsx)
  useSessionEvents()
  <SessionToolbar>
    <RunSkillButton> (packages/ui)
```

- Show file responsibility or a broad refactor as a **shallow file tree**:

```text
src/
├── commands/       # parses user actions
├── sessions/       # owns session state
└── transport/      # sends API requests
```

- Use a **diff** when the point is what changes and the surrounding shape already exists. Match the diff shape to the topic.

For a component change:

```diff
 <SessionPage>
   useSessionEvents()
   <SessionToolbar>
+    <RunSkillButton />
   <SessionTimeline>
+    <SkillResultCard />
```

For a file-layout change:

```diff
 src/
 ├── commands/
+│   └── show-me.ts       # expands the slash command
 ├── sessions/
-└── transport.ts
+└── transport/
+    ├── client.ts
+    └── stream.ts
```

For a call-tree or call-stack change:

```diff
 submitForm
   createSession
     persistPrompt
+    expandSkillMention
     launchAgent
-  navigateToSession
+  navigateToSession
+    subscribeToEvents
```

For a state or control-flow change:

```diff
 on(save)
-  write content
+  if content is unchanged
+    return cached result
+  write new content
+  invalidate cache
```

- Show the **whole block** when most of it is new, when omitted context would hide ownership or order, or when the user needs a copyable target shape:

```ts
function expandSkill(command: string): string {
  const skillName = command.slice(1)
  return `use the ${skillName} skill`
}
```

- For a visual UI, layout, state comparison, or concept too dense for text, write **one focused HTML file** — a diagram, an infographic, or a short slide deck, whichever fits the point. Match the product's colors, type, spacing, and components; use real labels and data; support desktop and mobile. Then open it for the user:

```
Bash(open path/to/show-me-{description}.html)
```

## Guidance

Place each visual next to the short text it supports. Keep only the calls, files, props, states, and boundaries needed to answer the user's **current question** or the options to resolve the current discussion point.

## In this monorepo

- **Name things with the ubiquitous language.** A diagram is prose too: label nodes with the canonical **Term** from `docs/staffea-migration/ubiquitous_language.md`, never the outdated Hublo identifier the surrounding code happens to use.
- **Write the HTML file to the scratchpad**, not into the worktree — an untracked file in the repo gets mistaken for source.
- Reference real paths as `file_path:line_number` so the user can click through from the tree straight into the code.
