# Receipts

Eight specific entropy incidents from leapedge-clip — the private trading-research product solo-edge was distilled from. Each one names what hit, why review missed it, and the mechanical convention that landed in solo-edge to prevent recurrence.

The receipts are sanitized: no customer data, no auth tokens, no Stripe IDs. Commit hashes are 7-char shorthashes; PR numbers are kept for narrative weight. The point is to show *which solo-edge conventions are battle-tested against which specific failures* — not to expose the codebase.

---

## 1. The missing Firestore composite index — every paste returned 500 (2026-05-10)

**What hit.** PR #34 shipped a cost-cap aggregation query:

```typescript
analysesCol(uid).where("createdAt", ">=", start).aggregate(AggregateField.sum("costCents"))
```

Firestore aggregation queries require a composite index covering both the filter field and the aggregated field. The index didn't exist. Every `/api/analyze` on production returned **HTTP 500 with an empty body** until PR #35 deployed the index ~30 minutes later.

**Why review missed it.** The rule existed. `.claude/rules/firestore.md` already said *"add composite indexes to `firestore.indexes.json` when introducing new ordered queries."* Two review rounds on PR #34 focused on the cost-tracking semantics (atomic increment, finalize semantics, retry carry-forward) — not the index manifest. The rule was enforced by human attention, which had a cost-tracking shape in front of it.

**Why tests missed it.** The repos test suite mocked the Admin SDK. Mocks don't enforce Firestore index preconditions. Local dev hit small datasets that sometimes pass without the composite index. Neither layer could have caught this.

**The fix.** PR #35 deployed `analyses(createdAt ASC, costCents ASC)` and shipped a defensive client-side parse — `PasteAnalyzeForm` now reads `res.text()` first, then attempts `JSON.parse`, so a future non-JSON 500 surfaces `<message> (HTTP <status>)` instead of "Unexpected end of JSON input."

**The convention that birthed in solo-edge.** `lib/firebase/index-manifest.test.ts` — a Vitest test that asserts bidirectional containment between a `REQUIRED_INDEXES` manifest (each row names the call site) and `firestore.indexes.json`. Missing index → test fails CI. Dead index (no consumer) → test fails CI. The rule is now a gate, not a hope. One of solo-edge's five entropy-defense gates ([docs/10-entropy-defense.md](docs/10-entropy-defense.md)).

**The lesson.** *Documented rules enforced by human attention are unenforced rules.* The next prod-impacting harness violation came along; the next one didn't, because the test catches it.

---

## 2. "Code clean, docs lag" — caught 6 times, then promoted to a CI gate (2026-05-08 → 2026-05-12)

**What kept happening.** Six consecutive entropy scans across Sessions 4, 7, 8, 9, 10, 11 found the same pattern:

- Code shipped cleanly — chokepoints intact, tests green, lint passing
- AGENTS.md, `.claude/rules/`, ARCHITECTURE.md lagged behind
- Each catchup cost ~30-45 minutes manually

Each session ended with a quick-fix list of "5-10 doc inconsistencies caught and closed in this run." Each session ended with the same recommendation: *promote the docs-update check from a PR template nudge to a mechanical CI gate.*

**Why catchup-after-the-fact was the wrong move.** The next AI session reading the (stale) docs makes the wrong call, then ships a regression. The cost of a stale doc compounds — six months from now nobody remembers the convention that birthed the rule.

**The mechanical fix.** Session 11 (2026-05-12, commit `e2abce7`): `scripts/check-docs-updated.sh` fails CI when a behavior-bearing source file changes without a matching doc update. Each row in the RULES array names a source pattern + the docs that must also change.

**First validation.** Session 12 ran on PR-B — 34 commits, 11,888 LOC, multi-doc-impacting. The gate fired mid-implementation, forcing the docs sweep to land *in the same PR* rather than as a follow-up. The 6-session "code clean, docs lag" streak broke for the first time.

**The convention that birthed in solo-edge.** `scripts/check-docs-updated.sh` — the first of solo-edge's five gates. The "caught 3+ times → promote to a mechanical gate" compounding model starts here. The same model later produced check-doc-content-drift, check-doc-indexes, and the in-code index-manifest test.

**The lesson.** *Three catches across separate sessions is a class.* Two is a coincidence; six is malpractice. The promotion log is in [QUALITY_SCORE.md](QUALITY_SCORE.md).

---

## 3. The single-character typo that lived in five doc files (2026-05-13)

