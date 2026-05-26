# The AI-fleet harness I distilled from shipping one real product

PR #34 to leapedge-clip shipped a Firestore aggregation query without the matching composite index. Every `/api/analyze` on production returned HTTP 500 with an empty body for thirty minutes. The `.claude/rules/firestore.md` file already said *"add composite indexes when introducing ordered queries."* Nothing enforced it.

That's receipt 1 of 8 in [RECEIPTS.md](../RECEIPTS.md). solo-edge is the conventions repo I copy into every new product I build with Claude Code. The conventions exist because each one closed a specific failure class — not "best practices we should adopt," but receipts of what already hit. If you ship solo with AI agents and the failure modes in those receipts feel familiar, solo-edge is what closed them. The next 1500 words walk through how.

## Why "AI-fleet harness" not "solo-builder playbook"

The first version of solo-edge's README called it "the opinionated solo-builder playbook." That framing wasn't wrong, but it wasn't the truth either. The actual problem isn't *solo builders* — it's *AI agents drifting across sessions, months, and model upgrades*.

A human solo builder has tribal knowledge. They remember why the helper is split four ways instead of one. They notice when a doc reference goes stale. They don't write `getUserDocOrNull` in three different places because they remember writing it the first time.

AI agents don't have any of that. Every session starts from zero context. Every model upgrade resets the prior. Every long absence — yours or theirs — means the next pass re-derives conventions from the code that's already there, which is now drifted, which compounds.

The harness is what fills the gap. AGENTS.md tells the next agent what this codebase IS. `.claude/rules/` tells it what's load-bearing in the area it's about to touch. The CI gates make sure when the agent inevitably forgets, the failure is mechanical, not silent. The QUALITY_SCORE log makes sure when the same class of bug shows up three times, it stops being a thing humans have to catch.

If you ship solo *without* AI agents, you don't need most of this. If you ship with AI agents and *don't* have it, you've already lost an afternoon to entropy you couldn't see.

## The compounding model

Every convention in solo-edge follows a promotion ladder. The ladder is documented in [QUALITY_SCORE.md](../QUALITY_SCORE.md), and it has exactly three rungs.

**Caught once.** Note it in the PR description. Move on. One catch is a bug, not a class.

**Caught twice.** Write it up in QUALITY_SCORE.md as a numbered session entry. Note that you've now seen it twice. Don't promote. Two is coincidence.

**Caught three+ times across separate sessions.** Promote to mechanical enforcement. Write the script. Add the CI gate. Cross-reference the prior catches in the gate's docstring. The pattern stops being a thing humans catch.

This isn't novel — engineering managers have run this loop forever. What's novel is doing it *out loud, in a file, where the next AI agent can read it*. The next agent doesn't have the prior catches in memory. Without the log, they re-catch the same things, every session, forever.

The "Code clean, docs lag" pattern (receipt 2) recurred 6 times across Sessions 4 through 11 before it got promoted to `scripts/check-docs-updated.sh`. The cost of each pre-promotion catch was ~30-45 minutes. The cost of the post-promotion catch is the CI run — about 3 seconds. The math compounds.

## The five gates currently in solo-edge

Day-1 solo-edge ships with 5 entropy-defense gates wired into CI. Each one is the load-bearing closure of a class that was previously human-attention-dependent.

**1. `scripts/check-docs-updated.sh`** — Behavior-bearing source change without a matching doc update fails the PR. The first gate, promoted Session 11 (2026-05-12) after 6 consecutive sessions catching the same class. Each row in the RULES array maps a source pattern to the docs that must also change.

**2. `scripts/check-doc-content-drift.sh`** — Backticked symbols in docs that don't grep to source fail the build. Walks the mutable doc set (AGENTS, ARCHITECTURE, README, `.claude/rules/`, `docs/runbooks/`), extracts every camelCase/PascalCase identifier inside backticks, checks each against the codebase. Warn-only first, promoted to `--strict` after 4 GREEN sessions. Plus a `DENIED_PHRASES` array for prose-mention drift — phrases describing past system states surviving in current-tense prose (receipts 3 and 6).

**3. `scripts/check-doc-indexes.sh`** — Every `docs/*.md` and `playbooks/*.md` must appear in both `README.md` and the relevant index README. Add a 14th doc, forget to update one of three indexes, CI fails. Added in PR #1 to solo-edge (2026-05-26) after `/devex-review`'s adversarial pass surfaced "three hand-maintained indexes will silently rot" as the highest-probability future entropy.

