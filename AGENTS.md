# This is NOT the [framework] you know — TEMPLATE

> **Reading this in solo-edge?** This file is the canonical AGENTS template that `scripts/init.sh` copies into new products. The `{project-name}` / `[framework]` / "ONE PARAGRAPH" placeholders below are intentional — they're filled in per-product.
>
> **Reading this in a new product (copied by init.sh)?** Replace `[framework]` with the framework version that requires this disclaimer (e.g. Next.js 16 — it has breaking changes from 15 that your training data may not know). The point is to tell future AI sessions to read local docs first, not rely on training memory.

# {project-name}

## What This Is

ONE PARAGRAPH. What the product is, who uses it, what it does. Anchor a future AI on the user value before architectural detail. Example from leapedge-clip:

> Personal trading-research tool. User signs in with Firebase Auth, pastes a YouTube URL, and gets a three-stage LLM analysis: key points → trading insights → critique self-review. Insights worth acting on get saved to a per-user trade list. Not financial advice.

## Architecture

ONE PARAGRAPH. The stack at a glance, the auth pattern, the LLM provider, the deploy target. Link to the full ARCHITECTURE.md for layer-by-layer detail.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the data flow, the auth handshake, and the dependency direction.

## Key Directories

This is the longest section. Every directory at the top level gets a one-line description. For non-obvious files inside each directory, name them with their purpose. **The goal: a fresh AI agent reading this section can navigate to any feature without grep.**

Template — fill in for your stack:

- [app/](app/) — Next.js App Router. Route groups: `(app)/` is authenticated, `(admin)/` is privileged read-only. Public pages live at root. Route handlers under `api/`.
- [components/](components/) — Client + server components. Marketing chrome lives in `MarketingHeader` + `MarketingFooter`. App chrome lives in `(app)/layout.tsx` + `MobileTabBar`.
- [lib/firebase/](lib/firebase/) — Server-only Admin SDK ([admin.ts](lib/firebase/admin.ts)), typed repo functions ([repos.ts](lib/firebase/repos.ts)), Firestore doc types ([types.ts](lib/firebase/types.ts)).
- [lib/auth/](lib/auth/) — `getCurrentUser()`, `getCurrentUserWithProfile()`, `requireAdmin()`, `checkRateLimit()`. The session-cookie chokepoint.
- [lib/security/](lib/security/) — `applySecurityHeaders()` for CSP/HSTS/COOP. Called from middleware.
- [lib/llm/](lib/llm/) — Task router, provider adapters, versioned prompts, Zod schemas, pricing.
- [lib/billing/](lib/billing/) — Stripe entitlements, quota helpers, webhook handlers.
- [middleware.ts](middleware.ts) — Edge presence check on session cookie. Real verification in Server Components.
- [firestore.rules](firestore.rules) — Security model: server writes via Admin SDK only.
- [.claude/rules/](.claude/rules/) — Path-specific rules auto-surfaced to the agent.

## Conventions

The hard list. Every convention here closes a known entropy class. Each entry is one paragraph max. Examples from leapedge-clip:

- **Prompt changes bump versions.** Prompts live at `lib/llm/prompts/{task}/v{n}.ts`. The composite version becomes part of the Firestore doc ID — bumping a prompt without bumping `n` would overwrite the prior analysis.
- **All LLM calls go through `runTask()`.** Enforced by ESLint: `@google/genai` may only be imported inside `lib/llm/providers/`.
- **All Stripe SDK imports go through `lib/billing/`.** Enforced by ESLint.
- **All billing state writes go through FOUR helpers in `lib/firebase/repos.ts`**, split on purpose: webhook write (`updateUserBilling`), pre-webhook bootstrap (`setStripeCustomerId`), auto-recovery clear (`clearStaleStripeFields`), manual override (`adminSetUserPlan`). Never reach for `userDoc(uid).set()` on billing fields directly.
- **Pro-only feature gates go through `getUserEntitlement()`.** No inline `user.plan === "pro"` for capability gating.
- **All Firestore reads and writes go through `lib/firebase/repos.ts`.** Enforced by ESLint.
- **Server-only modules import `"server-only"`.** Anything that touches firebase-admin must never enter a client bundle.
- **Middleware is Edge runtime; firebase-admin cannot run there.** Real verification is `getCurrentUser()` in Server Components.
- **Costs are recorded in cents (integers).** Per-tier daily cap on the entitlement.
- **Behavior-bearing source edits require matching doc updates.** CI gate enforces.
- **Pro-gated user flows require a Playwright e2e spec.** CI gate enforces.

## Session Artifacts

State carries across context windows via:

- `feature_list.json` (optional) — Scope contract you maintain by hand. AI may only modify the `passes` field. Seed it on day one if your product has more than ~5 in-flight features.
- `claude-progress.txt` (optional) — Running session log: activity, known issues, next steps. Useful when you're context-switching daily.
- `init.sh` (per-project) — Dev environment startup script you write for your stack (`pnpm dev`, emulators, etc.). Not the same as `solo-edge/scripts/init.sh` which bootstraps a new project from this template.

Use `/context-save` at session end, `/context-restore` at the start of the next — these are the primary state-carrier; the two `.json`/`.txt` files above are belt-and-braces for longer arcs.

## Deeper Context

- [ARCHITECTURE.md](ARCHITECTURE.md) — Layers, data flow, auth handshake.
- [.claude/rules/](.claude/rules/) — Per-area rules.
- [QUALITY_SCORE.md](QUALITY_SCORE.md) — Session-quality log: what entropy was caught and closed each session.
- [docs/](docs/) — Domain-specific playbooks (when added).
