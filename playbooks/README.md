# playbooks/ — daily-routine docs

Where `docs/` is reference, `playbooks/` is procedure. Each file walks through a specific activity end-to-end. Open the one matching what you're doing right now.

## Pick by activity

| File | When to read | Time |
|------|--------------|------|
| [solo-day.md](solo-day.md) | Daily — at session start, or when planning the day | 5 min |
| [feature-from-scratch.md](feature-from-scratch.md) | About to start a new feature; haven't opened the editor yet | 10 min |
| [pr-review-army.md](pr-review-army.md) | `/ship` fired multi-agent findings and you're triaging them | 5 min |
| [design-polish-pass.md](design-polish-pass.md) | After a UI launch; before a Product Hunt push; quarterly otherwise | 10 min |
| [billing-launch.md](billing-launch.md) | Adding paid tiers for the first time, or going test → live on Stripe | 15 min |
| [launch-day.md](launch-day.md) | T-14 days before Product Hunt; re-read at T-3, T-1, and morning-of | 20 min |
| [stuck-debugging.md](stuck-debugging.md) | An hour into a bug with no progress | 5 min |

## The shape of a playbook

Every playbook follows the same structure:

1. **What this is** — one paragraph framing
2. **When to run it** — entry conditions
3. **The workflow** — numbered phases with concrete steps
4. **Common mistakes** — what NOT to do
5. **How this compounds** — what you keep for the next iteration

If you're writing a new playbook, follow that shape.

## When to write a new playbook

Add one when you've done the activity 3+ times and noticed your steps converge. Don't write speculative playbooks — they rot fast and confuse the next reader.

## Relationship to docs/

- **docs/** answers "what's the contract?" → read once, refer back
- **playbooks/** answers "what do I do today?" → read often, evolve over time

The two complement each other. A new feature read might be: `playbooks/feature-from-scratch.md` (procedure) + `docs/03-shipping-loop.md` (contract) + `docs/04-design-system.md` (constraints for UI) + relevant `.claude/rules/*.md` (auto-surfaced).
