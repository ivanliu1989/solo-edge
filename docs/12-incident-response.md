# 12 — Incident response (solo on-call)

You're the only one. There's no engineering manager to delegate to. The playbook has to be short and runnable from a phone if needed.

## The 3am triage tree

```
Sentry alert / user report fires
    │
    ▼
1. CAN YOU REPRODUCE? ──no──► Add monitoring, go back to sleep, triage in morning
    │ yes
    ▼
2. IS IT DATA-LOSS? ──yes──► STOP. Stabilize first. Restore from backup if needed.
    │ no
    ▼
3. IS IT EARNING-LOSS? ──yes──► Disable the broken path (feature flag / route 503)
    │ no                        Fix in calm conditions next session
    ▼
4. IS IT >5% OF USERS? ──yes──► Disable broken path same as above
    │ no
    ▼
5. NOTE IT, GO TO BED. Fix in morning with /investigate.
```

Rule: **at 3am, your goal is to stop the bleeding, not to fix.** Fixing happens with full context, fresh eyes, all the tools.

## What "disable the broken path" looks like

Most products have a few ways to kill a feature without a deploy:

| Mechanism | What it requires | Speed |
|-----------|------------------|-------|
| Feature flag (server-evaluated) | Pre-wired flag check in the route | 30 seconds |
| Stripe Dashboard "Pause subscription" | Stripe Dashboard access | 1 minute |
| GCP / Firebase secret rotation | Console access | 2 minutes |
| Hot patch via commit + deploy | Working `/ship` workflow | 10-30 minutes |
| Database flag flip | Admin SDK script | 1 minute (if scripted) |

Wire ONE of these for each money-critical path before launch. If you don't have it, the 3am page becomes a 3am `/ship` cycle — bad.

## The `/investigate` workflow

When you're awake and ready to fix:

```
/investigate <one-line problem statement>
```

The skill produces:

1. Reproduction recipe (or "couldn't reproduce")
2. Root cause hypothesis (specific file:line)
3. Fix proposal (with side-effect analysis)
4. Test recommendation (regression test for the specific failure)

**Don't fix without root cause.** Symptomatic patches accumulate; root-cause fixes compound. `/investigate` enforces this discipline.

## What goes in a runbook

For each top-10 Sentry issue, a 3-bullet runbook under `docs/runbooks/<slug>.md`:

```markdown
# Stripe webhook signature failure

**What it means:** Stripe sent a webhook with a signature that didn't verify. Either:
1. STRIPE_WEBHOOK_SECRET is stale (rotated by you or someone else)
2. The request body was modified in transit (proxy stripped headers? rare)
3. Test-mode webhook hit a live-mode endpoint or vice versa

**Likely cause:** You rotated the webhook secret in Stripe Dashboard without updating Secret Manager.

**What to do:**
1. `firebase apphosting:secrets:set STRIPE_WEBHOOK_SECRET` with the value from Stripe Dashboard
2. Redeploy: `firebase apphosting:rollouts:create`
3. In Stripe Dashboard, "Resend" the failed events (last 7 days available)
```

Three bullets is the right size. Anything longer becomes a wiki nobody reads at 3am.

## Common incidents (from observation)

### LLM cost spike

**Symptom:** Sentry alert for `daily_cost_cap_exceeded` firing for many users in one day.

**Likely cause:** Your daily cost cap is too low (5x recent traffic) OR a model price changed silently OR a prompt change is consuming more tokens than expected.

**What to do:**
1. `pnpm check:cost-spike` (script you should pre-write) — shows top 10 users by cost today
2. Sample one of their analyses: `pnpm check:analysis-cost <analysisId>` — shows per-call tokens + cost
3. If tokens are up: revert the recent prompt change OR bump the cap
4. If price changed: update `lib/llm/pricing.ts` (model price table)

### Firestore index missing

**Symptom:** Cloud Function logs show `FAILED_PRECONDITION: The query requires an index`.

**Likely cause:** You added a composite query but didn't deploy the index. `lib/firebase/index-manifest.test.ts` should catch this in CI; if it didn't, the manifest wasn't updated.

