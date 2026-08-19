---
description: Scaffold a new Claude project from the standard template
---

Create a new Claude project using the standard spine.

If `$1` is empty, ask for the project name first and stop.

## Resolve these two paths first — never assume `~/Git_Repos`

```sh
CONFIG=$(dirname "$(dirname "$(readlink ~/.claude/commands)")")   # this configuration
BASE=$(dirname "$CONFIG")                                         # where repos are kept
```

`~/.claude/commands` is a symlink into the configuration repo, laid by `install.sh`, so
this resolves wherever it was cloned. The template is
`$CONFIG/global/templates/project/` and the Finder tagger is `$CONFIG/tag-spine.sh`.
`$BASE` is only the **default** home for the new project — the interview confirms it.

## Steps

1. **Refuse to clobber.** If the chosen directory already exists, say so and stop.

2. **Interview before writing.** Ask, in one message, using AskUserQuestion where the
   answers are a choice:
   - What is this project, in two or three sentences?
   - Is there a single idea that makes it tractable? (Optional — skip if not.)
   - Does it need `PLAN.md`? Only if it is built in phases.
   - What are its hard constraints — the things that must never be done?
   - Where should it live? Offer `$BASE/$1` as the default and accept any other path;
     `$BASE` is where this configuration happens to be cloned, which is a good guess and
     nothing more.
   Do not guess these. A template filled with plausible invention is worse than one
   with gaps.

3. **Copy the template** from `$CONFIG/global/templates/project/`
   and substitute: `{{PROJECT}}`, `{{WHAT}}`, `{{BIG_IDEA}}`, `{{LAYOUT}}`,
   `{{CONVENTIONS}}`, `{{GUARDRAILS}}`, `{{ONE_LINE}}`, `{{FIRST_TASK}}`,
   `{{WHAT_ONE_LINE}}`, `{{PRODUCES}}`, `{{STATE}}`,
   `{{FIRST_DECISION}}`, `{{DATE}}`. Get `{{DATE}}` from
   `date '+%Y-%m-%d %H:%M %Z'` — never invent it.

4. **Strip the `<!-- CONTRACT: … -->` comment** from the top of each file only if the
   user asks. It is there to stop a future session repurposing `STATUS.md`, and it
   costs nothing to leave in.

5. **Keep all five spine folders**, `.gitkeep` and all, even the ones this project
   will not use (D21). An empty `LATEX/` says "no manuscript here"; a *missing* one
   says nothing and costs a look. **Never** fill `{{WHAT_ONE_LINE}}`, `{{PRODUCES}}`
   or `{{STATE}}` with a guess — ask.

6. **Delete any section left entirely as a placeholder.** An empty
   "The one idea that makes this tractable" heading is noise; no heading is honest.
   Never leave `{{...}}` in a committed file.

7. **`git init`**, then open the session log **inside the project you just created** —
   `<project>/SESSIONS/<YYYY-MM-DD>_<HHMM>_<TZ>_<host>.md` — and start `LOG.md`. The
   session protocol applies from the first prompt, not from the second.

   **Do not weigh D34 here.** The repo whose files changed is the one you have just
   made, whatever directory the session was launched from and whether or not that
   directory is a repo at all. D34 is for a session that works across two *existing*
   repos.

   In the log's header, give the command that rebuilds it, with `$CONFIG` already
   expanded to a real path — `<config>/session-transcript.sh <log>`. A header that
   names a path which does not exist on this machine is why a log stays
   placeholder-shaped. **The session log's
   second line must be `<!-- session: <session-id> -->`**; the guards match on that
   comment and never on the filename, so a log without it is invisible to them.

8. **Do not create a GitHub remote.** That is outward-facing; offer, and let {{OWNER}}
   decide.

9. **Tag the spine folders for Finder** — `$CONFIG/tag-spine.sh <repo>`
   (D26). Tags are extended attributes, so git does not carry them; this has to be run
   once per machine per project, including after a fresh clone.

10. **Commit** with a message naming what the project is for.

## Afterwards

Tell {{OWNER}} what was created and what is still `{{...}}`-shaped or unanswered, so he
can fill it in rather than discovering it later.
