<!-- CONTRACT: what this project is, its one big idea, and its layout. Stable
     reference, read at the start of every session. NEVER a log — measured findings
     and design rulings are D## entries in DECISIONS.md. Universal working rules live
     in ~/.claude/CLAUDE.md and must not be repeated here. -->

# CLAUDE.md — `{{PROJECT}}`

**What:** {{WHAT_ONE_LINE}}
**Produces:** {{PRODUCES}}
**State:** {{STATE}}

Auto-loaded by Claude Code at the start of every session in this repo. Persistent
project context. Working rules that apply everywhere are in `~/.claude/CLAUDE.md`.

**Read in this order before starting work:**

| File | What it holds |
|------|---------------|
| `CLAUDE.md` (this file) | what the project is, its one big idea, the layout |
| `STATUS.md` | where things stand; its **active thread** is where to resume |
| `LOG.md` | one line per prompt — scan this to see what has been done |
| `DECISIONS.md` | why it is the way it is — numbered `D##` |
| `TASKS.md` | the work list |

Spine folders, always present even when empty: `DOCS/` (project documents), `LATEX/`
(manuscript sources and output), `ISSUE_ANALYSES/` (investigations, plus a flat folder
per language once code in that language exists — D36), `SESSIONS/`, `PRE_CONVERSION/`.

## What this project is

{{WHAT}}

## The one idea that makes this tractable

{{BIG_IDEA}}

## Layout

```
{{LAYOUT}}
```

## Conventions

{{CONVENTIONS}}
