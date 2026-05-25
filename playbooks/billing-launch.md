# Billing launch

The Stripe rollout checklist. Distilled from leapedge-clip's beta → paid transition.

## Phase 0: Decide the tier shape (1 day, mostly thinking)

- **How many tiers?** 1 (just paid) is fine. 3 (free + pro + max) gives upgrade headroom. More than 3 fragments your story.
- **Anchor pricing in comparisons.** "About one coffee a month" for entry-tier. "Less than Netflix" for the top. Don't lead with the dollar amount in copy.
- **Decide what each tier gets.** List capabilities side-by-side. For leapedge-clip:
  - Free: 3 analyses/day, 7-day archive, 10 action items
  - Pro: 20/day, ∞ archive, 10 channel subs, history analytics
  - Max: 100/day, ∞ archive, 50 channel subs, priority pipeline

## Phase 1: Build the entitlement layer (2 days)

Before any Stripe code, build the in-code entitlement struct:

```typescript
// lib/billing/entitlements.ts
export type Plan = "free" | "pro" | "max";

export type Entitlement = {
  tier: Plan;
  dailyAnalysisQuota: number;
  archiveDaysVisible: number;
  canSubscribeChannels: boolean;
  channelSubscriptionsCap: number;
  // ... etc
  dailyCostCapCents: number;
};

const ENTITLEMENTS: Record<Plan, Entitlement> = {
  free: { /* ... */ },
  pro: { /* ... */ },
  max: { /* ... */ },
};

export function getUserEntitlement({ plan, subscriptionStatus }: { plan: Plan | null; subscriptionStatus: SubscriptionStatus | null }): Entitlement {
  if (subscriptionStatus && subscriptionStatus !== "active" && subscriptionStatus !== "trialing") {
    return ENTITLEMENTS.free;
  }
  return ENTITLEMENTS[plan ?? "free"];
}
```

Then refactor every existing gate to go through `getUserEntitlement()`. ESLint can help (search for `user.plan === "pro"` and force migration).

This pays off later: when you add Pro, you change ONE table not 20 callsites.

## Phase 2: Stripe Dashboard setup (1 hour)

1. **Create products + prices** for each paid tier. Monthly subscription. Set the price IDs aside — they go in env vars.
2. **Create coupons:**
   - Founder coupon: `percent_off=50`, `duration=forever`, no `max_redemptions` (unlimited)
   - Launch-special coupon: `percent_off=100`, `duration=forever`, `max_redemptions=20` (or your cap)
3. **Create promotion codes attached to each coupon:**
   - `FOUNDER50OFF` (or similar) → founder coupon
   - `BETAFREE` (or similar) → launch-special coupon
4. **Configure the Billing Portal** (Settings → Billing → Customer portal):
   - Enable "Subscription updates → plan changes" (required for in-app Pro→Max swap)
   - Enable "Cancellation" + "Pause"
   - Allow updating payment method
5. **Set up the webhook endpoint** in Dashboard (Developers → Webhooks):
   - URL: `https://yourdomain/api/stripe/webhook`
   - Events to subscribe: `customer.subscription.created`, `.updated`, `.deleted`, `invoice.payment_succeeded`, `invoice.payment_failed`
   - Note the signing secret — that's `STRIPE_WEBHOOK_SECRET`

## Phase 3: Code the four routes (3-5 days)

In order:

### 3.1 `/api/stripe/checkout`

Mints a Checkout Session. Auto-recovers from stale `stripeCustomerId`. `allow_promotion_codes: true` so users can type any active code. `subscription_data.metadata.firebaseUid` so the webhook can resolve the user.

### 3.2 `/api/stripe/portal`

Mints a Billing Portal session. Auto-recovers from `resource_missing` → 404 + `redirectTo: "/pricing?stripe=cleaned"`. The UI follows the redirect; /pricing renders a one-time banner explaining the cleared state.

### 3.3 `/api/stripe/upgrade`

In-app Pro→Max swap via `subscriptions.update`. Preserves attached coupons (founder pricing follows the user across upgrades). 5/min rate limit.

### 3.4 `/api/stripe/webhook`

The only public Stripe route (signature-verified, no auth). MUST use `req.text()` for raw body. Dispatches to `lib/billing/webhook-handlers.ts`:

- `applySubscriptionUpsert` — handles `created` + `updated` + `deleted`
- `applyInvoicePaymentSucceeded` — handles trial-end + renewal
- `applyInvoicePaymentFailed` — handles dunning (with the "only from active/trialing" guard)

All writes go through `updateUserBilling(uid, patch, eventCreatedAt)` which stamps `lastWebhookAt` from `event.created`.

## Phase 4: Code the UI (2-3 days)

### 4.1 `/pricing` page

3-card layout. Each card branches CTA on user state:
- Signed-out: "Sign in to start"
- Free user: `<StartTrialButton tier="pro|max" />`
- Pro user on Pro card: "You're on Pro · Manage in Settings"
- Pro user on Max card: "Upgrade in Settings"
- Past_due: red "Fix payment in Settings"

Strike-through pricing conditional on `PROMO_CODE_FOUNDER` constant. Launch-special banner conditional on `PROMO_CODE_BETA_FREE` constant.

