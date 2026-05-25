#!/usr/bin/env bash
#
# setup.sh — one-time Claude Code + skill ecosystem bootstrap for a solo builder
#
# Installs:
#   - Claude Code CLI (via brew on macOS, official installer otherwise)
#   - gstack skill ecosystem (~/.claude/skills/gstack)
#   - superpowers skill ecosystem (~/.claude/skills/superpowers)
#   - Global safety rules in ~/.claude/CLAUDE.md (merge-safe — won't clobber)
#
# Idempotent — safe to re-run. Existing installs are upgraded, not replaced.
#
# Usage:
#   bash setup.sh
#   bash setup.sh --skip-claude-code  # if you already have CC and just want skills
#   bash setup.sh --skip-superpowers  # gstack only
#   bash setup.sh --dry-run           # show what would happen, change nothing

set -euo pipefail

# -------------- args + flags -------------------------------------------------

DRY_RUN=0
SKIP_CC=0
SKIP_SUPERPOWERS=0

for arg in "$@"; do
  case "$arg" in
    --dry-run)         DRY_RUN=1 ;;
    --skip-claude-code) SKIP_CC=1 ;;
    --skip-superpowers) SKIP_SUPERPOWERS=1 ;;
    --help|-h)
      sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown flag: $arg (try --help)"
      exit 1
      ;;
  esac
done

run() {
  if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] $*"
  else
    eval "$@"
  fi
}

say()  { printf "\033[1;32m==>\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m==>\033[0m %s\n" "$*"; }
fail() { printf "\033[1;31m==>\033[0m %s\n" "$*"; exit 1; }

# -------------- detect OS ----------------------------------------------------

OS="unknown"
case "$(uname -s)" in
  Darwin)  OS="macos" ;;
  Linux)   OS="linux" ;;
  *)       OS="other" ;;
esac
say "Detected OS: $OS"

# -------------- 1. Claude Code -----------------------------------------------

install_claude_code() {
  if command -v claude >/dev/null 2>&1; then
    say "Claude Code already installed: $(claude --version 2>/dev/null || echo 'version unknown')"
    return
  fi

  if [ "$OS" = "macos" ]; then
    if command -v brew >/dev/null 2>&1; then
      say "Installing Claude Code via Homebrew"
      run "brew install anthropic-ai/cc/claude-code" || \
        run "brew install --cask claude-code"
    else
      warn "Homebrew not found. Falling back to official installer."
      run "curl -fsSL https://claude.ai/install.sh | sh"
    fi
  else
    say "Installing Claude Code via official installer"
    run "curl -fsSL https://claude.ai/install.sh | sh"
  fi

  command -v claude >/dev/null 2>&1 || \
    fail "Claude Code install failed — see https://docs.claude.com/claude-code/install"
}

if [ "$SKIP_CC" = "1" ]; then
  warn "Skipping Claude Code install (--skip-claude-code)"
else
  install_claude_code
fi

# -------------- 2. Global ~/.claude/CLAUDE.md safety rules -------------------

CLAUDE_DIR="$HOME/.claude"
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"

run "mkdir -p $CLAUDE_DIR"

SAFETY_RULES=$(cat <<'EOF'
- Don't do git push and commit automatically
- Don't commit without my approval
- Don't commit before I review
- Do not automatically execute git commit or push
EOF
)

if [ -f "$CLAUDE_MD" ]; then
  if grep -q "Don't do git push and commit automatically" "$CLAUDE_MD"; then
    say "Safety rules already present in $CLAUDE_MD — leaving alone"
  else
    warn "$CLAUDE_MD exists but doesn't contain the safety rules"
    warn "Appending them to preserve any existing content. Review the file after."
    if [ "$DRY_RUN" = "0" ]; then
      {
        echo ""
        echo "# Safety rules (added by solo-edge setup.sh — do not remove)"
        echo "$SAFETY_RULES"
      } >> "$CLAUDE_MD"
    else
      echo "[dry-run] would append safety rules to $CLAUDE_MD"
    fi
  fi
else
  say "Creating $CLAUDE_MD with safety rules"
  if [ "$DRY_RUN" = "0" ]; then
    cat > "$CLAUDE_MD" <<EOF
# Global Claude Code rules — applies to every session on this machine
# Managed by solo-edge setup.sh (safe to edit; rules below are load-bearing)

$SAFETY_RULES
EOF
  else
    echo "[dry-run] would create $CLAUDE_MD"
  fi
fi

# -------------- 3. gstack skill ecosystem ------------------------------------

SKILLS_DIR="$CLAUDE_DIR/skills"
GSTACK_DIR="$SKILLS_DIR/gstack"

run "mkdir -p $SKILLS_DIR"

