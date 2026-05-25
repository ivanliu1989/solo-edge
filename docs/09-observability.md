# 09 — Observability

Sentry + GA4 + Cloud Logging. The minimum viable stack for a solo product that won't surprise you at 3am.

## Sentry — exception capture

Two SDKs, two contexts:

- `instrumentation.ts` — Node.js / Server Components / route handlers
- `instrumentation-client.ts` — browser
- Cloud Functions get their own init in `functions/src/index.ts`

```typescript
// instrumentation.ts
import * as Sentry from "@sentry/nextjs";

export async function register() {
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    release: process.env.SENTRY_RELEASE ?? process.env.K_REVISION,
    tracesSampleRate: 0.1,
    profilesSampleRate: 0.1,
  });
}

export const onRequestError = Sentry.captureRequestError;
```

`K_REVISION` is auto-injected by Cloud Run (Cloud Functions Gen 2 + App Hosting both run on Cloud Run) to the current revision id. Every captured event is tagged to a specific deploy.

## The facade pattern

`lib/observability/sentry.ts` — wraps Sentry so the rest of the code uses one import:

```typescript
import * as Sentry from "@sentry/nextjs";

export function captureException(
  err: unknown,
  context: { site: string; [key: string]: unknown },
): void {
  if (!process.env.SENTRY_DSN) return; // no-op in local dev
  Sentry.captureException(err, { extra: context, tags: { site: context.site } });
}

export function captureMessage(
  msg: string,
  level: "info" | "warning" | "error",
  context: { site: string; [key: string]: unknown },
): void {
  if (!process.env.SENTRY_DSN) return;
  Sentry.captureMessage(msg, { level, extra: context, tags: { site: context.site } });
}
```

**Every capture must have a `site:` tag.** It's the only practical way to navigate Sentry triage. Examples:

- `site: "runAnalysis"` — pipeline outer catch
- `site: "POST /api/analyze"` — route handler
- `site: "getCurrentUserWithProfile"` — session helper fallback
- `site: "buildDailyReports.perUser"` — cron inner catch
- `site: "fetchCaptions.youtubei"` — per-library captions failure

When triaging a Sentry issue, the `site:` tag tells you the owning catch in 5 seconds without re-reading the stack.

## Per-site severity split

Some catches are expected operational noise (declined payments, rate-limited captions, popup-cancelled-by-user). These get `captureMessage(..., "info", ...)` not `captureException`. Reserves the exception queue for real bugs.

Real examples from leapedge-clip:

| Site | Why info-level |
|------|----------------|
| `fetchCaptions.youtubei` (throw path) | YouTube routinely 403s from Cloud Run IPs; structural, not a regression |
| `invoice.payment_failed` | Declined cards fire on every dunning event; expected at any payment scale |
| `SignInForm.onGoogle.popupFallback` | Safari/in-app-browsers block popups; pattern is "fall back to redirect" |

The default is `captureException`. Only downgrade to `captureMessage("info")` when the alert is noise you can't act on.

## The user-mistake skip list

Don't capture user mistakes to Sentry. They become alert fatigue.

```typescript
const USER_MISTAKE_CODES = new Set([
  "auth/wrong-password",
  "auth/invalid-credential",
  "auth/user-not-found",
  "auth/email-already-in-use",
  "auth/weak-password",
  "auth/popup-closed-by-user",
]);

// In your sign-in catch:
const code = firebaseAuthCode(err);
if (!code || !USER_MISTAKE_CODES.has(code)) {
  captureException(err, { site: "SignInForm.onEmailSubmit", authErrorCode: code });
}
```

Friendly UI message still appears via `friendlyAuthError(code)`. Sentry just doesn't get notified.

## GA4 — usage telemetry

Three pieces:

1. `<GoogleAnalytics>` — the gtag.js loader, env-gated by `NEXT_PUBLIC_GA_MEASUREMENT_ID`
2. `<GoogleAnalyticsPageView>` — SPA page-view tracker (Next.js doesn't fire full page loads on client navigation)
3. `lib/analytics/track.ts` — thin `gtag()` wrapper with SSR/no-id no-ops

### PII discipline (load-bearing)

- **No uid** in event payloads
- **No email** in event payloads
- **No quote text / user-generated content** in event payloads
- **`page_view` uses `pathname` only, not `pathname + searchParams`** — so `/search?title=...` doesn't leak the user's query
- **Share routes rewrite `/share/d/<token>` → `/share/d/[token]`** before reporting — the token IS the access credential and must never reach Google's logs

### Curated events

Define a short list. Don't fire arbitrary events.

```typescript
const KNOWN_EVENTS = [
  "sign_in",          // { method: "google" | "email" }
  "sign_out",
  "analysis_started", // { cached: boolean }
  "subscribe_clicked",
  "action_item_saved",
  "search_submitted",
  "email_subscribed",
  "email_unsubscribed",
  "share_clicked",    // { channel: "copy" | "x" | "linkedin", surface? }
  "checkout_started", // { tier: "pro" | "max", source: "pricing" | "settings" | ... }
  "checkout_completed", // { tier }
] as const;
```

`checkout_completed` fires once from a `<CheckoutSuccessTracker>` component on `/settings` when Stripe redirects back with `?billing=success&tier=...`. The tracker strips both query params via `router.replace` after firing so a refresh doesn't double-emit.

## Cloud Logging

Free with GCP. Your `console.log/warn/error` in Cloud Functions land here automatically. Use for:

- Audit trails (rate-limit denials, unhandled webhook event types)
- Operational state changes (cron cycle start/end, retry attempts)
- Anything that's grep-able but not actionable enough to wake you up

Filter by `severity>=WARNING` for the bedtime view.

## The runbook contract

Every Sentry alert that fires should have a written response. If you don't have one, the alert is wasting your sleep.

For each top-10 Sentry issue, write a 3-bullet runbook:

1. **What it means** (one sentence)
2. **Likely cause** (two sentences max)
3. **What to do** (the one command or one-line fix)

Store under `docs/runbooks/{slug}.md`. Link from the Sentry alert if your plan supports it.

## What you DON'T need at first

- Distributed tracing (OpenTelemetry, Honeycomb) — Sentry's traces + Cloud Logging cover 90%
- Custom dashboards (Grafana, Datadog) — App Hosting / Functions consoles cover the operational view
- Synthetic monitoring (Pingdom, Better Stack) — until you have paying users on a non-trivial SLA
- APM (New Relic, AppDynamics) — overkill for a solo product

## What you NEED before paying users

- Sentry with `site:` tags and a runbook for top-10 issues
- GA4 with the curated event list and PII discipline
- Cloud Logging for cron cycles and webhook events
- A weekly "Sentry zero" practice: aim to leave the inbox empty every Friday

---

Read next: [10-entropy-defense.md](10-entropy-defense.md)
