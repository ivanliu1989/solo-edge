#!/usr/bin/env bash
# Doc content-drift gate — L3.5 companion to scripts/check-docs-updated.sh.
#
# The L3 presence-only gate (check-docs-updated.sh) catches "code changed,
# no doc was touched" — but lets through THREE failure modes the entropy
# scan kept finding:
#   1. Typos in symbol names (single-letter misspellings of real exports
#      that propagate across docs because they're invisible without grep).
#      [Caught: Sessions 14 + 15.]
#   2. Stale references to renamed/removed exports.
#      [Caught: Sessions 14 + 15.]
#   3. Prose-mention drift — factual claims about system state that go
#      stale when the state changes (e.g. "Stripe paused during beta"
#      after the beta freeze exited 2026-05-16).
#      [Caught: Sessions 22, 23, 24 — recurring class.]
# All three ship cleanly past the presence-only check because *a* doc was
# edited; this script is the mechanical companion that asks the stricter
# questions: "does every backticked symbol in our mutable docs actually
# exist in source?" AND "do any docs claim a past system state as current?"
#
# Posture: WARN by default (exit 0), BLOCKING in CI via --strict (exit 1
# on any warning). Local `pnpm doc:drift` stays warn-friendly for the
# dev loop; CI is the gate. Promotion from warn-only to CI-strict applied
# 2026-05-25 (Session 25) after 4 consecutive entropy sessions GREEN.
#
# Usage:
#   bash scripts/check-doc-content-drift.sh           # WARN mode (default; local dev)
#   bash scripts/check-doc-content-drift.sh --strict  # exit 1 on any warning (CI)
#
# What it scans:
#   - DOC_FILES: AGENTS.md, ARCHITECTURE.md, README.md,
#     .claude/rules/*.md, docs/runbooks/*.md (mutable, behavior-bearing).
#     QUALITY_SCORE.md is INTENTIONALLY EXCLUDED — it's a historical-log
#     file whose audit entries reference past typo'd names on purpose;
#     scanning it would noise the WARN output with intentional history.
#   - SRC_DIRS:  app/, lib/, components/, functions/src/, scripts/, e2e/,
#     middleware.ts, instrumentation.ts, instrumentation-client.ts.
#   - SKIPPED:   docs/design-docs/, docs/exec-plans/, docs/product-specs/,
#     docs/superpowers/ (historical / archived — references there may
#     intentionally reference removed types).
#
# Heuristic: a "doc-mentioned symbol" is an identifier inside backticks
# matching the regex below AND looking like a likely-exported JS/TS name
# (camelCase / PascalCase, length 4..40). For each, grep all SRC_DIRS for
# a definition or any reference. Zero matches = drift candidate.

set -euo pipefail

# Bash 4+ is required (uses `declare -A` associative arrays). macOS ships
# bash 3.2 by default — `brew install bash` gives 5.x at /opt/homebrew/bin/bash.
# Detect early and emit a clear message rather than failing mid-script with
# a cryptic "declare: -A: invalid option".
if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  # Unquoted heredoc delimiter so $BASH_VERSION expands. Backticks
  # below are escaped so bash doesn't try to command-substitute them.
  cat >&2 <<EOF
scripts/check-doc-content-drift.sh requires bash 4+ (uses associative arrays).
Detected: bash ${BASH_VERSION}

On macOS:
  brew install bash
  # Then invoke explicitly:
  /opt/homebrew/bin/bash scripts/check-doc-content-drift.sh
  # OR add /opt/homebrew/bin to PATH before /bin so \`bash\` finds the new one.

On CI (Ubuntu / Debian): bash 5.x is the default, no action needed.

Exit code: 2 (environment, not drift). Treats as non-blocking.
EOF
  exit 2
fi

STRICT=0
if [ "${1:-}" = "--strict" ]; then
  STRICT=1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

# Mutable / behavior-bearing docs we actively maintain.
# QUALITY_SCORE.md is intentionally EXCLUDED: it's a historical-log file
# that catalogs past drift findings by name (e.g. "Session 15 fixed the
# typo maybeSendDailyEmail/extra-y"). Those mentions are the audit trail,
# not active references — flagging them would defeat the log's purpose.
DOC_FILES=()
for f in AGENTS.md ARCHITECTURE.md README.md; do
  [ -f "$f" ] && DOC_FILES+=("$f")