if [ -d "$GSTACK_DIR/.git" ]; then
  say "gstack already installed — pulling latest"
  if [ "$DRY_RUN" = "0" ]; then
    (cd "$GSTACK_DIR" && git pull --ff-only) || warn "gstack update failed; existing install kept"
  else
    echo "[dry-run] would 'git pull' in $GSTACK_DIR"
  fi
else
  say "Cloning gstack into $GSTACK_DIR"
  run "git clone https://github.com/garryslist/gstack $GSTACK_DIR" || \
    fail "gstack clone failed — check network or the upstream URL"
fi

if [ -x "$GSTACK_DIR/setup" ]; then
  say "Running gstack setup"
  if [ "$DRY_RUN" = "0" ]; then
    (cd "$GSTACK_DIR" && ./setup) || warn "gstack setup returned non-zero; continuing"
  else
    echo "[dry-run] would run $GSTACK_DIR/setup"
  fi
fi

# -------------- 4. superpowers (optional) ------------------------------------

if [ "$SKIP_SUPERPOWERS" = "1" ]; then
  warn "Skipping superpowers (--skip-superpowers)"
else
  SUPERPOWERS_DIR="$SKILLS_DIR/superpowers"
  if [ -d "$SUPERPOWERS_DIR/.git" ]; then
    say "superpowers already installed — pulling latest"
    if [ "$DRY_RUN" = "0" ]; then
      (cd "$SUPERPOWERS_DIR" && git pull --ff-only) || warn "superpowers update failed; existing install kept"
    else
      echo "[dry-run] would 'git pull' in $SUPERPOWERS_DIR"
    fi
  else
    say "Cloning superpowers into $SUPERPOWERS_DIR"
    run "git clone https://github.com/anthropics/superpowers $SUPERPOWERS_DIR" || \
      warn "superpowers clone failed (URL may have changed) — install manually if you want it"
  fi
fi

# -------------- 5. settings.json — point CC at the skill paths ---------------

SETTINGS_JSON="$CLAUDE_DIR/settings.json"

if [ ! -f "$SETTINGS_JSON" ]; then
  say "Creating $SETTINGS_JSON with skill scan paths"
  if [ "$DRY_RUN" = "0" ]; then
    cat > "$SETTINGS_JSON" <<EOF
{
  "skills": {
    "scan_paths": [
      "~/.claude/skills/gstack/skills",
      "~/.claude/skills/superpowers/skills"
    ]
  }
}
EOF
  else
    echo "[dry-run] would create $SETTINGS_JSON"
  fi
else
  say "$SETTINGS_JSON already exists — leaving alone. If skills don't load, add:"
  cat <<'EOF'
  {
    "skills": {
      "scan_paths": [
        "~/.claude/skills/gstack/skills",
        "~/.claude/skills/superpowers/skills"
      ]
    }
  }
EOF
fi

# -------------- 6. verify -----------------------------------------------------

say "Verifying install"

if [ -x "$GSTACK_DIR/bin/gstack-update-check" ]; then
  if [ "$DRY_RUN" = "0" ]; then
    "$GSTACK_DIR/bin/gstack-update-check" 2>/dev/null || true
  fi
fi

# -------------- 7. summary ---------------------------------------------------

CC_PATH=$(command -v claude || echo 'not installed')
CC_LABEL=$([ "$SKIP_CC" = "1" ] && echo "(skipped) " || echo "")
SP_LABEL=$([ "$SKIP_SUPERPOWERS" = "1" ] && echo "(skipped)" || echo "$SKILLS_DIR/superpowers")

printf '\n\033[1;32m=== solo-edge setup complete ===\033[0m\n\n'
printf 'Installed:\n'
printf '  %sClaude Code CLI: %s\n' "$CC_LABEL" "$CC_PATH"
printf '  Safety rules:    %s\n' "$CLAUDE_MD"
printf '  gstack:          %s\n' "$GSTACK_DIR"
printf '  superpowers:     %s\n' "$SP_LABEL"
printf '  Skill settings:  %s\n\n' "$SETTINGS_JSON"

printf 'Next steps:\n'
printf '  1. Open Claude Code in any directory: \033[1mclaude\033[0m\n'
printf '  2. Type / to see the slash-command palette — you should see /autoplan, /ship, /qa, /office-hours, etc.\n'
printf '  3. Optionally configure gstack: \033[1m%s/bin/gstack-config\033[0m\n' "$GSTACK_DIR"
printf '     - Telemetry: anonymous (recommended) or off\n'
printf '     - Proactive: true (recommended) — gstack suggests the right skill at the right moment\n'
printf '  4. To bootstrap a new product from solo-edge conventions:\n'
printf '     \033[1m./scripts/init.sh /path/to/new-product\033[0m\n\n'
printf 'Reference: docs/01-claude-code-setup.md\n'
