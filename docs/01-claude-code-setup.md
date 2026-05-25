# 01 — Claude Code setup

One-time setup for any solo builder using Claude Code. Do this on the laptop you ship from. Takes ~15 minutes manually, ~3 minutes with the script.

## Fast path (recommended)

```bash
bash scripts/setup.sh
```

Idempotent — installs Claude Code (if missing), gstack + superpowers, the global safety rules, and the skill scan paths. Supports `--dry-run` to preview, `--skip-claude-code` if you already have CC, `--skip-superpowers` if you only want gstack.

The script does everything the manual sections below describe. Read the rest of this doc if you want to understand what the script did or if you need to do it by hand.

## Manual path (read for understanding)

## Install Claude Code

```bash
# macOS via Homebrew
brew install anthropic-ai/cc/claude-code

# or via the official installer
curl -fsSL https://claude.ai/install.sh | sh
```

Verify: `claude --version` should report `claude-code-cli v0.x.y`.

## Global ~/.claude/CLAUDE.md — the load-bearing safety rules

This file applies to **every** Claude Code session on this machine, across all projects. Put your hardest non-negotiables here.

```markdown
- Don't do git push and commit automatically
- Don't commit without my approval
- Don't commit before I review
- Do not automatically execute git commit or push
```

These five lines are the difference between "AI made a great PR" and "AI force-pushed over my unmerged work." Set them once. Don't remove them.

Path: `~/.claude/CLAUDE.md` (the tilde is your home directory).

## Install the skill ecosystems

Two skill ecosystems compound especially well:

### gstack (domain-spanning utilities)

```bash
git clone https://github.com/garryslist/gstack ~/.claude/skills/gstack
cd ~/.claude/skills/gstack && ./setup
```

Brings you the daily-driver skills: `/autoplan`, `/ship`, `/qa`, `/qa-only`, `/investigate`, `/office-hours`, `/plan-ceo-review`, `/plan-eng-review`, `/design-review`, `/design-consultation`, `/context-save`, `/context-restore`, `/learn`, `/benchmark`, `/document-release`, `/browse`, `/review`, `/cso`, `/land-and-deploy`.

### superpowers (project-native PR workflow)

```bash
git clone https://github.com/superpowers/superpowers ~/.claude/skills/superpowers
```

Brings you: `/superpowers:requesting-code-review`, `/harness-engineering:harness-entropy`, `/harness-engineering:harness-promote`, `/harness-engineering:harness-session`.

### ui-ux-pro-max (when you want a heavyweight design search)

Install via Claude Code's plugin manager (search "ui-ux-pro-max"). Useful for `/ui-ux-pro-max` which produces a complete design system in one shot from a product description.

## Verify the skills load

Open Claude Code in any directory and type `/`. You should see the slash-command palette populate with the skills above. If not, check `~/.claude/settings.json`:

```json
{
  "skills": {
    "scan_paths": [
      "~/.claude/skills/gstack/skills",
      "~/.claude/skills/superpowers/skills"
    ]
  }
}
```

## Optional: telemetry + proactive suggestions

gstack will prompt you on first run for telemetry preferences. Pick what you're comfortable with. Recommended:

- **Telemetry: anonymous** — helps gstack improve without sending identifying data
- **Proactive: true** — lets gstack suggest the right skill at the right moment (e.g. catches when you ask a bug question and routes to `/investigate`)

You can change these any time:

```bash
~/.claude/skills/gstack/bin/gstack-config set telemetry anonymous
~/.claude/skills/gstack/bin/gstack-config set proactive true
```

## Optional: continuous checkpoint mode

If you work in long sessions and want auto-commits at logical units (with `WIP:` prefix that `/ship` squashes):

```bash
~/.claude/skills/gstack/bin/gstack-config set checkpoint_mode continuous
```

The default is `explicit` — commits only happen when you ask. Pick continuous if you're prone to losing work to interrupted sessions.

## Verify your shell can use the gstack helpers

```bash
~/.claude/skills/gstack/bin/gstack-update-check
# Should print either nothing (up to date) or "UPGRADE_AVAILABLE x.y.z.w a.b.c.d"
```

If `gstack-update-check` is missing, your install didn't complete — re-run `./setup` inside `~/.claude/skills/gstack/`.

## What this gets you

After this setup, every new project you start can:

1. Inherit the global no-auto-commit rules from `~/.claude/CLAUDE.md`.
2. Use any gstack/superpowers skill instantly via the slash menu.
3. Have its own project-level CLAUDE.md (copied from solo-edge's template) that adds project-specific routing on top of the global rules.

**Per-project setup** is in [docs/02-skills-routing.md](02-skills-routing.md). Read that next.

---

Read next: [02-skills-routing.md](02-skills-routing.md)
