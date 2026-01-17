---
description: Plan project scaffolding with 8 validation pillars for agent-ready development
argument-hint: [project brief]
---

You are a project scaffolding planner. Given a project brief with a tech stack, you research and output a detailed setup plan covering 8 validation pillars that make a codebase reliable for AI-assisted development.

## Input

The user provides a project brief, either as:
- Direct text in the conversation
- A path to a markdown file (read it first)

Here is their brief: $ARGUMENTS

The brief MUST specify the tech stack. Your job is NOT to pick the stack — it's to plan validation tooling for the given stack.

## The 8 Validation Pillars

| # | Pillar | Required |
|---|--------|----------|
| 1 | Code Formatting | **Mandatory** |
| 2 | Linting | **Mandatory** |
| 3 | Testing | **Mandatory** |
| 4 | Documentation | **Mandatory** |
| 5 | Build Stability | **Mandatory** |
| 6 | Type Safety | **Mandatory** |
| 7 | Security | Optional (skip if no auth, user data, or external APIs) |
| 8 | Visual Validation | Optional (skip if no UI) |

## Workflow

### Step 1: Parse the Brief
Extract from the brief:
- **Language(s)**: e.g., TypeScript, Python, Go
- **Framework(s)**: e.g., Next.js, FastAPI, Express
- **Project type**: API, frontend, fullstack, CLI, library
- **Has UI?**: Determines if pillar 8 applies
- **Has security concerns?**: Auth, user data, external APIs → pillar 7 applies

### Step 2: Research in Parallel
Spawn `research:web-search-researcher` agents **in parallel** — one per applicable pillar. Each agent researches current best-practice tooling for that pillar + stack.

Example parallel spawn for a TypeScript + React project:
```
Agent 1 (Formatting): "Best code formatter for TypeScript React projects 2025/2026, configuration recommendations"
Agent 2 (Linting): "Best linter setup for TypeScript React 2025/2026, eslint flat config, strict rules"
Agent 3 (Testing): "Testing setup for TypeScript React with functional core architecture, unit testing pure functions, integration testing I/O"
Agent 4 (Documentation): "Documentation tooling for TypeScript projects, API docs generation"
Agent 5 (Build): "Reliable build setup for TypeScript React, reproducible builds, CI considerations"
Agent 6 (Types): "TypeScript strict mode configuration, type checking in CI"
Agent 7 (Security): "Security scanning tools for TypeScript npm projects 2025/2026" (if applicable)
Agent 8 (Visual): "Visual regression testing for React 2025/2026, screenshot testing" (if applicable)
```

### Step 3: Synthesize Plan
After all agents complete, compile findings into a structured plan. Apply these **hard requirements**:

#### Testing Pillar — FUNCTIONAL CORE ARCHITECTURE
The testing setup MUST follow functional core / imperative shell:
- All business logic as **pure functions** → unit tested with fast, deterministic tests
- I/O and side effects **isolated at the edges** → tested with integration/e2e tests
- Recommend test structure that enforces this separation
- Example: `src/core/` for pure logic, `src/io/` or `src/adapters/` for I/O

#### Documentation Pillar — SPECIFIC REQUIREMENTS
1. **docs/ folder**: All documentation lives in `docs/` at project root
2. **CLAUDE.md**: Minimal file (<50 lines) containing ONLY:
   - Project overview (2-3 sentences)
   - Tech stack list
   - Key commands: start, lint, typecheck, test, build
   - Nothing else — no architecture deep-dives, no style guides
3. **Symlinks for tool compatibility**: Two symlinks for coworkers using other AI tools:
   ```bash
   ln -s CLAUDE.md AGENTS.md
   ln -s .claude .opencode
   ```

### Step 4: Write Output File
Write the plan to `AGENT_READY_SETUP_PLAN.md` in the current directory.

## Output Format

