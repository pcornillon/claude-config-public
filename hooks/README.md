# Hooks — `claude-config-public`

**What each hook script in this folder does, when it runs, and why it exists.**
Written 2026-10-20 from the scripts themselves and `global/settings.json`; where a
script and this file disagree, the script is right and this file is stale.

## How a hook gets run

Claude Code runs a command at fixed points in a session — **events** — if
`~/.claude/settings.json` registers one for that event. The events used here are
Claude Code's own: `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`,
`Notification`, `Stop` (end of every assistant turn) and `SessionEnd`.

The scripts are not part of Claude Code. They were written for this configuration
and are registered in `global/settings.json`, which `install.sh` symlinks to
`~/.claude/settings.json`. The registrations name each script by an absolute path;
`install.sh` repoints those paths at wherever this repo is cloned, and refuses to link
a `settings.json` that does not parse or that names a missing script.

Each script receives a JSON **payload** on stdin — the session id, the working
directory, the path of the session's JSONL transcript, and event-specific fields. It
replies, if at all, with JSON on stdout:

- `systemMessage` — shown to {{OWNER}} in the terminal;
- `additionalContext` — given to Claude, not shown;
- `permissionDecision: "deny"` (`PreToolUse` only) — stops the tool call.

Hook configuration is read when a session starts, so a change to `settings.json`
reaches only sessions started after it.

## Rules every hook here follows

- **Fail open (D10).** Any error — malformed payload, missing file, no network,
  timeout — ends the script with exit 0 and no output. A broken hook must never
  interrupt the session it watches.
- **Warn before blocking (D11).** A guard ships warn-only. Only the decision-number
  guard blocks, and only on a fact a `grep` can establish.
- **No state under Dropbox (D17).** Online-only Dropbox files read as 0 bytes and
  appends to them are silently reverted, so anything a hook reads back lives in
  `~/.claude/` or `~/.hammerspoon/`. The prose log and the usage log write their
  output to Dropbox so it is on both machines; of the two, only the usage log reads
  its file back, and it never rewrites a file it could not read (Task #43).
- **Scope.** The logging guards act only inside a **Claude project** — a directory
  tree with both `CLAUDE.md` and `SESSIONS/` (or the pre-D23 `sessions/`), found by
  walking up from the working directory, never above `$HOME`. Elsewhere they are
  silent.
- **Python inside bash.** Every script except the dashboard hook is a bash wrapper
  around a `python3` program; the dashboard hook uses only bash and `awk` (D80 in
  `claude-switchboard`).

## Summary

<table>
<colgroup><col style="width:24%"><col style="width:24%"><col style="width:12%"><col style="width:40%"></colgroup>
<thead><tr><th>Script</th><th>Event</th><th>Can block?</th><th>In one line</th></tr></thead>
<tbody>
<tr><td><code>claude-prose-log.sh</code></td><td><code>Stop</code></td><td>no</td><td>raw prose transcript of every session, to Dropbox</td></tr>
<tr><td><code>claude-usage-log.sh</code></td><td><code>Stop</code></td><td>no</td><td>one CSV row of token counts per session, to Dropbox</td></tr>
<tr><td><code>claude-log-guard.sh</code></td><td><code>Stop</code></td><td>no (warn-only)</td><td>warns if the curated session log or <code>STATUS.md</code> has fallen behind</td></tr>
<tr><td><code>claude-log-debt.sh</code></td><td><code>SessionEnd</code>, <code>SessionStart</code></td><td>no</td><td>records unlogged prompts when a session ends; reports them when the next one starts</td></tr>
<tr><td><code>claude-cwd-guard.sh</code></td><td><code>SessionStart</code></td><td>no</td><td>warns if the session started outside a repository</td></tr>
<tr><td><code>claude-repo-freshness.sh</code></td><td><code>SessionStart</code></td><td>no</td><td>fetches, and warns if the checkout is behind its upstream</td></tr>
<tr><td><code>claude-handoff-guard.sh</code></td><td><code>PostToolUse</code> on a <code>git push</code></td><td>no (warn-only)</td><td>after a push, warns if the handoff looks unfinished</td></tr>
<tr><td><code>claude-decision-number-guard.sh</code></td><td><code>PreToolUse</code> on a <code>git commit</code></td><td><b>yes</b></td><td>refuses a commit while <code>DECISIONS.md</code> repeats a <code>D##</code> number</td></tr>
<tr><td><code>claude-dashboard-state.sh</code></td><td>five events</td><td>no</td><td>tells <code>claude-switchboard</code> what each session is doing</td></tr>
</tbody>
</table>

## The hooks one by one

### `claude-prose-log.sh` — the safety-net transcript

- **Event:** `Stop`, after every assistant turn. Timeout 20 s.
- **Reads:** the session JSONL named by `transcript_path`.
- **Writes:** `~/.claude/archive/transcripts/<session-id>.md`, regenerated in full each
  turn and replaced atomically (temp file, then rename).
- **What goes in:** every prompt, every assistant reply with each tool call reduced to
  `_[tool: Name]_`, and the two tool results that carry something {{OWNER}} said — the
  question and answer of an `AskUserQuestion`, and a denied permission prompt with
  any feedback typed. Harness injections, subagent traffic and other tool output are
  left out. A header gives the session id, project directory, first and last
  timestamps, and prompt and turn counts.
- **Why:** a record of every session exists whether or not the curated `SESSIONS/`
  log was kept. It is on both machines through Dropbox, and it is where to search
  first when a log looks missing.

### `claude-usage-log.sh` — token usage per session

- **Event:** `Stop`. Timeout 15 s.
- **Reads:** the session JSONL; sums the `usage` block of every main-chain assistant
  record.
- **Writes:** `~/.claude/archive/usage-log.csv`, one row per session — updated time,
  session id, project directory, model, prompt and turn counts, input, output,
  cache-write and cache-read tokens, and their sum. Each turn it replaces this
  session's row, keeps every other row, and rewrites the file atomically. If the
  file exists but cannot be read, or is not this CSV, it skips the update.
- **Why:** usage and cost can be tracked across sessions and projects.

### `claude-log-guard.sh` — is the curated log keeping up?

- **Event:** `Stop`. Timeout 10 s. Warn-only (D11).
- **Scope:** Claude projects only.
- **Checks:**
  1. **Is there a session log?** It looks in `SESSIONS/` for a file whose first ten
     lines contain `<!-- session: <this session's id> -->`. It never looks at file
     names.
  2. **Is it complete?** It counts {{OWNER}}'s prompts in the JSONL (excluding harness
     injections, slash-command records, interruptions, background notifications and
     subagent traffic) against the log's `## P` headings — or the rows of a generated
     prompt index, whichever is larger (D27). A gap of one is the prompt still being
     answered and is not reported.
  3. **Is `STATUS.md` current?** It compares `STATUS.md`'s modification time with the
     newest git-tracked file, ignoring `LOG.md` and `SESSIONS/`, with five minutes'
     grace.
