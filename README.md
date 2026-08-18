# `claude-config-public`

**A working standard for using Claude Code on real projects** — conventions that load in
every repo, a project template, and hooks that keep a record of what was done and why.

Built from a configuration in daily use on research projects, with the author's personal
material removed. Generated 2026-08-18 17:02 UTC from source commit `9851f20`.

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

## Install it

**Bold lines are things you do**, and each one says where you do it — in a terminal, or
inside `claude`. Everything else says what just happened and can be skipped on a first
pass. `<base-folder>` is wherever you keep repositories.

**1. In a terminal: clone it, and tell git your name.**

```sh
cd <base-folder>
git clone https://github.com/pcornillon/claude-config-public.git
cd claude-config-public
git config --global user.name "Your Name"
```

That last line matters more than it looks: `install.sh` writes your name into your rules
file, and with no git name set it falls back to your Unix login name.

**2. In the terminal: check what is missing.**

```sh
./check-prereqs.sh
```

It installs nothing. For each missing item it prints what the item is for and the
command that fixes it — `brew install jq` and the like. Run those yourself, then run
this again until it ends with `Core is complete.`

**3. In the terminal: install.**

```sh
./install.sh
```

No prompts; it asks you nothing. It links four things into `~/.claude/` —
`settings.json`, `CLAUDE.md`, `skills`, `commands` — and touches nothing outside that
directory. An existing `~/.claude/settings.json` or `~/.claude/CLAUDE.md` is copied to
`<name>.pre-install.bak` first and then replaced. If `~/.claude/skills` or
`~/.claude/commands` is a real directory rather than a link, it **stops** instead of
guessing: move yours into `global/skills` or `global/commands` and run it again.

**4. In the terminal: confirm the install.**

```sh
./install.sh --check
```

A shell command, like the two before it — it is the only thing here that verifies rather
than changes anything. It ends with `check: this machine is fully linked to <your path>`
when all four links are in place, and names what is wrong when they are not. Run it any
time you want to know whether this machine is still wired up.

**5. In the terminal: start a fresh `claude` session.** Any project will do; this repo
is fine.

It has to be a *new* session. Hook configuration is read once, when a session starts, so
any `claude` that was already open when you ran step 3 is still using whatever was there
before. You do not have to hunt down sessions in other projects — they simply will not
have the hooks until the next time they start. All that matters for step 6 is that the
session you use was started after step 3.

Everything up to here was typed in a terminal. Step 6 is the first thing typed inside
`claude`.

**6. In `claude`: type `This is a dummy prompt`, let it answer, then quit.**

The hooks run when a turn *ends*, so a session has to answer something and finish before
there is anything to see.

**7. Back in the terminal: confirm the hooks ran.**

```sh
ls -R ~/.claude/archive
```

Two things should be there: `usage-log.csv`, one row per session with its token counts,
and `transcripts/<session-id>.md`, a prose log of the session rewritten every turn. If
`~/.claude/archive` does not exist at all, no hook has run — nearly always because the
session you used in step 6 was started before step 3, which is what step 5 is for.

**8. Read `global/CLAUDE.md`** — in an editor, whenever you like.

It is one person's working rules, shipped intact on purpose: a specific set that earned
each of its lines beats a generic set nobody follows. **Keeping them as they are is a
perfectly good way to start**, and it is what most people do — they work as written, and
which parts do not suit you is far easier to see after a week of using them than on a
first reading. Nothing in this repo depends on your changing anything.

Change them when something grates: the tone, how much gets written down, how questions
are put to you. Then it is one edit in one file, and it applies to every repository on
this machine — which makes it the highest-leverage edit available to you. `TASKS.md`
Task #1 is there as a reminder that rewriting this file is expected, whenever you get to
it.

`INSTALL_AND_CONFIGURE.md` is the same sequence with more detail, plus how to take a
later version without losing your edits.

## Optional: the session panel

[claude-switchboard](https://github.com/pcornillon/claude-switchboard) is a macOS panel
showing every `claude` session running on your Mac — which project, which Desktop, and
which ones are waiting on you. It is a separate repo, and close enough to part of this
that `./check-prereqs.sh switchboard` checks for it.

```sh
cd <base-folder>
brew install --cask hammerspoon     # then launch it once
git clone https://github.com/pcornillon/claude-switchboard.git
```

Two steps a script cannot do for you:

1. **Grant Accessibility to Hammerspoon** — System Settings → Privacy & Security →
   Accessibility. Without it the panel loads and lists sessions but every label comes
   out blank.
2. **Point Hammerspoon at the clone** by copying the three lines of
   `claude-switchboard/init.lua.example` into `~/.hammerspoon/init.lua`, adjusting the
   path if you cloned somewhere other than `~/Git_Repos`. Then reload Hammerspoon and
   look for the panel.

**If macOS asks for Accessibility again**, after you have edited the panel's Lua and
reloaded Hammerspoon, you can dismiss it: the permission is granted to Hammerspoon
itself, not to the code it loads, so granting it once is enough. Confirm in System
Settings → Privacy & Security → Accessibility that **Hammerspoon** is still enabled if
you want to be sure.

`claude-switchboard/INSTALL.md` has the rest.

## Starting a new project

Inside `claude`, not in the shell:

```
/new-project my-project-name
```

It interviews you first — what this project is, whether it is built in phases, what
must never be done — then copies the template, writes the six spine files and the five
folders, runs `git init`, opens a session log, and commits. It deliberately does **not**
create a GitHub remote; that is outward-facing, so it asks.

Answer the interview plainly, and leave a gap rather than a guess. A template filled
with plausible invention is worse than one with holes in it, because the invention
reads as fact six weeks later.

## Reconfiguring a project you already have

There is no migration script, and deliberately so — moving a real project onto this
spine is a series of judgment calls about what its existing files mean. What there is,
is a command that tells you exactly what is missing. Inside `claude`, from the repo:

```
/audit-project
```

It reports drift and **changes nothing**: which spine files and folders are absent,
whether `STATUS.md` still ends in an active-thread section, `D##` and task-number gaps,
session logs in the wrong place or without their session comment. Work through what it
found, then ask `claude` to make the changes you agree with.

Two conventions worth keeping when you do:

- **Anything you replace moves to `PRE_CONVERSION/` unmodified**, not into the trash.
  A migration that loses the original is not reversible.
- **Decisions buried in old notes get promoted into `DECISIONS.md`** as they are found.
  That is usually the most valuable part of the whole exercise: the reasoning exists,
  it is just somewhere nobody will look again.

If the repo has no `CLAUDE.md` at all, `/audit-project` skips it by design — repos
predating the standard are out of scope. Ask `claude` to add the spine to it instead.

## Licence and provenance

**MIT** — see `LICENSE`. Use it, change it, ship it; keep the copyright notice.

The rules in `global/CLAUDE.md` arrive as **one person's** working rules, on purpose: a
specific set that earned each of its lines beats a generic set nobody follows. Names,
machines and projects have been replaced with placeholders. Change all of it.
