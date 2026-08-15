#!/usr/bin/env bash
# claude-handoff-guard.sh — Claude Code "PostToolUse" hook on `git push`.  Task #4.
#
# Makes "commit and push means I may be leaving" mechanical instead of a prose rule
# that has to be remembered. the owner says "commit and push" without exiting Claude, and
# by the standard that is the end of a session: STATUS.md's active thread refreshed,
# the session log finalized, then the commit. The push is the last observable moment
# at which that can still be caught, so this fires there.
#
# It runs AFTER the push, which is deliberate. PreToolUse would let it block the push
# itself, which is the wrong trade: a blocked push is a real cost, while a nudge that
# arrives a second late still gets the handoff finished before the terminal closes.
# On PostToolUse the turn continues regardless, so this nudges rather than derails.
#
# Design constraints, all recorded decisions — do not relax without changing them:
#
#   D10  fail open. Every error path exits 0 with no output.
#   D11  WARN-ONLY. It emits `systemMessage` (for the owner) and `additionalContext` (for
#        the assistant). It never emits `decision: "block"`. The blocking form is
#        written out, commented, at the bottom of this file.
#   D17  reads and writes nothing under ~/Dropbox.
#
# Scope: engages only in a tree with BOTH `CLAUDE.md` and `sessions/`, exactly like
# the Stop guard and the log-debt hook. Silent in the ten non-Claude repos.
#
# Registration: the `if:` key does the command filtering, so this script never has to
# parse `git push` out of a command line. Measured 2026-07-31 (Task #4) — with
#     "matcher": "Bash",  "if": "Bash(git push *)"
# the hook fired for `git push --dry-run origin main` and NOT for `echo …` or `cd …`,
# while an otherwise identical registration without `if` fired for all three. The key
# is real and it filters. The script still re-checks `tool_input.command` itself, so a
# future settings edit that drops the `if` cannot turn this into a hook that nags after
# every shell command.
#
# Payload fields used (measured from real PostToolUse payloads, Task #4):
#   session_id, transcript_path, cwd, tool_name, tool_input.command, tool_response

HOOK_JSON="$(cat)"
export HOOK_JSON

python3 - <<'PY' || true
import os, sys, json, glob, re, subprocess

def quit_quiet():
    sys.exit(0)

try:
    hook = json.loads(os.environ.get("HOOK_JSON") or "{}")
except Exception:
    quit_quiet()
if not isinstance(hook, dict):
    quit_quiet()

if hook.get("tool_name") != "Bash":
    quit_quiet()

cmd = ((hook.get("tool_input") or {}).get("command") or "")
if not isinstance(cmd, str):
    quit_quiet()

# Belt and braces behind the `if:` filter. Matches `git push` anywhere in the command
# so a compound `git commit -q -m '…' && git push` is caught, which is the shape the owner
# actually types. `--dry-run` is excluded: it changes nothing, so it is not a handoff.
if not re.search(r"\bgit\s+(-C\s+\S+\s+)?push\b", cmd):
    quit_quiet()
if "--dry-run" in cmd:
    quit_quiet()

# --- SESSIONS/ vs sessions/ ------------------------------------------------
# D23 renamed sessions/ -> SESSIONS/, but the migrations (#7-#11) land one repo at
# a time. Both guards must accept either name for the whole of that window, or the
# first rename silently blinds them in every repo that has not been done yet.
def sessdir(root):
    for n in ("SESSIONS", "sessions"):
        if os.path.isdir(os.path.join(root, n)):
            return n
    return None

session = hook.get("session_id") or ""
tpath   = hook.get("transcript_path") or ""
cwd     = hook.get("cwd") or ""
if not session:
    quit_quiet()

def project_root(start):
    home = os.path.realpath(os.path.expanduser("~"))
    d = os.path.realpath(start) if start else ""
    for _ in range(8):
        if not d or d == "/":
            return None
        if (os.path.isfile(os.path.join(d, "CLAUDE.md"))
                and sessdir(d)):
            return d
        if d == home:
            return None
        d = os.path.dirname(d)
    return None

