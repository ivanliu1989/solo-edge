#!/usr/bin/env bash
# Doc index integrity gate.
#
# Three hand-maintained indexes enumerate every doc and playbook:
#   - README.md            (top-level "What's in the box" + by-purpose tables)
#   - docs/README.md       (by-progression + by-use-case maps)
#   - playbooks/README.md  (activity → file table)
#
# When a 14th doc or 8th playbook lands, all three must update — without a
# mechanical gate, one or two silently rot. This script fails CI on any
# file that exists on disk but is missing from a required index.
#
# Exit 1 (CI-fail) if any doc or playbook is unindexed. Exit 0 otherwise.
#
# Usage:
#   bash scripts/check-doc-indexes.sh

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

MISSING=0

check_indexed() {
  local file="$1"; shift
  local label="$1"; shift
  local base
  base="$(basename "$file")"
  for index in "$@"; do
    if [ ! -f "$index" ]; then
      echo "[doc-indexes] MISSING INDEX FILE: $index does not exist"
      MISSING=$((MISSING + 1))
      continue
    fi
    # Substring match — works because every link form in the indexes
    # (relative or repo-rooted) contains the basename verbatim.
    if ! grep -q -- "$base" "$index"; then
      echo "[doc-indexes] $label '$file' not indexed in $index"
      MISSING=$((MISSING + 1))
    fi
  done
}

# Every docs/*.md (except its own README) must appear in README.md AND docs/README.md
if [ -d docs ]; then
  for f in docs/*.md; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    [ "$base" = "README.md" ] && continue
    check_indexed "$f" "doc" README.md docs/README.md
  done
fi

# Every playbooks/*.md (except its own README) must appear in README.md AND playbooks/README.md
if [ -d playbooks ]; then
  for f in playbooks/*.md; do
    [ -f "$f" ] || continue
    base="$(basename "$f")"
    [ "$base" = "README.md" ] && continue
    check_indexed "$f" "playbook" README.md playbooks/README.md
  done
fi

if [ "$MISSING" -gt 0 ]; then
  echo ""
  echo "[doc-indexes] FAIL: $MISSING file(s) not indexed."
  echo ""
  echo "Each docs/*.md must appear in README.md AND docs/README.md."
  echo "Each playbooks/*.md must appear in README.md AND playbooks/README.md."
  echo ""
  echo "Fix: add a row for each missing file to the listed indexes."
  exit 1
fi

echo "[doc-indexes] OK — all docs and playbooks are indexed in their required indexes."
exit 0
