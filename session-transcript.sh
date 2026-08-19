#!/usr/bin/env bash
# session-transcript.sh — rebuild a session log as a COMPLETE transcript (D38).
#
# Every prompt of the session, verbatim, followed by as much of the assistant's
# response as the transcript holds — the prose it wrote, plus a one-line trace of
# each tool call. Tool *output* is not included; it is bulk, and the response text
# is what says what came of it.
#
# The file it writes is still the curated session log: two things a human wrote are
# carried across every regeneration —
#
#   * the header, meaning everything above the first `## P` heading, and
#   * each entry's subject line and its optional `### Notes` block.
#
# Everything else is regenerated from the session JSONL, so it cannot drift from
# what was actually said. Run it again whenever more prompts have arrived; it
# REPLACES, it does not append.
#
# It supersedes prompt-index.sh (D29): a verbatim prompt is strictly more
# authoritative than a 78-character excerpt of one, so an index below the entries
# is duplication. Any existing index section is dropped on the first run.
#
# Usage:  ./session-transcript.sh <session-log.md> [transcript.jsonl]
#         (the JSONL defaults to the one whose name matches the log's
#          `<!-- session: … -->` comment, under ~/.claude/projects/)
#
# NOTE: session JSONLs are machine-local. A log written on the other machine can
# only be rebuilt there.

set -uo pipefail
log="${1:-}"
[ -f "$log" ] || { echo "usage: $0 <session-log.md> [transcript.jsonl]" >&2; exit 2; }

