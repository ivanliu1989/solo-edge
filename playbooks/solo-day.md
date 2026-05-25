# Solo day

What a productive day of solo AI-assisted building looks like. Concrete patterns, not abstract principles.

## Session shape (90-minute blocks)

Each block is one ship-loop iteration. Don't aim for multiple PRs per block; aim for ONE focused PR per block.

```
Block 1 (morning, 90min) — feature work: /autoplan → code → /ship
Block 2 (mid-morning, 60min) — review responses + iteration
Block 3 (after lunch, 90min) — feature work or polish PR
Block 4 (afternoon, 60min) — ops / observability / reading Sentry
Block 5 (late afternoon, 45min) — /context-save + next-session planning
```

Three feature blocks per day is the realistic ceiling. More than that and quality drops.

## Session open (5 min)

1. `git checkout main && git pull --ff-only origin main`
2. `git branch` — any feature branches still around? Merge or delete.
3. `gh pr list --author @me` — any open PRs need response?
4. Open Sentry. Check overnight issues. Triage to: fix-now / runbook / dismiss / silence.
5. If continuing from yesterday: `/context-restore`. If new direction: read `QUALITY_SCORE.md` last session and `claude-progress.txt`.

## Decide what to build (10 min if needed)

If you don't know what to do today:

1. Read `feature_list.json` — your scope contract. Anything P0?
2. Read `TODOS.md` — anything ready-to-do that you've been deferring?
3. If still unclear: `/office-hours` with a vague idea — the diagnostic surfaces the question you should ask yourself.

If you DO know what to do today: skip to /autoplan.

## /autoplan → code (60-90 min per feature)

For anything touching ≥3 files: `/autoplan <feature description>`.

The plan output goes to `~/.gstack/projects/<slug>/<user>-<branch>-design-<feature>-<timestamp>.md`. Keep that file open in your editor as you code — it's your reference + the next session's context.

While coding:

- **Mark tasks done as you finish them** via TodoWrite — don't batch-complete at the end.
- **Hit a snag?** `/investigate <one-line problem>` — produces root-cause hypothesis. Don't fix symptoms.
- **Done with a logical unit?** If checkpoint_mode=continuous, auto-commit fired. If explicit, decide whether to commit-as-you-go or one-big-commit-at-the-end.
- **Tests:** vitest as you go (`pnpm test`); save Playwright for end of session.

## /ship (10 min)

`/ship` is the non-interactive ship workflow. Re-runs from any state.

Things it'll stop you for:
- Base branch (you should be on a feature branch)
- Test failures (in-branch — pre-existing get triaged via P0 TODO)
- Pre-landing review ASK items (user judgment needed)
- Plan items NOT DONE without override

Things it won't stop you for:
- Uncommitted changes (always included)
- Version bump for MICRO/PATCH (auto)
- CHANGELOG content (auto-generated)
- Commit message (auto)

Average run: 4-7 minutes for a small PR, 10-15 for a larger one. Worth it every time — the docs-sync alone pays for itself.

## Review response (15-30 min per PR)

If Greptile is wired, /ship triages comments inside. Otherwise:

- Read the comments. Classify: valid-actionable, already-fixed, false-positive.
- Fix valid-actionable ones via small commits on the same branch.
- Reply to false-positives with the **False Positive reply template** from greptile-triage.md — include evidence + suggested re-rank.
- Push. CI re-runs.
- Hit Merge.

## Cleanup (5 min after each merge)

- `git checkout main && git pull --ff-only origin main`
- `git branch -d <merged-branch>` (local cleanup)
- Check Sentry — did the deploy break anything? Wait 5 min for traffic to hit.
- Update `claude-progress.txt` with one line: "Shipped PR #N: <title>"

## /context-save (5 min before EOD)

Run `/context-save` if:
- Mid-feature (so tomorrow you `/context-restore` cleanly)
- Just had a long debugging session and want to commit insights
- About to take a long break (>2 days)

Skip if:
- Just finished a clean ship cycle (everything's in main + docs)
- Last session was <30 minutes (not enough context to be worth saving)

## End of day mini-retro

5 minutes. Open `QUALITY_SCORE.md`:

- Anything catch your attention today as a pattern (not just a bug)?
- If yes: add a numbered session entry.
- If a pattern hit 3+ catches across sessions: promote to a gate (write the script or ESLint rule tomorrow morning).

## Common day-killers (avoid)

❌ **Reading Hacker News before opening Sentry.** Sentry first, news after.
❌ **Multi-file refactor at 5pm.** Cognitive load is wrong; you'll ship a regression.
❌ **Shipping without `/ship`.** You'll regret it tomorrow when docs are stale.
❌ **Ignoring the multi-agent review army.** It catches scope drift you can't see.
❌ **Skipping `/context-save` "just this once."** Tomorrow-you will be lost.
❌ **Picking up two features in parallel.** Solo capacity is one feature in flight at a time.

## Common day-makers (do)

✅ **First task of the day is the one with most uncertainty.** Tackle while your brain is fresh.
✅ **Lunch is a hard reset.** Step away, come back with new eyes. Code-after-lunch is often where you spot the obvious bug.
✅ **Quick wins on Friday afternoon.** Polish PR, doc cleanup, small a11y fix. Builds confidence for Monday.
✅ **One-day rule on Sentry alerts.** If you can fix in <30min, fix today. Otherwise runbook + schedule for Monday.
✅ **End the day with one decision queued for tomorrow.** Means tomorrow starts at 60% not 0%.

## When to take a day off

If you find yourself:

- Making the same class of bug twice in one day
- Reading the same Sentry issue 3+ times without acting
- Reverting a change because the second iteration was worse than the first

That's the signal. Take an afternoon, go for a walk, come back tomorrow. Solo capacity is not infinite; the model amplifies you but doesn't replace rest.