**4. `scripts/check-e2e-coverage.sh`** — Pro-gated user flows must have a Playwright spec. The REQUIRED list is in the script; CI does presence-only enforcement (it doesn't run the suite — that needs a browser install). Closes the class where a tier-gated feature ships without behavioral coverage.

**5. `lib/firebase/index-manifest.test.ts`** — A Vitest test that asserts bidirectional containment between a `REQUIRED_INDEXES` manifest and `firestore.indexes.json`. Missing index → test fails. Dead index (no consumer) → test fails. This was the closure on receipt 1's 30-minute prod incident. The rule existed; the test made it enforced.

Plus three ESLint chokepoints (`@google/genai` only via the LLM router, `stripe` only via `lib/billing/`, `@/lib/firebase/admin` only via `lib/firebase/repos.ts`) — same compounding principle, different layer.

## What this is NOT

Solo-edge is not autonomous AI shipping code. The human still invokes `/ship`. The human still reads each reviewer's findings. The human still approves the implementer dispatch. The human still reviews the final diff before pushing the PR. The multi-agent pipeline in [playbooks/pr-review-army.md](../playbooks/pr-review-army.md) is leverage on attention, not a replacement for it.

It's also not a tutorial. The 13 reference docs assume you've shipped real software before. They explain conventions that exist *because* something hit; they don't explain TypeScript, or React, or Firebase. If you've never deployed to App Hosting, the docs/05 QA workflow doc won't bridge that gap.

It's not a starter template. There's no `npx create-solo-edge`. The supported bootstrap is `git clone` + `scripts/init.sh /path/to/new-product`. Adopters take the conventions, fill in their own product specifics, and run it. Receipt 6 is the receipt that proves this matters — solo-edge's own template files drifted because nothing in the template ran the gates against itself. The fix wasn't more templates; it was running the same gates the template ships.

## What's still hard

Three things solo-edge doesn't solve.

**AI-reviewer hallucination.** Receipt 4 measures the rate at 47%. The discipline ("quote the motivating line before treating any finding as real") helps, but it doesn't eliminate the problem. Multi-pass review is high-signal pass 1, moderate pass 2, net-negative pass 3+. Until AI reviewers can verify their own claims against current source state, the verification burden stays on humans. The pre-emit verification gate in the review skill (force confidence to 4-5 if the motivating line can't be quoted) is the best closure I have, but it suppresses false positives at the cost of also suppressing genuine subtle catches.

**Upgrade path for v2 of conventions.** PR #2 to solo-edge added `init.sh --refresh` plus a version stamp in the copied CLAUDE.md (`<!-- bootstrapped from solo-edge@<sha> on <date> -->`). That's the rough sketch. The harder problem: a v1 adopter has now customized their docs; a v2 of solo-edge ships with stricter rules; the adopter has to diff against upstream. There's no `solo-edge upgrade` command yet. The `--refresh` flag overwrites with per-file confirmation prompts, which is half the answer.

**Runbook-vs-mechanical tradeoff.** Some classes can't be promoted to mechanical gates without becoming intrusive. Receipt 7 (the Firestore index deploy race) lives in a runbook (`docs/runbooks/firestore-index-deploys.md`) because the right answer is `firebase deploy --only firestore:indexes --wait` BEFORE the consuming code merges — but that's a deploy-time human discipline, not something a pre-merge gate can enforce. The runbook closes the class; the gate doesn't exist; the discipline depends on the deployer reading the runbook at the right moment.

## How to try it

```bash
git clone https://github.com/ivanliu1989/solo-edge ~/.solo-edge
~/.solo-edge/scripts/init.sh ~/code/my-new-product
cd ~/code/my-new-product && cat CLAUDE.md
```

Open Claude Code in `~/code/my-new-product` and the conventions auto-surface as you work.

Then read [RECEIPTS.md](../RECEIPTS.md). If three or more receipts feel familiar — if you've been the one debugging the 30-minute prod 500, the one chasing the doc reference that doesn't grep, the one wondering whether the AI reviewer's third-pass finding is real or a hallucination — solo-edge is what closed those for me. The conventions are MIT-licensed; copy whatever's useful.

The repo lives at [github.com/ivanliu1989/solo-edge](https://github.com/ivanliu1989/solo-edge). The product it was distilled from lives at [leapedge.app](https://leapedge.app). If you find solo-edge useful, I'd love to know what you built. If a receipt resonates so much that you want to share your own, even better — that's the next layer of the compounding loop, and it doesn't work without other people running it too.
