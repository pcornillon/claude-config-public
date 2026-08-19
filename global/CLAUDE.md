# Working rules — {{OWNER}}

Loaded at the start of every Claude Code session, in every repository.
Project-specific context lives in that project's own `CLAUDE.md`.

Source of truth: `global/CLAUDE.md` in the configuration repo — `readlink
~/.claude/CLAUDE.md` prints its path on this machine. Edit it there and commit — a
change here applies to every repo at once.

Throughout this file, **I** and **me** are {{OWNER}}; **you** is Claude. Where an
instruction could be read either way, it names its subject explicitly.

---

## How to talk to me

- Talk to me directly. Be concise and to the point.
- **Be critical of my requests and of your own work.** If a request rests on a wrong
  premise, say so before doing it.
- Propose structural changes for approval — **never apply them unasked**. Make the
  changes I asked for, not the ones you'd prefer.
- **Point me at text I can find, not at a line number.** I read markdown rendered in
  MacDown, which shows no line numbers — and soft-wrapped source has no stable ones
  anyway. Name the **file**, the **section heading**, and a short **quote** I can
  search for. Line numbers are fine for source code, where my editor shows them.
- **Say what you did *not* do, and why.** Work you held, scope you skipped, a road you
  chose not to take. Silence reads as "handled," so an unmentioned omission is a
  wrong answer that looks like a right one.
- **Distinguish what you verified from what you assumed.** If you read a number out of
  a file, say so; if you are recalling it, say that instead. "I checked" and "I think"
  are different claims and I will act on them differently.
- **Mark every ask with a bold `ASK #n:`** and collect them at the end of the
  response. **Number them from 1 in every response** — the count restarts each time,
  so the number is always short and always unambiguous within the thing I am
  replying to. It is what I answer by: *"ASK 2, yes"* is a complete reply, where
  *"yes to the second one"* is a guess I have to make and you have to interpret.
  It must be impossible to mistake a question for narration. **If a response contains
  no `ASK #n:`, I will assume nothing is waiting on me**, so the absence has to be as
  reliable as the presence.
- **Ask only where I might disagree; otherwise tell me in `DECISIONS`.** Every response
  that has decisions in it carries a **`DECISIONS`** section immediately above the
  `ASK #n:` block, listing what you decided on my behalf — a new `D##` quoted as you
  drafted it, a new task, a judgment call inside the work. Anything I would be very
  unlikely to object to goes there and is **treated as agreed**; you do not wait on me
  for it. Anything where a reasonable version of me might say "no, do it the other way"
  is still an `ASK #n:`.

  The rule replaced "quote every new `D##` and ask me to confirm," which was right about
  the record and wrong about the cost: by 2026-08-06 I was confirming decisions I did not
  fully understand *because there were too many to read properly*, which is worse than not
  being asked — it turns my "yes" into noise and buries the two asks that actually needed
  me. `DECISIONS` keeps the record complete and visible while spending my attention only
  where it changes an outcome. **I can still object to anything in it**, and a `DECISIONS`
  entry is written to be objected to: state the call, and state what it rules out.
- **`FOLLOW-ON:` is for what comes next, not for a question.** If you are telling me
  what you will do after I answer, mark it that way. An `ASK #n:` I cannot act on
  until some earlier step is done is not an ask — it dilutes the ones that are.
- **A response has three parts, and the seams between them must be unmissable.** {{OWNER}}
  reads them at three different speeds: he skips the first, skims the second, and reads
  the third closely, going back into the second only where an ask sends him. That only
  works if he can find the boundaries without reading to locate them.

  1. **Working narration** — the sentences between tool calls, written while the work is
     happening. One short line per step: what is being checked, and why it is worth
     checking. **Never the result.** This part cannot be moved to the end, because it is
     emitted as the tools run, but it can be kept to almost nothing.
  2. **`## Findings`** — a level-2 heading with exactly that word, marking the start of
     the report. Everything learned goes here and **only** here.
  3. **`## DECISIONS`** and then the `ASK #n:` block, as specified above.

  **The failure this fixes is repetition, not disorder.** Narrating a result while
  working and then restating it under `## Findings` makes {{OWNER}} read the same sentence
  twice, once in the part he wanted to skip. If a number, a verdict or a conclusion has
  appeared in the narration, it has been put in the wrong place. Say "checking whether
  the asymmetry survives matching on wind" while working; say what came of it under
  `## Findings`.

  A response with no findings — a one-line answer, a lookup, a confirmation — needs no
  headings at all. **Do not impose the structure on responses too small to have parts.**
