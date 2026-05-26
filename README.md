# solo-edge

The opinionated solo-builder playbook for shipping high-quality AI-native products with Claude Code.

If you ship with Claude Code / Cursor / Aider doing 60%+ of the keystrokes, this is the harness your AI fleet needs to not drift across sessions, months, and model upgrades.

> **Day-1 receipt.** PR #34 to leapedge-clip shipped a Firestore aggregation query without the matching composite index. Every `/api/analyze` on production returned HTTP 500 for ~30 minutes before the log dive surfaced `FAILED_PRECONDITION`. The rule existed in `.claude/rules/firestore.md` — nothing enforced it. After that incident, every composite query gets a `REQUIRED_INDEXES` row in a bidirectional containment test that fails CI on missing or dead indexes. → Full incident log: **[RECEIPTS.md](RECEIPTS.md)** (8 incidents, 8 conventions, 8 lessons).

This is not a starter template you `npx create` from. It's a **distilled set of conventions, scripts, and skill-routing rules** that I copy into every new product — so a fresh repo on day one already has the entropy defenses, design discipline, and shipping loop I'd otherwise re-invent in week six.

## Quickstart

```bash
git clone https://github.com/ivanliu1989/solo-edge ~/.solo-edge
~/.solo-edge/scripts/init.sh ~/code/my-product
cd ~/code/my-product && cat CLAUDE.md
```

That's it. Open Claude Code in `~/code/my-product` and the conventions auto-surface as you work.

**Read first:** [RECEIPTS.md](RECEIPTS.md) — the 8 specific incidents from leapedge-clip that birthed the conventions in this repo. Decide whether the failure modes resonate before you commit to the playbook.

## Prerequisites

- **macOS or Linux** (Windows: WSL2 works; native Windows untested)
- **bash 4+** (macOS ships 3.2 by default; `brew install bash` for 5.x)
- **git**
- **Claude Code CLI** — install via `bash scripts/setup.sh` (one-shot) or follow [docs/01-claude-code-setup.md](docs/01-claude-code-setup.md)

## Who this is for

You're one person. You're building a real product (paying users, real money, real downtime cost). You're using Claude Code as your primary collaborator. You can't afford the "code clean, docs lag" rot that kills six-month-old codebases written with AI assistance.

## What's in the box

```
docs/         13 reference docs — start with 00-principles.md, then follow the "Read next" chain
playbooks/    7 daily-routine playbooks — pick by what you're doing today
.claude/      project-CLAUDE.md template + 10 per-area rules (auto-surfaced when you touch matching paths)
scripts/      setup.sh (machine bootstrap), init.sh (project bootstrap), 4 doc/coverage CI gates
templates/    5 canonical drop-in files (globals.css, middleware.ts, security-headers.ts, eslint.config.mjs, firestore.rules)
examples/     reserved for anonymized real artifacts (see examples/README.md)
```

### docs/ — read by purpose

| # | Title | When to read |
|---|-------|--------------|
| [00](docs/00-principles.md) | Principles | First. The ten commandments of solo AI building. |
| [01](docs/01-claude-code-setup.md) | Claude Code setup | Once per machine. |
| [02](docs/02-skills-routing.md) | Skills routing | Once per new project. |
| [03](docs/03-shipping-loop.md) | The shipping loop | Memorize. `/office-hours` → `/autoplan` → code → `/ship`. |
| [04](docs/04-design-system.md) | Design system | Before writing any UI. |
| [05](docs/05-qa-workflow.md) | QA workflow | Before writing your first test. |
| [06](docs/06-marketing-surfaces.md) | Marketing surfaces | When building landing / pricing / FAQ. |
| [07](docs/07-billing-patterns.md) | Billing (Stripe) | When adding paid tiers. |
| [08](docs/08-llm-pipeline.md) | LLM pipeline | When adding model calls. |
| [09](docs/09-observability.md) | Observability | Before paying users. |
| [10](docs/10-entropy-defense.md) | Entropy defense | The most important doc. Read at month 1 + 3 + 6. |
| [11](docs/11-multi-pr-stacking.md) | Multi-PR stacking | When you've stacked PRs and one merged onto stale base. |
| [12](docs/12-incident-response.md) | Incident response | Before launch + every 3am page. |

See [docs/README.md](docs/README.md) for a by-use-case index.

### playbooks/ — read by activity

| File | When to read |
|------|--------------|
| [solo-day.md](playbooks/solo-day.md) | Daily — what a productive session looks like. |
| [feature-from-scratch.md](playbooks/feature-from-scratch.md) | When you're about to start a new feature. |
| [pr-review-army.md](playbooks/pr-review-army.md) | When `/ship`'s multi-agent review fires findings. |
| [design-polish-pass.md](playbooks/design-polish-pass.md) | After every major UI launch. |
| [billing-launch.md](playbooks/billing-launch.md) | Pre-launch Stripe rollout. |
| [launch-day.md](playbooks/launch-day.md) | T-14 days through T+72 hours of going public. |
| [stuck-debugging.md](playbooks/stuck-debugging.md) | When you're an hour in and the bug hasn't moved. |

## The 60-second tour

1. **Set up Claude Code once per machine.** Run `bash scripts/setup.sh` — installs Claude Code (if missing), gstack + superpowers skill ecosystems, and the global `~/.claude/CLAUDE.md` safety rules. Idempotent. See [docs/01-claude-code-setup.md](docs/01-claude-code-setup.md) for the manual version.
2. **For each new product, copy.** Run `./scripts/init.sh /path/to/new-product`. Drops in `CLAUDE.md`, `AGENTS.md`, `ARCHITECTURE.md`, `QUALITY_SCORE.md`, `.claude/rules/*`, `scripts/*`, `templates/*`. Then fill in the templates.
3. **Build via the shipping loop.** `/office-hours` for ideas → `/autoplan` for plans → code → `/ship` for PRs. See [docs/03-shipping-loop.md](docs/03-shipping-loop.md).
4. **Defend against entropy.** Wire the 5 gates from day one (4 bash CI scripts + 1 in-code Vitest test). Each one closes a known entropy class. See [docs/10-entropy-defense.md](docs/10-entropy-defense.md).
5. **Polish before launch.** Run `/design-review` post-implementation. Then ship the polish PR. See [playbooks/design-polish-pass.md](playbooks/design-polish-pass.md).
6. **Launch in public.** PH + X + first 72h handling. See [playbooks/launch-day.md](playbooks/launch-day.md).

## Why "edge"

Frontier AI for solo builders. The competitive edge isn't the model — every solo builder has access to the same frontier. The edge is the **discipline around the model**: shipping loops that don't rot, design systems that survive five products, entropy defenses that close before they cost a weekend to debug.

## Source

Distilled from [leapedge-clip](https://github.com/AtaNexus/leapedge-clip) — a Next.js 16 + Firebase + Stripe + Gemini 3.x trading-research tool shipped solo with Claude Code. Every convention in this repo has been used in production, not theory.

## License

MIT. Copy whatever you want. If you find this useful, let me know what you built.
