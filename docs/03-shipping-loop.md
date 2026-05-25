# 03 — The shipping loop

The daily rhythm. Memorize this.

```
       /office-hours       /autoplan           code              /ship
idea ──────────────► plan ──────────► PR-ready code ──────► merged PR + docs synced
                              ▲                                       │
                              └──── /investigate / /qa ────────────────┘
                                    /design-review / /review
                                    /learn (at session end)
```

## The four phases

### Phase 1: idea → conviction (`/office-hours`)

Six diagnostic questions, smart-skip when they don't apply. The point isn't to answer "is this a good idea" — it's to **surface the question YOU would ask if you had a co-founder**.

Use when:
- You have a vague idea and want to see if it survives 30 minutes of attention
- You're tempted to start coding something speculative
- You're deciding between two product directions

Don't use when:
- You're fixing a bug or making a small tweak
- The work is already scoped (i.e. you have a PR description sketched)

### Phase 2: conviction → plan (`/autoplan`)

Multi-phase review. Produces a written plan, runs CEO review (strategy), Design review (UX/visual), Eng review (architecture), DX review (developer experience). Optional outside-voice pass via Codex for cross-model consensus.

Use when:
- The work touches ≥3 files
- The work introduces a new data shape, route, or external dependency
- You want a second opinion before coding
- You're back from a long break and need to think clearly

Don't use when:
- The work is a single-file class change (`/ship` will run pre-landing review anyway)
- You're hotfixing production

### Phase 3: plan → code (your hands on the keyboard)

This is where you actually write the thing. With the plan in your context, the model knows the constraints. Code naturally lands inside the plan's lanes.

Tactics:
- **Stay in the same conversation as `/autoplan`** if possible — the model retains the plan in context.
- **If the conversation gets long**, `/context-save` then `/context-restore` in a fresh session with the plan file loaded.
- **For non-trivial features**, ask the model to set up tasks via TodoWrite at the start so progress is visible.
- **When stuck**, invoke `/investigate` — it produces a root-cause hypothesis and a fix proposal, doesn't just patch the symptom.

### Phase 4: code → merged PR (`/ship`)

`/ship` is a non-interactive, fully-automated workflow:

1. Pre-flight: branch check, tests pass, base branch merged
2. Coverage audit (via subagent)
3. Plan completion audit (via subagent)
4. Plan verification via `/qa-only` if the plan has a verification section
5. Scope drift detection
6. Pre-landing review (the multi-agent specialist army)
7. Greptile review comment resolution (if PR exists)
8. Adversarial review (Claude + Codex)
9. Version bump (auto-decide: micro/patch; ask for minor/major)
10. CHANGELOG auto-generated from commits
11. TODOS.md auto-marked for completed items
12. Bisectable commits (one logical change per commit)
13. Verification gate (re-run tests if code changed mid-ship)
14. Push
15. Documentation sync via `/document-release` (subagent)
16. PR/MR creation
17. Metrics persistence

**Idempotent.** Re-running `/ship` runs the whole checklist again. Actions skip if already done (push, PR create). Verifications always re-run.

## What to do between PRs

`/learn` — captures durable insights from the session into `~/.gstack/projects/{slug}/learnings.jsonl`. Future sessions can search these.

`/context-save` — checkpoints the conversation so you can come back tomorrow without re-explaining. The next session uses `/context-restore`.

## The anti-patterns

❌ **Coding without a plan when the work touches ≥3 files.** You'll find yourself in a rabbit hole at hour 4. Burn 10 minutes on `/autoplan` to save 2 hours.

❌ **Shipping without `/ship`.** Skips the docs sync, the version bump, the pre-landing review. Means you'll have to do it manually next week when you've forgotten the context.

❌ **Stacking PRs without rebasing the second onto main after the first merges.** See [docs/11-multi-pr-stacking.md](11-multi-pr-stacking.md) — this is the recovery story for an orphaned commit.

❌ **Ignoring the multi-agent review army.** It catches scope drift, missing tests, security gaps. If it flags something, treat it as a peer reviewer, not a robot.

❌ **Long sessions without `/context-save`.** If you crash at hour 6, you lose context. Save every ~90 minutes.

## What gets cheap with this loop

- **Long absences.** You can be away for a month. `/context-restore` + the AGENTS.md + the latest QUALITY_SCORE.md entry brings you back faster than re-reading your own code.
- **Onboarding the next AI version.** When Claude Opus 5 lands, it'll inherit the conventions automatically by reading the rules. No re-training.
- **Selling the codebase or going public.** Every convention is documented. A new developer can read the docs/ + .claude/rules/ + ARCHITECTURE.md and ship within a week.

---

Read next: [04-design-system.md](04-design-system.md)