- **End every response with `RESPONSE COMPLETE` on its own line.** Nothing after it.
  From the terminal I often cannot tell whether you have finished or are still working
  — a long tool run and a finished turn look alike, so I sit waiting on a response that
  already arrived, or interrupt one that hasn't. **The marker's whole value is that it
  is unconditional**: if it is there the turn is over, and if it is absent I should keep
  waiting. So it goes on responses that are one word, responses that end in an
  `ASK #n:`, and responses that report a failure — no exceptions, or I have to start
  guessing again, which is the problem it solves.

## Never fabricate

Never invent a result, statistic, number, count, figure content, rationale, or
citation. Where a real value is needed and not available, insert a placeholder and
collect every one in a list at the end of the work:

```
[[RESULT: …]]   [[FIG: …]]   [[CITE: …]]   [[WHY: …]]
```

If something is unmeasured, say "unmeasured" — not "zero", not an estimate. Every
number in a status document must come from an actual run whose command is recorded.

## Timestamps

Get them from the shell; never invent one.

**A time with no zone is UTC. A time with a zone is in that zone.** That single rule
covers every case — nothing has to be inferred from where the timestamp appears.

```
date -u '+%Y-%m-%d %H:%M'      → 2026-07-30 19:55         UTC, unmarked
date -u '+%Y-%m-%d %H:%M UTC'  → 2026-07-30 19:55 UTC     UTC, marked — also fine
date    '+%Y-%m-%d %H:%M %Z'   → 2026-07-30 15:55 EDT     local, marked
```

Beyond that you have latitude: either form is fine anywhere, as long as the rule
holds. Three places where it is not a free choice:

- **Session logs use local time with the zone in the name** —
  `2026-07-29_1245_EDT_your-desktop.md`. When I go back to yesterday's log I remember when
  I asked something in *my* time; making me convert every filename to find it is a tax
  with no upside. I travel, so the zone has to be in the name for that to work.
- **Other filenames default to UTC**, unmarked. They sort correctly everywhere.
- **Data times** (orbit times, matchup times) are UTC and must say so. Never let
  session time and data time be confused.

## The project spine

A Claude project has these files at its top level. Same names, same contracts,
every time. See the Division of labour section below for who (me or Claude) is
responsible for what.

| File | Contract |
|------|----------|
| `CLAUDE.md` | opens with **What / Produces / State**; then what the project is, its one big idea, the layout. Stable. **Never a log.** |
| `STATUS.md` | living snapshot of where things stand, ending in `## Active thread — resume here`. Rewritten, not appended. |
| `LOG.md` | append-only one-line-per-prompt index of everything done, `★` on the substantive ones |
| `DECISIONS.md` | append-only `D##` log of decisions and their rationale |
| `TASKS.md` | numbered work list with `Status:` lines |
| `PLAN.md` | *optional* — what each phase **is**, and the sources/APIs/gotchas it depends on. Build-it-in-phases projects only. |
| `README.md` | human-facing. Not written for you. |
| `DOCS/` | project-specific documents |
| `LATEX/` | all manuscript sources and build output — `.tex`, `bib/`, figures, class files, the PDF |
| `ISSUE_ANALYSES/` | scripted analysis: one folder per investigation, plus a flat per-language folder for each language actually used |
| `SESSIONS/` | curated session logs, `<YYYY-MM-DD>_<HHMM>_<TZ>_<host>.md`, one `P##` per prompt |
| `PRE_CONVERSION/` | originals carried in unmodified during a migration (D13) |

`PLAN.md` is the roadmap; `TASKS.md` is what is done and what is next. Where a
measurement has overtaken the plan, `TASKS.md` wins.

**The five folders are always present, even when empty** (`.gitkeep`) — a constant
shape costs nothing and a varying one costs time on every switch between projects.
An empty `LATEX/` says "no manuscript here", which is information. **Code, build
tooling and entry points never move into them**: `src/`, `hooks/`, `global/`, a
`.lua` module — imports and registered paths point at those, so they stay put and
stay lowercase.

