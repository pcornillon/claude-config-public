<!-- CONTRACT: what this project is, its one big idea, and its layout. Stable
     reference, read at the start of every session. NEVER a log — measured findings and
     design rulings are D## entries in DECISIONS.md. -->

# CLAUDE.md — `claude-config-public`

**What:** the working standard this machine's Claude Code sessions run under.
**Produces:** the `~/.claude/` payload — rules, skills, commands, hooks — plus the
template every new project is scaffolded from.
**State:** freshly installed; nothing customised yet. See `STATUS.md`.

## What this project is

One place for the conventions you and Claude work under, deployed into `~/.claude/` by
`install.sh` so they load in **every** repo, plus the project template that
`/new-project` copies.

## The two CLAUDE.md files

| File | Loaded when | Contains |
|------|-------------|----------|
| `CLAUDE.md` (this file) | working *in this repo* | context for this repo itself |
| `global/CLAUDE.md` | **every session, every repo**, once installed | your universal working rules |

`global/` is the payload — the tree symlinked into `~/.claude/`. Never merge the two.
A change to `global/CLAUDE.md` applies to all your repos at once.

## Layout

```
install.sh             symlinks global/ into ~/.claude/ — run once per machine
check-prereqs.sh       what this needs, what is missing, and how to get it
tag-spine.sh           Finder-tags the spine folders (macOS, cosmetic)
session-transcript.sh  rebuilds a session log as a complete transcript
global/                THE PAYLOAD — deploys to ~/.claude/
hooks/                 hook scripts named by global/settings.json
```

## Where the rules live

`global/CLAUDE.md` is one person's rules, shipped intact on purpose — a real set is
more useful than a generic one. **Rewriting it is Task #1.**
