#!/usr/bin/env bash
# claude-log-guard.sh — Claude Code "Stop" hook.  Task #3.
#
# Keeps the CURATED session log current. `claude-prose-log.sh` already guarantees
# the raw dialog survives; this guards the layer that can actually lapse — the
# per-prompt `## P##` entries in sessions/<...>.md.
#
# It compares three things, all cheap:
#
#   1. user prompts in the session JSONL   vs   `## P` headings in this session's log
#   2. whether a session log exists for this session at all
#   3. STATUS.md's mtime                   vs   the newest git-tracked file
#
# and reports what it finds as a single `systemMessage`.
#
# Design constraints, all recorded decisions — do not relax without changing them:
#
#   D9   it runs on Stop, after every assistant turn, so the log can never fall
#        more than one turn behind. SessionEnd is too late and does not fire on a
#        killed terminal.
#   D10  fail open. Every error path exits 0 with no output. Self-limiting via
#        `stop_hook_active` from the payload (measured present, Task #3) — there is
#        no state file and nothing to get stuck.
#   D11  WARN-ONLY. It emits `systemMessage` and never `{"decision":"block"}`, until
#        a week of observation shows how often it fires and whether it is right.
#        The blocking form is written out at the bottom of this file, commented, so
#        flipping it later is a deliberate edit rather than a rewrite.
#   D17  it reads and writes nothing under ~/Dropbox — online-only files there read
#        as 0 bytes and appends are silently reverted.
#
# Scope: it engages only in a directory tree that has BOTH `CLAUDE.md` and
# `sessions/`. In the ten non-Claude repos it exits 0 in silence.
#
# Payload fields used (measured from eight real Stop payloads, Task #3):
#   stop_hook_active, transcript_path, session_id, cwd
# `transcript_path` is the session JSONL under ~/.claude/projects/<slug>/<id>.jsonl,
# NOT the Dropbox prose transcript — that one is a rendering of this one.

HOOK_JSON="$(cat)"
export HOOK_JSON

# All real work in python3 (guaranteed present on these machines), guarded, and the
# script exits 0 regardless. stdin is already consumed above, so the heredoc is free.
python3 - <<'PY' || true
import os, sys, json, glob, re, subprocess, time

def quit_quiet():
    sys.exit(0)

try:
    hook = json.loads(os.environ.get("HOOK_JSON") or "{}")
except Exception:
    quit_quiet()
if not isinstance(hook, dict):
    quit_quiet()

# --- D10: self-limiting ---------------------------------------------------
# True only when a Stop hook already blocked and the assistant was resumed by it.
# Warn-only never sets it, but the check is here so that flipping to blocking mode
# cannot produce an infinite Stop loop.
if hook.get("stop_hook_active"):
    quit_quiet()

session = hook.get("session_id") or ""
tpath   = hook.get("transcript_path") or ""
cwd     = hook.get("cwd") or ""
if not session or not tpath or not os.path.exists(tpath):
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

# --- scope: a Claude project is a dir with CLAUDE.md AND SESSIONS/ (or legacy sessions/) ---------
def project_root(start):
    home = os.path.realpath(os.path.expanduser("~"))
    d = os.path.realpath(start) if start else ""
    for _ in range(8):
        if not d or d == "/":
            return None
        if (os.path.isfile(os.path.join(d, "CLAUDE.md"))
                and sessdir(d)):
            return d
        if d == home:          # never walk above the home directory
            return None
        d = os.path.dirname(d)
    return None

root = project_root(cwd)
if not root:
    quit_quiet()               # silent in every non-Claude repo

# --- 1. count user prompts in the session JSONL ---------------------------
# Same main-chain filter as claude-prose-log.sh, plus the harness-injected shapes.
# It deliberately UNDERCOUNTS where the shape is uncertain (slash-command records
# are unmeasured): an undercount only makes the guard quieter, an overcount would
# nag falsely.
HARNESS_PREFIXES = (
    "<system-reminder>", "<command-name>", "<command-message>", "<command-args>",
    "<local-command-stdout>", "<local-command-stderr>", "<user-memory-input>",
    "[Request interrupted", "<task-notification>",
)