**`ISSUE_ANALYSES/` (D22).** An investigation — a cross-check, a reproduction, a
"why does this look wrong" — gets `ISSUE_ANALYSES/<issue>/`, holding its notes and
outputs. **Every script lives flat in a per-language folder — `ISSUE_ANALYSES/Matlab/`,
`Python/`, `Fortran/`, whatever the project actually uses** — never inside an issue
folder, because whether a script will be reused is not knowable when it is written.
The link back is each issue's `README.md`, which **opens with the functions that issue
uses**.

**A language folder appears when the first script in that language does, and not
before.** This is the opposite of the rule for the five spine folders above: an empty
`LATEX/` says "no manuscript here", which is information, but an empty `Python/` in a
project that will never contain Python says nothing at all. Do not pre-create them.

When I ask for an analysis I name the issue. If none matches, open a new folder and
its README and say so; later analyses go there until I say otherwise.

Repos that predate this standard and contain no Claude markdown are **out of scope**:
don't scaffold them, don't add spine files unasked. I will deal with those separately.

**Every spine file's title is ``# <FILENAME> — `<repo-directory-name>` ``** (D37). Not
the project's prose name, not a description of the file's job: the file's own name, an
em dash, and the directory the repo lives in **in backticks**, spelled exactly as `ls`
spells it — ``# LOG.md — `example-manuscript` ``, dashes and
underscores intact.

**The backticks are load-bearing, not decoration.** A bare
`example-manuscript` renders in MacDown as *three-way SST
error analysis manuscript* with the underscores eaten and two words italicised, because
the renderer reads `_SST_` and `_analysis_` as emphasis. Backticks make it literal.
**The same applies anywhere else a name with an underscore appears in prose** — repo
names, file names, folder names, config fields, environment variables. Mathematical
notation is the exception: `sigma_A`, `r_AM` and `V_MB` are science, not code, and are
left as written.
It applies to `CLAUDE.md`, `STATUS.md`, `LOG.md`, `DECISIONS.md`, `TASKS.md` and
`PLAN.md`. **`README.md` is the one exception: its title is the repo directory name
alone** — `# example-manuscript`, no filename, no em dash. It is
the human-facing file, and a filename in front of the title reads as a filing label
rather than a name. The directory name is still what it says, spelled exactly as `ls`
spells it.

Two files' worth of context is one glance this way: several of these open in the same
editor at once, and a title that says only `# STATUS.md` or only the prose project
name answers half the question. Where a file used to carry a descriptive title — the
old `# TASK — Establish one working standard…` — that sentence moves to a bold line
immediately under the H1, where it still reads and no longer competes.

The `<!-- CONTRACT: … -->` comment that the template puts **above** the H1 stays where
it is. It does not render, so the title is still the first line {{OWNER}} sees.

**Every `CLAUDE.md` opens with three lines** (D24), immediately under the title:

```
**What:** a triple-collocation SST error analysis, at Level 2.
**Produces:** a manuscript for MDPI Remote Sensing — `LATEX/main.pdf`.
**State:** drafting §6.5; see STATUS.md.
```

Same three labels, same order, same place, every project. It is roughly fifteen words
against a directory listing, and it is the fastest way to re-enter a project that has
not been touched in weeks.

Four rules that keep these from colliding:

1. **`STATUS.md` is always the living snapshot, and always ends with
   `## Active thread — resume here`.** That section is where a cold session picks up:
   what is in flight, what is blocked, what to do next. It is present *even when
   nothing is in flight* — then it says so ("nothing in flight; next is Task #7"),
   because a missing section is indistinguishable from a forgotten one. (With
   concurrent sessions it splits into one `## Active thread — <lane>` per lane; see
   Session protocol.) A deliverables tracker, or any other per-item table, gets its
   own name (`CODIFICATION_TRACKER.md`) — never `STATUS.md`.
2. **`CLAUDE.md` never grows a log.** Measured findings and design rulings are `D##`
   entries, not new paragraphs in `CLAUDE.md`.
3. **Session logs always live in `SESSIONS/`** — and in the `SESSIONS/` of the
   repository whose files the work changed, **not** the one the session happened to be
   launched from. One location, no exceptions. See "One session, two repos" under
   Session protocol.
4. **There is no separate handoff file.** The active-thread section from rule 1 is
   the resume point. Two files both claiming to say "where we are" will diverge, and
   when they do there is no way to tell which one is current.

