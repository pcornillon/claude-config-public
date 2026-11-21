#!/usr/bin/env bash
# claude-plain-permission.sh — Claude Code "PreToolUse" hook.  Task #46.
#
# Put one plain-English sentence into the permission prompt for a command that deletes
# or moves files, saying what is deleted or moved, where to, and what else the same
# "Yes" approves.
#
# THE PROBLEM THIS EXISTS FOR, 2026-11-20 (the owner, `claude-config-public` P4–P5):
#
# `global/settings.json` makes `rm`, `rmdir`, `mv`, `trash`, `git rm` and `git mv` always
# ask. The prompt that results shows the raw shell — in the case the owner pasted, five steps
# chained with `&&` and `;`, the `mv` fourth — under Claude's own one-line description
# ("Sync, then move the template folder"), which named neither the folder nor where it
# was going. the owner: "Right now I just give permission without knowing what claude wants
# to do, which defeats the whole purpose of asking me in the first place."
#
# WHAT IT DOES: splits the command into its steps, finds every step that deletes or
# moves, resolves its paths against the working directory (following any `cd` earlier
# in the command), looks at what is actually there (a folder and how many files, a
# file, nothing yet), and returns permissionDecision "ask" with a reason that Claude
# Code shows in the prompt (hooks documentation, code.claude.com/docs/en/hooks, read
# 2026-11-20: for "ask", permissionDecisionReason is "shown to the user in the
# permission prompt"). The other steps are listed after it, because "Yes" approves
# the whole command, not just the step that triggered the question.
#
# WHAT IT DOES NOT DO: it says nothing about any other prompt. A hook cannot tell
# whether a command was going to prompt at all, so asking on anything else would add
# prompts where there were none. Every other prompt depends on the description Claude
# writes, which global/CLAUDE.md now rules on ("Permission prompts in plain English").
#
# Design constraints:
#
#   D10  fail open. Malformed payload, unparseable command (unbalanced quotes), python
#        missing, anything unexpected → print nothing, exit 0, and the ordinary
#        prompt from the ask rules still appears.
#   It only ever returns "ask", never "deny" or "allow", and only for commands the
#   ask rules in settings.json would stop anyway — so it adds no prompt that would not
#   otherwise have appeared, and removes none.
#
# Payload fields used (PreToolUse): tool_name, tool_input.command, cwd.

HOOK_JSON="$(cat)"
export HOOK_JSON

python3 - <<'PY' || true
import os, sys, json, re, glob, shlex

def quiet():
    sys.exit(0)

try:
    hook = json.loads(os.environ.get("HOOK_JSON") or "{}")
except Exception:
    quiet()
if not isinstance(hook, dict) or (hook.get("tool_name") or "") != "Bash":
    quiet()
cmd = ((hook.get("tool_input") or {}).get("command") or "")
cwd0 = hook.get("cwd") or os.getcwd()
if not cmd.strip():
    quiet()
# Cheap exit: none of the words this hook is about appear anywhere.
if not re.search(r"\b(rm|rmdir|mv|trash)\b", cmd):
    quiet()

HOME = os.path.expanduser("~")

# ---- split into lines, skipping heredoc bodies (their text is data, not commands) ----
lines, out, delim = cmd.split("\n"), [], None
for ln in lines:
    if delim is not None:
        if ln.strip() == delim:
            delim = None
        continue
    m = re.search(r"<<-?\s*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?", ln)
    if m:
        delim = m.group(1)
    out.append(ln)

# ---- tokenize each line into steps separated by shell operators ----
SEP = {"&&", "||", ";", "&", ";;", "(", ")", "{", "}"}
PIPE = {"|", "|&"}
steps = []   # each step is a pipeline: a list of commands, each a list of tokens
try:
    for ln in out:
        lx = shlex.shlex(ln, posix=True, punctuation_chars=True)
        lx.whitespace_split = True
        lx.commenters = "#"
        pipe, cur = [], []
        for t in lx:
            if t in SEP:
                if cur:
                    pipe.append(cur)
                if pipe:
                    steps.append(pipe)
                pipe, cur = [], []
            elif t in PIPE:
                if cur:
                    pipe.append(cur)
                cur = []
            else:
                cur.append(t)
        if cur:
            pipe.append(cur)
        if pipe:
            steps.append(pipe)
