# QUALITY_SCORE — Session log

This file is your **entropy defense memory**. Every session that catches a structural issue (not just a bug — a *pattern* that could happen again) gets a numbered entry. Future sessions read this to avoid re-catching the same thing.

> The Sessions 4-11 entropy scans on leapedge-clip caught the same "code clean, docs lag" pattern six times. After Session 11 we promoted that pattern to a CI gate (`check-docs-updated.sh`). That's the point of this file: turn repeated catches into mechanical enforcement.

## How to use this

1. **At session end** (or before `/context-save`): if you caught anything worth remembering, add a Session entry below.
2. **Each entry** notes the date, what was caught, what it would have cost if it shipped, and whether it warrants promotion to a CI gate.
3. **When the same pattern is caught 3+ times** across separate sessions: promote it to a mechanical gate. Add a script under `scripts/` and a CI step.
4. **Reference entries by session number** in commit messages and PR descriptions when fixing related issues.

## Template

```
## Session N — YYYY-MM-DD (one-line summary)

**Caught:** Brief description of the structural issue.
**Cost if shipped:** What this would have caused in production.
**Where:** File paths or modules affected.
**Fix this session:** What was done now.
**Promotion candidate:** YES / NO. If YES, what gate would close it.
**Cross-references:** Sessions K, M (related catches).
```

## Standing CI gates (closed entropy classes)

Each gate represents a pattern that was caught 3+ times before being promoted.

| Gate | Script | Class closed |
|------|--------|--------------|
| Source-to-doc | `scripts/check-docs-updated.sh` | Code changes that don't update AGENTS.md / .claude/rules / ARCHITECTURE.md |
| Doc-drift | `scripts/check-doc-content-drift.sh` | Docs reference symbols that don't exist (typo drift) + prose mentions past-state behavior |
| E2E coverage | `scripts/check-e2e-coverage.sh` | Pro-gated flows shipped without Playwright specs |

## Standing in-code gates

| Gate | Location | Class closed |
|------|----------|--------------|
| LLM router monopoly | ESLint `no-restricted-imports` on `@google/genai` | Direct provider SDK calls that bypass cost capture |
| Stripe SDK monopoly | ESLint `no-restricted-imports` on `stripe` | Direct Stripe imports outside `lib/billing/` |
| Firebase Admin monopoly | ESLint `no-restricted-imports` on `@/lib/firebase/admin` | Bypassing repos.ts |
| Firestore index manifest | `lib/firebase/index-manifest.test.ts` | Composite indexes without code consumers (dead) or code queries without indexes (broken) |

## Session log

(Add session entries here as you ship.)