### 4.2 `/settings` BillingSection

Renders current plan badge with dunning variants ("Pro · payment failed", "Pro · canceled — access until 2026-08-15"). Three branches:
- Free: Upgrade CTAs (StartTrialButton for both Pro + Max)
- Pro/Max active: ManageBillingButton + (for Pro on real Stripe sub) UpgradeTierButton
- Past_due: red banner + ManageBillingButton

### 4.3 UpgradeCard

Shared replacement panel that gated surfaces render in place of locked content. `/channels` shows it for free users; `/history` shows it on the analytics half; `/history/[date]` out-of-window shows it instead of `notFound()` (so users see WHY, not "page doesn't exist").

### 4.4 CheckoutSuccessTracker

Client component on `/settings` that fires `checkout_completed` GA event ONCE when Stripe redirects back with `?billing=success&tier=...`, then strips both query params via `router.replace`. Tier encoded into `success_url` by the checkout route so the tracker doesn't have to remember.

## Phase 5: Tests (1 day)

- **Unit tests** for webhook handlers (`__fixtures__/stripe-events.ts` provides canonical event payloads)
- **Route handler tests** for all four routes
- **E2E spec** `e2e/pricing.spec.ts`: auth-branched (signed-out, free, pro, max)
- **E2E spec** `e2e/billing-section.spec.ts`: tier-gated branches in Settings

## Phase 6: Pre-launch checklist (1 hour)

- [ ] All 3 secrets set in production: `STRIPE_SECRET_KEY`, `STRIPE_PRICE_ID_*_MONTHLY`, `STRIPE_WEBHOOK_SECRET`
- [ ] Webhook endpoint receiving events (Dashboard → Webhooks → recent deliveries → 200s)
- [ ] Stripe in **test mode** while you smoke-test
- [ ] Subscribe with a test card (4242 4242 4242 4242) — does the webhook fire? does the `plan` flip? does `/settings` show the new state?
- [ ] Cancel from Portal — does `subscriptionStatus` flip to `canceled`? does the badge show "access until..."?
- [ ] Trigger a `invoice.payment_failed` via Stripe Dashboard's "Send test event" — does `subscriptionStatus` flip to `past_due`? does the entitlement downgrade in-app? does the daily digest still send (free includes it)?
- [ ] Run `pnpm test:e2e` — all billing specs green

## Phase 7: Switch to live mode (10 minutes)

1. Get the 3 live-mode secrets from Stripe Dashboard
2. `firebase apphosting:secrets:set STRIPE_SECRET_KEY` (etc.) with live values
3. Update webhook endpoint in Dashboard → Webhooks. Rotate the signing secret. Update `STRIPE_WEBHOOK_SECRET`.
4. Deploy: `firebase apphosting:rollouts:create`
5. Subscribe yourself with a real card. Then refund and cancel — you want to verify the dunning + cancel paths work end-to-end with real Stripe.

The auto-recovery from `resource_missing` is your safety net. Any test-mode customer/subscription IDs still in your Firestore will trigger recovery on first contact.

## Phase 8: Day 1 watching (the first 24h post-launch)

- **Sentry watches:** `site: "POST /api/stripe/webhook"` should be quiet. Any failures = immediate triage.
- **Sentry watches:** `site: "applySubscriptionUpsert"` for unknown statuses (Stripe Dashboard config drift sending price IDs you didn't map).
- **Stripe Dashboard:** Recent webhooks all 200? Any 5xx? If yes — your webhook is failing for some events, Stripe will retry for ~5 days but the bug compounds.
- **Adoption signal:** Are `checkout_started` events firing? Are they converting to `checkout_completed`?

## Common day-1 issues

❌ **Webhook returning 500.** Usually `STRIPE_WEBHOOK_SECRET` mismatch. Stripe Dashboard → recent deliveries → click into one → see the response body. If it says "invalid_signature" → secret is stale.

❌ **`already_subscribed` blocking a legitimate user.** Their `stripeCustomerId` points at a test-mode customer that doesn't exist in live mode. Auto-recovery should fire on the next checkout attempt. If it doesn't: `pnpm clear:stale-stripe-customer <uid>` (script that calls `clearStaleStripeFields`).

❌ **Trial conversion fails silently.** Trial ends, `invoice.payment_failed` lands, user keeps Pro access because the `subscriptionStatus` is `incomplete` (first-charge failure). Fix is in `applyInvoicePaymentFailed`'s "only from active/trialing" guard — verify yours is there.

❌ **Founder pricing not "following" through upgrade.** User got 50% off Pro, upgraded to Max, got billed at full Max. The fix: `subscriptions.update` preserves coupons; `Checkout` for new sub does NOT. Make sure your Pro→Max path uses the upgrade route, not Checkout.

## Compounding for next product

After this launch, you have:
- `lib/billing/` — drop-in for the next product
- `.claude/rules/billing.md` — drop-in
- The whole entitlement pattern — drop-in
- The webhook handlers (with `__fixtures__/stripe-events.ts`) — drop-in
- The four routes — drop-in with minimal edits

Each subsequent product's billing launch is closer to "drop in the lib, edit the entitlement table, smoke-test, ship" than "build from scratch." The cost goes from 7-10 days to 2-3.
