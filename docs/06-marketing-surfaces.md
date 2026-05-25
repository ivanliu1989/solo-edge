# 06 — Marketing surfaces

Landing, pricing, FAQ, how-it-works, changelog, contact, privacy, terms, disclaimer. All public, all SEO-indexed, all share marketing chrome (header + footer).

## The contract

1. **Every public page renders `<MarketingHeader>` + `<MarketingFooter>`.** Exceptions are deliberate (sign-in, unsubscribe are transactional surfaces).
2. **All public pages opt out of static rendering via `export const dynamic = "force-dynamic"`.** Required because the header CTA reflects auth state, which requires reading the session cookie.
3. **Sitemap is hand-maintained.** When you add a public page, add it to `app/sitemap.ts`. A test asserts the exact URL list so a forgotten update fails CI.
4. **`lastModified` is a static per-URL date, not `new Date()`.** Bump the date when you materially change the page. Returning today's date for every URL tells Googlebot to expect changes that never happen, degrading crawl budget.
5. **JSON-LD `Organization` + `WebApplication` ride along on every public page** (via the footer). Per-page additions (FAQPage on /faq) embed inline via a `JsonLd` component.
6. **`SITE_URL` is a single constant** (`lib/site.ts`). Used by sitemap, OG metadata, JSON-LD, per-page canonicals. Override via `NEXT_PUBLIC_SITE_URL` for preview channels.
7. **OG image is site-wide by default.** `app/opengraph-image.tsx` at the root is shared. Per-page OG variants are future work — resist until the marketing surface is large enough to need them.
8. **Sign-in and unsubscribe are noindexed.** Both export `metadata.robots: { index: false, follow: false }`. Don't add to sitemap.
9. **Per-page metadata exports are required.** Title, description, canonical, OG. Title-template inheritance from root layout means `title: "FAQ"` renders as `FAQ · {product}`.
10. **Disclaimer voice matches your brand family.** Mirror what your parent brand's site says so the legal voice is consistent.

## Pricing card conventions

3-card layout (Free / Pro / Max — or your equivalent). Each card:

- Tier label in `terminal text-[0.72rem] uppercase tracking-[0.14em]`
- Price in `display text-2xl flex items-baseline gap-2`
- Strike-through original price (if promo active) via `<s className="text-text-fade text-[1.1rem]"><span className="sr-only">was </span>$8</s>` — the `sr-only "was"` is load-bearing for screen readers
- Marketing anchor ("about one coffee a month", "less than Netflix") under the price
- Feature list as `<ul>` with concise bullets
- Single primary CTA (StartTrialButton, ManageBillingButton, etc.)
- Dunning overlay (past_due, canceled) replaces the CTA with "Fix payment in Settings"

## Promo code model

Two coupons live in Stripe Dashboard concurrently:
- **Founder code** (e.g. 50% off forever) — advertised on /pricing via the `PROMO_CODE_FOUNDER` constant
- **Launch-special code** (e.g. 100% off, capped redemptions) — advertised via the `PROMO_CODE_BETA_FREE` constant

Both codes coexist via `allow_promotion_codes: true` on the Checkout session (Stripe enforces an either-or between pre-attached `discounts` and user-entered codes — picking user-entered enables both to coexist).

When the cap is hit on the launch-special: flip the constant to `null` → banner disappears. When the founder code is retired: flip its constant to `null` → strike-through disappears.

**Never write "limited time" for the founder code** — the discount is `duration=forever` for anyone who uses it. The phrasing that holds up is "locked in if you subscribe now."

## SEO infrastructure files

```
app/sitemap.ts          — hand-maintained URL list
app/robots.ts           — User-agent rules + sitemap pointer
app/opengraph-image.tsx — site-wide OG image (Vercel-OG ImageResponse)
app/icon.tsx            — favicon (programmatic)
```

The sitemap test:

```typescript
// app/sitemap.test.ts
it("includes every expected URL exactly", () => {
  const urls = sitemap().map((row) => row.url);
  expect(urls).toEqual([
    `${SITE_URL}/`,
    `${SITE_URL}/pricing`,
    `${SITE_URL}/how-it-works`,
    // ... full list
  ]);
});
```

A missing URL in this test catches the "I added a new page but forgot the sitemap" mistake.

## Public share pages (if applicable)

If your product has user-shareable URLs (daily reports, dashboards, etc.):

- Server-only collection (Firestore `allow read, write: if false`)
- 12-char base62 token = 71 bits of entropy
- Frozen-at-mint snapshot (re-running synthesis doesn't mutate the share doc)
- Soft-revoke via `revokedAt` timestamp (keep tombstones for audit)
- `metadata.robots: { index: false, follow: false }` on the share page
- OG image at `app/share/d/[token]/opengraph-image.tsx` IS reachable by crawlers — that's the point of sharing

See [.claude/rules/sharing.md](../.claude/rules/sharing.md) for the full pattern.

## Marketing copy doctrine

- **Lead with what the user can do** that they couldn't before. Not the feature, the capability.
- **Anchor pricing in everyday comparisons** ("about one coffee", "less than Netflix") — concrete > abstract.
- **Brand voice is consistent across child products** — match your parent brand's voice if you have one.
- **No corporate language.** "leverages", "enables", "empowers", "delve" — avoid.
- **No AI vocabulary.** "robust", "comprehensive", "nuanced", "multifaceted" — avoid.

## When to update marketing surfaces

- **Pricing changes** → /pricing page + AGENTS.md billing section + .claude/rules/billing.md
- **New tier launched** → all 3 above + e2e spec for the tier gate
- **Beta-freeze exit or new promo campaign** → /pricing constants + launch/producthunt copy + .claude/rules/billing.md
- **New public page** → app/sitemap.ts + sitemap test + relevant docs

The CI gate `scripts/check-docs-updated.sh` tracks `app/pricing/page.tsx` as a behavior-bearing file — changes there require matching doc updates.

---

Read next: [07-billing-patterns.md](07-billing-patterns.md)
