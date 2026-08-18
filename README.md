# `claude-config-public`

**A working standard for using Claude Code on real projects** — conventions that load in
every repo, a project template, and hooks that keep a record of what was done and why.

Built from a configuration in daily use on research projects, with the author's personal
material removed. Generated 2026-08-17 02:55 UTC from source commit `ef5fd34`.

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

Type these in order. Fork first — rewriting the rules file is the point of this repo,
and those edits need a repo of your own to live in.

```sh
gh repo fork pcornillon/claude-config-public --clone=false   # or press Fork on GitHub

cd ~/Git_Repos                                               # wherever you keep repos
git clone https://github.com/<your-github-username>/claude-config-public.git
cd claude-config-public

git config --global user.name "Your Name"    # install.sh writes this into your rules
./check-prereqs.sh                           # reports what is missing; installs nothing
./install.sh                                 # links global/ into ~/.claude/
```

Then quit `claude` and start it again — the payload is read at session start.

`INSTALL_AND_CONFIGURE.md` is the same sequence with what each command prints, how to
tell it worked, and what to do when it doesn't. Read it if anything above is unclear.
`TASKS.md` Task #1 is the one that matters afterwards: making `global/CLAUDE.md` yours.

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
