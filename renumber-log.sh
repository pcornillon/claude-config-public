#!/usr/bin/env bash
# Give every prompt row in a repo's LOG.md a project-wide running number, with the
# session's own number kept in parentheses: `**P4**` becomes `**P27 (P4)**` (D60).
#
#   renumber-log.sh [--apply] <repo> [<repo> ...]   dry run (a diff) unless --apply
#   renumber-log.sh --next <repo>                   print the next free running number
#
# Rows are numbered in FILE order, which is the order LOG.md is appended in — not by
# timestamp, because a backfilled row sits where it was written, and renumbering by
# date would reorder an append-only file's meaning. Foreign-key rows (D56) are prompts
# like any other and are counted.
#
# What counts, and how much:
#   P4, P27a, P14b, P7 (cont.), Prompt 2, Prompt 2, iterated     one prompt each
#   P13–P14, P8-P9                                               b-a+1 prompts, written
#                                                                as a running range
# What is left alone, and reported: ⚙ rows (a background turn is not a prompt —
# global/CLAUDE.md, Session protocol), `↳ mid-turn` rows, and rows with no P label at
# all (dated rows, NOTE rows, "no curated log" rows). They carried no session number
# either, so there is nothing to put in the parentheses.
#
# A row already in the new form keeps its running number and the count continues from
# it, so a second run is a no-op and a partly converted file finishes cleanly. This is
# also what --next reads: the next number is the highest running number plus one,
# taken from LOG.md at the moment of appending, as with D## (D60).
set -euo pipefail

mode=dry
case "${1:-}" in
  --apply) mode=apply; shift ;;
  --next)  mode=next;  shift ;;
esac
[ $# -ge 1 ] || { sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }

status=0
for repo in "$@"; do
  [ -f "$repo/LOG.md" ] || { echo "skip $repo — no LOG.md"; continue; }
  mode="$mode" python3 - "$repo" <<'PY' || status=$?
import difflib, io, os, re, sys

repo = sys.argv[1]
mode = os.environ["mode"]
logp = os.path.join(repo, "LOG.md")
src  = io.open(logp, encoding="utf-8").read()
name = os.path.basename(os.path.abspath(repo))

ROW = re.compile(r"^(- (?:★ )?\*\*)(.+?)(\*\*)")
# Already converted: P27 (P4), P27–P28 (P13–P14), P31 (Prompt 1). The parenthesis
# must open with a session label, or `P7 (cont.)` would read as running number 7.
NEW = re.compile(r"^P(\d+)(?:–P(\d+))? \(((?:P|Prompt )\d.*)\)$")
SINGLE = re.compile(r"^(?:P\d+[a-z]?|P\d+ \(cont\.\)|Prompt \d+(?:, iterated)?)$")
RANGE  = re.compile(r"^P(\d+)[–-]P(\d+)$")

n = 0
lines = src.split("\n")
left = {}
for i, ln in enumerate(lines):
    if not ln.startswith("- "):
        continue
    m = ROW.match(ln)
    label = m.group(2) if m else None
    if label and NEW.match(label):
        nm = NEW.match(label)
        n = int(nm.group(2) or nm.group(1))
        continue
    if label and SINGLE.match(label):
        n += 1
        inner = label.replace(" (cont.)", " cont.")
        new = "P%d (%s)" % (n, inner)
    elif label and RANGE.match(label):
        a, b = map(int, RANGE.match(label).groups())
        if b < a:
            print("%s line %d: backwards range %s — left alone" % (name, i + 1, label))
            continue
        new = "P%d–P%d (%s)" % (n + 1, n + b - a + 1, label)
        n += b - a + 1
    else:
        kind = ("⚙" if "⚙" in ln[:12] else
                "↳ mid-turn" if label and label.startswith("↳") else
                "no P label")
        left[kind] = left.get(kind, 0) + 1
        continue
    lines[i] = m.group(1) + new + m.group(3) + ln[m.end():]

if mode == "next":
    print(n + 1)
    raise SystemExit(0)

out = "\n".join(lines)
summary = "%-42s %d prompts numbered; left alone: %s" % (
    name, n, ", ".join("%s %d" % kv for kv in sorted(left.items())) or "none")
if mode == "dry":
    sys.stdout.writelines(difflib.unified_diff(
        src.splitlines(True), out.splitlines(True), "a/LOG.md", "b/LOG.md", n=0))
    print(summary + "  [dry run]")
else:
    if out != src:
        io.open(logp, "w", encoding="utf-8").write(out)
    print(summary)
PY
done
exit $status
