#!/bin/bash
# install.sh — point this machine's ~/.claude at this repo.
#
# Task #2. Run it once per machine:
#     bash ~/Git_Repos/claude-config-public/install.sh
#
# It is idempotent: running it again re-points anything that has drifted and
# leaves everything else alone. Use --check to verify without changing anything.
#
# What it links (individually — ~/.claude itself cannot be a symlink, because it
# also holds machine-local runtime state: projects/, sessions/, history.jsonl):
#
#     ~/.claude/settings.json  ->  global/settings.json
#     ~/.claude/CLAUDE.md      ->  global/CLAUDE.md
#     ~/.claude/skills         ->  global/skills
#     ~/.claude/commands       ->  global/commands
#
# What it deliberately does NOT touch: ~/.claude/archive/. The old scripts stay
# there as a fallback, and transcripts/ and usage-log.csv keep living there
# because they are generated data, not code (D3).
#
# Rollback is one line:
#     ln -sfn ~/.claude/archive/settings.json ~/.claude/settings.json
# plus removing the three new links.

set -u

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CLAUDE_DIR="$HOME/.claude"
CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

red()  { printf '\033[31m%s\033[0m\n' "$*"; }
grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
ylw()  { printf '\033[33m%s\033[0m\n' "$*"; }

fail=0

# What this configuration needs, and what is missing, before anything is linked. It
# reports and always exits 0, so it can never block an install — see check-prereqs.sh.
if [ "$CHECK_ONLY" = 0 ] && [ -x "$REPO/check-prereqs.sh" ]; then
  "$REPO/check-prereqs.sh" core
fi

# A starter built by make-starter.sh arrives with {{OWNER}} where a name belongs. Fill it
# in from git, so a default install asks nothing (D39). A no-op in a repo that has no
# placeholders, which is every repo except a freshly cloned starter.
if [ "$CHECK_ONLY" = 0 ] && grep -rlq '{{OWNER' "$REPO" --exclude-dir=.git 2>/dev/null; then
  OWNER=$(git config user.name || true); OWNER=${OWNER:-$USER}
  HANDLE=$(git config user.name || true); HANDLE=${HANDLE:-$USER}
  python3 - "$REPO" "$OWNER" "$HANDLE" <<'PY'
import os, sys
repo, owner, handle = sys.argv[1:4]
n = 0
for root, dirs, files in os.walk(repo):
    dirs[:] = [d for d in dirs if d != ".git"]
    for f in files:
        p = os.path.join(root, f)
        try:
            body = open(p, encoding="utf-8").read()
        except Exception:
            continue
        # Markdown only. A running script that rewrites itself makes bash lose its
        # place in the file and die mid-run — measured here, not theorised. Generated
        # scripts therefore carry plain words, never placeholders.
        if not f.endswith(".md") or "{{OWNER" not in body:
            continue
        open(p, "w", encoding="utf-8").write(
            body.replace("{{OWNER_HANDLE}}", handle).replace("{{OWNER}}", owner))
        n += 1
print("owner:  %s — filled in across %d file(s)" % (owner, n))
PY
fi

# settings.json names each hook by an ABSOLUTE path, so a clone that does not sit at
# the path the file was written with registers hooks that do not exist — and Claude Code
# reports nothing. Repoint them at this checkout. A no-op when they already match, and
# the file is only rewritten when something actually changed.
if [ "$CHECK_ONLY" = 0 ] && [ -f "$REPO/global/settings.json" ]; then
  python3 - "$REPO" <<'PY'
import json, os, sys
repo = sys.argv[1]
p = os.path.join(repo, "global/settings.json")
cfg = json.load(open(p, encoding="utf-8"))
changed = []
for event in (cfg.get("hooks") or {}).values():
    for matcher in event:
        for h in matcher.get("hooks") or []:
            cmd = h.get("command") or ""
            if "/hooks/" not in cmd:
                continue
            name = cmd.split("/hooks/")[-1].strip('" ').split('"')[0]
            want = os.path.join(repo, "hooks", name)
            if os.path.exists(want) and want not in cmd:
                h["command"] = 'bash "%s"' % want
                changed.append(name)
if changed:
    json.dump(cfg, open(p, "w", encoding="utf-8"), indent=2)
    open(p, "a", encoding="utf-8").write("\n")
    print("hooks:  repointed %d hook command(s) at this checkout" % len(changed))
PY
fi