- **Says:** one `systemMessage` beginning "log guard (warn-only):" listing what it
  found. Nothing if all three pass.
- **Why:** on `Stop` the log can never fall more than one turn behind (D9).
  `SessionEnd` is too late, and does not fire when a terminal is killed. The
  blocking form is written out, commented, at the end of the script, and the
  `stop_hook_active` check that would stop a blocking `Stop` hook from looping is
  already in place.

### `claude-log-debt.sh` — debts carried to the next session

- **Events:** `SessionEnd` and `SessionStart`. Timeout 10 s each.
- **Scope:** Claude projects only.
- **At `SessionEnd`:** counts prompts and `## P` entries as the log guard does. If the
  log is behind, it appends one JSON line to `~/.claude/log-debt.jsonl` — machine-local
  (D17) — with the session id, repo, end time and reason, the counts, and the paths
  of the log and the JSONL. `SessionEnd` cannot block or display anything (D9), so a
  note is all it can leave.
- **At `SessionStart`:** reads that file, and for this repo reports up to the five
  most recent debts from *other* sessions as `additionalContext`, telling Claude to
  raise them with {{OWNER}} before backfilling anything. Delivered rows are removed;
  rows older than 14 days are dropped unreported.
- **Why:** the log guard's warning dies with a session that ends dirty — terminal
  closed, `/exit` mid-thought, machine asleep. This is the breadcrumb that survives it.

### `claude-cwd-guard.sh` — started in the wrong place?

- **Event:** `SessionStart`, only on a fresh start or a resume (not after `/clear` or
  compaction). Timeout 10 s.
- **Checks:** where the session started.
  - In `$HOME` → loud warning.
  - Outside any git repository → loud warning.
  - In a subdirectory of a repository → a quiet note.
  - At a repository's root → nothing.
- **Says:** a `systemMessage` for {{OWNER}}, and `additionalContext` telling Claude to
  raise it rather than act on it.
- **Why (D31):** a session's project folder under `~/.claude/projects/` is fixed by
  the directory it starts in and never follows `cd`. On 2026-08-03 a session started
  in `$HOME` worked in eleven repositories for six hours and filed all 21 prompts
  under the home directory, where nobody looked for them. Only at start can it still
  be fixed, by restarting in the right place.

### `claude-repo-freshness.sh` — is this checkout behind?

