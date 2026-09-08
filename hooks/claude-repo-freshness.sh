#!/usr/bin/env bash
# claude-repo-freshness.sh — Claude Code "SessionStart" hook.  Task #33, D52.
#
# Say, before any work is done, that this checkout is behind its upstream — and say
# WHICH FILES are coming, because that is the only actionable part.
#
# THE PROBLEM THIS EXISTS FOR, measured 2026-09-08:
#
# A session in claude-config-public edited `global/CLAUDE.md`, `DECISIONS.md` and `LOG.md`
# on a checkout that was three commits behind `origin/main`. All three incoming
# commits touched all three files. The new decision was written as D48 — a number
# `origin/main` had already used, in an append-only log that is never renumbered.
#
# It was invisible for the ordinary reason: `git rev-list --left-right --count
# origin/main...HEAD` compares against the LOCAL `origin/main` ref, which had not been
# updated since 2026-09-05. It returned `0 0` and was believed. **A freshness check
# that does not fetch is worse than no check**, because it manufactures the confidence
# that stops the next person looking. So this hook always fetches, and stays silent
# rather than reporting from a stale ref.
#
# WHAT IT REPORTS, and what it deliberately does not:
#
#   * behind > 0  → the incoming commits, the files they touch, and — loudest — any of
#     those files that are ALSO modified in the working tree right now. That last set
#     is where the damage happens; everything else is context.
#   * behind == 0 → nothing at all. Most sessions are current, and a hook that speaks
#     every morning becomes wallpaper within a week. Alarm fatigue is the failure mode
#     that kills a check like this, so silence is the default.
#   * ahead > 0 with behind == 0 → nothing. Unpushed work is the handoff guard's job.
#
# IT NEVER PULLS, and it never asks Claude to pull. Two sessions can share one working
# tree (see "Concurrent sessions in one repo" in global/CLAUDE.md), so a pull can land
# on top of another lane's half-finished work. Reporting is safe; merging is not.
#
# Design constraints, matching the other hooks in this directory:
#
#   D10  fail open. Every error path — no remote, no upstream, no network, timeout,
#        detached HEAD, malformed payload — exits 0 with no output.
#   D11  informational only. It never blocks a session starting.
#   D31  it fires at SessionStart, for the same reason the cwd guard does: afterwards
#        the edits have already been made against the stale file.
#
# It requires a `CLAUDE.md` at the repo root — this is a check about Claude projects,
# and firing it in every unrelated repo on the machine would be noise with a network
# call attached.
#
# It does NOT fire on source=clear or source=compact: those re-enter a session that
# already ran this check, and a second network call says nothing new.
#
# Payload fields used (SessionStart): cwd, source.

HOOK_JSON="$(cat)"
export HOOK_JSON

python3 - <<'PY' || true
import os, sys, json, subprocess

def quit_quiet():
    sys.exit(0)

def git(root, *args, timeout=10):
    """stdout of a git command, or None on any failure at all."""
    try:
        p = subprocess.run(["git", "-C", root] + list(args),
                           capture_output=True, text=True, timeout=timeout)
    except Exception:
        return None
    return p.stdout.strip() if p.returncode == 0 else None

try:
    hook = json.loads(os.environ.get("HOOK_JSON") or "{}")
except Exception:
    quit_quiet()
if not isinstance(hook, dict):
    quit_quiet()

if (hook.get("hook_event_name") or "") != "SessionStart":
    quit_quiet()
if (hook.get("source") or "startup") not in ("startup", "resume"):
    quit_quiet()

cwd = hook.get("cwd") or ""
if not cwd:
    quit_quiet()
try:
    cwd = os.path.realpath(cwd)
except Exception:
    quit_quiet()

root = git(cwd, "rev-parse", "--show-toplevel", timeout=5)
if not root:
    quit_quiet()
root = os.path.realpath(root)

# A Claude project, not merely a git repo.
if not os.path.isfile(os.path.join(root, "CLAUDE.md")):
    quit_quiet()

branch = git(root, "rev-parse", "--abbrev-ref", "HEAD", timeout=5)
if not branch or branch == "HEAD":          # detached; nothing to be behind
    quit_quiet()

upstream = git(root, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}",
               timeout=5)
if not upstream:                            # no tracking branch — nothing to compare
    quit_quiet()
remote = upstream.split("/", 1)[0]

# THE FETCH. Without it every number below is read from a possibly ancient ref.
# 25s because this runs before the session can do anything useful anyway, and a
# check that gives up at 5s on a slow link silently degrades into the stale-ref bug
# it exists to prevent.
if git(root, "fetch", "--quiet", remote, timeout=25) is None:
    quit_quiet()                            # offline, unreachable, auth — say nothing

behind = git(root, "rev-list", "--count", "HEAD..@{u}", timeout=10)
if not behind or not behind.isdigit() or int(behind) == 0:
    quit_quiet()
behind = int(behind)

commits = (git(root, "log", "--oneline", "--no-decorate", "-8", "HEAD..@{u}",
               timeout=10) or "").splitlines()
files = (git(root, "diff", "--name-only", "HEAD...@{u}", timeout=10) or "").splitlines()
dirty = set((git(root, "diff", "--name-only", "HEAD", timeout=10) or "").splitlines())

overlap = [f for f in files if f in dirty]

parts = ["`%s` is %d commit%s behind `%s`."
         % (os.path.basename(root), behind, "" if behind == 1 else "s", upstream)]
if commits:
    shown = commits[:8]
    parts.append("Incoming: " + "; ".join(shown)
                 + ("; …." if behind > len(shown) else "."))
if files:
    parts.append("They touch: " + ", ".join(files[:12])
                 + (" (+%d more)." % (len(files) - 12) if len(files) > 12 else "."))
if overlap:
    parts.append("ALREADY MODIFIED HERE, so an edit will land on a stale file and "
                 "conflict: " + ", ".join(overlap) + ".")

msg = " ".join(parts)

out = {
    "systemMessage": "Checkout is behind upstream — " + msg,
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": (
            "Repo-freshness check (the local ref was refreshed by `git fetch`, so these "
            "counts are current): " + msg +
            " Raise it with the owner before editing any file listed above; do NOT pull on "
            "your own — this working tree may be shared with another session. Append-only "
            "files (`DECISIONS.md`, `LOG.md`, `TASKS.md`) are the ones that go wrong "
            "silently: numbers already used upstream will be reused here."),
    },
}
print(json.dumps(out))
PY

exit 0
