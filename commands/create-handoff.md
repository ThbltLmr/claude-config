---
description: Create handoff document for transferring work to another session
model: opus
---

# Create Handoff

You are tasked with writing a handoff document to hand off your work to another agent in a new session. You will create a handoff document that is thorough, but also **concise**. The goal is to compact and summarize your context without losing any of the key details of what you're working on.

## Process

### 1. Filepath & Metadata

Create your file under `.claude/handoffs/YYYY-MM-DD_HH-MM-SS_description.md` (in the current repository), where:
- YYYY-MM-DD is today's date
- HH-MM-SS is the current time in 24-hour format
- description is a brief kebab-case description of the work

Example: `2025-01-08_13-55-22_auth-refactor.md`

### 2. Handoff Writing

Using the above conventions, write your document with the following structure:

```markdown
---
date: [Current date and time with timezone in ISO format]
git_commit: [Current commit hash]
branch: [Current branch name]
repository: [Repository name]
topic: "[Feature/Task Name]"
tags: [relevant-tags]
status: [complete/in-progress/blocked]
last_updated: [Current date in YYYY-MM-DD format]
type: handoff
---

# Handoff: {concise description}

## Task(s)
{Description of the task(s) you were working on, along with the status of each (completed, in progress, planned). If working on an implementation plan, note which phase you are on. Reference any plan or research documents you are working from.}

## Critical References
{List any critical specification documents, architectural decisions, or design docs that must be followed. Include only 2-3 most important file paths. Leave blank if none.}

## Recent Changes
{Describe recent changes you made to the codebase in file:line syntax}

## Learnings
{Describe important things you learned - patterns, root causes of bugs, or other important information someone picking up your work should know. Include explicit file paths where relevant.}

## Artifacts
{An exhaustive list of artifacts you produced or updated as filepaths and/or file:line references - e.g. paths to feature documents, implementation plans, etc that should be read to resume your work.}

## Action Items & Next Steps
{A list of action items and next steps for the next agent to accomplish based on your tasks and their statuses}

## Other Notes
{Other notes, references, or useful information - e.g. where relevant sections of the codebase are, where relevant documents are, or other important things you learned that don't fit above categories}
```

### 3. Confirm Handoff

Once completed, respond to the user with:

```
Handoff created! You can resume from this handoff in a new session with:

/resume-handoff .claude/handoffs/YYYY-MM-DD_HH-MM-SS_description.md
```

## Guidelines

- **More information, not less**: This defines the minimum. Always include more if necessary.
- **Be thorough and precise**: Include both top-level objectives and lower-level details as needed.
- **Avoid excessive code snippets**: Prefer `file:line` references that an agent can follow later (e.g. `src/auth/login.ts:12-24`). Only include code if it pertains to an error you're debugging.
- **Focus on context transfer**: The goal is for a fresh session to quickly understand what was being worked on and why.
