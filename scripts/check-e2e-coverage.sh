#!/usr/bin/env bash
# E2E coverage presence-check.
#
# Promotes "every Pro-gated user flow has a Playwright e2e spec" from
# documented prose (.claude/rules/e2e.md) to a mechanical CI gate.
# Fails the PR if any spec from the required list is missing under
# `e2e/`.
#
# The required list is hard-coded — finite, small, and high-touch
# enough that a separate manifest file would add friction without
# value. When introducing a new Pro-gated surface, append the spec
# filename here AND commit the matching `e2e/<name>.spec.ts`.
#
# Escape hatch: `[skip e2e]` in the latest commit message. Use
# sparingly (rename-only, scaffolding moves, etc.).
#
# Usage:
#   bash scripts/check-e2e-coverage.sh

set -euo pipefail

# Escape hatch — check the most recent commit's message.
last_msg=$(git log -1 --pretty=%B HEAD 2>/dev/null || true)
if echo "$last_msg" | grep -qi '\[skip e2e\]'; then
  echo "[e2e-check] [skip e2e] in commit message — bypassing."
  exit 0
fi

# Required spec files. Each entry MUST be a path relative to the repo
# root. Adding a new gated surface = append a row here AND create the
# spec file in the same commit.
REQUIRED=(
  "e2e/pricing.spec.ts"
  "e2e/today-gate.spec.ts"
  "e2e/channels-gate.spec.ts"
  "e2e/history-clamp.spec.ts"
  "e2e/history-analytics.spec.ts"
  "e2e/billing-section.spec.ts"
  "e2e/share-public.spec.ts"
  "e2e/share-public-trends.spec.ts"
)

missing=()
for spec in "${REQUIRED[@]}"; do
  if [ ! -f "$spec" ]; then
    missing+=("$spec")
  fi
done

if [ ${#missing[@]} -gt 0 ]; then
  echo "[e2e-check] Missing required e2e spec(s):"
  for spec in "${missing[@]}"; do
    echo "  - $spec"
  done
  echo ""
  echo "Pro-gated user flows MUST have a Playwright e2e spec."
  echo "See .claude/rules/e2e.md for the flow inventory and the"
  echo "minimal spec shape. Add the missing file(s) and resubmit."
  echo ""
  echo "Escape hatch (use sparingly): add [skip e2e] to your last"
  echo "commit message."
  exit 1
fi

echo "[e2e-check] OK — all ${#REQUIRED[@]} required e2e spec(s) present."
