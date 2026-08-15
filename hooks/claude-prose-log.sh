#!/usr/bin/env bash
# claude-prose-log.sh — Claude Code "Stop" hook.
#
# Writes a readable prose transcript of the current session to
#   ~/.claude/archive/transcripts/<sessionId>.md
# so a raw record of every session always exists, independent of whether the
# assistant remembers to keep a curated one. (Curated per-project P## transcripts
# are a separate, human/assistant-authored artifact — this is the safety net.)
#
# Wiring (already in place): ~/.claude/settings.json -> ~/.claude/archive/settings.json
# registers this under hooks.Stop. The hook JSON arrives on stdin and includes
# `transcript_path` (the session JSONL) and `session_id`. Stop fires after every
# assistant turn, so this regenerates the whole file each time from the JSONL —
# idempotent, always complete, written atomically via a temp file.
#
# Never fails the hook: all real work is in python3 (guaranteed present on these
# machines), guarded, and the script always exits 0.

OUTDIR="${CLAUDE_ARCHIVE_DIR:-$HOME/.claude/archive}/transcripts"
mkdir -p "$OUTDIR" 2>/dev/null

# Consume the hook JSON from stdin into a variable, so stdin is free for the
# python program fed via the heredoc below (python3 - reads its program from
# stdin — the two must not share it). The payload is tiny; an env var is fine.
HOOK_JSON="$(cat)"
export HOOK_JSON

python3 - "$OUTDIR" <<'PY' || true
import sys, os, json, tempfile

outdir = sys.argv[1]

# --- read the hook payload (passed via env, not stdin) --------------------
try:
    hook = json.loads(os.environ.get("HOOK_JSON") or "{}")
except Exception:
    sys.exit(0)

tpath = hook.get("transcript_path") or ""
session = hook.get("session_id") or (
    os.path.splitext(os.path.basename(tpath))[0] if tpath else "unknown")
if not tpath or not os.path.exists(tpath):
    sys.exit(0)


def render_question(inp):
    """AskUserQuestion input -> the question and its options, in full.

    The terminal collapses these the moment they are answered and no setting
    keeps them; the session JSONL is the only place they survive. So this hook
    renders them rather than reducing them to `_[tool: AskUserQuestion]_`.
    """
    out = []
    for q in (inp or {}).get("questions") or []:
        if not isinstance(q, dict):
            continue
        head = (q.get("header") or "").strip()
        out.append(f"**Question — {head}**" if head else "**Question**")
        out.append("> " + (q.get("question") or "").strip().replace("\n", "\n> "))
        for o in q.get("options") or []:
            if not isinstance(o, dict):
                continue
            lab = (o.get("label") or "").strip()
            desc = (o.get("description") or "").strip()
            out.append(f"- **{lab}**" + (f" — {desc}" if desc else ""))
    return "\n\n".join(out) if out else "_[tool: AskUserQuestion]_"


def text_from_content(content, tools=None):
    """Assistant content is a list of blocks; keep text, mark tool calls.

    `tools`, when given, is filled in as a side effect: tool_use id -> name, so
    a later tool_result can say which tool it belongs to.
    """
    if isinstance(content, str):
        return content.strip()
    parts = []
    for b in content or []:
        if not isinstance(b, dict):
            continue
        t = b.get("type")
        if t == "text":
            parts.append((b.get("text") or "").strip())
        elif t == "tool_use":
            name = b.get("name", "?")
            if tools is not None and b.get("id"):
                tools[b["id"]] = name
            if name == "AskUserQuestion":
                parts.append(render_question(b.get("input")))
            else:
                parts.append(f"_[tool: {name}]_")
        elif t == "thinking":
            parts.append("_[thinking]_")
    return "\n\n".join(p for p in parts if p)


def render_answer(tur):
    """toolUseResult of an AskUserQuestion -> what was chosen."""
    if not isinstance(tur, dict):
        return None
    answers = tur.get("answers") or {}
    if not answers:
        return None
    out = [f"- *{q.strip()}* → **{a}**" for q, a in answers.items()]
    for q, ann in (tur.get("annotations") or {}).items():
        note = (ann or {}).get("notes") if isinstance(ann, dict) else None
        if note:
            out.append(f"  - note: {note.strip()}")
    return "\n".join(out)


