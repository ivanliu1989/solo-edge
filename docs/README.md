# docs/ — reference

13 numbered docs. Each one closes a specific entropy class or codifies a non-obvious pattern. Read in order if you're new; jump by use-case if you're returning.

## Read by progression (first-time read)

00 → 01 → 02 → 03 → 04 → 05 → 06 → 07 → 08 → 09 → 10 → 11 → 12

Each doc ends with a "Read next" footer that chains forward. Following the chain end-to-end is ~90 minutes and gives you the full picture.

## Read by use-case (returning)

| I'm about to… | Read |
|---------------|------|
| Set up Claude Code on a new machine | [01](01-claude-code-setup.md) |
| Bootstrap a new product from solo-edge | [02](02-skills-routing.md) |
| Start a new feature (any size) | [03](03-shipping-loop.md) + [playbooks/feature-from-scratch.md](../playbooks/feature-from-scratch.md) |
| Touch any UI surface | [04](04-design-system.md) |
| Write tests | [05](05-qa-workflow.md) |
| Build a landing / pricing / FAQ page | [06](06-marketing-surfaces.md) |
| Add Stripe / paid tiers | [07](07-billing-patterns.md) + [playbooks/billing-launch.md](../playbooks/billing-launch.md) |
| Add LLM calls | [08](08-llm-pipeline.md) |
| Wire Sentry / GA / runbooks (pre-launch) | [09](09-observability.md) |
| Defend against doc rot | [10](10-entropy-defense.md) |
| Recover from a stacked-PR mishap | [11](11-multi-pr-stacking.md) |
| Get paged at 3am | [12](12-incident-response.md) + [playbooks/stuck-debugging.md](../playbooks/stuck-debugging.md) |

## Read by principle (philosophy)

If you've internalized the ten commandments in [00-principles.md](00-principles.md), the rest of the docs are the operational mechanics behind each one:

| Principle | Mechanic |
|-----------|----------|
| Defend memory | [10](10-entropy-defense.md) — the four gates |
| Mechanical enforcement | [10](10-entropy-defense.md) — promotion ladder |
| Shipping loop is sacred | [03](03-shipping-loop.md) |
| Boil the lake | every doc's "Common mistakes" section |
| Single primary CTA | [04](04-design-system.md), [06](06-marketing-surfaces.md) |
| Trust boundaries | [07](07-billing-patterns.md), [08](08-llm-pipeline.md), `.claude/rules/auth.md` |
| Cost capture | [08](08-llm-pipeline.md), [07](07-billing-patterns.md) |
| Design lives in tokens | [04](04-design-system.md) |
| Frozen-at-mint snapshots | `.claude/rules/sharing.md` |
| Non-obvious decisions are documented | [10](10-entropy-defense.md), all `.claude/rules/*.md` |

## How these docs evolve

Every doc here was once a one-line note. The ones that mattered got expanded; the ones that got caught 3+ times became CI gates. If a section feels missing, that's a signal — either no one's been bitten by it yet, or it's already a mechanical gate so the doc only needs to point at the gate.

See [10-entropy-defense.md](10-entropy-defense.md) for the promotion model.
