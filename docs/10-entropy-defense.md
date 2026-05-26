# 10 — Entropy defense

The mechanical gates that close the "code clean, docs lag" failure mode. This is the most important document in this repo.

## The premise

When you ship with AI assistance, **code productivity outpaces documentation discipline**. The model writes a feature in 20 minutes; updating AGENTS.md / .claude/rules / ARCHITECTURE.md takes 5 minutes more — which is exactly the time you skip when shipping at 11pm.

After six months, the docs don't match the code. The next AI session reads the (stale) docs, makes the wrong call, and ships a regression.

**Entropy defense = mechanical gates that fail the PR when docs lag.**

The leapedge-clip Sessions 4-11 entropy scans caught the same "code clean, docs lag" pattern six times before promotion to a CI gate. Then it stopped happening, because the gate fires automatically.

## The five CI gates

(4 bash scripts + 1 in-code vitest test.)

### 1. Source-to-doc updates (L3)

`scripts/check-docs-updated.sh` — fails CI when behavior-bearing source files change without matching doc updates.

```bash
# Example from leapedge-clip — yours will differ.
# Start with a minimal 2-3 rule baseline, add rows as you catch
# "I changed X but forgot Y" patterns. Three catches = permanent row.
declare -a RULES=(
  'lib/firebase/types\.ts|ARCHITECTURE.md|.claude/rules/firestore.md|AGENTS.md'
  'lib/firebase/repos\.ts|.claude/rules/firestore.md|AGENTS.md'
  'lib/auth/session\.ts|.claude/rules/auth.md|AGENTS.md'
  'lib/llm/router\.ts|.claude/rules/llm-pipeline.md'
  'functions/src/index\.ts|.claude/rules/functions.md'
  'middleware\.ts|.claude/rules/auth.md|AGENTS.md'
  'app/\(app\)/[^/]+/page\.tsx|AGENTS.md'
  'lib/billing/.*\.ts|.claude/rules/billing.md|AGENTS.md'
  'app/api/stripe/.*\.ts|.claude/rules/billing.md|AGENTS.md'
  'app/pricing/page\.tsx|AGENTS.md'
  'lib/auth/admin\.ts|.claude/rules/admin.md|AGENTS.md'
)
```

Each row: source pattern → list of docs (any one must also change). The shipped `scripts/check-docs-updated.sh` carries the leapedge rows above — trim to match your stack before relying on it.

**Escape hatch:** `[skip docs]` in the commit message — for class-only changes, comment fixes, type renames. Use sparingly.

### 2. Doc-drift (L3.5)

`scripts/check-doc-content-drift.sh` — fails CI on:

(a) **Backticked-symbol drift** — every backticked camelCase/PascalCase identifier in mutable docs is grep-checked against `app/ lib/ components/ functions/src/ scripts/ e2e/`. A doc reference with no source match fails.

Catches:
- Single-letter typo drift (`getUserDOcOrNull` vs `getUserDocOrNull`)
- Stale-rename leftovers (function renamed in code, doc still names the old version)

(b) **Prose-mention drift** — phrases in a `DENIED_PHRASES` list fail when found in current-tense prose. Seed it with phrases YOUR project keeps mistakenly using in present tense after the state has moved on.

```bash
# Example from leapedge-clip — replace with phrases that bite YOUR docs.
# leapedge-clip's beta freeze ended; the phrase kept reappearing in 3 consecutive
# entropy sweeps before getting promoted to this list.
DENIED_PHRASES=(
  "beta freeze is currently in effect"  # past-tense state described as current
  # Add new denied phrases here when the same prose-drift pattern is caught 3+ times
)
```

Local `pnpm doc:drift` runs warn-only for the dev loop. CI invokes `--strict` and blocks the PR.

### 3. Doc-index integrity

`scripts/check-doc-indexes.sh` — fails CI when a file in `docs/` or `playbooks/` exists on disk but is missing from the required README indexes (`README.md`, `docs/README.md`, `playbooks/README.md`). Closes the rot class where you add `docs/14-monitoring.md` and forget to update 1-3 indexes.

Posture: BLOCKING. Cost: ~30 lines of bash, ~50ms per run.

### 4. E2E spec presence

`scripts/check-e2e-coverage.sh` — fails CI when a required Playwright spec is missing.

```bash
REQUIRED=(
  "e2e/pricing.spec.ts"
  "e2e/today-gate.spec.ts"
  # ... gated user flows
)
```

