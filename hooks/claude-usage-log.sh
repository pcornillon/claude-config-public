#!/usr/bin/env bash
# claude-usage-log.sh — Claude Code "Stop" hook.
#
# Maintains one CSV row per session in ~/.claude/archive/usage-log.csv with the
# session's cumulative token usage, so cost/usage across sessions is trackable.
#
# Wiring (already in place): ~/.claude/settings.json -> ~/.claude/archive/settings.json
# registers this under hooks.Stop alongside claude-prose-log.sh. The hook JSON
# arrives on stdin with `transcript_path` + `session_id`; the token counts live on
# each assistant record's message.usage in that JSONL. Stop fires every turn, so
# this UPSERTS the session's row (replace-or-append) and rewrites the CSV
# atomically each time — the row always reflects the session's latest totals.
#
# Never fails the hook: work is in python3 (guaranteed present), guarded, exit 0.

OUTFILE="${CLAUDE_ARCHIVE_DIR:-$HOME/.claude/archive}/usage-log.csv"

# Consume the hook JSON from stdin (frees stdin for the heredoc'd program).
HOOK_JSON="$(cat)"
export HOOK_JSON OUTFILE

python3 - <<'PY' || true
import os, json, csv, tempfile

outfile = os.environ["OUTFILE"]

try:
    hook = json.loads(os.environ.get("HOOK_JSON") or "{}")
except Exception:
    raise SystemExit(0)

tpath = hook.get("transcript_path") or ""
session = hook.get("session_id") or (
    os.path.splitext(os.path.basename(tpath))[0] if tpath else "")
if not session or not tpath or not os.path.exists(tpath):
    raise SystemExit(0)

# --- sum token usage across the session's assistant records ---------------
tok = {"input_tokens": 0, "output_tokens": 0,
       "cache_creation_input_tokens": 0, "cache_read_input_tokens": 0}
model = ""
cwd = ""
prompts = 0
turns = 0
last_ts = ""
for line in open(tpath, encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line:
        continue
    try:
        rec = json.loads(line)
    except Exception:
        continue
    cwd = rec.get("cwd", cwd)
    last_ts = rec.get("timestamp", last_ts)
    rtype = rec.get("type")
    if rec.get("isSidechain"):
        continue
    if rtype == "user":
        c = (rec.get("message") or {}).get("content")
        if isinstance(c, str) and c.strip() and not c.startswith("<system-reminder>"):
            prompts += 1
    elif rtype == "assistant":
        u = (rec.get("message") or {}).get("usage") or {}
        if u:
            turns += 1
            model = (rec.get("message") or {}).get("model", model)
            for k in tok:
                tok[k] += u.get(k) or 0

row = {
    "updated_at": last_ts,
    "session_id": session,
    "project": cwd,
    "model": model,
    "user_prompts": prompts,
    "assistant_turns": turns,
    "input_tokens": tok["input_tokens"],
    "output_tokens": tok["output_tokens"],
    "cache_creation_tokens": tok["cache_creation_input_tokens"],
    "cache_read_tokens": tok["cache_read_input_tokens"],
    "sum_tokens": sum(tok.values()),
}
FIELDS = list(row.keys())

# --- upsert this session's row, keeping all others ------------------------
rows = []
if os.path.exists(outfile) and os.path.getsize(outfile) > 0:
    try:
        with open(outfile, newline="", encoding="utf-8") as fh:
            for r in csv.DictReader(fh):
                if r.get("session_id") != session:
                    rows.append(r)
    except Exception:
        rows = []                    # unreadable CSV: start clean rather than crash
rows.append(row)

# --- atomic write ---------------------------------------------------------
d = os.path.dirname(outfile) or "."
try:
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".usage-", suffix=".tmp")
    with os.fdopen(fd, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=FIELDS)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in FIELDS})
    os.chmod(tmp, 0o644)
    os.replace(tmp, outfile)
except Exception:
    try:
        os.unlink(tmp)
    except Exception:
        pass
    raise SystemExit(0)
PY

exit 0