def render_rejection(tool, text):
    """A denied permission prompt -> the tool, plus any feedback typed.

    Only an approval is unrecorded; a denial lands here. The harness wraps the
    feedback in boilerplate addressed to the assistant, which is not something
    the owner said, so it is stripped rather than quoted back at him.
    """
    out = [f"Rejected the `{tool}` tool use."]
    marker = "the user said:\n"
    if marker in text:
        said = text.split(marker, 1)[1].strip()
        if said.startswith("The user wants to clarify"):
            out[0] += " the owner chose to clarify instead."
            said = ""
        said = said.split("\n\nNote: The user's next message", 1)[0].strip()
        if said:
            out.append("> " + said.replace("\n", "\n> "))
    return "\n\n".join(out)


# --- walk the JSONL, collecting the main-chain conversation ---------------
turns = []          # (role, text, timestamp)
first_ts = last_ts = None
cwd = None
tools = {}          # tool_use id -> tool name, filled as the file is walked
for line in open(tpath, encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line:
        continue
    try:
        rec = json.loads(line)
    except Exception:
        continue

    ts = rec.get("timestamp")
    if ts:
        first_ts = first_ts or ts
        last_ts = ts
    cwd = rec.get("cwd", cwd)

    rtype = rec.get("type")
    if rtype not in ("user", "assistant"):
        continue
    if rec.get("isSidechain"):        # sub-agent traffic — skip from the main log
        continue

    content = (rec.get("message") or {}).get("content")

    if rtype == "user":
        if not isinstance(content, str):
            # List content is tool results. Almost all of them are machine
            # output that belongs nowhere near a prose log, but two carry
            # things the owner said and cannot otherwise recover: the answer to an
            # AskUserQuestion, and a denied permission prompt. Keep only those.
            for b in content or []:
                if not isinstance(b, dict) or b.get("type") != "tool_result":
                    continue
                tool = tools.get(b.get("tool_use_id"), "?")
                body = b.get("content")
                if not isinstance(body, str):
                    body = " ".join(x.get("text", "") for x in body or []
                                    if isinstance(x, dict))
                if body.lstrip().startswith("The user doesn't want to proceed"):
                    turns.append(("Rejected",
                                  render_rejection(tool, body), ts))
                elif tool == "AskUserQuestion":
                    a = render_answer(rec.get("toolUseResult"))
                    if a:
                        turns.append(("Answer", a, ts))
            continue
        s = content.strip()
        if not s or s.startswith("<system-reminder>"):
            continue                  # harness injection, not the user speaking
        turns.append(("User", s, ts))
    else:
        s = text_from_content(content, tools)
        if s:
            turns.append(("Assistant", s, ts))

if not turns:
    sys.exit(0)

# --- render markdown ------------------------------------------------------
out = []
out.append("# Session transcript (auto-logged)\n")
out.append(f"- **Session:** `{session}`")
if cwd:
    out.append(f"- **Project:** `{cwd}`")
out.append(f"- **First message:** {first_ts or '?'}")
out.append(f"- **Last updated:** {last_ts or '?'}")
n_user = sum(1 for r, _, _ in turns if r == "User")
n_asst = sum(1 for r, _, _ in turns if r == "Assistant")
out.append(f"- **User prompts:** {n_user}  ·  "
           f"**assistant turns:** {n_asst}")
out.append("- _Raw prose log written by the `claude-prose-log.sh` Stop hook. "
           "Regenerated in full each turn; not a curated transcript._\n")
out.append("---\n")

n = 0
for role, text, ts in turns:
    if role == "User":
        n += 1
        out.append(f"## [{n}] User\n\n{text}\n")
    elif role == "Answer":
        out.append(f"### Answered\n\n{text}\n")
    elif role == "Rejected":
        out.append(f"### Rejected\n\n{text}\n")
    else:
        out.append(f"### Assistant\n\n{text}\n")

body = "\n".join(out)

# --- atomic write ---------------------------------------------------------
target = os.path.join(outdir, f"{session}.md")
try:
    fd, tmp = tempfile.mkstemp(dir=outdir, prefix=".prose-", suffix=".tmp")
    with os.fdopen(fd, "w", encoding="utf-8") as fh:
        fh.write(body)
    os.chmod(tmp, 0o644)              # mkstemp is 0600; keep transcripts readable
    os.replace(tmp, target)
except Exception:
    try:
        os.unlink(tmp)
    except Exception:
        pass
    sys.exit(0)
PY

exit 0
