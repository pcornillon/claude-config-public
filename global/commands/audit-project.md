---
description: Check the current repo against the project spine and report drift
---

Audit the repo in the current working directory against the standard spine.
**Report only — change nothing without being asked.**

Skip silently and say so if there is no `CLAUDE.md`: repos predating the standard are
out of scope.

## Checks

**Spine present**
- Files: `CLAUDE.md`, `STATUS.md`, `LOG.md`, `DECISIONS.md`, `TASKS.md`, `README.md`.
  `PLAN.md` optional.
- Folders, **all five, even if empty** (D21): `DOCS/`, `LATEX/`, `ISSUE_ANALYSES/`,
  `SESSIONS/`, `PRE_CONVERSION/`. A lowercase `sessions/` or `pre_conversion/`, or a
  surviving `Claude_diagnostic_analyses/`, means the repo predates D23.
- `CLAUDE.md` opens with **What / Produces / State** (D24) — three lines, that order,
  immediately under the title.
- Every spine file's H1 is ``# <FILENAME> — `<repo-directory-name>` `` (D37), the
  directory name **in backticks**, spelled as `ls` spells it; `README.md`'s is the
  backticked directory name **alone**. Flag a prose project name, a descriptive
  sentence, a bare `# STATUS.md`, or a title with the backticks missing — without them
  an underscored name renders as italics with the underscores eaten.
- Bare underscored names in body prose — repo, file, folder, field, env-var — should be
  backticked for the same reason (D37). Mathematical notation is exempt.

**Contracts held**
- `STATUS.md` ends with `## Active thread` (or one per lane). Flag if absent — that
  is the section a cold session resumes from.
- `STATUS.md` is not a session-by-session history. Flag a long run of dated entries.
- `CLAUDE.md` has not grown a log — flag dated entries or accumulating findings that
  belong in `DECISIONS.md`.
- No `HANDOFF.md` (superseded by the active thread).

**Numbering**
- `D##` gaps or duplicates; `D##` cited from tasks/status that do not exist.
- Task-number gaps or duplicates; more than two tasks `doing` at once; any task
  reopened after `done`.

**Session logs**
- Any `TRANSCRIPT_*.md` or session log outside `SESSIONS/`.
- **`ISSUE_ANALYSES/` (D22):** a script inside an issue folder rather than flat in its
  per-language folder (`Matlab/`, `Python/`, `Fortran/`, …); an **empty** language
  folder, which should not exist until it has a script in it (D36); an issue folder
  with no `README.md`; and the index both
  ways — every script named by some issue README, every function a README names still
  present. The index is the only thing linking a flat script to its context, and it
  goes stale silently.
- Filenames not matching `<YYYY-MM-DD>_<HHMM>_<TZ>_<host>.md`; a missing `_<TZ>_`
  means the name claims UTC. Legacy logs may omit the host — that is expected.
- **A log with no `<!-- session: … -->` comment in its first ten lines.** Both guards
  find the log by that comment and never by the filename, so a log without it is
  invisible to them and they report "no session log" while it sits in plain sight.
  Report it as a contract violation, not as mechanics. Legacy logs migrated from
  before the convention are exempt — no live session will ever match them:
  `for f in sessions/*.md; do head -10 "$f" | grep -q '<!-- session:' || echo "$f"; done`
- `LOG.md` entry count versus `## P` headings across `sessions/` — a large shortfall
  means the index is not being written live.

**Session logs, continued (D28, D29)**
- A log whose newest `## P##` timestamp precedes the newest tracked file by a wide
  margin — times were probably read on handling, not on arrival.
- A closed session log with no machine-extracted prompt index at the end.

**Finder tags (D26, D30)**
- `~/Git_Repos/claude-config-public/tag-spine.sh --check .` — untagged spine folders mean
  this machine has not had the tag applied since the repo was cloned. Report it as
  drift, not a violation: it is per-machine state, not repo content.

**Staleness**
- `STATUS.md` older than the newest tracked file.
- Paths that no longer resolve; `~/Git_repos` in the wrong case (macOS is
  case-insensitive, so it lists fine and fails to prefix-match — this has caused a
  silent bug before).
- Repos referenced by a nickname rather than their directory name.

**Markdown mechanics**

These are the conventions that are mechanically checkable. **When a `D##` adds
another one, add its check here in the same breath** — otherwise the rule applies
retroactively to every already-migrated repo and nothing notices the drift.

- `grep -nE '^#+[^ #]'` — a hard-wrapped line starting with `#` (a task number at
  column 0 reads as a heading).
- **D14, in `LOG.md` only.** Three greps, each a different way the same bug shows up —
  a markdown metacharacter used as data, which silently merges entries into one blob:
  - `grep -nE '^\*' LOG.md` — a `*` at column 0. This is the original bug: `*` reads
    as list syntax, so a star meant as a data marker becomes a bullet. Entries use
    `★`, which is not a metacharacter.
  - `grep -nE '^\s*(★|\*\*P[0-9])' LOG.md` — an entry that opens with `★` or `**P##**`
    without the leading `- `. Not a list item, so it merges into the one above it.
  - `grep -nE '^→' LOG.md` — an outcome line at column 0. It must be indented two
    spaces to stay inside its list item.

  Report a hit as a contract violation, not as mechanics: the entries still *read*
  fine in source, which is exactly why this went unnoticed until {{OWNER}} saw P6–P14
  render as a single paragraph.

## Output

Group by severity: **contract violations** (a file is being used for something it is
not), then **drift** (stale, missing, mis-numbered), then **mechanics**. Cite each by
**file, section heading, and a short quote** — never by line number; {{OWNER}} reads these
rendered, where line numbers do not exist.

If everything passes, say so in one line. Do not manufacture findings.
