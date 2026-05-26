# 02 — Skills routing

How project-level CLAUDE.md wires Claude Code skills to your codebase. Done once per product, then forgotten.

## The two-layer model

```
~/.claude/CLAUDE.md      ← machine-wide, applies to every session everywhere
                           contains: safety rules (no auto-commit, no auto-push)

{project}/CLAUDE.md      ← project-wide, applies to this codebase
                           contains: skill-routing rules, .claude/rules/ pointers
                           includes @AGENTS.md for project context

@AGENTS.md               ← directory map + key conventions for THIS project

.claude/rules/*.md       ← path-specific rules, auto-surfaced when working in matching dirs
```

When Claude Code starts a session in `{project}/`, it reads in this order:

1. `~/.claude/CLAUDE.md` (global safety rules)
2. `{project}/CLAUDE.md` (project-specific routing)
3. `{project}/AGENTS.md` (included via `@AGENTS.md` in step 2)
4. On-demand: `.claude/rules/*.md` when working in matching paths

## What goes in project CLAUDE.md

Three sections, in this order:

### 1. The AGENTS.md include

First line of CLAUDE.md should be:

```
@AGENTS.md
```

This pulls in the full project context. Don't put project context directly in CLAUDE.md — put it in AGENTS.md so docs/architecture/external readers can read it without a Claude Code session.

### 2. Skill routing rules

The "if user asks X, invoke skill Y" mapping. Copy from this template:

```markdown
## Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. When in doubt, invoke the skill.

This project layers TWO complementary skill ecosystems:

- **harness-engineering / superpowers** — project-native PR workflow + multi-agent review.
- **gstack** — global tooling layer. Domain-spanning utilities.

When a request matches both, prefer the project-native skill. When only gstack matches, invoke the gstack skill.

Key gstack routing rules:

- Product ideas/brainstorming → /office-hours
- Strategy/scope → /plan-ceo-review
- Architecture → /plan-eng-review
- Design system/plan review → /design-consultation or /plan-design-review
- Full review pipeline → /autoplan
- Bugs/errors → /investigate
- QA/testing site behavior → /qa or /qa-only
- Code review/diff check → /review
- Visual polish → /design-review
- Ship/deploy/PR → /ship or /land-and-deploy
- Save progress → /context-save
- Resume context → /context-restore
- Capture learning → /learn
- Performance baseline → /benchmark
- Security audit → /cso
- Release docs sync → /document-release
```

### 3. Path-specific rules pointers

A table of `.claude/rules/*.md` files and what they cover:

```markdown
## Path-specific rules

| File | Covers |
|------|--------|
| `.claude/rules/nextjs.md` | Next.js conventions, server actions, async params |
| `.claude/rules/auth.md` | Session cookie pattern, rate limiting |
| ... | ... |
```

When Claude Code works in `app/api/auth/*`, it'll auto-surface `auth.md`. When it works in `app/(app)/`, it'll surface `nextjs.md`. The matching is based on file paths in the diff.

## When to write a new .claude/rules/ file

Add a new file when **all three** are true:

1. You have ≥3 different files in the same area that share a convention.
2. The convention isn't obvious from reading the code.
3. A new AI session would re-invent the wrong pattern without the rule.

Bad examples (don't write a rule):
- "Use 2-space indentation" → Prettier handles this.
- "Functions should be small" → universal.

Good examples (write a rule):
- "All Stripe webhook handlers must read raw body via `req.text()` not `req.json()`" — non-obvious, codifies a real production bug.
- "Daily reports are keyed by user's LOCAL date, not UTC" — a future agent would naturally assume UTC; this catches it.

## When to update a rule

Same trigger as the CI gate: when a behavior-bearing source file changes that's covered by that rule, update the rule in the same PR. The `check-docs-updated.sh` gate fails the build otherwise.

## When to retire a rule

A rule that's been mechanically enforced (by ESLint, CI, type system, runtime check) can be slimmed to "Enforced by X" with a one-line pointer. Don't delete — the prose explanation is still useful for understanding *why* the enforcement exists.

## How to bootstrap rules in a new project

The supported path is `scripts/init.sh`:

```bash
/path/to/solo-edge/scripts/init.sh /path/to/new-product
```

It handles the copy (CLAUDE.md, AGENTS.md, ARCHITECTURE.md, QUALITY_SCORE.md, `.claude/rules/`, `scripts/check-*.sh`, `templates/`), refuses to clobber existing customisations, and prints the next-steps checklist.

If you want to copy manually instead (or refresh selective files), `cd` into the new project and copy from your local solo-edge checkout — substitute `$SOLO_EDGE` for wherever you cloned it. The full file set `init.sh` would have copied:

```bash
SOLO_EDGE=/path/to/your/solo-edge  # adjust to your local clone
# Root templates (4 files)
cp "$SOLO_EDGE/CLAUDE.md" ./
cp "$SOLO_EDGE/AGENTS.md" ./
cp "$SOLO_EDGE/ARCHITECTURE.md" ./
cp "$SOLO_EDGE/QUALITY_SCORE.md" ./
# .gitignore (merge-safe: append missing lines if you already have one)
cp "$SOLO_EDGE/.gitignore" ./
# Per-area rules
mkdir -p .claude
cp -r "$SOLO_EDGE/.claude/rules" .claude/
# CI gates
mkdir -p scripts
cp "$SOLO_EDGE/scripts/check-docs-updated.sh" scripts/
cp "$SOLO_EDGE/scripts/check-doc-content-drift.sh" scripts/
cp "$SOLO_EDGE/scripts/check-doc-indexes.sh" scripts/
cp "$SOLO_EDGE/scripts/check-e2e-coverage.sh" scripts/
chmod +x scripts/check-*.sh
# Canonical drop-in source files
mkdir -p templates
cp -r "$SOLO_EDGE/templates/." templates/
```

`init.sh` skips files that already exist; the manual block above does the same if you guard each `cp` with `[ ! -f target ] && cp ...`. Re-running `init.sh` is the supported way to refresh — it'll prompt before overwriting and skip per-file.

Then edit:
1. `AGENTS.md` — replace template with your project's actual directory map
2. `CLAUDE.md` — keep skill routing as-is; trim the rules table to match `.claude/rules/` files you actually have
3. `.claude/rules/*.md` — keep the ones relevant to your stack; delete the rest; edit content to match your code

The point is to **start with too much and trim**, not start blank and add. The cost of an extra rule is low. The cost of a missing one is a production bug.

---

Read next: [03-shipping-loop.md](03-shipping-loop.md)