except Exception:
    quiet()

def strip_redirects(toks):
    res, skip = [], False
    for t in toks:
        if skip:
            skip = False
            continue
        if re.fullmatch(r"[0-9]*[<>]+&?|&>>?|>&", t):
            skip = True          # the redirect's target follows
            if res and res[-1].isdigit():
                res.pop()        # the file-descriptor number of 2>&1, split off by shlex
            continue
        if re.fullmatch(r"[0-9]*[<>]+&?[0-9-]+", t):
            continue             # 2>&1 written as one token
        res.append(t)
    return res

def unwrap(toks):
    """Drop leading VAR=value, sudo, command, env, nohup, time, and xargs (+ its options)."""
    i, via_xargs = 0, False
    while i < len(toks):
        t = toks[i]
        if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", t):
            i += 1; continue
        if t in ("sudo", "command", "env", "nohup", "time", "builtin", "exec"):
            i += 1; continue
        if t == "xargs":
            via_xargs = True
            i += 1
            while i < len(toks) and toks[i].startswith("-"):
                i += 1
            continue
        break
    return toks[i:], via_xargs

def show(p):
    """A path for a human: relative to the starting folder when inside it, else ~/…"""
    try:
        r = os.path.relpath(p, cwd0)
        if not r.startswith(".."):
            return r
    except Exception:
        pass
    return "~" + p[len(HOME):] if p.startswith(HOME + os.sep) or p == HOME else p

def resolve(t, vcwd):
    t = os.path.expanduser(t)
    return os.path.normpath(t if os.path.isabs(t) else os.path.join(vcwd, t))

def count_files(d, cap=100000):
    n = 0
    for _, _, fs in os.walk(d):
        n += len(fs)
        if n >= cap:
            return f"{cap}+"
    return str(n)

def what(p):
    if os.path.islink(p):
        return ("the link", "")
    if os.path.isdir(p):
        n = count_files(p)
        return ("the folder", f" ({n} file{'' if n == '1' else 's'} inside)")
    if os.path.isfile(p):
        return ("the file", "")
    return ("", " (nothing there yet)")

def targets(args, vcwd):
    """Expand each argument to (shown path, description)."""
    res = []
    for a in args:
        if "$" in a or "`" in a:
            res.append((a, ("", " (a shell variable; the real path is only known when it runs)")))
            continue
        if any(c in a for c in "*?["):
            hits = sorted(glob.glob(resolve(a, vcwd)))
            if not hits:
                res.append((a, ("", " (matches nothing)")))
            else:
                shown = ", ".join(show(h) for h in hits[:8])
                more = f" and {len(hits) - 8} more" if len(hits) > 8 else ""
                res.append((show(resolve(a, vcwd)), ("", f" (matches {len(hits)}: {shown}{more})")))
            continue
        p = resolve(a, vcwd)
        res.append((show(p), what(p)))
    return res

def fmt(ts):
    return "; ".join((f"{n} {p}" if n else p) + suf for p, (n, suf) in ts)

def split_opts(args):
    opts, rest, ended = [], [], False
    for a in args:
        if not ended and a == "--":
            ended = True; continue
        if not ended and a.startswith("-") and a != "-":
            opts.append(a)
        else:
            rest.append(a)
    return opts, rest

def has_flag(opts, short, long_=()):
    for o in opts:
        if o in long_:
            return True
        if not o.startswith("--") and any(c in o[1:] for c in short):
            return True
    return False

