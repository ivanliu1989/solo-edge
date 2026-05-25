# Stuck debugging

When you're an hour in and the bug hasn't moved. Use `/investigate` instead of throwing more code at it.

## The /investigate workflow

```
> /investigate <one-line problem statement>
```

Examples:

- `/investigate users sometimes see Today's signal as empty even though they have analyses`
- `/investigate Stripe webhook returning 500 on subscription.updated for some users`
- `/investigate the daily-email cron is sending duplicate emails to ~5% of users`

The skill produces:

1. **Reproduction recipe** — exact steps + data state needed to reproduce, OR "couldn't reproduce; here's what would help"
2. **Root cause hypothesis** — specific file:line + the logic flaw
3. **Fix proposal** — minimal change, with side-effect analysis (what else might this affect)
4. **Test recommendation** — regression test for the specific failure mode

Key word: **root cause**. Symptomatic patches accumulate; root-cause fixes compound. The skill enforces this discipline.

## When to invoke /investigate

✅ You've been stuck >30 minutes on a bug
✅ A Sentry issue has fired 10+ times and you're not sure why
✅ User-reported behavior doesn't match what your code "should" do
✅ A test passes locally but fails in CI (or vice versa)
✅ You want to refactor but suspect there's a hidden contract you don't see

❌ Bug is obvious — just fix it. Don't waste the cycle.
❌ You haven't actually read the code yet. Read first, then /investigate if stuck.

## How to brief /investigate well

The single-line problem statement should include:

- **Who** experiences it (free user vs Pro, all users vs a subset)
- **What** they see (the symptom, not the cause)
- **When** it happens (always, sometimes, only after action X, only at time Y)
- **Where** in the system (URL, route handler, cron name)

Bad: "Today page is broken"
Good: "Pro users on /today see TodaysSignalSection as empty (gray skeleton) even though they have completed analyses for today"

The model needs the specifics. Bad briefing → bad hypothesis.

## What /investigate does that you wouldn't

1. **Searches across the whole codebase** including paths you might not have grep'd
2. **Reads adjacent files** (the import graph) — finds contracts you didn't know existed
3. **Cross-references with `.claude/rules/`** — rules often encode known failure modes
4. **Reads Sentry context** if you paste an error fingerprint
5. **Proposes the minimal fix** — not the "while I'm in there" expansion
6. **Names the side effects** — what else this fix touches

The cost is ~5-10 minutes of model time. The benefit is "you avoid the wrong-fix rabbit hole."

## When the hypothesis is wrong

Sometimes the model's hypothesis is off. Read it critically:

- **Does the cited line actually exist?** Sometimes the model hallucinates file paths. Verify before trusting.
- **Does the proposed fix make sense given the hypothesis?** Sometimes the diagnosis is right but the fix doesn't actually address it.
- **What does the test recommendation prove?** If the test is just "call the function and assert it doesn't throw," the fix isn't tied to the failure mode tightly enough.

If the hypothesis is clearly wrong: don't argue with the model in chat. Re-brief with more specifics. The model wasn't told the right things.

## The dead-end pattern

You've /investigated. The hypothesis was reasonable. You tried the fix. It didn't work. What now?

1. **Stop coding.** Walk away for 15 minutes.
2. **Re-brief /investigate with what you learned.** "I tried X, here's what happened, the original hypothesis was wrong because Y."
3. **Or escalate to /plan-eng-review for an architectural read.** Maybe the bug isn't in the symptom area; maybe it's in the design.
4. **Or post in a community** (Discord, Twitter, Slack) — fresh eyes catch things models miss.

The pattern that wastes time: re-prompting the same model with the same brief expecting different answers. Doesn't happen. Change the input.

## When the bug is "intermittent"

Intermittent bugs are usually:

- **Race conditions** — two requests modifying same state concurrently
- **Time-of-day specific** — DST boundary, hour rollover, midnight cron
- **User-state specific** — only happens for users with N items, or with a specific timezone
- **External-state specific** — only happens when X third-party returns a specific shape

For each category, ask `/investigate` differently:

- Race conditions → "what's the read-modify-write sequence? where could two requests interleave?"
- Time-of-day → "what date/time math is in the path? what happens at midnight / DST / Feb 29 / leap second?"
- User-state → "what user-doc fields are read in this path? what defaults are assumed?"
- External-state → "what's the call to X? what shapes does the code handle vs not?"

Specificity in the brief → specificity in the hypothesis.

## When the bug is "in production but not local"

Almost always one of:

- **Different env vars** — local has fallback values, prod has stricter ones (or vice versa)
- **Different DB state** — local has fresh data, prod has accumulated edge cases
- **Different traffic patterns** — local single-request, prod concurrent
- **Different time zones** — your machine vs Cloud Run vs the user's browser

Ask /investigate to enumerate which of these could cause the difference. Then verify each.

## When the bug is "in CI but not local"

Almost always one of:

- **Test order dependency** — one test modifies state another test reads
- **Time-sensitive test** — `new Date()` evaluates differently in CI's clock
- **Missing env var in CI** — `process.env.X` is undefined in CI
- **Filesystem case-sensitivity** — macOS local insensitive, Linux CI sensitive
- **Concurrent test execution** — Vitest runs in parallel; one test reads what another wrote

Fix: make the test deterministic. Lock the seed. Inject the time. Provide the env var. Isolate the filesystem path.

## The capture-when-fixed pattern

When you finally fix a hard bug, capture the learning:

```bash
~/.claude/skills/gstack/bin/gstack-learnings-log '{
  "skill": "investigate",
  "type": "pitfall",
  "key": "SHORT_KEY_LIKE_CRON_DST_DOUBLE_FIRE",
  "insight": "Description of the pitfall + how to avoid it",
  "confidence": 9,
  "source": "observed",
  "files": ["lib/format/localDate.ts", "functions/src/index.ts"]
}'
```

Next time you (or the next AI session) `/investigate` a similar bug, this learning surfaces. Compounding.

## When to add it to QUALITY_SCORE.md

If the bug was caused by a class of issue (not a one-off typo), add a session entry. If the same class catches 3+ times across sessions, promote to a CI gate.

Real examples from leapedge-clip:

- "Code change without matching docs" — caught Sessions 4, 7, 8, 9, 10, 11 → promoted to `check-docs-updated.sh`
- "Backticked doc references stale symbols" — caught Sessions 22, 23, 24 → promoted to `check-doc-content-drift.sh --strict`
- "Composite index missing for new query" — caught Session 8 + PR #34 → promoted to `index-manifest.test.ts`

Each promotion was a "stuck debugging" session that captured the pattern. The pattern stops happening once mechanically enforced.