tr_path="${2:-}"
if [ -z "$tr_path" ]; then
  sid=$(head -10 "$log" | sed -n 's/.*<!-- *session: *\([0-9a-fA-F-]*\) *-->.*/\1/p' | head -1)
  [ -n "$sid" ] || { echo "$log has no <!-- session: … --> comment; name the JSONL explicitly" >&2; exit 2; }
  tr_path=$(ls -t "$HOME"/.claude/projects/*/"$sid".jsonl 2>/dev/null | head -1)
  [ -n "$tr_path" ] || { echo "no local JSONL for session $sid — it was probably written on the other machine" >&2; exit 1; }
fi
[ -f "$tr_path" ] || { echo "no transcript at $tr_path" >&2; exit 1; }

python3 - "$log" "$tr_path" <<'PY'
import json, sys, re, datetime

log, tpath = sys.argv[1], sys.argv[2]

# Harness-injected user turns that are not prompts. Same filter as the guards use.
HARNESS = ("<system-reminder>", "<command-name>", "<command-message>", "<command-args>",
           "<local-command-stdout>", "<local-command-stderr>", "<user-memory-input>",
           "[Request interrupted", "<task-notification>")

# A slash command IS a prompt — the owner typed it — but the harness rewrites the turn
# into a <command-*> wrapper that HARNESS above would drop. Dropping it does not just
# lose the entry: every following response is appended to the PREVIOUS prompt, so one
# unrecognised slash command silently merges two entries and shifts every subject line
# after it by one. Matched before the HARNESS test and rendered as typed.
SLASH = re.compile(r"^(?:<command-message>.*?</command-message>\s*)?"
                   r"<command-name>(.*?)</command-name>"
                   r"(?:\s*<command-args>(.*?)</command-args>)?\s*$", re.S)

# --- what the assistant did, in one line per call -------------------------
# The argument that identifies the call, per tool. Anything not named here is
# rendered as the bare tool name.
TOOL_ARG = {"Bash": "command", "Read": "file_path", "Edit": "file_path",
            "Write": "file_path", "NotebookEdit": "notebook_path",
            "Glob": "pattern", "Grep": "pattern", "Task": "description",
            "Agent": "description", "WebFetch": "url", "WebSearch": "query",
            "Skill": "skill", "TaskCreate": "description"}


def tool_line(name, inp):
    arg = (inp or {}).get(TOOL_ARG.get(name, ""), "")
    if not isinstance(arg, str):
        arg = ""
    arg = " ".join(arg.split())
    if len(arg) > 90:
        arg = arg[:87] + "…"
    return "_[%s: %s]_" % (name, arg) if arg else "_[%s]_" % name


def user_text(rec):
    """The prompt as typed, or None if this user turn is not a prompt."""
    c = (rec.get("message") or {}).get("content")
    if isinstance(c, str):
        s = c
    elif isinstance(c, list):
        if any(isinstance(e, dict) and e.get("type") == "tool_result" for e in c):
            return None
        s = "\n".join(e.get("text") or "" for e in c
                      if isinstance(e, dict) and e.get("type") == "text")
    else:
        return None
    s = s.strip()
    m = SLASH.match(s)
    if m:
        name, arg = (m.group(1) or "").strip(), (m.group(2) or "").strip()
        return (name + " " + arg).strip() or None
    return None if (not s or s.startswith(HARNESS)) else s


def demote(md):
    """Push the response's own headings two levels down.

    A response that says `## DECISIONS` would otherwise sit at the same level as the
    `## P##` entries and break the log's outline. Two levels puts it under
    `### Response`. Headings inside fenced code are left alone.
    """
    out, fenced = [], False
    for ln in md.split("\n"):
        if ln.lstrip().startswith("```"):
            fenced = not fenced
        elif not fenced:
            m = re.match(r"(#{1,6})(\s)", ln)
            if m:
                ln = "#" * min(6, len(m.group(1)) + 2) + ln[len(m.group(1)):]
        out.append(ln)
    return "\n".join(out)


def assistant_blocks(rec):
    """Prose and tool calls from one assistant turn. Thinking is dropped."""
    out = []
    c = (rec.get("message") or {}).get("content")
    if isinstance(c, str):
        return [demote(c.strip())] if c.strip() else []
    for b in c or []:
        if not isinstance(b, dict):
            continue
        if b.get("type") == "text" and (b.get("text") or "").strip():
            out.append(demote(b["text"].strip()))
        elif b.get("type") == "tool_use":
            out.append(tool_line(b.get("name") or "tool", b.get("input")))
    return out


def stamp(ts):
    """Transcript stamps are UTC; session logs are local with the zone named (D5)."""
    for fmt in ("%Y-%m-%dT%H:%M:%S.%fZ", "%Y-%m-%dT%H:%M:%SZ"):
        try:
            dt = datetime.datetime.strptime(ts, fmt).replace(
                tzinfo=datetime.timezone.utc).astimezone()
            return dt.strftime("%Y-%m-%d %H:%M %Z")
        except Exception:
            pass
    return "unknown"


# --- walk the transcript: prompt, then everything until the next prompt ----
turns = []                                   # [{"stamp":…, "prompt":…, "reply":[…]}]
for line in open(tpath, encoding="utf-8", errors="replace"):
    line = line.strip()
    if not line:
        continue
    try:
        r = json.loads(line)
    except Exception:
        continue
    if r.get("isSidechain") or r.get("isMeta") or r.get("isCompactSummary"):
        continue
    kind = r.get("type")
    if kind == "user":
        t = user_text(r)
        if t is not None:
            turns.append({"stamp": stamp(r.get("timestamp", "")), "prompt": t, "reply": []})
    elif kind == "assistant" and turns:
        turns[-1]["reply"].extend(assistant_blocks(r))

if not turns:
    sys.exit("%s: no prompts found in %s" % (log, tpath))

# --- carry the human-written parts of the existing log across --------------
body = open(log, encoding="utf-8").read()

# A pre-D38 log ends with prompt-index.sh's index. Verbatim prompts replace it, so
# drop it here rather than letting it fall into the last entry's notes.
# Anchored to the start of a line: prose that merely *mentions* the old index —
# this file's own notes do — must not be mistaken for the index itself.
ixm = re.search(r"^## Prompt index", body, re.M)
if ixm:
    sep = body.rfind("\n---\n", 0, ixm.start())
    body = body[:sep if sep != -1 else ixm.start()]

P_HEAD = re.compile(r"^## +P(\d+)\b(.*)$", re.M)
heads = list(P_HEAD.finditer(body))
header = body[:heads[0].start()].rstrip() if heads else body.rstrip()

subjects, notes = {}, {}
for i, m in enumerate(heads):
    n = int(m.group(1))
    # The subject is what is left of the heading once the separator and the
    # timestamp field are removed. Pre-D38 logs on `your-desktop` used `—` as the
    # separator rather than `·`, so both are accepted here.
    s = re.sub(r"^\s*[·—-]\s*", "", m.group(2))
    s = re.sub(r"^\d{4}-\d{2}-\d{2}\s+\d{1,2}:\d{2}\s*[A-Z]{0,4}\s*[·—-]\s*", "", s)
    if s.strip():
        subjects[n] = s.strip()
    seg = body[m.end(): heads[i + 1].start() if i + 1 < len(heads) else len(body)]
    if "### Prompt" in seg:                  # already D38: only ### Notes is human-written
        nm = re.search(r"^### +Notes *$\n(.*)\Z", seg, re.M | re.S)
        keep = nm.group(1) if nm else ""
        # Anything after the response that is NOT under a ### Notes heading would
        # otherwise be dropped on the next rebuild — which is silent data loss, and it
        # happens every time a note is appended to a log before its own `## P##`
        # heading exists. Recover it by subtracting the response this rebuild produced.
        rm = re.search(r"^### +Response *$\n\n(.*?)(?=^### +Notes *$|\Z)", seg, re.M | re.S)
        if rm and n <= len(turns):
            new_resp = "\n\n".join(turns[n - 1]["reply"]).strip()
            old_resp = rm.group(1).strip()
            if new_resp and old_resp.startswith(new_resp):
                tail = old_resp[len(new_resp):].strip()
                if tail:
                    sys.stderr.write("%s: P%d — recovered %d characters written below "
                                     "the response, not under ### Notes\n"
                                     % (log, n, len(tail)))
                    keep = (tail + "\n\n" + keep).strip() if keep else tail
    else:                                    # pre-D38: the whole entry is the curated note
        keep = seg
    if keep.strip():
        notes[n] = keep.strip()

# --- write it out ----------------------------------------------------------
out = [header, ""]
for i, t in enumerate(turns, 1):
    subj = subjects.get(i) or " ".join(t["prompt"].split())[:60]
    out += ["## P%d · %s · %s" % (i, t["stamp"], subj), "",
            "### Prompt", "",
            "\n".join("> " + ln if ln else ">" for ln in t["prompt"].split("\n")), "",
            "### Response", ""]
    out += ["\n\n".join(t["reply"]) if t["reply"] else "_(no response recorded)_", ""]
    if i in notes:
        out += ["### Notes", "", notes[i], ""]

open(log, "w", encoding="utf-8").write("\n".join(out).rstrip() + "\n")
print("%s: %d prompts, %d subject line(s) and %d Notes block(s) preserved"
      % (log, len(turns), len(subjects), len(notes)))
PY