**What to do:**
1. Click the link in the Firebase error message — it deeplinks to the index-creation form
2. Approve creation; wait 5-15 min
3. ALSO: add the index to `firestore.indexes.json` + `REQUIRED_INDEXES` manifest
4. Deploy: `firebase deploy --only firestore:indexes`
5. Now the manifest test will catch future drift

### Pipeline stuck at status="queued"

**Symptom:** Users report "my analysis isn't starting." Firestore shows docs at status="queued" for >5 minutes.

**Likely cause:** Cloud Function trigger isn't firing. Either:
1. The function crashed before reaching `runAnalysis` (look for the outer-catch capture)
2. The function deployed broken (missing secret, build error)
3. Cloud Functions quota hit (rare but possible)

**What to do:**
1. Check Cloud Functions logs for the affected timestamps
2. If outer-catch capture exists: read the Sentry context, fix root cause
3. If no logs at all for that timeframe: trigger isn't firing. Check function deployment status. Redeploy if needed
4. For stuck docs: `pnpm requeue-stuck-analyses --max-age 1h` (script you should pre-write) — sets `status=failed` with a friendly error so users can retry

### Stripe webhook lag

**Symptom:** User completes Checkout, but their `plan` field doesn't update for >30 seconds.

**Likely cause:** Stripe webhook delivery is delayed (their issue, not yours) OR your webhook endpoint is failing and Stripe is retrying.

**What to do:**
1. Check Stripe Dashboard → Developers → Webhooks → recent deliveries. Are they 200ing?
2. If 500ing: check Sentry for `site: "POST /api/stripe/webhook"` failures
3. If 200ing but plan not updated: check Sentry for `site: "applySubscriptionUpsert"` — maybe `priceIdToTier()` returned null (unknown price id; Stripe Dashboard misconfig)
4. As a one-off, manually update: `pnpm admin:set-plan <uid> pro active`

## The pre-launch incident-prep checklist

Before paying users:

- [ ] Sentry DSN set in production. `instrumentation.ts` + `instrumentation-client.ts` configured.
- [ ] Top-10 Sentry issues each have a runbook under `docs/runbooks/`.
- [ ] One "disable the broken path" mechanism wired for every money-critical path (feature flag, route 503, Stripe pause).
- [ ] Webhook secret rotation procedure documented (Secret Manager update + deploy + Stripe Dashboard resend).
- [ ] Cost cap headroom: today's cap is ≥5x today's typical traffic so a flash crowd doesn't trigger false 429s.
- [ ] Backup strategy: Firestore exports scheduled (or accept "no backup" as a deliberate choice).
- [ ] Phone has the AppHosting / Firebase / Stripe / Sentry consoles bookmarked or app-installed.

## After an incident

Within 48 hours, write a short post-mortem under `docs/post-mortems/<date>-<slug>.md`:

```markdown
# Post-mortem: <slug>

**Date:** YYYY-MM-DD
**Duration:** N minutes (start to user-impact ended)
**User impact:** What broke for users, how many were affected
**Detection:** How did you find out (Sentry alert, user report, your own check)
**Root cause:** The one or two sentences that explain it
**Fix:** What you did
**Prevention:** What gate/runbook/script would have caught this earlier

Optional: a Session N entry in QUALITY_SCORE.md if the pattern is promotion-worthy.
```

Three uses of post-mortems:
1. Closes the entropy loop (turns a one-time incident into a documented class)
2. Builds your own playbook over time (the next similar incident is faster to triage)
3. Shows discipline (useful if you ever onboard someone, sell the product, or audit your own quality)

## What you DON'T need at first

- PagerDuty / OpsGenie — Sentry email + phone notifications are enough at <100 paying users
- Status page (status.yourcompany.com) — until you have an SLA written into a contract
- Multi-region failover — overkill until you have a customer in another region asking for it
- 99.9% SLA — pick "best effort" and a 4xx error budget; promise it explicitly to users so expectations are right

The goal at solo scale is **fewer, simpler incidents**, not **fancier incident infrastructure**.

---

End of docs/. Next: read `.claude/rules/*` for path-specific conventions, then explore `playbooks/`.
