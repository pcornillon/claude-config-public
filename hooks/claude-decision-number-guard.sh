#!/usr/bin/env bash
# claude-decision-number-guard.sh — Claude Code "PreToolUse" hook.  Task #35, D54.
#
# Refuse a `git commit` that would put a repeated `D##` number into DECISIONS.md.
#
# THE PROBLEM THIS EXISTS FOR, measured 2026-09-08:
#
# A session on a checkout three commits behind `origin/main` appended a new decision as
# D48. `origin/main` already had a D48, and a D49 and a D50. DECISIONS.md is append-only
# and never renumbered, so a duplicate number is not a merge conflict to be resolved —
# it is a permanent ambiguity in every citation that ever says "D48". The collision was
# caught only because that session happened to run `git fetch` for an unrelated reason.
#
# This is the cheap, deterministic backstop for that: the number either repeats or it
# does not, and a `grep` can tell. `claude-repo-freshness.sh` (D52) reduces how often it
# happens; this catches it when it happens anyway — after a merge, on a second machine,
# or from a session that never fetched.
#
# WHAT IT CHECKS: every `^### D<number>.` heading in the repo's DECISIONS.md. A number
# appearing twice is a hard deny. Nothing else is: gaps are legitimate (numbers are
# retired, and two repos number independently), and out-of-order entries are a style
# matter, not a corruption.
#
# WHY PreToolUse RATHER THAN A GIT hook: git hooks are per-clone, uninstalled by
# default, and not carried by `git clone` — they would have to be laid down again on
# every machine and every new project. This configuration already deploys hooks
# centrally through settings.json, so the check reaches every repo at once.
#
# Design constraints:
#
#   D10  fail open. No repo, no DECISIONS.md, unreadable file, malformed payload,
#        anything unexpected → allow the commit, print nothing.
#   The ONLY outcome that ever blocks is a genuine repeated number. A guard that
#   blocks commits on a guess would be turned off within a day, and then it protects
#   nothing.
#
# Payload fields used (PreToolUse): tool_name, tool_input.command, cwd.

HOOK_JSON="$(cat)"
export HOOK_JSON

python3 - <<'PY' || true
import os, sys, json, re, subprocess
from collections import Counter

def quit_quiet():
    sys.exit(0)

try:
    hook = json.loads(os.environ.get("HOOK_JSON") or "{}")
except Exception:
    quit_quiet()
if not isinstance(hook, dict):
    quit_quiet()

if (hook.get("tool_name") or "") != "Bash":
    quit_quiet()

cmd = ((hook.get("tool_input") or {}).get("command") or "")
# `git commit` in any position of a compound command. `git commit --help`, and the
# word "commit" inside a message or a filename, are not it.
if not re.search(r"\bgit\s+(?:-[^\s]+\s+|--\S+\s+)*commit\b", cmd):
    quit_quiet()
if "--help" in cmd:
    quit_quiet()

cwd = hook.get("cwd") or os.getcwd()
try:
    p = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"],
                       capture_output=True, text=True, timeout=5)
except Exception:
    quit_quiet()
if p.returncode != 0:
    quit_quiet()
root = (p.stdout or "").strip()
if not root:
    quit_quiet()

path = os.path.join(root, "DECISIONS.md")
if not os.path.isfile(path):
    quit_quiet()
try:
    text = open(path, encoding="utf-8", errors="replace").read()
except Exception:
    quit_quiet()

nums = re.findall(r"^### +D(\d+)\.", text, re.M)
dupes = sorted({int(n) for n, c in Counter(nums).items() if c > 1})
if not dupes:
    quit_quiet()

listed = ", ".join("D%d" % n for n in dupes)
reason = (
    "DECISIONS.md has a repeated decision number: %s. That file is append-only and "
    "never renumbered, so a duplicate is not a conflict to resolve later — it "
    "permanently breaks every citation of that number, in code comments, tasks and "
    "other repos. The usual cause is appending on a checkout that is behind its "
    "upstream, where the number was already taken. Fetch, see which number upstream "
    "reached, renumber the local entry to the next free one, and update anything that "
    "cites it (LOG.md, TASKS.md, the session log). Then commit again."
    % listed)

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": reason,
    },
}))
PY

exit 0