Presence-only (CI doesn't execute the suite — needs browser install). Run locally via `pnpm test:e2e`.

**Escape hatch:** `[skip e2e]` in the commit message — only for emergency hotfixes that can't wait for a new spec.

### 5. Firestore index manifest

`lib/firebase/index-manifest.test.ts` (Vitest, not bash) — asserts bidirectional containment between:

- `REQUIRED_INDEXES` — the manifest of every composite index this codebase uses, each row naming the call site
- `firestore.indexes.json` — the deployed index definitions

Catches:
- **Missing indexes** (the leapedge-clip PR #34 failure: aggregation query shipped without an index, broke production)
- **Dead indexes** (Session 8 finding: `analyses(status, titleLower)` index existed with no consumer)

Workflow for adding a new query that needs a composite index:

1. Add the query in `repos.ts`
2. Add a `REQUIRED_INDEXES` row naming the call site
3. Add the matching block to `firestore.indexes.json`
4. `pnpm test` confirms the manifest matches
5. `firebase deploy --only firestore:indexes` BEFORE merging

## In-code gates (ESLint)

Three chokepoints enforced by `no-restricted-imports`:

```javascript
// eslint.config.mjs
{
  files: ["**/*.ts", "**/*.tsx"],
  ignores: ["lib/llm/providers/**", "lib/transcribe/**"],
  rules: {
    "no-restricted-imports": ["error", {
      paths: [{ name: "@google/genai", message: "Import via lib/llm/router" }],
    }],
  },
},
{
  files: ["**/*.ts", "**/*.tsx"],
  ignores: ["lib/billing/**", "app/api/stripe/**"],
  rules: {
    "no-restricted-imports": ["error", {
      paths: [{ name: "stripe", message: "Use lib/billing/stripe-client" }],
    }],
  },
},
{
  files: ["**/*.ts", "**/*.tsx"],
  ignores: ["lib/firebase/**"],
  rules: {
    "no-restricted-imports": ["error", {
      patterns: [{ group: ["@/lib/firebase/admin"], message: "Go through lib/firebase/repos.ts" }],
    }],
  },
},
```

Each chokepoint represents a contract:

- LLM router monopoly → cost capture + Zod validation can't be bypassed
- Stripe SDK monopoly → singleton + auto-recovery can't be bypassed
- Firebase Admin monopoly → repos.ts is the only Firestore contract

## Session-quality log (QUALITY_SCORE.md)

The promotion pipeline:

```
Caught once       → note it in the PR description
Caught twice      → write it up in QUALITY_SCORE.md as a numbered session entry
Caught three+ times → promote to mechanical gate (script or ESLint rule)
                      add to QUALITY_SCORE.md "Standing gates" table
```

Format of a session entry (from QUALITY_SCORE.md template):

```markdown
## Session N — YYYY-MM-DD (one-line summary)

**Caught:** Brief description.
**Cost if shipped:** What it would have caused.
**Where:** File paths.
**Fix this session:** What was done.
**Promotion candidate:** YES/NO. If YES, what gate would close it.
**Cross-references:** Sessions K, M.
```

When a session catches something that links to 2 prior sessions, the pattern has 3 catches → time to promote.

## Promotion examples (from leapedge-clip)

| Pattern caught | Sessions caught in | Promotion | Result |
|----------------|-------------------|-----------|--------|
| Code change without matching docs | 4, 7, 8, 9, 10, 11 | `check-docs-updated.sh` (Session 11) | Stopped happening |
| Doc backtick references stale symbols | 22, 23, 24 | `check-doc-content-drift.sh` (Session 25, promoted to --strict) | Stopped happening |
| Pro-gated flow shipped without e2e spec | (planned, before launch) | `check-e2e-coverage.sh` | N/A — preemptive |
| Composite index missing or dead | PR #34, Session 8 | `index-manifest.test.ts` | Stopped happening |

The compounding effect: every promotion is one less class of bug you have to remember.

## When NOT to promote

- **One catch is just a bug fix.** Don't promote.
- **Two catches is a pattern.** Note it; don't promote yet.
- **Three catches across separate sessions is a class.** Promote.

Don't promote based on theoretical risk. Promote based on observed recurrence.

## The cost of a gate

Each gate adds:
- 5-30 seconds to CI
- ~30 lines of script
- An entry in QUALITY_SCORE.md

The cost is real. The cost of NOT promoting a 3x-caught pattern is unbounded — the next catch could be after launch, when users are watching.

## What gates look like for a fresh project

Day 1, copy from solo-edge:

- `scripts/check-docs-updated.sh` (already wired to common file patterns)
- `scripts/check-doc-content-drift.sh` (empty DENIED_PHRASES list)
- `scripts/check-e2e-coverage.sh` (empty REQUIRED list)

Don't wait until session 6 to add these. Day 1 is free. Session 6 is expensive (every line you've written so far might have issues a gate would catch).

## What gates look like for an existing project

If you're retrofitting onto a codebase that doesn't have these:

1. **Wire all four gates with warn-only output** for one week. Don't block PRs yet.
2. **Triage the violations**. There will be many.
3. **Fix the violations in dedicated cleanup PRs** (one PR per category).
4. **Flip the gates to fail-mode** when the codebase is clean.

Don't try to fix everything in the same PR that wires the gates. That's the failure shape.

---

Read next: [11-multi-pr-stacking.md](11-multi-pr-stacking.md)
