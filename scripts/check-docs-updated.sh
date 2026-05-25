#!/usr/bin/env bash
# Behavior-change-requires-doc-update gate.
#
# Fails CI if a PR modifies a behavior-bearing source file but no
# matching doc was updated in the same diff.
#
# The Sessions 4/7/8/9/10/11 entropy scans all caught the same failure
# mode: code lands clean, docs lag. This script promotes the rule from
# documented prose to a mechanical CI gate. The escape hatch is
# `[skip docs]` in the latest commit message — use sparingly for type
# renames, test-only changes, etc.
#
# Usage:
#   bash scripts/check-docs-updated.sh [base] [head]
#
# Defaults: base=origin/main, head=HEAD.

set -euo pipefail

BASE="${1:-origin/main}"
HEAD="${2:-HEAD}"

# Escape hatch — scan every commit on the branch (not just HEAD).
# pull_request events check out a synthetic merge commit whose message
# never has the marker, so a HEAD-only check silently ignores the hatch
# in CI even when it works locally.
range_msgs=$(git log --pretty=%B "$BASE..$HEAD" 2>/dev/null || true)
if echo "$range_msgs" | grep -qi '\[skip docs\]'; then
  echo "[docs-check] [skip docs] found in branch commits — bypassing."
  exit 0
fi

# List files changed between base and head.
changed=$(git diff --name-only "$BASE...$HEAD")

# Source-to-doc mapping. Each row: a source-path pattern (extended regex)
# matched against the changed files; if matched, AT LEAST ONE of the
# pipe-separated doc paths must also appear in the diff.
#
# Add a row when a new behavior-bearing surface is introduced.
declare -a RULES=(
  'lib/firebase/types\.ts|ARCHITECTURE.md|.claude/rules/firestore.md|AGENTS.md'
  'lib/firebase/repos\.ts|.claude/rules/firestore.md|AGENTS.md'
  'lib/auth/session\.ts|.claude/rules/auth.md|AGENTS.md'
  'lib/llm/router\.ts|.claude/rules/llm-pipeline.md'
  'functions/src/index\.ts|.claude/rules/functions.md'
  'middleware\.ts|.claude/rules/auth.md|AGENTS.md'
  'app/\(app\)/[^/]+/page\.tsx|AGENTS.md'
  'lib/billing/.*\.ts|.claude/rules/billing.md|AGENTS.md'
  'app/api/stripe/.*\.ts|.claude/rules/billing.md|AGENTS.md'
  'app/pricing/page\.tsx|AGENTS.md'
  'lib/auth/admin\.ts|.claude/rules/admin.md|AGENTS.md'
  'lib/firebase/admin-queries\.ts|.claude/rules/admin.md|AGENTS.md'
  'app/\(admin\)/.+\.tsx|.claude/rules/admin.md|AGENTS.md'
)

violations=()
for rule in "${RULES[@]}"; do
  src_re="${rule%%|*}"          # everything before first pipe
  docs_part="${rule#*|}"         # everything after first pipe (pipes act as
                                 # alternation directly inside grep -E '(a|b|c)').

  if echo "$changed" | grep -E -q "^${src_re}$"; then
    if ! echo "$changed" | grep -E -q "^(${docs_part})$"; then
      violations+=("  - ${src_re} was modified, but none of: ${docs_part}")
    fi
  fi
done

if [ ${#violations[@]} -gt 0 ]; then
  echo "[docs-check] Behavior-bearing source files were modified without matching doc updates:"
  printf '%s\n' "${violations[@]}"
  echo ""
  echo "Fix by either:"
  echo "  1. Updating the relevant doc(s) in the same PR (preferred), OR"
  echo "  2. Adding [skip docs] to your last commit message"
  echo "     (use sparingly: type renames, test-only changes, comment fixes)"
  echo ""
  echo "Why this gate exists: the entropy scan caught the same"
  echo "'code clean, docs lag' pattern six times across Sessions 4-11."
  echo "Mechanical enforcement closes the recurring leak. See"
  echo "QUALITY_SCORE.md Session 11 standing items."
  exit 1
fi

echo "[docs-check] OK — all behavior-bearing edits have matching doc updates."