done
for f in .claude/rules/*.md; do
  [ -f "$f" ] && DOC_FILES+=("$f")
done
for f in docs/runbooks/*.md; do
  [ -f "$f" ] && DOC_FILES+=("$f")
done

if [ ${#DOC_FILES[@]} -eq 0 ]; then
  echo "[doc-drift] No doc files found — nothing to check."
  exit 0
fi

# Source paths where exports / symbols can legitimately live.
# Keep this list aligned with the codebase layout in AGENTS.md.
# Note: we deliberately exclude functions/lib/ (esbuild build artifact)
# via the --exclude-dir flag on the grep call; that dir name collides
# with the legitimate top-level lib/, hence the explicit path list.
SRC_PATHS=(app lib components functions/src scripts e2e middleware.ts instrumentation.ts instrumentation-client.ts)

# grep filters: include only TS/JS source; exclude build outputs.
GREP_INCLUDES=(--include='*.ts' --include='*.tsx' --include='*.mjs' --include='*.js')
GREP_EXCLUDES=(
  --exclude-dir=node_modules
  --exclude-dir=.next
  --exclude-dir=.firebase
  --exclude-dir=.worktrees
  --exclude-dir=dist
  --exclude-dir=build
  --exclude-dir=coverage
)

# Helper: does the symbol exist anywhere in source?
symbol_exists_in_source() {
  local sym="$1"
  # Word-boundary search via grep -w on the symbol name (-l = list files,
  # -I = skip binary). Exit 0 if any match, 1 otherwise.
  if grep -RwlI \
      "${GREP_INCLUDES[@]}" \
      "${GREP_EXCLUDES[@]}" \
      -- "$sym" \
      "${SRC_PATHS[@]}" \
      >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# Allowlist: identifiers that are legitimately doc-only (no source export
# expected). Examples: parameter names referenced abstractly, well-known
# external symbols, Stripe / Firestore field names, etc. Add a row + a
# 1-line comment explaining WHY.
declare -A ALLOWLIST
ALLOWLIST[true]=1                  # boolean literal
ALLOWLIST[false]=1                 # boolean literal
ALLOWLIST[null]=1                  # null literal
ALLOWLIST[undefined]=1             # undefined literal
ALLOWLIST[Promise]=1               # built-in
ALLOWLIST[Headers]=1               # web API
ALLOWLIST[FormData]=1              # web API
ALLOWLIST[NEXT_HTTP_ERROR_FALLBACK]=1  # Next.js internal sentinel string
ALLOWLIST[NAME_TO_SYMBOL]=1        # documented map name, may live as object literal
ALLOWLIST[ENTITLEMENTS]=1          # documented const map name
ALLOWLIST[REQUIRED]=1              # local-scope identifier in scripts
ALLOWLIST[REQUIRED_INDEXES]=1      # test-local const, may not be exported
ALLOWLIST[KNOWN_STATUSES]=1        # webhook-handlers local const
ALLOWLIST[NAME]=1                  # generic capture group
ALLOWLIST[DAILY_USER_COST_CAP_CENTS]=1  # env-driven constant
ALLOWLIST[SESSION_TTL_MS]=1        # documented internal const
ALLOWLIST[SESSION_COOKIE_NAME]=1   # documented internal const
ALLOWLIST[PROTECTED_PREFIXES]=1    # middleware-local const
ALLOWLIST[TTL_EXPIRE_VALUE]=1      # Firebase extension config var
ALLOWLIST[applyInvoice]=1          # Sentry tag-filter PREFIX (matches applyInvoicePaymentFailed); cited in sentry-alert-rules.md
ALLOWLIST[applySubscription]=1     # Sentry tag-filter PREFIX (matches applySubscriptionUpsert/Deleted); cited in sentry-alert-rules.md
ALLOWLIST[canSeeTodaysSignal]=1    # historical rename — flag removed at PH launch; billing.md preserves the removal narrative for future grep+find
ALLOWLIST[getServerSideProps]=1    # Next.js pages-router external API; nextjs.md uses it as a "don't do this" reference
ALLOWLIST[getStaticProps]=1        # Next.js pages-router external API; nextjs.md uses it as a "don't do this" reference
ALLOWLIST[minInstances]=1          # apphosting.yaml runConfig field; YAML is not in the script's scanned paths (the script scans app/lib/components/functions/scripts/e2e + root middleware.ts + instrumentation*.ts only)
ALLOWLIST[withSentryConfig]=1      # @sentry/nextjs export used in next.config.ts; next.config.ts is NOT in the script's root-file allowlist (only middleware.ts + instrumentation*.ts are)
ALLOWLIST[sessionStorage]=1        # DOM/Web Storage API global — not a project symbol; ARCHITECTURE.md cites it in the PR #94 history note where the F2 simulation flag flipped from sessionStorage to localStorage
ALLOWLIST[refreshPrices]=1         # Removed in PR #102; ARCHITECTURE.md history-table cites it in past-tense ("built then fully removed mid-PR") as part of the rescope arc
ALLOWLIST[simulationStorageKey]=1  # Removed in PR #98; docs/runbooks/launch-day-backlog.md cites it in past-tense when scoping M-Q5 down to just the stage-advancement helper

# --- Denied prose phrases -----------------------------------------------
#
# Phrases describing past system states that have lingered in current-
# tense prose across multiple entropy sweeps. Adding here = the docs
# MUST be updated when the underlying state changes. The first entry
# encodes Session 22 + 23 + 24's recurring finding: variants of
# "paused during beta" survived in stack-table cells / pricing prose
# after the beta freeze exited 2026-05-16 (PR #70).
#
# Format: PIPE-DELIMITED triple — "phrase|rationale|allowed-files"
#   phrase        — exact substring (case-insensitive) to flag. Choose
#                   narrow phrases that have no legitimate current-state
#                   meaning (e.g. "paused during beta" is unambiguous;
#                   "beta" alone is too broad).
#   rationale     — explanation that surfaces in the WARN output so the
#                   maintainer knows what current state to write instead.
#   allowed-files — comma-separated paths where the phrase MAY appear
#                   (e.g. history-narrative docs). Leave empty for "no
#                   exceptions." QUALITY_SCORE.md is already excluded
#                   from DOC_FILES so no need to list it here.
#
# Adding a phrase = adding an obligation. Be selective; only deny
# phrases that have actually drifted ≥2 times across entropy sweeps.
DENIED_PHRASES=(
  "paused during beta|Stripe Checkout is live since 2026-05-16 (PR #70). Use present tense (\"live since 2026-05-16\") or past-tense narrative (\"was paused during beta freeze; exited 2026-05-16\") in a clearly-historical section.|"
)

# Walk each doc file, extract backticked identifiers, dedup, then check.
# Use a PID-stamped temp path under ${TMPDIR:-/tmp}; the OS janitor
# handles cleanup. The file is small — kilobytes — and short-lived
# per CI run. (Avoid `mktemp` so we keep the script portable across
# CI runners with locked-down system binaries.)
CANDIDATES="${TMPDIR:-/tmp}/doc-drift.$$.txt"
: > "$CANDIDATES"

for doc in "${DOC_FILES[@]}"; do
  # Match `identifier` where the identifier is camelCase or PascalCase,
  # starts with a letter, length 4..40. Also allow underscores so SCREAMING
  # constants get picked up but we'll filter them via the allowlist or
  # source presence.
  grep -oE '`[A-Za-z][A-Za-z0-9_]{3,39}`' "$doc" \
    | sed -e 's/^`//' -e 's/`$//' \
    | awk -v d="$doc" '{ print $0 "|" d }'
done | sort -u > "$CANDIDATES"

# Filter to identifiers that LOOK like exported symbols (camelCase or
# PascalCase, contains at least one lowercase letter — drops pure
# CONSTANTS that are routinely doc-only and noisy):
#   - camelCase: ^[a-z][A-Za-z0-9]*[A-Z][A-Za-z0-9_]*$   e.g. maybeSendDailyEmail
#   - PascalCase + lowercase suffix: ^[A-Z][A-Za-z0-9]*[a-z][A-Za-z0-9_]*$
# This is intentionally narrow to keep false-positive volume low in WARN
# mode.

WARNINGS=0
declare -A SEEN_SYMBOL

while IFS='|' read -r sym doc; do
  [ -z "$sym" ] && continue
  # Already-warned this run? skip duplicates across docs.
  if [ -n "${SEEN_SYMBOL[$sym]:-}" ]; then
    continue
  fi

  # Allowlist filter.
  if [ -n "${ALLOWLIST[$sym]:-}" ]; then
    continue
  fi

  # Shape filter: camelCase or PascalCase identifier with at least one
  # case transition (a → A or A → a). Drops:
  #   - SCREAMING_SNAKE_CASE (DAILY_USER_COST_CAP_CENTS etc)
  #   - all-lowercase prose words ("status", "queued")
  #   - all-uppercase acronyms ("URL", "API")
  if ! echo "$sym" | grep -qE '([a-z][A-Z]|[A-Z][a-z])'; then
    continue
  fi

  if symbol_exists_in_source "$sym"; then
    SEEN_SYMBOL[$sym]=1
    continue
  fi

  echo "[doc-drift] WARN  $sym  (referenced in $doc, no match in source)"
  SEEN_SYMBOL[$sym]=1
  WARNINGS=$((WARNINGS + 1))
done < "$CANDIDATES"

# --- Denylist phrase check ----------------------------------------------
# Runs AFTER the backtick-symbol pass so all WARN lines aggregate into
# the single WARNINGS counter; --strict mode then fails on either kind
# of drift. Case-insensitive substring match per phrase. The allowed-
# files CSV exempts known-legitimate historical surfaces (currently
# unused — every entry below is universally denied).
for entry in "${DENIED_PHRASES[@]}"; do
  IFS='|' read -r phrase rationale allowed <<< "$entry"
  [ -z "$phrase" ] && continue
  # CSV → array; empty string means "no exceptions."
  IFS=',' read -ra allowed_paths <<< "$allowed"
  printed_rationale=0
  for doc in "${DOC_FILES[@]}"; do
    skip=0
    for ap in "${allowed_paths[@]}"; do
      [ -z "$ap" ] && continue
      if [ "$doc" = "$ap" ]; then
        skip=1
        break
      fi
    done
    [ $skip -eq 1 ] && continue
    # grep -in: case-insensitive + line numbers. The || true keeps
    # set -e from tripping on the "no match" exit-1 from grep.
    matches=$(grep -in -- "$phrase" "$doc" 2>/dev/null || true)
    [ -z "$matches" ] && continue
    while IFS= read -r line; do
      lineno="${line%%:*}"
      echo "[doc-drift] WARN  prose-mention drift: \"$phrase\" in $doc:$lineno"
      WARNINGS=$((WARNINGS + 1))
    done <<< "$matches"
    if [ $printed_rationale -eq 0 ]; then
      echo "[doc-drift]       fix: $rationale"
      printed_rationale=1
    fi
  done
done

echo ""
if [ $WARNINGS -eq 0 ]; then
  echo "[doc-drift] OK — no doc references missing from source."
  exit 0
fi

echo "[doc-drift] Found $WARNINGS doc-drift warning(s)."
echo ""
echo "What this means:"
echo "  - Symbol drift: a doc backticks an identifier (function/const/type)"
echo "    that grep can't find anywhere under app/, lib/, components/,"
echo "    functions/src/, scripts/, e2e/, or the root middleware/"
echo "    instrumentation files. Likely cause: a rename happened in"
echo "    source and the doc edit missed it, OR the symbol was deleted."
echo "    False positives: parameter names referenced abstractly,"
echo "    external library symbols, JSON field names. Add legitimate"
echo "    cases to the ALLOWLIST inside this script with a 1-line WHY."
echo "  - Prose-mention drift: a doc contains a phrase from"
echo "    DENIED_PHRASES that describes a past system state in current-"
echo "    tense prose. See the per-phrase \"fix:\" line above for the"
echo "    canonical replacement. If the phrase legitimately appears in"
echo "    historical-narrative context, either reword the sentence to"
echo "    be unambiguously past-tense OR add the file path to the"
echo "    phrase's allowed-files list inside DENIED_PHRASES."
echo ""
echo "Posture: BLOCKING in CI (--strict mode); WARN-only in local dev"
echo "(\`pnpm doc:drift\` without --strict). Promotion from warn-only"
echo "to CI-strict applied 2026-05-25 (Session 25) after 4 consecutive"
echo "entropy sessions GREEN."

if [ "$STRICT" -eq 1 ]; then
  exit 1
fi
exit 0
