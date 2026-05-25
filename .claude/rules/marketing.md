# Marketing / Public-site Rules

Public surfaces are SEO-indexed and share marketing chrome. Authenticated `(app)/` and `(admin)/` groups are explicitly excluded.

- **Every public page renders `<MarketingHeader>` + `<MarketingFooter>`.** Exceptions: `/sign-in` and `/unsubscribe` stay chrome-free (transactional surfaces).
- **All public pages opt out of static rendering via `export const dynamic = "force-dynamic"`.** Required: header CTA reflects auth state via session cookie. Performance cost is negligible for low-traffic pages.
- **Footer carries JSON-LD `Organization` + `WebApplication` schemas.** Per-page additions (FAQPage on /faq) embed inline via `<JsonLd>` component.
- **Sitemap is hand-maintained** in `app/sitemap.ts`. When adding a public page, add an entry; when removing, remove. The test at `app/sitemap.test.ts` asserts the exact URL list so a forgotten update fails CI.
- **`lastModified` is a STATIC per-URL date, not `new Date()`.** Returning today for every URL tells Googlebot to expect changes that never happen, degrades crawl-budget allocation. Bump the relevant date when you materially change the page.
- **`SITE_URL`** (`lib/site.ts`) is the canonical public-site URL. Override via `NEXT_PUBLIC_SITE_URL` for preview channels. Used by sitemap, OG metadata, JSON-LD, per-page canonicals — change in one place.
- **OG image is site-wide by default** (`app/opengraph-image.tsx` at root). Node runtime (not Edge — explicit `runtime = "edge"` causes a Next.js 16 dev-server compile failure on this route while `ImageResponse` itself works fine without it). Per-page OG variants are future work; resist until the marketing surface is large enough.
- **Pricing copy doctrine:** Strike-through pricing is CONDITIONAL on `PROMO_CODE_FOUNDER`. When set, cards show original→discount with code annotation. When null, original price only. **Never write "limited time" for a `duration=forever` coupon** — the phrasing that holds up is "locked in if you subscribe now" or "founder pricing." Launch-special banner (gated on `PROMO_CODE_BETA_FREE`) IS time/quantity-limited and copy reflects that.
- **Disclaimer wording stays aligned with parent brand.** Mirror what your brand-family sites emit so legal voice is consistent.
- **Parent-brand links open in new tab with `rel="noopener noreferrer"`.** Internal links use `next/link` without `target="_blank"`.
- **Sign-in and unsubscribe pages are noindexed.** Both export `metadata.robots: { index: false, follow: false }`. Don't add to sitemap.
- **New public pages must add per-page `metadata` exports.** Title, description, canonical, OG. Title-template inheritance from root layout means `title: "FAQ"` renders as `FAQ · {product}`.
- **Privacy / Terms / Disclaimer are MVP copy, not lawyer-reviewed.** Pre-rollout: founder review for accuracy. Major changes require email notice to account holders per the Terms.
- **Public leaderboard / standalone marketing surfaces** (if applicable) reuse components from the main marketing chrome with optional props (`highlightChannelId`, etc.). Pre-validate query params via regex on the server (`^UC[A-Za-z0-9_-]{22}$` for YouTube channel IDs) before passing to component. Server-render highlight; no client JS for the highlight pass.
- **Quarterly-regenerated content** (e.g. channel-returns leaderboard, market stats): write as JSON consumed at build time. Component returns `null` when array is empty so the section auto-hides between regenerations. Surface `generatedAt` honestly so users see the freshness.
- **a11y on public pages is not optional:**
  - `formatPct` pairs ▲/▼ glyphs with color (WCAG 1.4.1 — color not the only signal)
  - Every `<th>` carries `scope="col"`; sortable columns have `aria-sort` (WCAG 1.3.1)
  - `generatedAt` formatted to day-precision and visible (E-E-A-T + FTC honesty)
  - Methodology details `<details open>` by default — methodology adjacent to performance claim, not buried
