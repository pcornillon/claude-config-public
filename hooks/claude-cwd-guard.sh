#!/usr/bin/env bash
# claude-cwd-guard.sh — Claude Code "SessionStart" hook.  Task #20, D31.
#
# Warn when a session is starting somewhere that will scatter its own record.
#
# THE PROBLEM THIS EXISTS FOR, measured 2026-08-03:
#
# A session's project folder — ~/.claude/projects/<slugified-cwd>/ — is fixed at
# session START and never moves. `cd` during the session does not change it. On
# 2026-08-03 a session was started from $HOME, ran for six hours across ELEVEN
# directories (claude-config-public, three-way…, example-codification, example-abstract,
# example-registry, …), and filed all 21 of its prompts under
#   ~/.claude/projects/-Users-petercornillon/
# Looking in claude-config-public's own project folder that day showed a jump from 10:15 to
# 15:26 with nothing between, and the morning's work — including the prompt that
# proposed the whole spine change — looked lost. It was not lost; it was filed under
# the home directory, which nobody thinks to search.
#
# Nothing downstream can repair this. The session log, the prompt index and the
# Stop-hook transcript all key off the project folder. The only cheap fix is to say
# so at the one moment it can still be acted on: before any work has been done.
#
# WHAT IT CHECKS (cheapest first, most severe first):
#
#   1. cwd is $HOME exactly                → loud. This is the measured failure.
#   2. cwd is not inside a git work tree   → loud. Same consequence, other paths.
#   3. cwd is inside a repo but not at its root → quiet note. The record still lands
#      in one place per subdirectory, so two sessions in two subdirectories of one
#      repo file separately. Worth knowing, not worth a warning.
#
# A session started at a repo root — the overwhelmingly common case — prints nothing.
#
# Design constraints, matching the other hooks in this directory:
#
#   D10  fail open. Every error path exits 0 with no output.
#   D11  informational only. It emits a message; it never blocks a session starting.
#   D31  the warning fires at SessionStart, not at Stop or SessionEnd. By Stop the
#        project folder is already fixed and the advice is useless.
#
# It does NOT fire on source=clear or source=compact: those re-enter a session whose
# project folder was decided long ago, so the advice would be noise.
#
# Payload fields used (SessionStart): cwd, source.

HOOK_JSON="$(cat)"
export HOOK_JSON

python3 - <<'PY' || true
import os, sys, json, subprocess

def quit_quiet():
    sys.exit(0)

try:
    hook = json.loads(os.environ.get("HOOK_JSON") or "{}")
except Exception:
    quit_quiet()
if not isinstance(hook, dict):
    quit_quiet()

if (hook.get("hook_event_name") or "") != "SessionStart":
    quit_quiet()

# Only the entry points that actually choose a project folder.
if (hook.get("source") or "startup") not in ("startup", "resume"):
    quit_quiet()

cwd = hook.get("cwd") or ""
if not cwd:
    quit_quiet()
try:
    cwd = os.path.realpath(cwd)
except Exception:
    quit_quiet()
home = os.path.realpath(os.path.expanduser("~"))

WHY = ("A session's project folder is fixed at start and never follows `cd`, so every "
       "prompt, the Stop-hook transcript and the prompt index will file under this "
       "path for the whole session.")

def git_root(d):
    try:
        out = subprocess.run(
            ["git", "-C", d, "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=5)
    except Exception:
        return None
    if out.returncode != 0:
        return None
    root = (out.stdout or "").strip()
    return os.path.realpath(root) if root else None

root = git_root(cwd)

if cwd == home:
    msg = ("Started in your HOME directory, not a repository. " + WHY + " On "
           "2026-08-03 this scattered six hours of claude-config-public work under "
           "~/.claude/projects/-Users-petercornillon/ and it took a search across "
           "every project folder to find it again. If this session is meant to work "
           "on a project, exit and restart inside that repo.")
    level = "warn"
elif root is None:
    msg = ("Started outside any git repository (%s). " % cwd + WHY + " If this "
           "session is meant to work on a project, exit and restart inside that repo.")
    level = "warn"
elif root != cwd:
    msg = ("Started in a subdirectory of %s, not at its root. " % os.path.basename(root)
           + "The record will file under this subdirectory rather than the repo, so a "
           "session started elsewhere in the same repo files separately. Harmless if "
           "deliberate.")
    level = "note"
else:
    quit_quiet()

out = {
    "systemMessage": ("Session location: " if level == "note" else
                      "Session location — worth fixing now: ") + msg,
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": (
            "Session-location check: " + msg +
            " Raise this with the owner rather than acting on it; a session cannot move "
            "its own project folder."),
    },
}
print(json.dumps(out))
PY

exit 0
