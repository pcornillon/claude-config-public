#!/usr/bin/env bash
# check-prereqs.sh — say what this configuration needs, what is missing, and how to get it.
#
# Run on its own, or automatically as the first thing install.sh does:
#     ./check-prereqs.sh              everything
#     ./check-prereqs.sh core         just what the config itself needs
#     ./check-prereqs.sh switchboard  just the panel
#
# Four tiers, because "missing" means different things:
#
#   core         nothing works without these
#   multi        only needed if you use this config on more than one machine
#   switchboard  claude-switchboard, the session panel — optional, separate repo
#   switchboard-full  the parts of the panel that need a human to click something
#
# It never installs anything and never fails the caller: it reports, and exit 0 always,
# so it can sit at the top of install.sh without being able to block it. Missing items
# in `core` are the one thing it shouts about.

set -u
[ "${1:-all}" = "--help" ] && { sed -n '2,20p' "$0"; exit 0; }
WANT="${1:-all}"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
grn()  { printf '  \033[32m✓\033[0m %s\n' "$*"; }
red()  { printf '  \033[31m✗\033[0m %s\n' "$*"; }
ylw()  { printf '  \033[33m•\033[0m %s\n' "$*"; }
note() { printf '      %s\n' "$*"; }

missing_core=0

# have <command>
have() { command -v "$1" >/dev/null 2>&1; }

# report <ok?> <name> <what it is for> <where to get it> <how to install it>
report() {
  local ok=$1 name=$2 purpose=$3 where=$4 how=$5
  if [ "$ok" = 1 ]; then
    grn "$name — $purpose"
  else
    red "$name is missing — $purpose"
    [ -n "$where" ] && note "get it: $where"
    [ -n "$how" ]   && note "install: $how"
  fi
}

if [ "$WANT" = all ] || [ "$WANT" = core ]; then
  bold "Core — nothing here works without these"

  have claude && c=1 || { c=0; missing_core=1; }
  report $c "claude (Claude Code)" "the thing this configuration configures" \
    "https://claude.com/claude-code" "npm install -g @anthropic-ai/claude-code"

  have git && c=1 || { c=0; missing_core=1; }
  report $c "git" "every project is a repo; the spine is versioned" \
    "https://git-scm.com" "xcode-select --install   (macOS ships it with the CLI tools)"

  have python3 && c=1 || { c=0; missing_core=1; }
  report $c "python3" "the hooks and session-transcript.sh are python inside bash" \
    "https://www.python.org/downloads/" "xcode-select --install, or brew install python"

  have jq && c=1 || { c=0; missing_core=1; }
  report $c "jq" "install.sh refuses to link a settings.json that does not parse" \
    "https://jqlang.github.io/jq/" "brew install jq"

  have xattr && c=1 || c=0        # macOS ships it; absence is not fatal
  report $c "xattr" "tag-spine.sh writes Finder tags (cosmetic — safe to skip)" \
    "part of macOS" ""

  case "$(uname -s)" in
    Darwin) grn "macOS — tag-spine.sh and the machine-name lookup are macOS-only" ;;
    *)      ylw "not macOS — the config works, but tag-spine.sh and the Finder tags do not" ;;
  esac
  echo
fi

if [ "$WANT" = all ] || [ "$WANT" = multi ]; then
  bold "Multi-machine — only if you work on more than one computer"

  have gh && c=1 || c=0
  report $c "gh (GitHub CLI)" "creating and checking remotes without a browser" \
    "https://cli.github.com" "brew install gh   (then: gh auth login)"

  if git ls-remote --exit-code . >/dev/null 2>&1 || git remote 2>/dev/null | grep -q .; then
    grn "a git remote is configured for this repo"
  else
    ylw "no git remote here — a second machine has no way to pull this configuration"
    note "create one: gh repo create <name> --private --source=. --push"
  fi

  if ls "$HOME"/.ssh/id_* >/dev/null 2>&1; then
    grn "an ssh key exists in ~/.ssh"
  else
    ylw "no ssh key in ~/.ssh — pushes will ask for credentials every time"
    note "create one: ssh-keygen -t ed25519 -C 'you@example.com'"
    note "then add it: gh ssh-key add ~/.ssh/id_ed25519.pub"
  fi
  echo
fi

if [ "$WANT" = all ] || [ "$WANT" = switchboard ]; then
  bold "claude-switchboard — the session panel (optional, and a separate repo)"
  note "what it is: one panel showing every claude session on this Mac — which project,"
  note "which Desktop, working or waiting on you. https://github.com/pcornillon/claude-switchboard"

  if [ -d /Applications/Hammerspoon.app ] || [ -d "$HOME/Applications/Hammerspoon.app" ]; then
    grn "Hammerspoon — the panel is a Hammerspoon module; it cannot run without it"
  else
    red "Hammerspoon is missing — claude-switchboard is built on it and will not run"
    note "get it: https://www.hammerspoon.org  (free, notarized, no SIP changes)"
    note "install: brew install --cask hammerspoon    then launch it once"
  fi

  if [ -f "$HOME/.hammerspoon/init.lua" ]; then
    if grep -q "desktop_dashboard" "$HOME/.hammerspoon/init.lua" 2>/dev/null; then
      grn "~/.hammerspoon/init.lua loads the panel"
    else
      ylw "~/.hammerspoon/init.lua exists but does not load the panel"
      note "add the loader line — see claude-switchboard/INSTALL.md, step 3"
    fi
  else
    ylw "no ~/.hammerspoon/init.lua yet — nothing loads the panel"
    note "see claude-switchboard/INSTALL.md, steps 1 and 3"
  fi
  echo
fi

if [ "$WANT" = all ] || [ "$WANT" = switchboard-full ]; then
  bold "claude-switchboard, fully working — these need a human, not a script"
  ylw "Accessibility permission for Hammerspoon — cannot be granted by software, by design"
  note "System Settings → Privacy & Security → Accessibility → enable Hammerspoon"
  note "without it the panel loads and lists sessions, but cannot place them on Desktops"
  ylw "Terminal.app or iTerm2 for the Desktop column"
  note "sessions in Ghostty, kitty or an editor's terminal still appear, without a Desktop"
  echo
fi

if [ "$missing_core" = 1 ]; then
  bold "Something in Core is missing. Install it before running install.sh."
else
  [ "$WANT" = all ] && bold "Core is complete."
fi
exit 0
