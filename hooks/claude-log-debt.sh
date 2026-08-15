#!/usr/bin/env bash
# claude-log-debt.sh — Claude Code "SessionEnd" + "SessionStart" hook.  Task #5.
#
# The breadcrumb that survives a session dying dirty.
#
# `claude-log-guard.sh` (Task #3) warns on every Stop while a session is alive. If
# the session ends anyway — terminal killed, /exit typed mid-thought, machine put to
# sleep — that warning dies with it and the next session opens knowing nothing. This
# hook closes that gap in two halves:
#
#   SessionEnd    count the unlogged prompts and APPEND one JSON line to a debt file.
#                 SessionEnd cannot block (D9), but it can leave a note.
#   SessionStart  read the debt file, inject any debt for THIS repo as context, and
#                 remove the lines it delivered so they are reported once, not forever.
#
# Design constraints, all recorded decisions — do not relax without changing them:
#
#   D9   SessionEnd cannot block or prompt; it records and nothing more. The
#        enforcement layer is Stop (Task #3), not this.
#   D10  fail open. Every error path exits 0 with no output.
#   D11  informational only. SessionStart emits `additionalContext`; it never blocks
#        a session from starting, and nothing here can wedge a startup.
#   D17  the debt file is MACHINE-LOCAL — $HOME/.claude/log-debt.jsonl — and never
#        under ~/Dropbox, where an online-only file reads 0 bytes and appends are
#        silently reverted. That failure mode would make this hook worse than absent:
#        it would look like "no debt" instead of "cannot tell".
#
# Scope: engages only in a tree that has BOTH `CLAUDE.md` and `sessions/`, exactly
# like the Stop guard. Silent in the ten non-Claude repos.
#
# Payload fields used (measured from real payloads, Task #3):
#   SessionEnd    session_id, transcript_path, cwd, reason
#   SessionStart  session_id, cwd, source
# `transcript_path` is the session JSONL under ~/.claude/projects/<slug>/<id>.jsonl,
# NOT the Dropbox prose transcript — that one is a rendering of this one.

HOOK_JSON="$(cat)"
export HOOK_JSON

python3 - <<'PY' || true
import os, sys, json, glob, re, time

DEBT = os.path.join(os.path.expanduser("~"), ".claude", "log-debt.jsonl")
MAX_AGE_DAYS = 14        # older breadcrumbs are noise, not news
MAX_REPORTED = 5         # never dump more than five at a startup

def quit_quiet():
    sys.exit(0)

try:
    hook = json.loads(os.environ.get("HOOK_JSON") or "{}")
except Exception:
    quit_quiet()
if not isinstance(hook, dict):
    quit_quiet()

event   = hook.get("hook_event_name") or ""
session = hook.get("session_id") or ""
cwd     = hook.get("cwd") or ""
if not session:
    quit_quiet()

# --- scope: a Claude project is a dir with CLAUDE.md AND sessions/ ---------
def project_root(start):
    home = os.path.realpath(os.path.expanduser("~"))
    d = os.path.realpath(start) if start else ""
    for _ in range(8):
        if not d or d == "/":
            return None
        if (os.path.isfile(os.path.join(d, "CLAUDE.md"))
                and os.path.isdir(os.path.join(d, "sessions"))):
            return d
        if d == home:
            return None
        d = os.path.dirname(d)
    return None

root = project_root(cwd)
if not root:
    quit_quiet()

# --- shared with claude-log-guard.sh: count prompts, count `## P` ----------
# Kept deliberately identical to the Stop guard's filter so the two layers cannot
# disagree about how far behind a session is. It UNDERCOUNTS where the record shape
# is uncertain: an undercount makes this quieter, an overcount would cry wolf.
HARNESS_PREFIXES = (
    "<system-reminder>", "<command-name>", "<command-message>", "<command-args>",
    "<local-command-stdout>", "<local-command-stderr>", "<user-memory-input>",
    "[Request interrupted", "<task-notification>",
)
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

def count_prompts(tpath):
    n = 0
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
            n += 1
    return n

def find_log(root, session):
    for cand in sorted(glob.glob(os.path.join(root, "sessions", "*.md"))):
        try:
            with open(cand, encoding="utf-8", errors="replace") as fh:
                head = [next(fh, "") for _ in range(10)]
        except Exception:
            continue
        for ln in head:
            m = SESSION_RE.search(ln)
            if m and m.group(1) == session:
                return cand
    return None