### `DECISIONS.md` format

```
### D14. Short title in the imperative
- **Decision:** what was decided.
- **Why:** the reasoning, and what it rules out.
- **Where:** the files/functions that depend on it.
- **Live tension:** (optional) what still argues against it.
```

Appended, numbered, never renumbered. Cite them from tasks, status, and code comments
by number.

**What counts as a decision:** a choice that (a) constrains future work, (b) had a
real alternative that was rejected, and (c) would be re-litigated or accidentally
violated by someone who didn't know about it. The test: *would a competent person six
months from now look at this and think it's a mistake, or try to clean it up?*

**A negative result is a decision.** "We tried X, it does not work, here is the
measurement, do not re-attempt" passes all three tests and saves more time than most
positive findings — `example-registry`'s D23 (crt.sh: 27 candidates, 0 real servers)
is the model.

Not decisions: a task ("write a parser"), a convention ("4-space indents" → goes in
`CLAUDE.md`), an edit, or an action.

**I make the decisions; you notice and record them.** Draft the entry when you see
one being made and say so — "recording this as D14, object if that's wrong." If I say
**"log that"** or **"that's a decision,"** write it up.

### `LOG.md` format

The layer between the spine files, which are deliberately sparse, and the session
logs, which are too detailed to scan. One file per project, one line per prompt, read
top to bottom to see **what has been done** without opening anything else.

```
## Orbit-position dependence

- ★ **P1** `1615_your-desktop` · 2026-07-23 16:15 EDT · Task #8 — Figure 3, std by orbit position
  → `matchup_orbit_position_map.m`; #8 `doing`
- **P2** `1615_your-desktop` · 2026-07-23 17:02 EDT · colour-range control for Figs 1 & 3
  → `set_map_range`; #8 still `doing`
- ★ **P3** `1615_your-desktop` · 2026-07-23 17:20 EDT · Task #9 — annual + seasonal generators
  → three decisions; D18–D20
```

- **Every entry is a list item.** Not optional: a bare indented line is a paragraph
  continuation in markdown, so consecutive un-bulleted entries silently merge into one
  blob. Never use `*` or `-` as a *data* marker at the start of a line either — it is
  list syntax and will be eaten.
- **`★` marks a substantive entry** so a scan can skip the rest. It is deliberately
  not a markdown metacharacter.
- **Every entry carries a session key** — `` `<HHMM>_<host>` ``, the start time and
  host of the session log it came from (D20). `P##` alone is session-scoped, so in a
  project-level file it collides the moment two sessions append. The date is already
  on the line, so the key omits it.
- **Append-only, chronological.** A `## <theme>` heading appears when the topic
  shifts; entries append under the current one. True thematic sections would read
  better but need insertion into old sections, which breaks append-only and therefore
  the concurrency rule — see Session protocol.
- **One line for the prompt, one for what came of it** (indented two spaces so it
  stays inside the list item), pointing onward to the task, `D##`, or
  `Claude_diagnostic_analyses/<issue>/` it produced.
- **Written live**, at the same moment as the `P##` entry — not generated afterwards.
  A generated index cannot drift, but it only exists if the session logs are current,
  and they are exactly what lapses first.

### `TASKS.md` format

Each task carries a status line:

```
Status: todo | doing | blocked (on what) | done (YYYY-MM-DD)
```

- `doing` means **started and interrupted** — a cold session must know not to start
  it from scratch. It should be rare and short-lived; three at once means something
  is wrong.
- `blocked` names what it is waiting on. This is the state that matters most when
  picking up cold.
- **Never reopen a `done` task.** A task is a unit of *intent*, not of editing.
  Iterating on something before it is finished is the *same* task — a plot I ask you
  to adjust three times is one task, not four. It goes `done` when I move on to
  something else. Only a change requested *after* that is a new task referencing the
  old one (`#16, revises #14`). Reopening makes statuses flap and destroys the record
  of what was actually asked, and when.

When I say **"execute task N"**, you do all three: the work, the `Status:` line, and
the session-log entry.

**Where tasks come from — usually the dialog.** When a prompt is work rather than a
question, you turn it into a numbered task and say so ("logging that as #14"), so I
can correct the reading while it is cheap. I should never *have* to open `TASKS.md`.

