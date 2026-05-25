# templates/

Canonical files from a shipped product (leapedge-clip). Copy into your new project's source tree, then edit specifics.

## What's here

| File | Drop-in location | Edit needed |
|------|------------------|-------------|
| `globals.css` | `app/globals.css` | Brand colors (`--accent`, `--accent-deep`, etc.) |
| `middleware.ts` | `middleware.ts` (root) | `PROTECTED_PREFIXES` to match your route groups |
| `lib-security-headers.ts` | `lib/security/headers.ts` | CSP allowlist (GA, Stripe, your auth provider's iframe) |
| `eslint.config.mjs` | `eslint.config.mjs` (root) | The chokepoint paths (`lib/llm/providers`, `lib/billing`, `lib/firebase`) match your code |
| `firestore.rules` | `firestore.rules` (root) | Collection paths + auth predicates match your data model |

## globals.css — what NOT to remove

These pieces are load-bearing — don't trim them while customizing brand colors:

- **The `[data-theme="light"]` + `@media (prefers-color-scheme: light)` byte-for-byte parity block.** Required so OS-preferred light = explicit-user light. Test this with `app/globals-light-tokens.test.ts` (port from leapedge-clip).
- **`@media (prefers-reduced-motion: reduce)` block at the bottom.** Neutralizes `row-in`, `signal-pulse`, `signal-ring`. WCAG 2.3.3 essentially requires it.
- **The `:where(button, a, [role="button"], summary):focus-visible` rule.** Tailwind preflight strips browser-default outlines; without this rule, keyboard users have no visible focus.
- **`tabular-nums` + `font-feature-settings: "ss01" "cv11" "kern"` on body.** Tabular figures matter for any data-heavy product; cv11 gives the single-storey 'a' that reads as "modern instrumentation."
- **The dotted-grid backdrop (`body::before`).** Subtle texture, defines the instrumentation aesthetic. Remove if you want a different vibe; keep if you want the leapedge look.

## middleware.ts — what NOT to remove

- **`applySecurityHeaders(res.headers)` on BOTH paths** (protected-redirect AND next() pass-through). Security headers must be on every response, not just the redirect.
- **Edge runtime declaration** (`export const runtime = "edge"` is implicit but documented as load-bearing — Node-runtime `proxy.ts` migration forces a cold-start per request).
- **Cookie name `__session`** — Firebase Hosting's allowlisted cookie name. Don't rename.
- **Matcher excluding static assets** (`/_next/static/`, `/favicon`, etc.). Otherwise CSP headers attach to image responses too, which wastes bytes.

## lib-security-headers.ts — what NOT to remove

- **`Cross-Origin-Opener-Policy: same-origin-allow-popups`** — load-bearing for Firebase signInWithPopup. Bare `same-origin` severs `window.opener.postMessage` and Firebase reports `auth/popup-closed-by-user`.
- **`frame-src https://*.firebaseapp.com`** in CSP — signInWithPopup creates an invisible iframe at `<authDomain>/__/auth/iframe`.
- **The full CSP allowlist** documented inline in the file header. Trim only after testing — removing a directive that handles a real third-party can break auth/analytics/payments.

## eslint.config.mjs — what NOT to remove

The three `no-restricted-imports` blocks:

1. `@google/genai` (or your LLM provider SDK) restricted outside `lib/llm/providers/` + `lib/transcribe/`
2. `stripe` restricted outside `lib/billing/` + `app/api/stripe/`
3. `@/lib/firebase/admin` restricted outside `lib/firebase/`

Each one is a chokepoint contract. Disabling any of them lets bypass code through review.

## firestore.rules — what NOT to remove

- **`allow read, write: if false`** on every server-only collection (analyses, transcripts, channels, subscriptions, mail, rateLimits, sharedReports). Admin SDK bypasses rules; clients must be denied. Don't add `allow read: if request.auth != null` to these — that's the failure shape.
- **The denying-by-default pattern.** Last rule in the file should be `match /{document=**} { allow read, write: if false; }`. Without it, a new collection inadvertently inherits permissive defaults.

## What you'll need to add per-project

- `app/page.tsx` (landing) — your own marketing copy
- `app/(app)/layout.tsx` (app chrome) — port from leapedge-clip but customize nav items
- `components/MarketingHeader.tsx` + `components/MarketingFooter.tsx` — brand-specific
- `components/MobileTabBar.tsx` — your nav structure
- `lib/firebase/admin.ts` + `lib/firebase/client.ts` — boilerplate, takes 10 minutes
- `app/sitemap.ts` — your URL list

These are not in templates/ because they require too much per-project customization to be useful as drop-ins. See the docs/ folder for patterns.
