# 05 — QA workflow

Three layers, from cheapest to most expensive:

1. **Vitest unit tests** — colocated `*.test.ts`. Runs in seconds. Drives 80% of confidence.
2. **Playwright e2e tests** — spec presence enforced by CI. Run locally via `pnpm test:e2e`.
3. **`/qa` / `/qa-only`** — AI-driven browser interaction. Pre-launch verification.

## Layer 1: Vitest

Colocated tests next to source. Test runner aliases `server-only` to a no-op stub so server-gated modules unit-test cleanly.

### What to test

- **Pure helpers** — date math, ranking, formatters. High ROI per line.
- **Route handlers** — mock all collaborators (session, repos, observability), assert response status + body + Sentry context.
- **Repo functions** — mock Admin SDK, assert correct doc paths + payloads.
- **Server actions** — mock `next/navigation.redirect` to throw, assert via `.rejects.toThrow()`.

### Canonical shapes

Route handler test:

```typescript
// app/api/analyze/route.test.ts
import { describe, expect, it, vi } from "vitest";

vi.mock("@/lib/auth/session", () => ({ getCurrentUser: vi.fn() }));
vi.mock("@/lib/firebase/repos", () => ({ createOrGetAnalysis: vi.fn() }));
vi.mock("@/lib/observability/sentry", () => ({ captureException: vi.fn() }));

describe("POST /api/analyze", () => {
  it("returns 401 when no session", async () => {
    // ...
    const { POST } = await import("./route");
    const res = await POST(req);
    expect(res.status).toBe(401);
  });
});
```

Server action test:

```typescript
// app/(app)/settings/actions.test.ts
vi.mock("next/navigation", () => ({
  redirect: (url: string) => {
    throw new Error(`__redirect:${url}`);
  },
}));

it("redirects to /settings?saved=profile on success", async () => {
  await expect(updateProfileAction(formData)).rejects.toThrow(
    "__redirect:/settings?saved=profile",
  );
});
```

### What NOT to test

- React component render output (too brittle, too low ROI). Use Playwright instead for visible UI.
- Third-party libraries.
- Generated code (Prisma client, gRPC stubs).

## Layer 2: Playwright e2e — presence gate

The CI script `scripts/check-e2e-coverage.sh` fails the PR when required specs are missing. The list of required specs is hardcoded in the script.

```bash
REQUIRED=(
  "e2e/pricing.spec.ts"
  "e2e/today-gate.spec.ts"
  "e2e/channels-gate.spec.ts"
  "e2e/history-clamp.spec.ts"
  "e2e/history-analytics.spec.ts"
  "e2e/billing-section.spec.ts"
  "e2e/share-public.spec.ts"
)
```

**Presence only.** CI does not execute the suite (no browser install). Run locally:

```bash
pnpm dlx playwright install chromium  # one-time
pnpm dev                                # in another terminal
pnpm test:e2e                           # the real run
```

### Helper: authenticated sessions

`e2e/helpers/auth.ts`:

```typescript
export async function signInAs({
  context,
  tier,
}: {
  context: BrowserContext;
  tier: "free" | "pro" | "max" | "pro-past-due";
}) {
  // Mint custom token via firebase-admin
  // Exchange for ID token via Auth REST
  // POST to /api/auth/session for real __session cookie
  // No app-side test-only code path
}
```

`e2e/helpers/firestore-seed.ts` — pre-seed `users/{uid}` with the tier under test. Both helpers are emulator-aware via `FIREBASE_AUTH_EMULATOR_HOST`.

### When to add a new spec

The CI gate's REQUIRED list is your source of truth. When you add a new gated user flow, add the spec to the list. The gate fails until you commit the spec file.

A spec file with `test.skip(...)` only counts as "present." Useful for stubbing in a new gate while writing the implementation.

## Layer 3: /qa and /qa-only

`/qa` opens a browser (via Playwright under the hood), navigates through specified pages, takes screenshots, and reports findings. `/qa-only` skips the fix loop — used inside `/ship` for plan verification.

### When to use /qa

- Pre-launch verification of a public page
- Bug report from a user where you want to reproduce in-browser
- Pre-design-review audit (see what the page actually looks like)

### When to use /qa-only

- Inside `/ship` automatically (you don't invoke directly)
- After deploying a change you want to verify without the AI proposing fixes

### What /qa does well

- Catches visible regressions (layout shifts, missing CTAs, broken images)
- Verifies user flows end-to-end across pages
- Generates screenshots you can attach to a PR

### What /qa doesn't do

- Performance benchmarking (use `/benchmark`)
- Security auditing (use `/cso`)
- Accessibility audit beyond surface issues (use `/design-review` for a11y pass)

## The cost-cap rail (when you have LLM-spending features)

Tests aren't the only verification. For LLM-spending features:

- Per-tier daily cap on the entitlement (`dailyCostCapCents`)
- Enforced at the API boundary AND in-pipeline
- A blown cap returns 429 with a friendly message
- Cost recorded per-call in `llmCalls` subcollection
- Anyone can run `pnpm check:user-cost <uid> <date>` to see today's spend

This is QA at runtime — the same gate that prevents test failure also prevents runaway production cost.

---

Read next: [06-marketing-surfaces.md](06-marketing-surfaces.md)