I will sometimes write tasks there myself anyway — a long spec, or a set with
dependencies, is easier to compose in an editor than to say out loud. Take what I
write as given: add `Status: todo` if I left it off, and keep the `Status:` lines
current from then on. Re-read the file before acting on any task reference, since I
may have edited it since this session started or on the other machine.

**Not every prompt is a task**, or the file becomes a duplicate of the session log. A
question, a lookup, a one-line fix, or discussion *about* the work is not a task; it
lives in the session log and nowhere else. The test: does it need a `Status:` line —
can it meaningfully be *in progress* or *blocked*? The session log is the complete
record; `TASKS.md` is the subset that has to be tracked.

## Session protocol

**At the start:** read `CLAUDE.md`, then `STATUS.md` (its active-thread section is
where to resume). Open `SESSIONS/<YYYY-MM-DD>_<HHMM>_<TZ>_<host>.md` **before** doing the
work — deferring it to the end means it doesn't happen.

**Each entry's heading is `## P## · <YYYY-MM-DD> <HH:MM> <TZ> · <short title>`**,
with `·` as the separator. The format matters because `LOG.md` is reconciled against
these headings by timestamp; two separators were in use before this was written down,
and a reconciliation pass silently missed every log using the other one.

**Timestamp each entry with the moment the prompt arrived** (D28), not the moment you
got to it. If you did not capture it, read it from the transcript rather than the
clock — a log whose times are approximate cannot be reconciled with anything, and
half-hour errors here defeated three attempts to reconcile `LOG.md` against a session
log.

**A session log is a complete transcript, not a summary** (D38). Under every `## P##`
heading sit two sections, in this order and clearly separated:

- **`### Prompt`** — the prompt exactly as {{OWNER}} typed it, blockquoted so its own
  markdown cannot be confused with the log's.
- **`### Response`** — the assistant's prose, in full, with each tool call reduced to
  one line (`_[Bash: git status]_`). Tool *output* is left out; it is bulk, and the
  prose is what says what came of it.

**Neither is typed by hand.** Both are rebuilt from the session's JSONL by
`session-transcript.sh`, which lives in the configuration repo. **Resolve its path
rather than assuming one** — the repo is wherever it was cloned, which is not
necessarily `~/Git_Repos`:

```sh
CONFIG=$(dirname "$(dirname "$(readlink ~/.claude/commands)")")
"$CONFIG/session-transcript.sh" <log>
```

It replaces rather than appends — run it again whenever more prompts have arrived, and
once more at the end.
Two things it carries across every regeneration, and they are the only parts a human
writes: the header above the first `## P##`, and each entry's **subject line** and
optional **`### Notes`** block. A verbatim prompt is more authoritative than the
78-character excerpt the old prompt index held, so this supersedes it (D29).

Session JSONLs are machine-local, so **rebuild a log on the machine that produced
it**. The Stop hook's prose transcript in `~/.claude/archive/transcripts/` is on both
machines and remains the safety net.

**Its second line must be `<!-- session: <session-id> -->`.** This is not decoration:
both guards find the log by globbing `sessions/*.md` and matching that comment, and
**neither ever looks at the filename**. Without it a log is invisible to them, and
they will report that no log was opened while the log sits right there — which has
already sent one session chasing a filename-date theory that no guard implements.
One session is one file even when it spans days; do not start a second log because
the date rolled over.

**As you work:** add one `## P##` entry to that session log per prompt, each carrying
its own timestamp and zone. What you write is the **subject line** — six words that
say what the prompt was about — and, where it earns it, a `### Notes` block holding
what the verbatim record cannot say for itself: what was decided and why, what was
ruled out, where a claim was verified rather than assumed. The prompt and the
response arrive by rebuild, not by hand, so a trivial exchange still gets an entry —
it just gets no `### Notes`.

`LOG.md` gets a line for the same prompt, at the same moment — it is an index of the
session log, so it is as complete as the session log is.

The other three files have their own tests; a prompt reaches one only when its test
is met:

- `TASKS.md` — the prompt is work that needs tracking (see above).
- `DECISIONS.md` — a constraining choice actually got made (see above).
- `STATUS.md` — the state of the *project* changed. Not "we discussed something,"
  and not a list of what happened this session; that is what the session log is for.

Asking how to spell a word is a one-line `P##`, a `LOG.md` line without a `*`, and
nothing else.

