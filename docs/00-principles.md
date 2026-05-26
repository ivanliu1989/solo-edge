# 00 — Principles

The ten commandments of solo AI building. These come from real production incidents, not theory. Each one was earned.

## 1. AI is fast at writing, slow at remembering. Defend memory.

The model in front of you knows everything about general programming and nothing about *this codebase as of yesterday*. AGENTS.md, .claude/rules/, ARCHITECTURE.md, and QUALITY_SCORE.md are how you compensate. **Update them in the same PR as the code that needs them**, not "later" — there is no later when you're solo.

The CI gate that fails when you don't is in [scripts/check-docs-updated.sh](../scripts/check-docs-updated.sh). It's not annoying; it's the single most important load-bearing gate in this stack.

## 2. Mechanical enforcement beats discipline.

Solo discipline is a renewable resource that burns out at 11pm. CI gates don't burn out. Every time you catch the same class of issue three times, **promote it to a script**. The promotion log is in [QUALITY_SCORE.md](../QUALITY_SCORE.md).

This is why ESLint owns the imports (LLM router only, Stripe only, Firebase Admin only). This is why CI owns the docs-updated check. The rule: if you can mechanize it, do.

## 3. The shipping loop is sacred.

`/office-hours` → `/autoplan` → code → `/ship`. Don't ship without `/ship`. Don't plan without `/autoplan` for non-trivial work. Don't brainstorm in your head when `/office-hours` exists.

The loop is described in [docs/03-shipping-loop.md](03-shipping-loop.md). Every shortcut around it eventually costs more than the time saved.

## 4. Boil the lake — completeness is cheap now.

AI makes completeness the cheap option. When tests, edge cases, and error paths cost 10x more than the happy path in 2020, you cut. When they cost 1.2x in 2026, you don't. Cover the whole feature, not just the demo path.

The principle inverts "don't boil the ocean" (a famous warning against unbounded scope) — boil the *lake* instead, because the lake is bounded, complete, and now cheap. The source post is at [garryslist.org/posts/boil-the-ocean](https://garryslist.org/posts/boil-the-ocean) — the URL keeps the old phrase, the principle uses the new one.

Exceptions: deliberate prototypes meant to be thrown away. If you're not sure whether it's a prototype, it's not — boil the lake.

## 5. The single primary CTA is real.

Every screen has ONE primary action. Every PR has ONE goal. Every session has ONE focus. When you find yourself wanting to "while-I'm-in-here," stop. Make a TODO. Ship the current thing first.

When the multi-agent review army flags scope drift, listen. It's right more than half the time.

## 6. Trust boundaries are load-bearing.

The session cookie is the only auth contract between client and server. The LLM router is the only LLM contract. The repos.ts file is the only Firestore contract. **Identify these chokepoints early** and let nothing bypass them.

When in doubt: would a future me, reading this in six months, be able to find every caller of this function with one grep? If no, add a chokepoint.

## 7. Cost capture or it didn't happen.

Every LLM call writes a row to `llmCalls`. Every Stripe webhook writes the timestamp. Every analysis records its `costCents`. Without this you can't:

- Reason about per-user economics
- Enforce daily caps
- Triage cost spikes
- Justify pricing changes

It's two lines of code. Do it from day one.

## 8. Design lives in tokens, not stylesheets.

A dual-theme token system (CSS vars + Tailwind theme) survives five products. Pre-hydration theme bootstrap kills FOUC. Component-level color decisions don't compound. Token-level decisions do.

See [docs/04-design-system.md](04-design-system.md) for the instrumentation-panel pattern.

## 9. Frozen-at-mint snapshots over live joins.

When you share a daily report, you snapshot it. When you save an action item, you snapshot the insight. When you mint a share token, the data inside is immutable from that point. Live joins back to mutable source data create silent corruption when the source moves on.

The contract is: a shared URL today shows the same thing in six months. This forces clarity about what's truly part of the share vs. what's live data.

## 10. The non-obvious decision is the documented decision.

Every "why is this like this?" you ask of your own codebase six months from now should be answered by an inline comment in the code. If you can't find a pattern to put it in code, put it in `.claude/rules/`. If it doesn't fit there, AGENTS.md.

**Documentation is not the tax you pay for shipping; it's the runtime check you can't add via a unit test.** It's a tool for the next agent — including future-you — to make the right call without a re-derivation.

---

## Anti-principles (what NOT to do)

- ❌ "I'll document it later." There is no later. CI gate fails the PR.
- ❌ "It's just a small change." Small changes don't break production, missed conventions do.
- ❌ "I'll add the test in a follow-up." E2E presence gate fails the PR.
- ❌ "The model will figure it out from context." It won't. Surface the context.
- ❌ "Let me just push a hotfix without /ship." Hotfixes without `/ship` are how shipping discipline dies.

---

Read next: [01-claude-code-setup.md](01-claude-code-setup.md)
