#!/usr/bin/env bash
# tag-spine.sh — Finder-tag a project's spine: folders "Spine" (blue), files
# "Spine doc" (purple), so both group at the top and nothing needs renaming.
#
# Why this exists (D26). Finder sorts case-insensitively, so the ALL-CAPS spine
# convention (D23) groups nothing there — SESSIONS/ lands between resources/ and
# STATUS.md. Renaming was tried on paper twice and rejected both times: prefixing the
# spine fails because CLAUDE.md cannot be renamed (Claude Code looks it up by exact
# name), and prefixing everything else fails because "everything else" is precisely
# the tooling-bound set — src/, hooks/, global/, a required .lua module, LICENSE.
#
# A Finder tag groups them with no rename at all, so nothing that points at a path
# breaks. Verified 2026-08-03 on your-desktop: the xattr writes, `mdls` reads it back in a
# Spotlight-indexed location, and `git status` stays clean.
#
# THE CATCH: tags live in an extended attribute, not in the file. Git does not carry
# them. They are per-machine, and a fresh clone has none — so run this after cloning
# a project on a new machine. That is the price of not renaming anything.
#
# Usage. This script lives in claude-config-public and nowhere else, so `./tag-spine.sh`
# only works while you are standing in claude-config-public. From any other repo, call it by
# its path — the usual case:
#
#   TS=~/Git_Repos/claude-config-public/tag-spine.sh
#
#   $TS ~/Git_Repos/*              # every project that has a CLAUDE.md — the one to
#                                  #   run on a machine that has just cloned or pulled
#   $TS ~/Git_Repos/<project>      # one project
#   $TS                            # no argument: tag the repo you are standing in
#   $TS --check <repo>             # report, change nothing
#   $TS --clear <repo>             # remove the tag
#
# A directory without a CLAUDE.md is skipped in silence, so pointing this at all of
# ~/Git_Repos is safe.
#
# EXIT CODE: --check exits 1 if anything is UNTAGGED. That is drift being reported,
# not a failure. Items shown as `missing` are spine files or folders the project does
# not have yet — normal in a repo that has not been migrated.
#
# Fails open: a directory that cannot be tagged is reported and skipped, never fatal.

set -uo pipefail

# Two tags, so folders and files group separately. "Spine" sorts before "Spine doc"
# alphabetically, which puts the folders first in a Tags-sorted Finder window.
# NOTE: folders-before-files is Finder's "Keep folders on top" view setting, not
# something a tag controls. Tags group; that setting orders within the group.
DIR_TAG="Spine";      DIR_COLOUR=4      # blue
FILE_TAG="Spine doc"; FILE_COLOUR=3     # purple
                                        # 0 none · 1 grey · 2 green · 3 purple
                                        # 4 blue · 5 yellow · 6 red · 7 orange
XATTR="com.apple.metadata:_kMDItemUserTags"
SPINE_DIRS=(DOCS LATEX ISSUE_ANALYSES SESSIONS PRE_CONVERSION)
SPINE_FILES=(CLAUDE.md STATUS.md LOG.md DECISIONS.md TASKS.md README.md PLAN.md)

mode="apply"
case "${1:-}" in
  --check) mode="check"; shift ;;
  --clear) mode="clear"; shift ;;
  -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
esac

[ $# -eq 0 ] && set -- .

rc=0
for repo in "$@"; do
  [ -d "$repo" ] || continue
  [ -f "$repo/CLAUDE.md" ] || continue          # not a Claude project; skip in silence
  name=$(basename "$(cd "$repo" && pwd)")
  printf '%s\n' "── $name"
  for item in "${SPINE_DIRS[@]}" "${SPINE_FILES[@]}"; do
    target="$repo/$item"
    case " ${SPINE_DIRS[*]} " in *" $item "*) kind=dir ;; *) kind=file ;; esac
    if [ "$kind" = dir ]; then
      TAG_NAME="$DIR_TAG";  TAG_COLOUR="$DIR_COLOUR";  label="$item/"
      [ -d "$target" ] || { printf '   %-16s missing\n' "$label"; continue; }
    else
      TAG_NAME="$FILE_TAG"; TAG_COLOUR="$FILE_COLOUR"; label="$item"
      # PLAN.md is optional; its absence is not a fault.
      [ -f "$target" ] || { [ "$item" = PLAN.md ] || printf '   %-16s missing\n' "$label"; continue; }
    fi
    case "$mode" in
      check)
        # Read the xattr, NOT `mdls`. mdls reports Spotlight's index, which lags a
        # few seconds behind a write — measured 2026-08-03, when --check called
        # four folders UNTAGGED immediately after tagging them successfully. The
        # xattr is the authoritative store and is readable at once.
        if python3 - "$target" <<PY 2>/dev/null
import plistlib, subprocess, sys
# -x is required: without it xattr emits raw binary and any text filter chokes.
r = subprocess.run(["xattr", "-p", "-x", "$XATTR", sys.argv[1]],
                   capture_output=True, text=True)
h = "".join(r.stdout.split())
sys.exit(0 if r.returncode == 0 and h and "$TAG_NAME" in str(plistlib.loads(bytes.fromhex(h))) else 1)
PY
        then
          printf '   %-16s tagged\n' "$label"
        else
          printf '   %-16s UNTAGGED\n' "$label"; rc=1
        fi
        ;;
      clear)
        xattr -d "$XATTR" "$target" 2>/dev/null
        printf '   %-16s cleared\n' "$label"
        ;;
      apply)
        if python3 - "$target" <<PY 2>/dev/null
import plistlib, subprocess, sys
data = plistlib.dumps(["$TAG_NAME\n$TAG_COLOUR"], fmt=plistlib.FMT_BINARY)
subprocess.run(["xattr", "-w", "-x", "$XATTR", data.hex(), sys.argv[1]], check=True)
PY
        then printf '   %-16s tagged\n' "$label"
        else printf '   %-16s FAILED\n' "$label"; rc=1
        fi
        ;;
    esac
  done
done
exit $rc
