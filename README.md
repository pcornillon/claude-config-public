# `claude-config-public`

**A working standard for using Claude Code on real projects** — conventions that load in
every repo, a project template, and hooks that keep a record of what was done and why.

Built from a configuration in daily use on research projects, with the author's personal
material removed. Generated 2026-08-15 19:56 UTC from source commit `ed76cfa`.

## What you get

- **One rules file, loaded everywhere.** `global/CLAUDE.md` deploys to `~/.claude/` and
  applies in every repository — how you want to be talked to, how decisions get
  recorded, what must never be invented.
- **A project spine.** Every project gets the same six files and five folders, so
  picking up a project you have not touched in a month costs a glance rather than an
  afternoon: `CLAUDE.md`, `STATUS.md`, `LOG.md`, `DECISIONS.md`, `TASKS.md`, `README.md`.
- **`/new-project`**, which scaffolds that spine, interviews you first, and refuses to
  fill it with plausible invention.
- **Hooks** that write a prose transcript of every session, warn when the curated log
  falls behind, and note unlogged work for the next session to pick up.

## Start here

```sh
./check-prereqs.sh      # what this needs, and how to get anything missing
./install.sh            # symlinks global/ into ~/.claude/
```

Then read **INSTALL_AND_CONFIGURE.md**, which walks through both, and **Task #1** in
`TASKS.md`: making `global/CLAUDE.md` yours.

## A companion, optional

[claude-switchboard](https://github.com/pcornillon/claude-switchboard) is a macOS panel
showing every `claude` session running on your Mac — which project, which Desktop, and
which ones are waiting on you. It needs Hammerspoon; `./check-prereqs.sh switchboard`
tells you what is missing.

## Licence and provenance

**MIT** — see `LICENSE`. Use it, change it, ship it; keep the copyright notice.

The rules in `global/CLAUDE.md` arrive as **one person's** working rules, on purpose: a
specific set that earned each of its lines beats a generic set nobody follows. Names,
machines and projects have been replaced with placeholders. Change all of it.