**What was caught.** A function called `maybeSendDailyEmail`. Five doc files — AGENTS.md (×2 lines), ARCHITECTURE.md, `.claude/rules/llm-pipeline.md`, `.claude/rules/functions.md` (×2 in one line) — all referenced it as `maybySendDailyEmail`. An extra "y" before "S."

The actual function name in code was correct. Sentry tags emitted the correct form. Sentry search worked. But the docs lied to anyone grepping them.

**Why it propagated.** *"No one notices a single-character misspelling without grep verification."* Every subsequent doc edit carried the typo forward because each editor pattern-matched on the surrounding prose, not the symbol name. The L3 presence-only `check-docs-updated.sh` gate fired green on every PR — *some* doc was edited — but couldn't see that the symbol in those docs didn't grep to source.

Same session: `ARCHITECTURE.md` referenced `components/HeroInsightCard.tsx`. That component never existed at that path — the original rendering moved to `InsightExpanded.tsx` + `SourcePanel.tsx` in a pre-merge rename whose doc propagation got missed.

**The fix.** Session 16 shipped `scripts/check-doc-content-drift.sh` as the warn-only L3.5 companion. It walks the mutable doc set (AGENTS, ARCHITECTURE, README, `.claude/rules/*.md`, `docs/runbooks/*.md`), extracts every backticked camelCase/PascalCase identifier (4-40 chars, length-bounded, with case-transition shape), and greps for each across `app/ lib/ components/ functions/src/ scripts/ e2e/ middleware.ts instrumentation*.ts`. Zero matches = WARN line.

**Promotion ladder.** Warn-only first (Session 16) → 4 consecutive sessions GREEN (Sessions 22, 23, 24, 25) → promoted to `--strict` CI-blocking (Session 25, 2026-05-25). Same session added a `DENIED_PHRASES` array for prose-mention drift — the first denied phrase encoded a beta-freeze-era prose finding that recurred in 3 separate entropy sweeps.

**The convention that birthed in solo-edge.** `scripts/check-doc-content-drift.sh` — the second of solo-edge's five gates. The "warn-only first, promote when stable" pattern.

**The lesson.** *Presence-only gates miss content drift.* A presence gate asks "was *some* doc edited?" — it can't ask "was the doc edited *correctly*?" The L3.5 companion closes that gap mechanically.

---

## 4. The reviewer hallucination rate measured at 47% (2026-05-14)

**What was measured.** An 8-PR / 24-hour merge burst went through an iterative-review process — 1st-pass / 2nd-pass / 3rd-pass / hand-verification. Cumulative findings raised across all rounds: **17**.

- True positives (real issues that needed fixing): 9
- False alarms (reviewers reading the base branch, misreading operators, hallucinating non-existent code): **8**

**The calibration finding.** Multi-pass review is high-signal on pass 1, moderate on pass 2, net-negative on pass 3+. The false-alarm rate climbs faster than the true-positive rate. Each additional pass adds findings; most are noise. A 4th pass would have produced more false alarms than the 3rd.

**Why this matters for AI-assisted shipping.** The instinct is "more review = better PRs." The measurement says otherwise. AI reviewers hallucinate confidently — they read the wrong file, infer non-existent code paths, and produce findings that don't reproduce. Without a verification discipline, you end up *fixing* phantom bugs.

**The conventions that birthed in solo-edge.**

- The "verify-before-implement" discipline in [playbooks/pr-review-army.md](playbooks/pr-review-army.md) — quote the cited line in the source before treating a review finding as real.
- The pre-emit verification gate in the engineering review skill: *"if you cannot quote the motivating line, the finding is unverified — force confidence to 4-5 (suppressed from main report)."*
- The confidence calibration ladder (1-10) — findings under 7 get caveats; findings under 5 get suppressed.

**The lesson.** *AI reviewers are not human peer reviewers — they hallucinate at scale.* The discipline isn't "trust the model"; it's "make the model show its evidence." The hand-verification pass at the end of multi-round AI review is non-negotiable.

---

## 5. The in-app WebView that silently broke Google sign-in (2026-05-16, PR #83)

**What hit.** Real users on production opened the landing page from Facebook / Instagram / LinkedIn / iOS Mail. Clicked "Sign in with Google." Got a popup that closed itself. Got the Firebase error `auth/popup-closed-by-user`. Never signed in.

