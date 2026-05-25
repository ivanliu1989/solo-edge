# 07 — Billing patterns (Stripe)

The patterns that survive contact with production. All distilled from leapedge-clip's Stripe rollout.

## The four primitives

1. **Checkout route** (`/api/stripe/checkout`) — mints a Stripe-hosted Checkout Session URL. Auto-recovers from stale `stripeCustomerId` (test→live mode migration etc.).
2. **Portal route** (`/api/stripe/portal`) — mints a Billing Portal session URL. Auto-recovers, returns 404 + `redirectTo: "/pricing?stripe=cleaned"` when no active sub.
3. **Upgrade route** (`/api/stripe/upgrade`) — in-app tier swap via `subscriptions.update` with proration. Preserves attached coupons.
4. **Webhook route** (`/api/stripe/webhook`) — signature-verified, public, never auth-gated. Handles all `customer.subscription.*` + `invoice.*` events.

## The chokepoint: ONE Stripe singleton

`lib/billing/stripe-client.ts`:

```typescript
import Stripe from "stripe";

let _stripe: Stripe | null = null;

export function getStripe(): Stripe {
  if (!_stripe) {
    _stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
      apiVersion: "2024-12-18.acacia",
    });
  }
  return _stripe;
}

// For test isolation
export function __resetStripeForTests(): void {
  _stripe = null;
}
```

ESLint blocks `stripe` imports outside `lib/billing/` and `app/api/stripe/`. The singleton is the only `new Stripe(...)` site in the codebase.

## Entitlement-driven gating

`lib/billing/entitlements.ts`:

```typescript
export type Plan = "free" | "pro" | "max";

export type Entitlement = {
  tier: Plan;
  dailyAnalysisQuota: number;
  archiveDaysVisible: number;
  canSubscribeChannels: boolean;
  channelSubscriptionsCap: number;
  canReceiveDailyDigest: boolean;
  actionItemsCap: number;
  priorityPipeline: boolean;
  canShare: boolean;
  canViewHistoryAnalytics: boolean;
  dailyCostCapCents: number;
};

const ENTITLEMENTS: Record<Plan, Entitlement> = {
  free: { /* ... */ },
  pro: { /* ... */ },
  max: { /* ... */ },
};

export function getUserEntitlement({
  plan,
  subscriptionStatus,
}: {
  plan: Plan | null;
  subscriptionStatus: SubscriptionStatus | null;
}): Entitlement {
  // past_due / canceled / incomplete downgrade to free
  // while plan stays at "pro" until customer.subscription.deleted lands
  if (subscriptionStatus && subscriptionStatus !== "active" && subscriptionStatus !== "trialing") {
    return ENTITLEMENTS.free;
  }
  return ENTITLEMENTS[plan ?? "free"];
}
```

**No inline `user.plan === "pro"` checks for capability gating.** The entitlement struct is the contract.

**Inline `plan === "pro"` is sanctioned only for subscription-STATE UI** (badges, "you're on Pro" copy, dunning state). Four legitimate sites: checkout `already_subscribed` gate, pricing CTA branching, settings billing badge, admin user list badge.

## Webhook idempotency

`isStaleWebhook(event, lastWebhookAt)` rejects events whose `event.created` (unix seconds × 1000) is older than the recorded stamp. Stripe doesn't guarantee delivery order — without this, an out-of-order `subscription.updated` could overwrite a fresher `subscription.created` write.

```typescript
export function isStaleWebhook(
  event: Stripe.Event,
  lastWebhookAt: Timestamp | undefined,
): boolean {
  if (!lastWebhookAt) return false; // first event for this user
  const eventMs = event.created * 1000;
  const lastMs = lastWebhookAt.toMillis();
  return eventMs < lastMs;
}
```

Replay-safe (same event id processed twice writes the same payload). Granularity is one second (Stripe `event.created` is unix seconds). Two events with identical timestamps tie (`==` → not stale, both processed).

## The 4-helper billing write split

`lib/firebase/repos.ts` exposes EXACTLY four functions that touch billing fields. Direct `userDoc(uid).set()` on billing fields is banned.

| Helper | Caller | What it writes |
|--------|--------|----------------|
| `updateUserBilling(uid, patch, eventCreatedAt)` | Only `lib/billing/webhook-handlers.ts` | Stamps `lastWebhookAt` from `event.created` |
| `setStripeCustomerId(uid, customerId \| null)` | Only `/api/stripe/checkout` | Pre-webhook bootstrap; deliberately leaves `lastWebhookAt` undefined |
| `clearStaleStripeFields(uid)` | All `/api/stripe/*` routes | Clears all 5 Stripe-side fields atomically when `resource_missing` |
| `adminSetUserPlan(uid, plan, subscriptionStatus)` | Only `app/(admin)/admin/users/[uid]/actions.ts` | Manual override; leaves `lastWebhookAt` undefined |

