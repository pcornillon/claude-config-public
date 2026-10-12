<!-- CONTRACT: append-only, one line per prompt, written live alongside the P##
     session-log entry. EVERY entry is a list item — a bare indented line is a
     paragraph continuation in markdown and consecutive entries will silently merge.
     '★' marks substantive entries; never use '*' or '-' as a data marker, they are
     list syntax. A '## <theme>' heading when the topic shifts. This is the scannable
     layer between the sparse spine files and the detailed session logs — never edit
     past entries. Every entry carries a session key, written as a LINK to the session
     log it came from (D20, D55) — never reconstruct that filename from the row's date,
     because the key is the session's START and the date is the prompt's. -->

# LOG.md — `{{PROJECT}}`

One line per prompt, appended live, numbered project-wide with the session's own
number in parentheses — `P27 (P4)` (D60). `★` marks a substantive entry, and the
`` `<HHMM>_<host>` `` key **links to** the session log it came from (D20, D55).
Detail lives in `SESSIONS/`; this file is for scanning.

The link lands at the top of the log, not at the prompt: MacDown honours a `#fragment`
only inside the document already displayed, so use its search for the `## P##` once
there. **A key left unlinked is information** — it means no session log for it lives in
this repo, either because the work was logged in another repo (D34) or because no log
was written. When that happens, `claude-config-public/foreign-keys.sh` writes a "Session logs
held elsewhere" block here naming the repo that holds each (D56).

---

## Setup

- ★ **P1 (P1)** [`{{SESSION_KEY}}`](SESSIONS/{{SESSION_LOG}}) · {{DATE}} · scaffold the project
  → spine written