echo "repo:   $REPO"
echo "target: $CLAUDE_DIR"
echo

# ---------------------------------------------------------------------------
# Guard 1: settings.json must be valid JSON before it is linked.
# Malformed JSON silently disables EVERY setting in the file — permissions and
# all hooks — with no error anywhere. Never link an unvalidated file.
# ---------------------------------------------------------------------------
if command -v jq >/dev/null 2>&1; then
    if jq -e . "$REPO/global/settings.json" >/dev/null 2>&1; then
        grn "OK   global/settings.json is valid JSON"
    else
        red  "STOP global/settings.json is NOT valid JSON — refusing to link it."
        red  "     Fix it first; linking it would silently disable every setting."
        exit 1
    fi
else
    ylw "WARN jq not found — cannot validate settings.json. Install jq."
fi

# ---------------------------------------------------------------------------
# Guard 2: every hook script named in settings.json must exist.
# ---------------------------------------------------------------------------
if command -v jq >/dev/null 2>&1; then
    missing=0
    while read -r cmd; do
        p=$(printf '%s' "$cmd" | sed -E 's/^bash "([^"]+)".*/\1/')
        p=${p/\$HOME/$HOME}
        [ -f "$p" ] || { red "STOP hook script missing: $p"; missing=1; }
    done < <(jq -r '.hooks[]?[].hooks[].command' "$REPO/global/settings.json")
    [ "$missing" -eq 0 ] && grn "OK   every hook script in settings.json exists" || exit 1
fi

mkdir -p "$CLAUDE_DIR" 2>/dev/null

# ---------------------------------------------------------------------------
# link <source-relative-to-repo> <name-under-~/.claude>
# ---------------------------------------------------------------------------
link() {
    local src="$REPO/$1" dst="$CLAUDE_DIR/$2"

    if [ ! -e "$src" ]; then
        red "STOP source does not exist: $src"; fail=1; return
    fi

    # Already correct?
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        grn "OK   $2 -> $1"; return
    fi

    if [ "$CHECK_ONLY" -eq 1 ]; then
        if [ -L "$dst" ]; then ylw "DIFF $2 -> $(readlink "$dst")"
        elif [ -e "$dst" ]; then ylw "DIFF $2 is a real file/dir, not a link"
        else ylw "MISS $2 is absent"; fi
        fail=1; return
    fi

    # A real (non-symlink) file or directory is someone's data. Back up a file;
    # refuse to touch a directory rather than risk deleting its contents.
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        if [ -d "$dst" ]; then
            red "STOP $dst is a real directory, not a symlink."
            red "     Merge its contents into $src by hand, then re-run."
            fail=1; return
        fi
        local bak="$dst.pre-install.bak"
        cp -p "$dst" "$bak" 2>/dev/null && ylw "note backed up existing $2 -> $(basename "$bak")"
    fi

    # -n is required: without it, linking over an existing symlink-to-directory
    # creates the new link INSIDE that directory instead of replacing it.
    if ln -sfn "$src" "$dst"; then
        grn "LINK $2 -> $1"
    else
        red "STOP could not link $dst"; fail=1
    fi
}

link global/settings.json settings.json
link global/CLAUDE.md     CLAUDE.md
link global/skills        skills
link global/commands      commands

echo
if [ "$fail" -ne 0 ]; then
    if [ "$CHECK_ONLY" -eq 1 ]; then
        ylw "check: this machine is NOT fully linked (see DIFF/MISS above)."
    else
        red "install finished with problems — read the STOP lines above."
    fi
    exit 1
fi

if [ "$CHECK_ONLY" -eq 1 ]; then
    grn "check: this machine is fully linked to $REPO"
    exit 0
fi

cat <<'EOF'
Linked.

Hook configuration is captured when a session starts, so none of this takes
effect in a session that is already running. Start a NEW session, then confirm:

  1. ~/.claude/archive/usage-log.csv         gains a row for the new session
  2. ~/.claude/archive/transcripts/<id>.md   appears
  3. ~/.hammerspoon/claude_state/<id>.json  updates (Hammerspoon machines only)
  4. end a turn without writing its `## P` entry in SESSIONS/ — a "log guard
     (warn-only)" message should name the gap (claude-log-guard.sh)
  5. exit that session while it is still behind, then start another one in the
     same repo — it should open knowing about the debt (claude-log-debt.sh).
     The breadcrumb file is ~/.claude/log-debt.jsonl, machine-local.
EOF
