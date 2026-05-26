#!/usr/bin/env bash
# init.sh — bootstrap a new solo-edge-style project
#
# Run from inside an empty (or near-empty) directory you want to turn into a
# solo-edge-style codebase. Copies the conventions, rules, scripts, and
# templates from this repo into your target project.
#
# Usage:
#   /path/to/solo-edge/scripts/init.sh [--refresh] [--help] <target-directory>
#
# Default behavior is additive — existing files in the target are skipped so
# your customizations are preserved. Use --refresh to overwrite existing files
# with the current solo-edge versions (with a confirmation prompt).

set -euo pipefail

# -------------- arg parsing --------------------------------------------------

REFRESH=0

print_help() {
  cat <<'HELP'
init.sh — bootstrap a new solo-edge-style project

USAGE:
  /path/to/solo-edge/scripts/init.sh [OPTIONS] <target-directory>

OPTIONS:
  --refresh   Overwrite existing files with current solo-edge versions.
              Asks for confirmation before each existing file is overwritten.
              Default: additive (existing files skipped).
  --help, -h  Print this help and exit.

EXAMPLES:
  # Bootstrap a fresh project
  ./scripts/init.sh ~/code/my-product

  # Refresh an existing solo-edge project with the latest conventions
  ./scripts/init.sh --refresh ~/code/my-product

WHAT IT COPIES:
  CLAUDE.md, AGENTS.md, ARCHITECTURE.md, QUALITY_SCORE.md (root templates)
  .gitignore (merge-safe — appends missing lines)
  .claude/rules/ (per-area conventions)
  scripts/check-*.sh (4 CI gates)
  templates/ (5 canonical drop-in source files)

NOTES:
  - Stamps the copied CLAUDE.md with the solo-edge commit SHA so you can
    diff against upstream later.
  - --refresh overwrites everything. Commit your customizations FIRST.
HELP
}

POSITIONAL=()
for arg in "$@"; do
  case "$arg" in
    --refresh) REFRESH=1 ;;
    --help|-h) print_help; exit 0 ;;
    --*) echo "Unknown flag: $arg (try --help)" >&2; exit 1 ;;
    *) POSITIONAL+=("$arg") ;;
  esac
done

