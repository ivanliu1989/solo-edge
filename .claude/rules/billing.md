# Billing (Stripe) Rules

All plan state writes flow through ONE choke point: webhook handler at `app/api/stripe/webhook/route.ts` dispatching to pure handlers in `lib/billing/webhook-handlers.ts`.

- **All Stripe SDK imports go through `lib/billing/`.** Enforced by ESLint: `stripe` import restricted outside `lib/billing/` and `app/api/stripe/`. The `stripe-client.ts` lazy singleton is the single `new Stripe(...)` site.
- **All entitlement reads go through `getUserEntitlement()`** in `lib/billing/entitlements.ts`. No inline `user.plan === "pro"` for **capability gating**. The entitlement struct is the contract.
- **Inline `plan === "pro"` is sanctioned for subscription-STATE UI ONLY** (distinct from capability gating). Four legitimate sites: checkout `already_subscribed` gate, pricing CTA branching, settings billing badge, admin user list badge. Rule of thumb: "would the user feel misled if this surface treated them as free?" Yes → inline `plan === "pro"` is correct.
- **Dunning state downgrades entitlement, not `plan`.** `past_due`/`canceled`/`incomplete` → entitlement is free, but `plan` stays at "pro" until `customer.subscription.deleted` fires. Only `active`/`trialing` unlocks paid.
- **All four Stripe routes read UserDoc via `getUserDocOrNull(uid)`** from repos.ts. Single read, extract fields via optional chaining. Webhook folds `lastWebhookAt` + `subscriptionStatus` from the same snap.
- **All billing field writes go through FOUR helpers in `lib/firebase/repos.ts`, split on purpose:**

| Helper | Caller | What it writes |
|--------|--------|----------------|
| `updateUserBilling(uid, patch, eventCreatedAt)` | Only webhook handlers | Stamps `lastWebhookAt` from `event.created` |
| `setStripeCustomerId(uid, customerId \| null)` | Only `/api/stripe/checkout` | Pre-webhook bootstrap; leaves `lastWebhookAt` undefined |
| `clearStaleStripeFields(uid)` | All `/api/stripe/*` routes | Clears all 5 Stripe-side fields atomically on `resource_missing` |
| `adminSetUserPlan(uid, plan, subscriptionStatus)` | Only admin plan-mutation form | Manual override; leaves `lastWebhookAt` undefined |

  Route handlers, Server Components, Cloud Functions MUST NOT call `userDoc(uid).set()` directly on billing fields. Pick the right helper based on context.