The `lastWebhookAt`-leaves-undefined pattern is load-bearing: when a real Stripe webhook arrives later, `isStaleWebhook` returns `false` (because `lastWebhookAt` is missing) and the webhook processes normally. Stamping a "now" timestamp would block legitimate webhooks.

## Auto-recovery from `resource_missing`

When test-mode and live-mode Stripe accounts get crossed (typical when a project flips from test to live keys), `stripeCustomerId` points at a customer that doesn't exist in the current Stripe environment.

The detector (`lib/billing/stripe-errors.ts`):

```typescript
export function isStripeResourceMissing(err: unknown): boolean {
  return (
    err instanceof Stripe.errors.StripeError &&
    (err as Stripe.errors.StripeError).code === "resource_missing"
  );
}
```

Each route handles recovery:

- **Checkout** validates customer before `already_subscribed` gate; on `resource_missing` clears stale fields and falls through to fresh-mint
- **Portal** on `resource_missing` returns 404 `no_active_subscription` + `redirectTo: "/pricing?stripe=cleaned"`. UI follows the redirect; /pricing renders a one-time success banner explaining the cleared state
- **Upgrade** on `resource_missing` returns 404 `no_subscription` + same `redirectTo`

`clearStaleStripeFields(uid)` clears ALL 5 fields atomically: `stripeCustomerId`, `stripeSubscriptionId`, `currentPeriodEnd`, `trialEndsAt`, `lastWebhookAt`. They're written by the same lineage in production, so stale as a group.

## Tier-change paths (do not collapse)

Three distinct paths. Conflating them double-charges users.

| Path | Use | Mechanism |
|------|-----|-----------|
| Free → Pro / Free → Max | New customer signing up for paid | `/api/stripe/checkout` (`mode=subscription`) |
| Grandfathered Pro → Max | Internal-beta user without real Stripe sub | `/api/stripe/checkout` (gate keys on `stripeSubscriptionId`, not just `subscriptionStatus`, so grandfathered users pass cleanly) |
| Real Pro → Max | Existing paid customer upgrading | `/api/stripe/upgrade` → `subscriptions.update` with proration |

Never use Checkout for an existing-sub tier change (mints duplicate subscription, double-charges). Never use the upgrade route from a grandfathered user (no `stripeSubscriptionId`, route 404s).

## Cancellations + payment-method updates

The Billing Portal handles these. `ManageBillingButton` posts to `/api/stripe/portal`, gets a URL, navigates. Stripe Portal's config in the Dashboard must have "Subscription updates → plan changes" enabled to expose Pro↔Max swaps (one-time setup, pre-rollout).

## Dunning state

`subscriptionStatus="past_due"` (or canceled, incomplete, etc.) downgrades the in-app **entitlement** to free while `plan` stays at "pro" until Stripe fires `customer.subscription.deleted` at period end.

The badge on Settings reads "Pro · payment failed" (not "Free"), so the user sees their real Stripe state. Inline `plan === "pro"` is correct here — the entitlement view would mislead.

## Rate limiting per Stripe route

5 req/min on each:

- `/api/stripe/checkout` (bucket `stripe-checkout`)
- `/api/stripe/portal` (bucket `stripe-portal`)
- `/api/stripe/upgrade` (bucket `stripe-upgrade`)

Webhook is signature-verified, no rate limit (would block legitimate Stripe retries on transient errors).

## Idempotency keys

`customers.create` MUST pass `idempotencyKey: \`customer-create:${uid}\``. Two concurrent checkout POSTs (double-click, two tabs) would otherwise mint duplicate Customer objects.

`subscriptions.update` for upgrade passes `idempotencyKey: \`subscription-upgrade:${uid}:${subId}:${target}:${itemId}\``.

## The "switch test to live" checklist

1. Set the three secrets in Secret Manager (or env): `STRIPE_SECRET_KEY`, `STRIPE_PRICE_ID_PRO_MONTHLY`, `STRIPE_WEBHOOK_SECRET`
2. The webhook endpoint URL changes per environment — rotate `STRIPE_WEBHOOK_SECRET` to match the live-mode endpoint's signing secret
3. The first user signing up after the flip with a stale `stripeCustomerId` triggers auto-recovery → clean slate

No code change. The auto-recovery is the safety net.

## Common mistakes

❌ **Reading webhook body via `req.json()` instead of `req.text()`.** HMAC verification hashes the raw bytes; `req.json()` mutates whitespace, breaks signature.

❌ **Stamping `lastWebhookAt` from manual override.** Blocks the legit first Stripe webhook for that user.

❌ **Using Checkout for existing-sub tier change.** Double-charge.

❌ **Hardcoding `percent_off` in strike-through prices without checking the coupon.** If the coupon changes, the page lies. Solution: keep `PROMO_CODE_FOUNDER` aligned with the actual coupon's `percent_off` via an inline invariant comment, OR query Stripe for the percent at render time.

❌ **Adding `discounts` array to Checkout + setting `allow_promotion_codes: true`.** Stripe rejects with an either-or. Pick one.

---

Read next: [08-llm-pipeline.md](08-llm-pipeline.md)