root = project_root(cwd)
if not root:
    quit_quiet()

def git(*args):
    try:
        out = subprocess.run(["git", "-C", root] + list(args),
                             capture_output=True, timeout=5)
        if out.returncode != 0:
            return None
        return out.stdout.decode("utf-8", "replace")
    except Exception:
        return None

warnings = []

# --- 1. the session log, same counters as the Stop guard -------------------
# Duplicated rather than shared: see the note in claude-log-debt.sh. If this filter
# changes, change it in all three hooks.
HARNESS_PREFIXES = (
    "<system-reminder>", "<command-name>", "<command-message>", "<command-args>",
    "<local-command-stdout>", "<local-command-stderr>", "<user-memory-input>",
    "[Request interrupted", "<task-notification>",
)
def index_rows(path):
    """Rows of a machine-extracted prompt index — `- `NN` · <time> · <text>` (D27).

    A session log may account for its prompts either by per-prompt `## P##` entries
    or by an index generated from the transcript. The index is the MORE complete of
    the two, so a guard that only counts entries reports a fuller log as delinquent
    and then warns on every push — D11's failure mode.
    """
    n = 0
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                if re.match(r"^- `\d+`\s*·", line):
                    n += 1
    except Exception:
        return 0
    return n

SESSION_RE = re.compile(r"<!--\s*session:\s*([0-9a-fA-F-]{8,})\s*-->")

def prompt_text(rec):
    """The user's own words, or None if the record is not a prompt.

    Measured 2026-07-31 (Task #4): `message.content` is a STRING for a typed prompt
    and a LIST for BOTH tool results and a prompt carrying an attachment
    ([{"type":"image"}, {"type":"text"}]). Skipping every list drops real prompts.
    """
    content = (rec.get("message") or {}).get("content")
    if isinstance(content, str):
        s = content.strip()
    elif isinstance(content, list):
        if any(isinstance(e, dict) and e.get("type") == "tool_result" for e in content):
            return None
        s = " ".join(e.get("text") or "" for e in content
                     if isinstance(e, dict) and e.get("type") == "text").strip()
    else:
        return None
    if not s or s.startswith(HARNESS_PREFIXES):
        return None
    return s

