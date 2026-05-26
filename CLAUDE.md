@AGENTS.md

# Project CLAUDE.md — TEMPLATE

> **Reading this in solo-edge?** This file is the canonical template that `scripts/init.sh` copies into new products. Edits propagate to every future bootstrap — change carefully.
>
> **Reading this in a new product (copied by init.sh)?** Edit the @AGENTS.md include and the skill-routing rules below to match your stack. Everything else stays as-is.

## Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. When in doubt, invoke the skill.

This project layers TWO complementary skill ecosystems:

- **harness-engineering / superpowers** — project-native PR workflow + multi-agent review. Use for shipping, code review, structural quality.
- **gstack** — global tooling layer (`~/.claude/skills/gstack/`). Domain-spanning utilities (planning, design, QA, docs).

When a request matches both ecosystems, prefer the project-native skill. When only gstack matches, invoke the gstack skill.

Key gstack routing rules:

- Product ideas/brainstorming → invoke `/office-hours`
- Strategy/scope → invoke `/plan-ceo-review`
- Architecture → invoke `/plan-eng-review`
- Design system/plan review → invoke `/design-consultation` or `/plan-design-review`
- Full review pipeline → invoke `/autoplan`
- Bugs/errors → invoke `/investigate`
- QA/testing site behavior → invoke `/qa` or `/qa-only`
- Code review/diff check → invoke `/review`
- Visual polish → invoke `/design-review`
- Ship/deploy/PR → invoke `/ship` or `/land-and-deploy`
- Save progress → invoke `/context-save`
- Resume context → invoke `/context-restore`
- Capture session learning → invoke `/learn`
- Performance baseline → invoke `/benchmark`
- Security audit → invoke `/cso`
- Release docs sync → invoke `/document-release`

## Path-specific rules

Path-specific conventions live in [.claude/rules/](.claude/rules/) and are auto-surfaced to the agent when working in matching paths. Read them before touching code in those areas.

| File | Covers |
|------|--------|
| [.claude/rules/nextjs.md](.claude/rules/nextjs.md) | Next.js 16 conventions, async params/cookies, route groups, server actions |
| [.claude/rules/auth.md](.claude/rules/auth.md) | Session cookie pattern, getCurrentUser, rate limiting buckets |
| [.claude/rules/firestore.md](.claude/rules/firestore.md) | Repo helpers, doc shapes, security rules, index manifest |
| [.claude/rules/llm-pipeline.md](.claude/rules/llm-pipeline.md) | Task router, prompt versioning, cost capture, audio fallback |
| [.claude/rules/billing.md](.claude/rules/billing.md) | Stripe checkout/portal/webhook, dunning, auto-recovery |
| [.claude/rules/marketing.md](.claude/rules/marketing.md) | Landing pages, sitemap, JSON-LD, force-dynamic public pages |
| [.claude/rules/e2e.md](.claude/rules/e2e.md) | Playwright spec inventory + CI presence gate |
| [.claude/rules/admin.md](.claude/rules/admin.md) | Admin route group, requireAdmin gate, read-only by default |
| [.claude/rules/functions.md](.claude/rules/functions.md) | Cloud Functions Gen 2, no-throw rule, Sentry captures |
| [.claude/rules/sharing.md](.claude/rules/sharing.md) | Public share tokens, frozen-at-mint snapshots, noindex |

## Quality contract (do not break)

These conventions appear in this repo because each closes a documented entropy class. Read [docs/10-entropy-defense.md](docs/10-entropy-defense.md) for the full rationale.

1. **All code paths that mutate billing state go through 4 helpers in lib/firebase/repos.ts** — `updateUserBilling` (webhook), `setStripeCustomerId` (pre-webhook bootstrap), `clearStaleStripeFields` (auto-recovery), `adminSetUserPlan` (manual override). Inline `set()` calls on user-doc billing fields are banned. ESLint enforces. See [.claude/rules/billing.md](.claude/rules/billing.md) for the full table.
2. **All LLM calls go through `runTask()` in lib/llm/router.ts.** Direct provider SDK calls bypass cost capture + validation. ESLint enforces.
3. **All Firestore reads/writes go through lib/firebase/repos.ts.** Server-only via Admin SDK. ESLint blocks direct admin imports outside lib/firebase/.
4. **Behavior-bearing source edits require matching doc updates.** `scripts/check-docs-updated.sh` fails CI when source-of-truth files change without docs.
5. **Pro-gated user flows require a Playwright e2e spec.** `scripts/check-e2e-coverage.sh` fails CI when a required spec is missing.
6. **No emojis as structural icons.** SVG only. Per [docs/04-design-system.md](docs/04-design-system.md).
7. **Public marketing pages opt out of static rendering via `dynamic = "force-dynamic"`.** The header CTA must reflect auth state.

## Default user instructions (paste into ~/.claude/CLAUDE.md once)

- Don't do git push and commit automatically
- Don't commit without my approval
- Don't commit before I review
- Do not automatically execute git commit or push

These belong in your global `~/.claude/CLAUDE.md`, not in the project file — they apply to every Claude Code session.
