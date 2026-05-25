# PR review army

How to use the multi-agent specialist review dispatched by `/ship` (Step 9). What it catches, when to override, how to read its output.

## What it is

When `/ship` reaches Step 9 (Pre-Landing Review), it dispatches specialist subagents in parallel. Each has fresh context (no prior bias from earlier review). Each runs a checklist:

- **Testing** — coverage gaps, behavioral vs structural tests, regression risk
- **Maintainability** — naming, code smell, complexity
- **Security** (conditional on auth/backend scope) — auth flow, injection, secret exposure
- **Performance** (conditional on backend/frontend scope) — N+1 queries, render thrash, bundle size
- **Data Migration** (conditional on migration scope) — backfill safety, rollback plan
- **API Contract** (conditional on API scope) — request/response shape stability, versioning
- **Design** (conditional on frontend scope) — checklist + Codex pass

Then optionally **Red Team** for diffs >200 lines or when any specialist found a CRITICAL issue.

All findings are JSON. The parent script merges them, dedups by fingerprint (`path:line:category`), boosts confidence for multi-specialist agreement, and presents.

## How to read the output

```
SPECIALIST REVIEW: N findings (X critical, Y informational) from Z specialists

[CRITICAL] (confidence: 9/10, specialist: security) app/api/share/daily/route.ts:42 — Token returned in response body without rate limit
  Fix: Add checkRateLimit before mint
  MULTI-SPECIALIST CONFIRMED (security + api-contract)

[INFORMATIONAL] (confidence: 7/10, specialist: testing) components/ShareReportButton.tsx:67 — Clipboard write failure path not tested
  Fix: Add test for navigator.clipboard.writeText rejection
  Test stub: see below

PR Quality Score: 7.5/10
```

**Confidence calibration:**

| Score | What it means |
|-------|---------------|
| 9-10 | Verified by reading specific code. Concrete bug or exploit demonstrated. |
| 7-8 | High confidence pattern match. Very likely correct. |
| 5-6 | Moderate. Could be false positive. Caveat: "verify this is actually an issue" |
| 3-4 | Low confidence. Suspicious but may be fine. Appendix only. |
| 1-2 | Speculation. Only reported if severity is P0. |

Confidence < 5 doesn't appear in the main report. Don't argue with the report on confidence; if it's there, the model thinks it's real.

## What to do with findings

`/ship` classifies each finding as AUTO-FIX or ASK:

- **AUTO-FIX** — informational findings, dead code, missing tests, stale comments, mechanical CSS fixes. `/ship` applies these automatically and commits as `fix: pre-landing review fixes`.
- **ASK** — critical findings, anything requiring judgment. `/ship` stops and asks you per-finding: A) Fix, B) Skip.

**Don't skip lightly.** A CRITICAL finding is a model that read your code and says it's broken. The cost of investigating is 5 minutes; the cost of ignoring + shipping is variable but often "next Tuesday's incident."

## Force flags

If you want to invoke a specialist that wasn't auto-selected (scope didn't trigger it):

```
/ship --security
/ship --performance
/ship --all-specialists
```

Use for:
- Pre-launch audits ("everything must be reviewed")
- Suspicious diff that scope detection missed
- Diff that's small but high-stakes (e.g. auth flow change <50 lines)

## Adaptive gating

After dispatching the same specialist 10+ times across reviews and finding nothing, gstack auto-gates it ("specialist auto-gated"). This is fine — it's the same compounding principle as ESLint rules.

Exceptions (NEVER_GATE):
- **Security** — insurance specialist, always runs when scope matches
- **Data Migration** — insurance specialist, always runs when scope matches

For these, even 50 silent reviews don't auto-gate. The cost of a silent security bug is asymmetric.

## Adversarial review (Step 11)

Different from specialists. **Always runs** for every diff, both Claude adversarial subagent (free, fast) AND Codex adversarial challenge (if Codex CLI installed). For diffs >200 lines, ALSO runs Codex structured review with [P1] gate.

Claude adversarial = "think like an attacker, find ways this will fail in production."

Codex adversarial = same prompt, different model = cross-model coverage.

Codex structured (large diffs) = full checklist review with [P1] markers = GATE: PASS or FAIL.

Read all output. High-confidence findings (agreed on by multiple sources) get priority. Unique findings from one source might be a false positive OR a unique catch — read the reasoning, not just the conclusion.

## When to argue with the review army

You're allowed to override. The model is opinionated; sometimes wrong. Override when:

- **The finding's premise is wrong** ("the field doesn't exist" — you verified it does)
- **The fix would make things worse** ("add error handling here" — the silent fail is intentional)
- **The cost of the fix exceeds the cost of the bug** (low-conviction performance suggestion for code that runs once per day)

DON'T override when:

- "I'll fix it in a follow-up" (you won't)
- "It's not that important" (you don't know that yet)
- "I just want to ship this PR" (the cost of fixing later compounds)

## When the review army is silent

Sometimes 0 findings. This is rare and means one of:

- The diff is small + mechanical (CSS class change, copy edit) — silence is correct
- Scope detection mis-detected (you ran on a backend file but the specialists thought it was frontend) — re-run with `--all-specialists`
- The model genuinely thinks it's clean (rare, treat as evidence not proof)

Don't celebrate. Read the diff yourself one more time. The model is a peer reviewer, not a guarantor.

## What the review army DOESN'T catch

- **Visual bugs** (use `/design-review` and `/qa` for these)
- **Cross-PR scope drift** (use `/plan-ceo-review` for the macro view)
- **Domain logic correctness** (only you and your users know if the math is right)
- **Performance under real load** (`/benchmark` for baselines; production traffic for the truth)

The review army is a structural reviewer. It catches CLASSES of bugs. It doesn't catch INSTANCES that depend on domain knowledge.

## How to improve the review army's signal

Whenever you spot an instance the review army missed:

1. Note it in QUALITY_SCORE.md as a session catch
2. If caught 3+ times across sessions, write a learning:
   ```bash
   ~/.claude/skills/gstack/bin/gstack-learnings-log '{"skill":"review","type":"pitfall","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":N}'
   ```
3. The next review session searches learnings and applies the matched pattern with higher confidence
4. Eventually, common catches become specialist checklist items

This is the compounding loop. The review army gets smarter every quarter.