prompts = 0
if tpath and os.path.exists(tpath):
    try:
        with open(tpath, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    rec = json.loads(line)
                except Exception:
                    continue
                if rec.get("type") != "user":
                    continue
                if rec.get("isSidechain") or rec.get("isMeta") or rec.get("isCompactSummary"):
                    continue
                if prompt_text(rec) is None:
                    continue
                prompts += 1
    except Exception:
        prompts = 0

log_path = None
try:
    for cand in sorted(glob.glob(os.path.join(root, sessdir(root) or "SESSIONS", "*.md"))):
        try:
            with open(cand, encoding="utf-8", errors="replace") as fh:
                head = [next(fh, "") for _ in range(10)]
        except Exception:
            continue
        for ln in head:
            m = SESSION_RE.search(ln)
            if m and m.group(1) == session:
                log_path = cand
                break
        if log_path:
            break
except Exception:
    pass

if prompts:
    if log_path is None:
        # Say WHICH failure this is. "No log was opened" and "a log exists but
        # carries no id comment" need opposite fixes, and a session that has been
        # working all day almost always has a file. Conflating them sent one session
        # chasing a filename-date theory that no guard has ever implemented — both
        # guards match on the id comment and never look at the filename.
        n_logs = 0
        try:
            n_logs = len(glob.glob(os.path.join(root, sessdir(root) or "SESSIONS", "*.md")))
        except Exception:
            pass
        if n_logs:
            warnings.append(
                "no session log carries this session's id (%d prompt%s). "
                "SESSIONS/ holds %d log%s — if one of them is this session's, add "
                "`<!-- session: %s -->` as its second line; the guards match on that "
                "comment, never on the filename"
                % (prompts, "" if prompts == 1 else "s",
                   n_logs, "" if n_logs == 1 else "s", session))
        else:
            warnings.append(
                "no session log was ever opened for this session (%d prompt%s) — "
                "expected SESSIONS/<date>_<HHMM>_<TZ>_<host>.md with "
                "`<!-- session: %s -->` as its second line"
                % (prompts, "" if prompts == 1 else "s", session))
    else:
        entries = 0
        try:
            with open(log_path, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    if re.match(r"^##\s+P\d", line):
                        entries += 1
        except Exception:
            entries = prompts        # unreadable: assume fine rather than nag
        # A gap of one is the in-flight prompt, not a lapse — see the log guard.
        if max(entries, index_rows(log_path)) < prompts - 1:   # D27
            warnings.append("%s has %d `## P` entr%s for %d prompt%s"
                            % (os.path.relpath(log_path, root), entries,
                               "y" if entries == 1 else "ies", prompts,
                               "" if prompts == 1 else "s"))

# --- 2. did STATUS.md move at all this session? ----------------------------
# The handoff rule is specifically that the ACTIVE THREAD is refreshed before the
# push. Checking mtime against the newest tracked file (what the Stop guard does)
# answers a different question. Here the sharper test is whether STATUS.md is among
# the files whose content changed in the commits that were just pushed.
head_status = git("log", "-1", "--format=%H", "--", "STATUS.md")
head_all    = git("log", "-1", "--format=%H")
if head_status is not None and head_all is not None:
    hs, ha = head_status.strip(), head_all.strip()
    if hs and ha and hs != ha:
        # STATUS.md was not touched by the tip commit. Only worth saying if some
        # other spine-relevant file was.
        changed = git("show", "--name-only", "--format=", "HEAD") or ""
        names = [n for n in changed.split("\n") if n.strip()]
        substantive = [n for n in names
                       if not n.split("/")[0] in ("SESSIONS", "sessions") and n not in ("LOG.md",)]
        if substantive:
            warnings.append("STATUS.md is not in the commit just pushed, which changed "
                            + ", ".join(substantive[:4])
                            + ("…" if len(substantive) > 4 else ""))

# --- 3. anything left uncommitted? -----------------------------------------
# A push with tracked modifications still sitting in the tree is the classic
# half-finished handoff. Untracked files are NOT reported: new scratch files are
# normal and naming them would make this noisy.
porcelain = git("status", "--porcelain")
if porcelain:
    dirty = [ln[3:] for ln in porcelain.split("\n")
             if ln.strip() and not ln.startswith("??")]
    if dirty:
        warnings.append("%d tracked file%s still modified and unpushed: %s%s"
                        % (len(dirty), "" if len(dirty) == 1 else "s",
                           ", ".join(dirty[:4]), "…" if len(dirty) > 4 else ""))

if not warnings:
    quit_quiet()

msg = ("handoff guard (warn-only): pushed, but the handoff looks unfinished — "
       + "; ".join(warnings) + ".")

# --- D11: warn only -------------------------------------------------------
# `systemMessage` is for the owner; `additionalContext` is for the assistant, so the
# nudge lands on whoever can act on it. Neither can block: the turn continues.
#
# To make it blocking later (only after the observation period D11 requires), replace
# the print below with:
#     print(json.dumps({"decision": "block", "reason": msg}))
# On PostToolUse a block feeds the reason back and the turn continues, so even the
# blocking form here cannot derail a session — it is closer to a loud warning.
print(json.dumps({
    "systemMessage": msg,
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": msg + " If the owner is leaving, finish the active thread in "
                                   "STATUS.md and the session log, then commit again.",
    },
}))
PY

exit 0