def prompt_text(rec):
    """The user's own words in a JSONL record, or None if it is not a prompt.

    Measured 2026-07-31 (Task #4): `message.content` is a STRING for a plain typed
    prompt and a LIST for two quite different things — tool results (39 of them in
    the session sampled) and a prompt carrying an attachment, which arrives as
    [{"type":"image"}, {"type":"text"}]. The first version of this filter skipped
    every list as "tool results, not the user speaking" and therefore silently
    dropped a real prompt: the session where the owner pasted a screenshot counted 3
    prompts against 3 log entries and looked current when it was one behind.
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
    quit_quiet()

if prompts == 0:
    quit_quiet()

# --- 2. find this session's log by its id ---------------------------------
# The convention puts `<!-- session: <id> -->` on line 2, but measured 2026-07-31:
# one of the four existing logs carries it on line 3 (a blank line after the `#`
# heading). Scanning the head instead of pinning line 2 avoids reporting "no log
# open" for a log that is in fact open — the worst possible false positive here.
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
    quit_quiet()

warnings = []

if log_path is None:
    warnings.append(
        "no session log is open for this session — expected "
        "SESSIONS/<date>_<HHMM>_<TZ>_<host>.md with "
        "`<!-- session: %s -->` near the top (%d prompt%s so far)"
        % (session, prompts, "" if prompts == 1 else "s"))
else:
    entries = 0
    try:
        with open(log_path, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                if re.match(r"^##\s+P\d", line):
                    entries += 1
    except Exception:
        quit_quiet()
    idx = index_rows(log_path)
    covered = max(entries, idx)                       # D27
    # The prompt being handled right now cannot yet be logged — its entry is written
    # during the turn, and a push can happen before that. A gap of one is therefore
    # expected, not a lapse; warning on it would make the guard fire on every mid-session
    # push, which is the D11 failure this guard already had once. Anything larger is real.
    IN_FLIGHT = 1
    if covered < prompts - IN_FLIGHT:
        gap = prompts - covered
        warnings.append(
            "%s is %d prompt%s behind — %d user prompt%s this session, %d `## P` "
            "entr%s%s in the log"
            % (os.path.relpath(log_path, root), gap, "" if gap == 1 else "s",
               prompts, "" if prompts == 1 else "s",
               entries, "y" if entries == 1 else "ies",
               "" if not idx else " and a %d-row prompt index" % idx))
    elif idx >= prompts and entries * 2 < prompts:
        # D27's live tension: the index discharges the obligation, but it only
        # records what was ASKED. The curated entries carry what was decided and why.
        warnings.append(
            "%s is covered by its prompt index (%d rows) but has only %d curated "
            "`## P` entr%s — the index records what was asked, not what was decided"
            % (os.path.relpath(log_path, root), idx, entries,
               "y" if entries == 1 else "ies"))

# --- 3. STATUS.md vs the newest tracked file ------------------------------
# `sessions/**` and `LOG.md` are excluded: both are written every turn by design,
# so including them would leave STATUS.md permanently "stale" and the warning would
# be noise from the first turn onward. The 5-minute tolerance covers a STATUS.md
# written moments before another file in the same turn.
STATUS_TOLERANCE = 300

status = os.path.join(root, "STATUS.md")
if os.path.isfile(status):
    try:
        out = subprocess.run(
            ["git", "-C", root, "ls-files", "-z"],
            capture_output=True, timeout=5)
        files = [f for f in out.stdout.decode("utf-8", "replace").split("\0") if f]
    except Exception:
        files = []
    if files and len(files) <= 5000:      # cap: this runs on every turn
        s_mtime = os.path.getmtime(status)
        newest, newest_mtime = None, 0.0
        for rel in files:
            if rel == "STATUS.md" or rel == "LOG.md" or rel.split("/")[0] in ("SESSIONS", "sessions"):
                continue
            try:
                m = os.path.getmtime(os.path.join(root, rel))
            except OSError:
                continue
            if m > newest_mtime:
                newest, newest_mtime = rel, m
        if newest and newest_mtime > s_mtime + STATUS_TOLERANCE:
            age = int((newest_mtime - s_mtime) // 60)
            warnings.append(
                "STATUS.md is older than %s by %d min — check whether the active "
                "thread still describes the project" % (newest, age))

if not warnings:
    quit_quiet()

# --- D11: warn only -------------------------------------------------------
# One JSON object on stdout, carrying `systemMessage` and nothing else. No
# `decision`, no `reason`: this cannot block, cannot alter the turn, and cannot
# wedge a session.
#
# To make it blocking later (only after the observation period D11 requires), add:
#     "decision": "block",
#     "reason":   "<the same text, addressed to the assistant>"
# The `stop_hook_active` check at the top is already in place for that day.
print(json.dumps({
    "systemMessage": "log guard (warn-only): " + "; ".join(warnings) + "."
}))
PY

exit 0