**Why this is a class.** In-app browsers (the WebView-based browsers inside FB/IG/LinkedIn/iOS Mail/etc.) block third-party OAuth popups silently. The popup opens and closes in the same render frame because the WebView refuses to grant the popup window's `window.opener` to Google. Firebase reports it as "user closed the popup" — but the user did nothing.

This was invisible in dev, invisible in incognito Chrome, invisible in Playwright. Only real users on real social platforms hit it.

**The fix.** PR #83 catches three Firebase Auth error codes (`auth/popup-blocked`, `auth/cancelled-popup-request`, `auth/operation-not-supported-in-this-environment`) in the sign-in form. On any of them, fall back from `signInWithPopup` to `signInWithRedirect`. Add a mount-time `useEffect` that calls `getRedirectResult(auth)` to complete the flow on return. Without the mount-time handler the user comes back from Google's redirect into a page that doesn't know to finish the sign-in.

Closed the issue. Friendly UI messages now appear via a `friendlyAuthError(code)` mapper. User-mistake codes (`auth/wrong-password`, `auth/invalid-credential`, `auth/user-not-found`) explicitly do NOT capture to Sentry — they would flood the inbox with noise from typos.

**The convention that birthed in solo-edge.** Documented in [.claude/rules/auth.md](.claude/rules/auth.md): *"Google sign-in falls back to redirect. Detect `auth/popup-blocked`, `auth/cancelled-popup-request`, `auth/operation-not-supported-in-this-environment` in the catch."* Also: `Cross-Origin-Opener-Policy: same-origin-allow-popups` is load-bearing — bare `same-origin` severs `window.opener.postMessage` and Firebase reports the same error code in regular Chrome.

**The lesson.** *Consumer-facing auth flows fail in places your test environment cannot see.* Safari, in-app WebViews, aggressive popup blockers, and COOP misconfigurations all produce the same user-facing symptom from different root causes. The mitigation is the same — fall back to redirect — but the detection requires real users on real platforms.

---

## 6. The "3 helpers" / "4 helpers" drift that recurred *inside the entropy-defense template itself* (2026-05-18 → 2026-05-26)

This one is a recursive receipt — the kind of meta-loop that proves the system works.

**Original drift.** Session 19 (2026-05-18, finding I-6) caught a doc inconsistency in leapedge-clip's AGENTS.md: the doc said *"All billing state writes go through THREE helpers in `lib/firebase/repos.ts`"* — then enumerated FOUR (`updateUserBilling`, `setStripeCustomerId`, `adminSetUserPlan`, `clearStaleStripeFields`). The 4th was added when Stripe auto-recovery shipped; the count-word never got updated. Fixed in the same entropy sweep.

**The recursion.** Solo-edge was distilled from leapedge-clip and inherited the same doc structure. In 2026-05-26 — *the audit that produced the current state of solo-edge* — `/devex-review` re-caught the exact same drift in solo-edge's own copies of CLAUDE.md and AGENTS.md. The repo distilling the entropy-defense playbook was leaking entropy of the same class the playbook exists to prevent.

**The fix.** PR #1 to solo-edge (2026-05-26) closed 12 of 13 audit findings — including the helper count. Adversarial review (in the same session) caught more: a private-product sentence leaked verbatim into solo-edge's QUALITY_SCORE template (any new project bootstrapped via `init.sh` would inherit it). Six more fixes shipped.

**The mechanical closure.** Session 25's `DENIED_PHRASES` mechanism inspired the closing fix: solo-edge's `scripts/check-doc-content-drift.sh` now scans CLAUDE.md too, and the strings `"3 helpers in lib/firebase"` + `"three helpers in"` are in DENIED_PHRASES. The next drift back to 3 fails CI.

**The convention that birthed in solo-edge.** [scripts/check-doc-content-drift.sh](scripts/check-doc-content-drift.sh) DENIED_PHRASES — the third gate's prose-drift mode. Plus [scripts/check-doc-indexes.sh](scripts/check-doc-indexes.sh) — the fourth gate — to catch the related class where adding a 14th doc fails to update the 3 hand-maintained README index tables.

**The lesson.** *Eat your own dogfood, including the meta-layer.* The repo that documents entropy defense will drift unless it runs the same gates against itself. solo-edge now does.

---

## 7. The Firestore index that built too slowly — /settings 500'd in production (2026-05-21)

**What hit.** PR #105 shipped a new public-share feature backed by a new `sharedTrends/{token}` collection. The collection had a new composite index `(uid, revokedAt, createdAt DESC)` deployed via the same Firebase project. App Hosting rolled out the consuming query *before* Firestore finished building the index.