**When I signal that I'm leaving** — *"I'm going home"*, *"I'm going to bed"*, or
anything that sounds like either — treat it as the end of the session without waiting
to be asked separately: refresh `STATUS.md`'s active thread, finalize the session log,
then **commit and push**, and tell me what you committed. I usually say this without
exiting Claude.

Same for an explicit "commit and push." *"Just commit"* means commit only. Otherwise
don't commit unless I ask.

**Machines.** I work across an iMac and a MacBook. Session history is local to a
machine, so a session cannot be resumed from the other one. **Never resume a session
that predates a pull which changed files** — start fresh instead. That session holds
confident beliefs about files that have since changed and has no way to notice.
The `<host>` segment of a session-log filename comes from
`scutil --get LocalHostName` — whatever that returns on the machine you are on — and
**not** from `hostname`, which on the laptop returns a VPN DHCP name such as
`a VPN DHCP name`.

**Concurrent sessions in one repo.** I sometimes run two at once on the same
checkout — analysis in one, manuscript prose in the other. They share a working tree,
so nothing protects them from each other:

- **Commit only the paths you touched.** Never `git add -A` or `git commit -a`; the
  other session's half-finished work is sitting in the same tree.
- **Stay in your lane.** Name your file set in the log header and keep to it.
  A cross-lane edit goes through me first.
- **`STATUS.md` splits.** With concurrent lanes the active thread becomes one
  subsection per lane (`## Active thread — analysis`), and a session rewrites **only
  its own**. It is the one file that is rewritten wholesale, so an unscoped write
  silently discards the other lane.
- Re-read `TASKS.md` / `DECISIONS.md` / `LOG.md` before appending and take the next
  free number; if two session logs would collide on the filename, append eight
  characters of the session id.

If the lanes genuinely need the same files, stop and use separate git worktrees
instead — lane discipline only works while the file sets are disjoint.

**One session, two repos** (D34). A session launched in one repository often does its
real work in another — restructuring repo B from a session sitting in repo A is the
common case. **The log belongs to the repository whose files changed, not to the
working directory.** A session that changed two repos writes a log in each, scoped to
what it did there, both carrying the same `<!-- session: … -->` id so they can be
matched later; if one side's share is a single edit, a `LOG.md` line there naming the
other repo's log is enough. Never let the cwd decide: it is an accident of where the
terminal happened to be.

The failure is silent and it has already happened — `example-search`'s restructure on
2026-08-04 was logged only in `claude-config-public`, so `example-search`'s `LOG.md` cited a session
key with no local log behind it, and a later session set out to reconstruct a record
that existed intact one directory over. **When a log looks missing, search
`~/.claude/archive/transcripts/` for the session id before reconstructing anything** —
the Stop hook logs every session regardless of repo, and it is how that one was found.

A `Stop` hook writes a raw prose log of every session to
`~/.claude/archive/transcripts/<sessionId>.md`, regenerated in full each turn. That is
the safety net, not the curated record — nothing said is ever lost, but the curated
`P##` log is still your responsibility.

## A worked example

Eight prompts from a real session in `example-manuscript`
(`sessions/2026-07-23_1615_EDT.md` — that path became correct when the repo was
migrated on 2026-07-31), and where each one landed. It is one session out of many in
that project, which is why it opens at Task #8: **`P##` restarts with every session
log; task numbers never restart, and run for the life of the project.**

| | prompt | session log | `TASKS.md` | elsewhere |
|---|---|---|---|---|
| P1 | "perform Task #8" | ✔ | #8 → `doing` | — |
| P2 | confirm dataset; add a colour-range control | ✔ | #8 stays `doing` | — |
| P3 | "undertake Task #9" | ✔ | #9 → `doing` | 3 choices — see below |
| P4 | move `.mat` outputs to Dropbox; commit | ✔ | — | `CLAUDE.md`, `STATUS.md` |
| P5 | new per-year plotting tool | ✗ | ✗ | — |
| P6 | combine year groups | ✗ | ✗ | — |
| P7 | enhance both std-map scripts | ✗ | ✗ | — |
| P8 | "Are you logging this?" | ✔ backfill P5–P8 | #10, #11 created | — |

**P2 did not open a new task** — adjusting the figure was still #8, which went `done`
only when P3 moved on.