- **`lastWebhookAt`-leaves-undefined pattern is load-bearing.** When a real webhook arrives later, `isStaleWebhook` returns false (missing `lastWebhookAt`) and processes normally. Stamping "now" would block legitimate webhooks.
- **Webhook idempotency is `lastWebhookAt`-based**, stamped from Stripe's `event.created` (NOT server time). Out-of-order events can't clobber fresher state. Replay-safe. Granularity 1 second (Stripe `event.created` is unix seconds).
- **`applySubscriptionUpsert` runtime-guards Stripe's `status` against literal union.** Unknown statuses (e.g. future `"frozen"`) `console.warn` and skip — never throw to Stripe (would trigger ~5 days of retries). Next event likely lands a known status; otherwise ship a fix.
- **`applyInvoicePaymentFailed` only transitions to `past_due` from `active`/`trialing` baseline.** First-charge-failures leave `subscriptionStatus="incomplete"`; the follow-up `customer.subscription.updated` lands correct state. Skip the write entirely when current status isn't healthy — don't clobber `incomplete` with `past_due`.
- **Webhook route MUST use `req.text()` for raw body.** `req.json()` mutates whitespace, breaks HMAC. Signature verification IS the auth — no separate session check.
- **Webhook route is intentionally public** (not in middleware's protected list). 200 ack means "processed or intentionally ignored" (orphan customer, stale event, unknown event type → all 200 with descriptive body). 500 means "retry" → Stripe backs off exponentially up to ~5 days. Unhandled event types `console.log` (NOT `captureException`) — Sentry reserved for failures.
- **`invoice.payment_failed` uses `captureMessage("info", ...)`, not `captureException`.** Dunning events fire on every declined card; would noise-flood Sentry. INFO-level keeps signal without alert pressure.
- **`resolveUidForEvent`'s customer-id fallback Firestore query is wrapped in its own try/catch.** A throw there would propagate to the route's outer catch tagged as the route's `site:` — wrong triage path. Inner catch tags `site: "resolveUidForEvent.customerQuery"` and returns null (caller 200-acks).
- **Subscription `metadata.firebaseUid` is the uid contract.** Set during Checkout in `subscription_data.metadata.firebaseUid` + `customer.metadata.firebaseUid` (defensive secondary). Webhook reads via `resolveUidForEvent()`. Invoice events lack subscription metadata; fallback is `usersCol.where("stripeCustomerId", "==", customer)`.
- **`stripe.customers.create` MUST pass `idempotencyKey: \`customer-create:${uid}\`.`** Two concurrent checkout POSTs would otherwise mint duplicate Customer objects. Rate-limit (5/min) doesn't close this window because limit > 1.
- **All three /api/stripe/* routes auto-recover from `resource_missing`.** Test/live mode separation, customer wiped in dashboard, etc. Use the shared `isStripeResourceMissing()` detector and `clearStaleStripeFields(uid)` helper. Checkout falls through to fresh-mint; portal/upgrade return 404 + `redirectTo: "/pricing?stripe=cleaned"` so UI explains the cleared state.
- **`clearStaleStripeFields(uid)` clears ALL 5 fields together** (`stripeCustomerId`, `stripeSubscriptionId`, `currentPeriodEnd`, `trialEndsAt`, `lastWebhookAt`). Written by same lineage in production, stale as a group.
- **Tier-change paths — three distinct, do not collapse:**
  - Free → Pro/Max + grandfathered Pro → Max: `/api/stripe/checkout` (Checkout in `mode=subscription`)
  - Real Pro → Max: `/api/stripe/upgrade` (`subscriptions.update` with proration, keeps same sub object, preserves coupons)
  - Cancel / payment-method / invoice history / downgrade: Billing Portal via `ManageBillingButton`
  Never use Checkout for an existing-sub tier change (mints duplicate sub, double-charges). Never use upgrade from a grandfathered user (no `stripeSubscriptionId`, 404s).
- **`subscriptions.update` for upgrade passes `idempotencyKey: \`subscription-upgrade:${uid}:${subId}:${target}:${itemId}\``.**
- **API-version-vs-field-location warning:** bumping the Stripe API pin past `2025-03-31` requires moving `subscription.current_period_end` to `subscription.items.data[].current_period_end`. Two call sites read this — change them in lockstep. Inline `FIELD-LOCATION WARNING` comments at each site.
- **Secrets are App Hosting Secret Manager bindings:** `STRIPE_SECRET_KEY`, `STRIPE_PRICE_ID_*_MONTHLY`, `STRIPE_WEBHOOK_SECRET`. No `NEXT_PUBLIC_STRIPE_*` — Checkout is redirect-based.
- **Switching test ↔ live mode is a Secret Manager update, no code change.** Update three secrets, redeploy. Webhook endpoint URL changes per env (test vs live in Stripe Dashboard); rotate `STRIPE_WEBHOOK_SECRET` to match.
- **Per-user daily gates use local-day boundary.** Both `getTodayAnalysisCount(uid, tz)` and `getTodayCostCents(uid, tz)` compute window via `localDayWindow(tz, today)`. Sydney user's quota AND cost cap reset at local midnight. Legacy users without stored timezone fall back to UTC.
- **`getTodayAnalysisCount` counts cached re-fetches too** (re-pasting same URL still costs a quota slot). Otherwise free users could pump unlimited analyses with a few URLs. Enforced in `/api/analyze` BEFORE the cache check; 429 with `error: "tier_quota_exceeded"` + `upgradeUrl: "/pricing"`.
- **`POST /api/subscriptions` enforces BOTH `canSubscribeChannels` AND `channelSubscriptionsCap`.** Boolean gate alone allowed Pro users to subscribe to unlimited channels. Cap check fires AFTER channel resolution, BEFORE Firestore writes. Re-subscribe carve-out (already-active channel passes) preserves idempotent semantics.
- **Server-side cron fan-outs gate on entitlement, not just route handlers.** Bulk-read `UserDoc.plan` + `subscriptionStatus` for every subscriber, filter to `entitlement.canSubscribeChannels === true` BEFORE fanning out paid work. Without this, a Pro→Free downgraded user's legacy active rows would keep triggering server-side LLM spend.
- **`SessionUserWithProfile.plan` defaults to `"free"` on Firestore-read failure, not throw.** Plus in-memory cache fallback so Pro users get last-known-good profile during transient blip instead of seeing free UI. Authoritative `plan` writes happen exclusively from Stripe webhook handler.
