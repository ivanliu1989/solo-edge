# solo-edge

The opinionated solo-builder playbook for shipping high-quality AI-native products with Claude Code.

This is not a starter template you `npx create` from. It's a **distilled set of conventions, scripts, and skill-routing rules** that I copy into every new product — so a fresh repo on day one already has the entropy defenses, design discipline, and shipping loop I'd otherwise re-invent in week six.

## Who this is for

You're one person. You're building a real product (paying users, real money, real downtime cost). You're using Claude Code as your primary collaborator. You can't afford the "code clean, docs lag" rot that kills six-month-old codebases written with AI assistance.

## What's in the box

```
docs/         the 13 playbook docs — start with 00-principles.md
.claude/      project-CLAUDE.md template + per-area rules
scripts/      4 CI gates that close the most common entropy leaks
templates/    canonical files (globals.css, middleware.ts, security-headers.ts, eslint.config.mjs)
playbooks/    daily-routine docs (solo-day, feature-from-scratch, pr-review-army, design-polish-pass)
examples/     real artifacts from a shipped product so the next agent learns from real, not synthetic
```

## The 60-second tour

1. **Set up Claude Code once.** Install gstack + superpowers + ui-ux-pro-max. Set up the global `~/.claude/CLAUDE.md` with no-auto-commit + no-auto-push rules. See [docs/01-claude-code-setup.md](docs/01-claude-code-setup.md).
2. **For each new product, copy.** Copy `CLAUDE.md`, `AGENTS.md`, `ARCHITECTURE.md`, `QUALITY_SCORE.md`, `.claude/rules/*`, `scripts/*`, `templates/*` into the new repo's root. Fill in the templates.
3. **Build via the shipping loop.** `/office-hours` for ideas → `/autoplan` for plans → code → `/ship` for PRs. See [docs/03-shipping-loop.md](docs/03-shipping-loop.md).
4. **Defend against entropy.** Wire the 4 CI gates from day one. Each one closes a known entropy class. See [docs/10-entropy-defense.md](docs/10-entropy-defense.md).
5. **Polish before launch.** Run `/design-review` post-implementation. Then ship the polish PR. See [playbooks/design-polish-pass.md](playbooks/design-polish-pass.md).

## Why "edge"

Frontier AI for solo builders. The competitive edge isn't the model — every solo builder has access to the same frontier. The edge is the **discipline around the model**: shipping loops that don't rot, design systems that survive five products, entropy defenses that close before they cost a weekend to debug.

## Source

Distilled from [leapedge-clip](https://github.com/AtaNexus/leapedge-clip) — a Next.js 16 + Firebase + Stripe + Gemini 3.x trading-research tool shipped solo with Claude Code. Every convention in this repo has been used in production, not theory.

## License

MIT. Copy whatever you want. If you find this useful, let me know what you built.
