# `claude-config-public`

**A working standard for using Claude Code on real projects** — conventions that load in
every repo, a project template, and hooks that keep a record of what was done and why.

Built from a configuration in daily use on research projects, with the author's personal
material removed. Generated 2026-08-17 02:36 UTC from source commit `c358dbf`.

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

Six steps, one command each. Steps 1–2 get you a copy you can edit and keep; 3–5
install it; 6 proves it worked.

### 1. Fork this repo

```sh
gh repo fork pcornillon/claude-config-public --clone=false
```

Or press **Fork** on GitHub. Fork rather than clone: Task #1 is rewriting
`global/CLAUDE.md` into your own rules, and a fork is where those edits live.

### 2. Clone your fork

```sh
git clone https://github.com/<your-github-username>/claude-config-public.git
cd claude-config-public
```

Wherever you keep repos. Every command below runs from inside that directory.

### 3. Tell git your name

```sh
git config --global user.name "Your Name"
```

`install.sh` writes this name into your rules file. Do it first: with no git name
set, it falls back to your Unix login name.

### 4. Check what is missing

```sh
./check-prereqs.sh
```

### 5. Install

```sh
./install.sh
```

### 6. Restart `claude`, then confirm

```sh
./install.sh --check
```

Hook configuration is read at session start, so quit `claude` and start it again
before checking anything.

Then read `INSTALL_AND_CONFIGURE.md`: the same six steps with the reasons, how to
check the hooks are really running, and two more steps — making the rules yours
(**Task #1** in `TASKS.md`) and scaffolding your first project.

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