def move_sentence(opts, rest, vcwd, git=False):
    tdir = None
    for i, o in enumerate(opts):
        if o.startswith("--target-directory="):
            tdir = o.split("=", 1)[1]
    if "-t" in opts and rest:          # mv -t DIR src...
        tdir, rest = rest[0], rest[1:]
    if tdir is None:
        if len(rest) < 2:
            return None
        srcs, dest = rest[:-1], rest[-1]
    else:
        srcs, dest = rest, tdir
    dp = resolve(dest, vcwd)
    verb = "MOVE (and record the move in git)" if git else "MOVE"
    src_txt = fmt(targets(srcs, vcwd))
    into = tdir is not None or len(srcs) > 1 or os.path.isdir(dp) or dest.endswith("/")
    if into:
        state = "" if os.path.isdir(dp) else " (that folder does not exist yet)"
        return f"{verb} {src_txt} into the folder {show(dp)}{state}"
    sp = resolve(srcs[0], vcwd)
    if os.path.dirname(sp) == os.path.dirname(dp):
        r = f"RENAME {src_txt} to {os.path.basename(dp)}"
    else:
        r = f"{verb} {src_txt} to {show(dp)}"
    if os.path.isfile(dp):
        r += f" — REPLACING the existing file {show(dp)}"
    return r

def display(pipe):
    txt = " | ".join(shlex.join(strip_redirects(c)) for c in pipe)
    return txt if len(txt) <= 80 else txt[:77] + "..."

def judge(toks, vcwd, upstream):
    """The plain sentence for one command, or None if it neither deletes nor moves."""
    toks, via_xargs = unwrap(strip_redirects(toks))
    if not toks:
        return None
    head, args = toks[0], toks[1:]
    base = os.path.basename(head)
    fed = (f"the files whose names come from `{upstream}`" if via_xargs and upstream
           else "files named by the step before it")
    if base == "rm":
        opts, rest = split_opts(args)
        kind = "DELETE permanently (not to the Trash)"
        if has_flag(opts, "rR", ("--recursive",)):
            kind += ", with everything inside"
        if rest:
            return f"{kind}: {fmt(targets(rest, vcwd))}"
        return f"{kind}: {fed}" if via_xargs else None
    if base == "rmdir":
        opts, rest = split_opts(args)
        return f"DELETE the empty folder(s): {fmt(targets(rest, vcwd))}" if rest else None
    if base == "trash":
        opts, rest = split_opts(args)
        if rest:
            return f"MOVE TO THE TRASH: {fmt(targets(rest, vcwd))}"
        return f"MOVE TO THE TRASH: {fed}" if via_xargs else None
    if base == "mv":
        opts, rest = split_opts(args)
        return move_sentence(opts, rest, vcwd)
    if base == "git" and args and args[0] in ("rm", "mv"):
        opts, rest = split_opts(args[1:])
        if args[0] == "rm":
            if has_flag(opts, "", ("--cached",)):
                return f"STOP git tracking (files stay on disk): {fmt(targets(rest, vcwd))}"
            return f"DELETE and remove from git: {fmt(targets(rest, vcwd))}" if rest else None
        return move_sentence(opts, rest, vcwd, git=True)
    return None

asks, others, vcwd = [], [], cwd0
for pipe in steps:
    first, _ = unwrap(strip_redirects(pipe[0]))
    if len(pipe) == 1 and first and first[0] == "cd":
        dest = first[1] if len(first) > 1 else HOME
        if dest != "-" and "$" not in dest:
            vcwd = resolve(dest, vcwd)
        others.append(f"go to the folder {show(vcwd)}")
        continue
    found = []
    for k, c in enumerate(pipe):
        up = display(pipe[:k]) if k else ""
        j = judge(c, vcwd, up)
        if j:
            found.append(j)
    if found:
        asks.extend(found)
    else:
        others.append(display(pipe))

if not asks:
    quiet()

where = ("~" + cwd0[len(HOME):]) if cwd0.startswith(HOME) else cwd0
lines = [f"In {where}, Claude is asking to:"]
lines += [f"  • {a}" for a in asks]
if others:
    lines.append(f"Saying Yes also runs {len(others)} other step{'s' if len(others) != 1 else ''}:")
    lines += [f"  – {o}" for o in others[:8]]
    if len(others) > 8:
        lines.append(f"  – and {len(others) - 8} more")

print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "\n".join(lines),
}}))
PY