def count_entries(path):
    n = 0
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if re.match(r"^##\s+P\d", line):
                n += 1
    return n

def read_debt():
    rows = []
    if not os.path.isfile(DEBT):
        return rows
    try:
        with open(DEBT, encoding="utf-8", errors="replace") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    r = json.loads(line)
                except Exception:
                    continue          # a torn line is skipped, never fatal
                if isinstance(r, dict):
                    rows.append(r)
    except Exception:
        return []
    return rows

def write_debt(rows):
    # temp + rename so a crash mid-write cannot leave a truncated file
    tmp = DEBT + ".tmp.%d" % os.getpid()
    with open(tmp, "w", encoding="utf-8") as fh:
        for r in rows:
            fh.write(json.dumps(r) + "\n")
    os.replace(tmp, DEBT)

# =========================== SessionEnd ===================================
if event == "SessionEnd":
    tpath = hook.get("transcript_path") or ""
    if not tpath or not os.path.exists(tpath):
        quit_quiet()
    try:
        prompts = count_prompts(tpath)
    except Exception:
        quit_quiet()
    if prompts == 0:
        quit_quiet()

    log_path = find_log(root, session)
    entries = 0
    if log_path:
        try:
            entries = count_entries(log_path)
        except Exception:
            quit_quiet()
    if entries >= prompts:
        quit_quiet()                  # the log is current; leave no breadcrumb

    row = {
        "session":    session,
        "repo":       os.path.basename(root),
        "root":       root,
        "ended":      time.strftime("%Y-%m-%d %H:%M %Z", time.localtime()),
        "ended_epoch": int(time.time()),
        "reason":     hook.get("reason") or "",
        "prompts":    prompts,
        "entries":    entries,
        "gap":        prompts - entries,
        "log":        os.path.relpath(log_path, root) if log_path else None,
        "transcript": tpath,
    }
    try:
        os.makedirs(os.path.dirname(DEBT), exist_ok=True)
        with open(DEBT, "a", encoding="utf-8") as fh:
            fh.write(json.dumps(row) + "\n")
    except Exception:
        pass
    quit_quiet()                      # SessionEnd output is never displayed (D9)

# =========================== SessionStart =================================
if event != "SessionStart":
    quit_quiet()

rows = read_debt()
if not rows:
    quit_quiet()

now = int(time.time())
cutoff = now - MAX_AGE_DAYS * 86400
kept, mine = [], []
for r in rows:
    try:
        if int(r.get("ended_epoch") or 0) < cutoff:
            continue                  # aged out — dropped, not reported
    except Exception:
        continue
    if r.get("root") == root and r.get("session") != session:
        mine.append(r)
    else:
        kept.append(r)

if not mine:
    # Nothing to report, but rows may have aged out of `rows` on the way here. Rewrite
    # only if that actually happened, so the common case does no I/O at all — without
    # this, an expired row is never reported and never removed, and the file grows
    # forever. Measured: it did exactly that before this branch existed.
    if len(kept) != len(rows):
        try:
            write_debt(kept)
        except Exception:
            pass
    quit_quiet()

mine.sort(key=lambda r: r.get("ended_epoch") or 0)
shown = mine[-MAX_REPORTED:]
dropped = len(mine) - len(shown)

lines = ["Log debt from previous session(s) in this repo — the curated log was left "
         "behind when the session ended. This is a note, not an instruction: raise it "
         "with the owner before backfilling anything."]
for r in shown:
    lines.append(
        "- session %s ended %s (%s): %s user prompt(s), %s `## P` entr(y/ies) — %s "
        "unlogged. Log: %s. Raw JSONL: %s"
        % (str(r.get("session"))[:8], r.get("ended"), r.get("reason") or "unknown",
           r.get("prompts"), r.get("entries"), r.get("gap"),
           r.get("log") or "none was ever opened", r.get("transcript")))
if dropped:
    lines.append("- (%d older entr%s not shown)" % (dropped, "y" if dropped == 1 else "ies"))

# Delivered once: the reported rows are removed. If this session also dies dirty its
# own SessionEnd writes a fresh row, so nothing is lost by clearing here — whereas
# keeping them would repeat the same debt at every startup until it was paid.
try:
    write_debt(kept)
except Exception:
    pass

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": "\n".join(lines),
    }
}))
PY

exit 0