- **Event:** `SessionStart`, fresh start or resume only. Timeout 40 s.
- **Scope:** git repositories with a `CLAUDE.md` at the root, on a branch that tracks
  an upstream.
- **Does:** `git fetch` (up to 25 s), then counts commits on the upstream that are
  not here. If there are any, it reports up to eight of them, the files they touch,
  and — loudest — any of those files that are *also* modified in this working tree.
- **Never pulls,** and tells Claude not to: two sessions may share this working tree,
  and a pull could land on the other's unfinished work.
- **Silent when** the checkout is current, or the fetch fails. It never reports from
  an unrefreshed ref.
- **Why (D52):** on 2026-09-08 a session three commits behind wrote a new decision as
  D48, a number `origin/main` already had. The check that should have caught it
  compared against a local ref last fetched three days earlier and reported "up to
  date". A freshness check that does not fetch is worse than none.

### `claude-handoff-guard.sh` — pushed, but is the handoff finished?

- **Event:** `PostToolUse` on the Bash tool, filtered in `settings.json` by
  `"if": "Bash(git push *)"`; the script checks for `git push` again itself, and
  ignores `--dry-run`. Timeout 10 s. Warn-only (D11).
- **Scope:** Claude projects only.
- **Checks, after the push:**
  1. the session log, as the log guard does — and if none carries this session's id,
     whether `SESSIONS/` holds logs at all, because "no log opened" and "log missing
     its id comment" need opposite fixes;
  2. whether the commit just pushed changed anything other than `LOG.md` and
     `SESSIONS/` without changing `STATUS.md`;
  3. whether tracked files are still modified (untracked files are ignored).
- **Says:** a `systemMessage` beginning "handoff guard (warn-only):", and the same
  text to Claude with "If {{OWNER}} is leaving, finish the active thread in STATUS.md
  and the session log, then commit again."
- **Why:** "commit and push" often means {{OWNER}} is leaving without exiting Claude. The
  push is the last moment the unfinished handoff can be caught. It runs *after* the
  push on purpose: blocking a push costs more than a nudge a second late.

### `claude-decision-number-guard.sh` — no repeated `D##`

- **Event:** `PreToolUse` on the Bash tool; acts only when the command contains
  `git commit` (not `--help`). Timeout 10 s.
- **Checks:** every `### D<n>.` heading in the repository's `DECISIONS.md`.
- **Blocks** the commit, with `permissionDecision: "deny"`, if any number appears
  twice, and says how to fix it: fetch, renumber the local entry to the next free
  number, update what cites it. Gaps and out-of-order entries are allowed.
- **Why (D54):** `DECISIONS.md` is append-only and never renumbered, so a duplicate
  number permanently breaks every citation of it. It is a `PreToolUse` hook rather
  than a git hook because git hooks are per-clone and not carried by `git clone`;
  this reaches every repository at once.

### `claude-dashboard-state.sh` — what `claude-switchboard` displays

- **Owned by `claude-switchboard`;** this repo carries a checked copy, and `install.sh`
  warns if the two differ (D46).
- **Events and states:**
  - `SessionStart` → `idle` — a session exists and has not been asked anything;
  - `UserPromptSubmit` and every `PostToolUse` → `working`;
  - `Notification` → `waiting` — Claude wants {{OWNER}} (permission or question). The
    idle "waiting for your input" nudge Claude Code sends about a minute after a
    turn ends is filtered out, or every finished session would turn red;
  - `Stop` → `done`, or `background` when the turn ended with background work still
    running (read from the payload's `background_tasks`);
  - `SessionEnd` → `gone` — the state file is removed.
- **Writes:** `~/.hammerspoon/claude_state/<session-id>.json` (machine-local), and a
  trace of state *transitions* only. Does nothing on a machine without Hammerspoon.
- **Optional remote alert:** if `~/.claude/dashboard-notify.conf` exists, a `waiting`
  state can also drop a marker in Dropbox for another Mac or push to a phone (ntfy,
  Pushover). No config file, no network traffic.
- **Why:** the terminal title shows whether a session is computing, but not *why* it
  stopped. Only `Notification` says a session is blocked on {{OWNER}}, and that is what
  lights the red dot. Its design decisions are in `claude-switchboard`'s
  `DECISIONS.md` (D80, D83, D95, D97).

## Known gaps

- **The prompt-counting filter is copied into three hooks** — the log guard, the
  log-debt hook and the handoff guard. A change to it has to be made in all three, or
  they will disagree about how far behind a log is.

Fixed 2026-10-20 (Task #43): `claude-usage-log.sh` now leaves an unreadable or
unrecognised CSV alone instead of rewriting it with one row, and
`claude-log-debt.sh` accepts `SESSIONS/` as well as `sessions/`, like the other
guards.