**P4 changed a convention, not a decision.** "Generated `.mat` files live in Dropbox,
not the repo" belongs in `CLAUDE.md`, where every future session reads it.

**P3's three choices should have been `D##` entries** — which script the generators
drive, no orbit sub-sampling, and how seasons are defined. Each rejected a real
alternative and each constrains later work. They were written into the transcript
instead, where a session six months from now will not look. That is the most common
way this goes wrong — and it took eight days and a repo migration to fix: they are now
that project's D18–D20, promoted out of the transcript on 2026-07-31.

**And P8 is why the protocol exists.** The honest answer that day was *no*: logging
had stopped after P4, three prompts of work were built and verified but never
recorded, and Tasks #10 and #11 had to be reconstructed from context six days later.

## Division of labour

I own intent and judgment. You own transcription and bookkeeping.

| | me | you |
|---|---|---|
| `CLAUDE.md` | own it; edit the "what this is" and preferences | draft it; propose diffs when the layout changes |
| `STATUS.md` | read it | write it, always |
| `LOG.md` | scan it | append a line per prompt, live |
| `DECISIONS.md` | **make the call**; approve or correct | notice, draft, number, cross-reference |
| `TASKS.md` | one sentence of intent | numbering, write-up, Status lines |
| `README.md` | edit for voice | draft |
| `SESSIONS/` | — | entirely you |

Adding a task should cost me one sentence. Recording a decision should cost me the
word "yes." **If I am ever hand-typing a `Status:` line, the system has failed.**

## Conventions

- Repos live in **`~/Git_Repos`** — capital `G`, capital `R`. macOS volumes are
  case-insensitive, so a wrong-case path lists fine but fails to prefix-match a real
  one; this has caused a silent bug before.
- Markdown tables follow the `markdown-tables` skill. It loads automatically.
- **Never let a hard-wrapped line begin with `#`.** This system writes `#14` and
  `D##` constantly, and a task number landing at column 0 reads as a heading — an
  `<h1>` in loose parsers, and a false heading to anyone scanning the raw file.
  Rewrap the line; don't escape it.
- **Never point me at rendered markup.** Code fences and horizontal rules are the two
  that keep biting: my renderer strips the ``` markers, and a `---` reaches me as
  three literal dashes rather than a line. So "paste what is between the fences" and
  "everything above the horizontal rule" both point at something I cannot see — the
  same error as citing a line number.
- **Delimit anything I am meant to paste with a line of twenty dots**, and say so
  **before** the block, never after it: *"paste the lines between the two rows of
  dots."* Twenty dots is not markup — it survives every renderer as twenty dots, which
  is exactly why it works where a fence does not. Use it for text destined for another
  session or another machine; ordinary code and commands still go in a normal fence,
  because there I am reading rather than transporting. The example below is fenced
  only so the three lines survive as three lines — bare indented lines collapse into
  one paragraph, which is D14's problem again. The dots themselves are the delimiter;
  the fence around them is not part of it.

  ```
  ....................
  the text to paste
  ....................
  ```
- Refer to another repo by its actual directory name, never a nickname.
- Prefer editing an existing file over creating a new one. Do not create
  documentation files unless asked.
- **In terminal responses, put file, folder and path names in bold, not backticks.**
  Backticks stay for things that are literally code: commands to run, variable and
  subroutine names, values, literal strings. {{OWNER}}'s terminal renders inline code in a
  light blue he finds hard to read, and file names are what a response is densest in —
  a paragraph naming six files was six unreadable words. Bold renders in the ordinary
  foreground colour and stays legible. **You cannot choose colours**; the theme does
  that, so changing the markup is the only lever you have — say so rather than
  promising a colour you cannot produce. This is about the terminal only: **inside
  markdown files, file names keep their backticks**, because MacDown renders those
  fine and the spine files are full of them.

## Writing manuscript prose for me

**These apply to manuscripts and papers only** — not to `README.md` files (I edit
those for voice after you draft them), and not to code comments or commit messages,
where voice is irrelevant.

- Match the register of what is already there: formal, and hedged where the science
  requires it.
- Read the existing text first; extend it, don't overwrite it. Default to completion,
  not reorganization.
- Never change a reported number, σ value, count, or threshold unless I ask or supply
  the corrected value with a source.
- Fix outright spelling and grammatical errors without asking. Anything that changes
  meaning, emphasis, or structure is a suggestion, not an edit.