if [ ${#POSITIONAL[@]} -lt 1 ]; then
  print_help >&2
  exit 1
fi

TARGET="${POSITIONAL[0]}"
SOLO_EDGE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Capture solo-edge git SHA for version stamping into copied CLAUDE.md.
SOLO_EDGE_SHA="$(cd "$SOLO_EDGE_ROOT" && git rev-parse --short HEAD 2>/dev/null || echo unknown)"
STAMP_DATE="$(date +%Y-%m-%d)"

# -------------- helpers -------------------------------------------------------

# safe_cp — copy with actionable error messages on failure.
# Returns 0 on success, 1 on failure. Caller decides whether to abort or skip.
safe_cp() {
  local src="$1"
  local dst="$2"
  if [ ! -f "$src" ] && [ ! -d "$src" ]; then
    echo "  [init.sh] FAILED to copy: source missing at $src"
    echo "  [init.sh]   Check that solo-edge is cloned cleanly: cd $SOLO_EDGE_ROOT && git status"
    return 1
  fi
  if ! cp "$src" "$dst" 2>/dev/null; then
    echo "  [init.sh] FAILED to copy: $src -> $dst"
    echo "  [init.sh]   Likely cause: permission denied or disk full"
    echo "  [init.sh]   Try: chmod u+w \"$(dirname "$dst")\" && df -h \"$(dirname "$dst")\""
    return 1
  fi
  return 0
}

# should_copy — does the destination need this file?
# Honors --refresh by asking for confirmation per-file when a file exists.
# Returns 0 = copy, 1 = skip.
should_copy() {
  local dst="$1"
  if [ ! -e "$dst" ]; then
    return 0
  fi
  if [ "$REFRESH" = "1" ]; then
    read -p "  $dst exists. Overwrite? [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && return 0 || return 1
  fi
  return 1
}

# -------------- bootstrap -----------------------------------------------------

if [ ! -d "$TARGET" ]; then
  echo "Creating target directory: $TARGET"
  mkdir -p "$TARGET"
fi

cd "$TARGET"

# Detect existing solo-edge project (so the user gets a single up-front
# confirmation rather than per-file prompts on first re-run).
if [ -f "CLAUDE.md" ] && grep -q "solo-edge" CLAUDE.md 2>/dev/null; then
  echo "This directory already appears to be a solo-edge project."
  if [ "$REFRESH" = "1" ]; then
    echo "Running in --refresh mode (will prompt per existing file)."
  else
    read -p "Refresh conventions anyway? [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 0
  fi
fi

echo "Copying root files..."
for f in CLAUDE.md AGENTS.md ARCHITECTURE.md QUALITY_SCORE.md; do
  if ! should_copy "$f"; then
    echo "  skipping $f (already exists)"
    continue
  fi
  if safe_cp "$SOLO_EDGE_ROOT/$f" "./$f"; then
    echo "  copied $f"
  fi
done

# Stamp version line into the copied CLAUDE.md so future you can diff against
# upstream. Idempotent — re-running --refresh updates the line in place.
if [ -f "CLAUDE.md" ]; then
  STAMP_LINE="<!-- bootstrapped from solo-edge@${SOLO_EDGE_SHA} on ${STAMP_DATE} -->"
  if grep -q "^<!-- bootstrapped from solo-edge@" CLAUDE.md; then
    # Replace the existing stamp.
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' "1s|^<!-- bootstrapped from solo-edge@.*|${STAMP_LINE}|" CLAUDE.md
    else
      sed -i "1s|^<!-- bootstrapped from solo-edge@.*|${STAMP_LINE}|" CLAUDE.md
    fi
  else
    # Prepend the stamp as line 1.
    printf '%s\n%s' "$STAMP_LINE" "$(cat CLAUDE.md)" > CLAUDE.md.tmp && mv CLAUDE.md.tmp CLAUDE.md
  fi
  echo "  stamped CLAUDE.md with solo-edge@${SOLO_EDGE_SHA}"
fi

echo "Copying .gitignore (merge-safe)..."
if [ -f ".gitignore" ]; then
  echo "  appending missing entries to existing .gitignore"
  while IFS= read -r line; do
    if [ -n "$line" ] && ! grep -Fxq "$line" .gitignore; then
      echo "$line" >> .gitignore
    fi
  done < "$SOLO_EDGE_ROOT/.gitignore"
else
  safe_cp "$SOLO_EDGE_ROOT/.gitignore" ./.gitignore
fi

echo "Copying .claude/rules/..."
mkdir -p .claude
if [ -d ".claude/rules" ] && [ "$REFRESH" != "1" ]; then
  echo "  .claude/rules already exists — skipping (use --refresh to overwrite)"
else
  if [ -d ".claude/rules" ] && [ "$REFRESH" = "1" ]; then
    read -p "  .claude/rules exists. Overwrite entire directory? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -rf .claude/rules
      cp -r "$SOLO_EDGE_ROOT/.claude/rules" .claude/
      echo "  copied .claude/rules/ (refreshed)"
    else
      echo "  skipping .claude/rules"
    fi
  else
    cp -r "$SOLO_EDGE_ROOT/.claude/rules" .claude/
    echo "  copied .claude/rules/"
  fi
fi

echo "Copying scripts/ (CI gates)..."
mkdir -p scripts
for s in check-docs-updated.sh check-doc-content-drift.sh check-doc-indexes.sh check-e2e-coverage.sh; do
  if ! should_copy "scripts/$s"; then
    echo "  skipping scripts/$s (already exists)"
    continue
  fi
  if safe_cp "$SOLO_EDGE_ROOT/scripts/$s" "scripts/$s"; then
    chmod +x "scripts/$s"
    echo "  copied scripts/$s"
  fi
done

echo "Copying templates/ (you'll merge into source manually)..."
mkdir -p templates
if [ -d "templates" ] && [ -n "$(ls -A templates 2>/dev/null)" ] && [ "$REFRESH" != "1" ]; then
  echo "  templates/ has content — skipping (use --refresh to overwrite)"
else
  if [ "$REFRESH" = "1" ] && [ -n "$(ls -A templates 2>/dev/null)" ]; then
    read -p "  templates/ has content. Overwrite? [y/N] " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]] && cp -r "$SOLO_EDGE_ROOT/templates/." templates/ && echo "  copied templates/ (refreshed)"
  else
    cp -r "$SOLO_EDGE_ROOT/templates/." templates/
    echo "  copied templates/"
  fi
fi

# -------------- done ---------------------------------------------------------

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
echo
# Magical moment: point at one concrete file that demonstrates the value
# in 60 seconds, not buried in a 7-step TODO.
echo "Try this next:"
echo "  open $TARGET/.claude/rules/billing.md"
echo "  (battle-tested Stripe rule — auto-surfaces when Claude Code touches any billing file)"
