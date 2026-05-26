#!/usr/bin/env bash
# init.sh — bootstrap a new solo-edge-style project
#
# Run from inside an empty (or near-empty) directory you want to turn into a
# solo-edge-style codebase. Copies the conventions, rules, scripts, and
# templates from this repo into your target project.
#
# Usage:
#   /path/to/solo-edge/scripts/init.sh /path/to/new-project
#
# Idempotent — safe to re-run if you want to refresh the conventions.

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <target-directory>"
  exit 1
fi

TARGET="$1"
SOLO_EDGE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [ ! -d "$TARGET" ]; then
  echo "Creating target directory: $TARGET"
  mkdir -p "$TARGET"
fi

cd "$TARGET"

# Stop if already a solo-edge project (avoid overwriting existing customisations)
if [ -f "CLAUDE.md" ] && grep -q "solo-edge" CLAUDE.md 2>/dev/null; then
  echo "This directory already appears to be a solo-edge project."
  read -p "Refresh conventions anyway? [y/N] " -n 1 -r
  echo
  [[ $REPLY =~ ^[Yy]$ ]] || exit 0
fi

echo "Copying root files..."
for f in CLAUDE.md AGENTS.md ARCHITECTURE.md QUALITY_SCORE.md; do
  if [ -f "$f" ]; then
    echo "  skipping $f (already exists)"
  else
    cp "$SOLO_EDGE_ROOT/$f" "./$f"
    echo "  copied $f"
  fi
done

echo "Copying .gitignore (merge-safe)..."
if [ -f ".gitignore" ]; then
  echo "  appending missing entries to existing .gitignore"
  # Append only lines not already present
  while IFS= read -r line; do
    if [ -n "$line" ] && ! grep -Fxq "$line" .gitignore; then
      echo "$line" >> .gitignore
    fi
  done < "$SOLO_EDGE_ROOT/.gitignore"
else
  cp "$SOLO_EDGE_ROOT/.gitignore" ./.gitignore
fi

echo "Copying .claude/rules/..."
mkdir -p .claude
if [ -d ".claude/rules" ]; then
  echo "  .claude/rules already exists — skipping (run manually if you want to refresh specific files)"
else
  cp -r "$SOLO_EDGE_ROOT/.claude/rules" .claude/
  echo "  copied .claude/rules/"
fi

echo "Copying scripts/ (CI gates)..."
mkdir -p scripts
for s in check-docs-updated.sh check-doc-content-drift.sh check-doc-indexes.sh check-e2e-coverage.sh; do
  if [ -f "scripts/$s" ]; then
    echo "  skipping scripts/$s (already exists)"
  else
    cp "$SOLO_EDGE_ROOT/scripts/$s" "scripts/$s"
    chmod +x "scripts/$s"
    echo "  copied scripts/$s"
  fi
done

echo "Copying templates/ (you'll merge into source manually)..."
mkdir -p templates
if [ -d "templates" ] && [ -n "$(ls -A templates 2>/dev/null)" ]; then
  echo "  templates/ has content — skipping"
else
  cp -r "$SOLO_EDGE_ROOT/templates/." templates/
  echo "  copied templates/"
fi

echo
echo "Done. Next steps:"
echo "  0. If you haven't already, run $SOLO_EDGE_ROOT/scripts/setup.sh ONCE to install"
echo "     Claude Code + gstack + superpowers on this machine."
echo "  1. Edit CLAUDE.md @AGENTS.md include + skill routing rules"
echo "  2. Edit AGENTS.md to describe THIS project"
echo "  3. Edit ARCHITECTURE.md to describe THIS project's data flow"
echo "  4. Trim .claude/rules/ to match your stack"
echo "  5. Wire scripts/check-*.sh into your CI (.github/workflows/ci.yml)"
echo "  6. Merge templates/globals.css, middleware.ts, eslint.config.mjs into your source tree"
echo "  7. git init && git add . && git commit -m 'chore: bootstrap from solo-edge'"
echo
echo "Reference docs are in $SOLO_EDGE_ROOT/docs/ — start with 00-principles.md"
echo "Daily-routine playbooks are in $SOLO_EDGE_ROOT/playbooks/"