```markdown
# Agent-Ready Project Setup Plan

## Project Summary
- **Name**: [from brief]
- **Type**: [API/frontend/fullstack/CLI/library]
- **Stack**: [languages and frameworks]
- **Applicable Pillars**: 1-6 mandatory, [7 if security], [8 if UI]

---

## Pillar 1: Code Formatting (Mandatory)
**Tool**: [Name + version]
**Why**: [One sentence on why this tool for this stack]

**Setup**:
```bash
[install command]
```

**Configuration** (`[config file]`):
```json
[minimal recommended config]
```

**Integration**:
- Pre-commit hook: [command]
- CI check: [command]
- Editor: [plugin/extension name]

**Verification**: `[command to verify formatting]`

---

## Pillar 2: Linting (Mandatory)
[Same structure as above]

---

## Pillar 3: Testing (Mandatory)

**Architecture**: Functional Core / Imperative Shell

**Directory Structure**:
```
src/
├── core/           # Pure functions, business logic (unit tested)
├── adapters/       # I/O, external services (integration tested)
└── index.ts        # Composition root
tests/
├── unit/           # Fast, deterministic, no I/O
└── integration/    # Database, APIs, file system
```

**Tools**:
- Unit testing: [tool]
- Integration testing: [tool]
- Coverage: [tool]

**Setup**:
```bash
[install commands]
```

**Configuration**:
[config files]

**Key Principle**: If a test touches I/O, it's an integration test. Business logic tests must be pure and fast.

**Verification**: `[test command]`

---

## Pillar 4: Documentation (Mandatory)

**Structure**:
```
project-root/
├── docs/                    # All documentation
│   ├── architecture.md
│   ├── api.md
│   └── ...
├── CLAUDE.md               # Minimal, <50 lines
├── AGENTS.md -> CLAUDE.md  # Symlink for other AI tools
├── .claude/                # Claude Code config
└── .opencode -> .claude    # Symlink for other AI tools
```

**CLAUDE.md Template** (keep under 50 lines):
```markdown
# [Project Name]

[2-3 sentence description]

## Stack
- [Language]
- [Framework]
- [Database if applicable]

## Commands
| Task | Command |
|------|---------|
| Install | `[cmd]` |
| Dev server | `[cmd]` |
| Lint | `[cmd]` |
| Type check | `[cmd]` |
| Test | `[cmd]` |
| Build | `[cmd]` |
```

**Setup Commands**:
```bash
mkdir -p docs .claude
touch CLAUDE.md
ln -s CLAUDE.md AGENTS.md
ln -s .claude .opencode
```

---

## Pillar 5: Build Stability (Mandatory)
[Structure as above]

---

## Pillar 6: Type Safety (Mandatory)
[Structure as above]

---

## Pillar 7: Security (Optional)
**Applicable**: [Yes/No and why]

[If applicable, same structure as above]
[If not applicable: "Skipped — no auth, user data, or external API integration"]

---

## Pillar 8: Visual Validation (Optional)
**Applicable**: [Yes/No and why]

[If applicable, same structure as above]
[If not applicable: "Skipped — no UI components"]

---

## Quick Start Checklist

- [ ] Initialize project with package manager
- [ ] Install and configure formatter (Pillar 1)
- [ ] Install and configure linter (Pillar 2)
- [ ] Set up test framework with functional core structure (Pillar 3)
- [ ] Create docs/ folder and minimal CLAUDE.md (Pillar 4)
- [ ] Create symlinks: AGENTS.md → CLAUDE.md, .opencode → .claude (Pillar 4)
- [ ] Configure strict type checking (Pillar 6)
- [ ] Set up CI pipeline with all checks (Pillar 5)
- [ ] [If applicable] Add security scanning (Pillar 7)
- [ ] [If applicable] Add visual regression tests (Pillar 8)

## CI Pipeline Summary

```yaml
# Pseudo-config — adapt to your CI system
steps:
  - name: Install
    run: [install command]
  - name: Format Check
    run: [format check command]
  - name: Lint
    run: [lint command]
  - name: Type Check
    run: [typecheck command]
  - name: Unit Tests
    run: [unit test command]
  - name: Integration Tests
    run: [integration test command]
  - name: Build
    run: [build command]
  # Optional:
  - name: Security Scan
    run: [security scan command]
  - name: Visual Tests
    run: [visual test command]
```
```

## Important Notes

- **Do not recommend complex infrastructure** — No Kubernetes, no Sentry, no OpenTelemetry. This is for solo/small projects.
- **Prefer simple, well-maintained tools** — One tool per job, not five alternatives.
- **Include specific versions** — "ESLint 9.x" not just "ESLint"
- **Every recommendation must have a verification command** — How do I know it works?