`/settings` (which lists each user's active public shares) hit the consuming query. The query returned `FAILED_PRECONDITION: The query requires an index`. The page crashed with a 500. Users with active shares could not load their billing settings.

**The class of failure.** This is the Firestore index race. Index deploys are eventually consistent; consuming-code deploys are immediate. Without the `--wait` flag on `firebase deploy --only firestore:indexes`, the deploy returns immediately and the consuming code rolls forward into an unbuilt index.

**The fix.** PR #108 wrapped both Firestore queries in `PublicLinksSection` with defensive `.catch()` blocks — on failure, degrade to an empty list + `captureException` to Sentry, rather than crash the page. PR #109 codified the deploy order in `docs/runbooks/firestore-index-deploys.md`: *"Deploy indexes BEFORE the consuming code lands in prod. Use `firebase deploy --only firestore:indexes --wait` to block until ready."*

This is the second prod incident in the receipt set rooted in Firestore indexes. The class is not going away — it is structurally how Firestore works.

**The convention that birthed in solo-edge.** The Firestore index manifest pattern in [.claude/rules/firestore.md](.claude/rules/firestore.md): every composite query in repos.ts gets a `REQUIRED_INDEXES` row + a matching `firestore.indexes.json` block + `pnpm test` confirms the manifest matches + `firebase deploy --only firestore:indexes --wait` BEFORE merging the consuming code. Defensive `.catch()` on Firestore reads where a stale index race would crash a UI surface, with explicit Sentry capture.

**The lesson.** *The same class can hit you twice — at the manifest level (Receipt 1) and at the deploy timing level (Receipt 7).* Mechanical gates close the manifest level. Defensive catch + a deploy runbook close the timing level. Both are required.

---

## 8. The multi-agent review-then-implement pipeline that worked (2026-05-24, PR #114)

**What was demonstrated.** PR #114 was the first session-scale demonstration of the full pre-rollout pipeline running end-to-end in a single session:

- **6 dimension reviewers** dispatched in parallel: security / performance / code-quality / SEO / production-readiness / accessibility
- Reviewers surfaced **4 WCAG-A blockers + 7 HIGH items**
- **5 file-partitioned implementer agents** dispatched in parallel to fix
- Zero file-conflict between implementers
- Zero blocking review rejection from the second-pass code-quality reviewers
- Tests / tsc / lint stayed green throughout
- PR shipped clean

13 files changed, +180/-65. The implementer wave finished in approximately the same wall-clock time as a single-threaded human pass would have taken for one of the 5 file partitions.

**Why this matters.** The interesting metric is not "AI can fix bugs" — it is "AI can fix bugs *concurrently without stepping on its own toes*." The file partition is what makes it work. Each implementer agent gets a non-overlapping file set. They do not see each other's work. They do not merge each other's diffs.

**What this is not.** This is not autonomous AI shipping code. The human invokes `/ship`, the human reads each reviewer's output, the human approves the implementer dispatch, the human reviews the final diff before pushing the PR. The multi-agent pipeline is leverage on attention, not a replacement for it.

**The convention that birthed in solo-edge.** [playbooks/pr-review-army.md](playbooks/pr-review-army.md) — when to dispatch which specialist, how to read the consensus table, when to override findings, when to ask the user. The file-partition discipline. Adaptive gating: after a specialist returns 0 findings across 10+ dispatches it auto-gates ("auto-gated" — security and data-migration are exceptions, they always run when in scope).

**The lesson.** *The interesting frontier is not "can AI do the thing" — it is "can N AI agents do parallel work without conflicting."* The answer is yes, with the right structural discipline (file partitions, fresh context per agent, no cross-agent visibility). Solo-edge documents the structural discipline.

---

## What these eight receipts have in common

Every one of them is a specific incident or measurement, with a specific cost, that produced a specific mechanical convention now shipped in solo-edge. None of them are "best practices we should adopt." All of them are *receipts of things that already hit*.

The compounding model is documented in [QUALITY_SCORE.md](QUALITY_SCORE.md): caught once = note it; caught twice = pattern; caught three+ times across separate sessions = promote to mechanical enforcement. Each promotion is one less class of bug that depends on human attention to catch.

If you are building solo with AI agents and the experiences above sound foreign, you may be ahead. If they sound familiar, solo-edge is what closed them — not in theory, in production at leapedge.app.
