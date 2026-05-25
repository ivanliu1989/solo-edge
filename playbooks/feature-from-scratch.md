# Feature from scratch

End-to-end walkthrough of building a new feature, from idea → merged PR. Concrete example using the leapedge-clip "share daily report" feature as the case study.

## Phase 0: Idea (you bring the spark)

```
"I want users to share their daily-signal page with friends."
```

That's the spark. From here, **don't open the editor**. Use `/office-hours` first.

## Phase 1: /office-hours (30 min)

```
> /office-hours
```

Six diagnostic questions, smart-skip. For "share daily report":

- **Q1 (what problem):** "Users want to send their thesis to peer traders for feedback"
- **Q2 (why now):** "Two users asked in DMs this week"
- **Q3 (what does success look like):** "10% of paying users mint a share link per month"
- **Q4 (skip data discovery):** "I want to skip — just give me the plan"
- **Q5/Q6 smart-skipped**

The output is a 1-page brief. Save it. It becomes Phase 2's input.

## Phase 2: /autoplan (45-90 min)

```
> /autoplan
```

The skill walks through:

1. **Design proposal** — what's the data model, the routes, the UI shape
2. **CEO review** — strategy fit, business risk, scope check
3. **Design review** — UX flow, a11y, mobile considerations
4. **Eng review** — architecture, dependencies, testing strategy
5. **DX review** — naming, documentation, downstream maintenance
6. **(Optional) Outside voice via Codex** — cross-model consensus

Output: a plan file at `~/.gstack/projects/<slug>/<user>-<branch>-design-<feature>-<timestamp>.md`.

The plan for "share daily report" came out as:

```
SCOPE
- Add sharedReports/{token} top-level collection
- POST /api/share/daily — auth-gated mint, idempotent on (uid, reportDate)
- DELETE /api/share/daily/[token] — revoke
- /share/d/[token]/page.tsx — public route, noindex/nofollow
- /share/d/[token]/opengraph-image.tsx — social card
- ShareReportButton component on /today
- ShareReportButton component on /history/[date]
- PublicLinksSection on /settings — list active shares + revoke
- E2E spec e2e/share-public.spec.ts

DATA MODEL
SharedReportDoc:
  - token: string (12 base62 = 71 bits)
  - uid: string
  - reportDate: string
  - reportPath: string (lookup back to the user's daily report)
  - snapshot: SerializedDailyReportDoc (frozen at mint time)
  - createdAt: Timestamp
  - revokedAt: Timestamp | null
  - viewCount: number

SECURITY
- Server-only collection (allow read, write: if false)
- Token is the access credential
- isValidShareToken() validates shape before any read
- Rate-limit 10/min on the mint route

a11y
- "Copied" confirmation via aria-live
- Popover dismisses on click-outside + Escape
- Trigger label flips to "Copied ✓" for 1.5s

DOCS
- AGENTS.md additions: route, component, collection
- .claude/rules/sharing.md (new file)
- ARCHITECTURE.md: add to "non-obvious decisions"
```

## Phase 3: Branch + Implementation (60-180 min, depends on feature)

```bash
git checkout -b feat/share-daily-report-2026-05-XX
```

Keep the plan file open in a split. Implementation order matches the plan:

1. **Types first** (`lib/firebase/types.ts`) — add `SharedReportDoc` shape. Run typecheck immediately to catch any conflicts.
2. **Repos** (`lib/firebase/repos.ts`) — `mintOrGetShareToken`, `revokeShare`, `getSharedReport`, `incrementShareViewCount`, `listUserShares`. Add to test suite.
3. **Helpers** (`lib/share/token.ts`) — `generateShareToken`, `isValidShareToken`. Unit tests as you write.
4. **Routes** (`app/api/share/daily/route.ts`) — POST + DELETE. Route-handler tests.
5. **Public page** (`app/share/d/[token]/page.tsx`) — Server Component, `notFound()` on invalid/missing/revoked.
6. **OG image** (`app/share/d/[token]/opengraph-image.tsx`) — Vercel-OG.
7. **Settings UI** (`components/PublicLinksSection.tsx` + server action) — list + revoke.
8. **Share button** (`components/ShareReportButton.tsx`) — POST, clipboard, popover.
9. **Wire into pages** — `<TodaysSignalSection shareSlot={<ShareReportButton />} />`.
10. **E2E spec** (`e2e/share-public.spec.ts`) — assert noindex public page renders without auth.
11. **Docs** — add `.claude/rules/sharing.md` + AGENTS.md additions + ARCHITECTURE.md non-obvious-decision.

If you're using continuous checkpoint mode, you'll have WIP commits along the way. `/ship` will squash them.

## Phase 4: /ship (10-20 min)

```
> /ship
```

What `/ship` will catch on this feature:

- **Pre-landing review** — likely flags places where you forgot rate-limiting, missed `aria-live` on a status announcement, didn't set `metadata.robots` correctly on the share page
- **Plan completion audit** — checks every plan item against the diff; if you forgot `PublicLinksSection`, this catches it
- **Coverage audit** — generates tests for any uncovered new code paths
- **Greptile** — third-party review comments triaged automatically
- **Adversarial review** — what could go wrong in production (race conditions on minting, token guessing, leaked tokens via Sentry logs)

Fix issues `/ship` surfaces. Re-run `/ship`. When clean: pushed + PR opened + docs synced automatically.

## Phase 5: Review + merge (15-45 min)

CI runs. Greptile comments arrive. /ship's internal review caught most. Anything new from Greptile gets triaged + replied to or fixed.

Mobile screenshot the share button on iOS Safari — does the copy-confirmation glow? Does the menu dismiss on tap-outside? If yes: ready to merge.

Click Merge. Delete the source branch (or let GitHub do it).

## Phase 6: Post-launch observation (over the next few days)

- **Sentry watches** — any new `site:` tags firing? Especially `site: "POST /api/share/daily"` should be quiet.
- **GA event watches** — `share_clicked` events appearing? Counts roughly match user activity?
- **One-week retro** — adoption matches the office-hours Q3 prediction?

If yes: feature shipped. If no: post-mortem on the prediction gap. This data informs next quarter's `/office-hours` cycles.

## Total time

For "share daily report" (medium-complexity feature): **6-10 hours** total across 1-2 working days. Breakdown:

- /office-hours: 30 min
- /autoplan: 60 min
- Coding: 4-6 hours
- /ship + review + merge: 1-2 hours

Without the loop (just opening the editor and coding): probably the same total time, but the docs would be wrong, the e2e spec missing, the rate-limit forgotten, and the post-launch a11y polish PR would happen 2 weeks later. **The loop frontloads the discipline.**

## When to skip the loop

Skip /office-hours when:
- The feature is already scoped (you have a PR description sketched)
- It's a bug fix
- It's a maintenance / cleanup pass

Skip /autoplan when:
- The work is a single-file class change
- /ship will run pre-landing review anyway and that's enough
- You're hotfixing production

Skip /ship NEVER. Even for hotfixes — /ship's coverage audit catches the test you forgot. Skipping /ship is how shipping discipline dies.
