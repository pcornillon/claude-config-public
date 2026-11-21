---
description: Explain, in plain English, how to read a Claude Code permission prompt and what each choice does
---

Explain how to read a Claude Code permission prompt, in plain English, for someone who
has never seen one. **Report only — run nothing, change no files.**

If the user pasted a prompt with the command, explain **that** prompt line by line,
quoting each part. Otherwise, explain the general shape below. Keep it short, and drop
the usual Findings / DECISIONS / Definitions structure; this is a lookup. Still end with
the end-of-turn marker.

## What the prompt is

Claude has stopped before running something, because a setting says it must ask first.
Nothing has happened yet. The only question is whether the thing described is what you
wanted.

## Reading it, top to bottom

- **"Bash command"** (or "Edit file", "Write file", …): the kind of action. "Bash" means
  a command run in the terminal.
- **The first line under it**: Claude's own one-sentence description of what it wants
  to do. **Read this first.** It should name the files or folders involved.
- **The box below**: the exact command that will run. Check that the names in it match
  the description. If the box holds several steps joined by `&&` or `;`, saying Yes
  approves **all** of them, not just the one that triggered the question.
- **"Rule Bash(mv \*) from user settings overrides auto mode"** (or `rm`, `rmdir`,
  `trash`, `git rm`, `git mv`): this means "you set Claude to always ask before deleting
  or moving files, so it is asking". Nothing to do.
- **"/permissions to let auto mode decide"**: a hint from Claude Code about switching
  that rule off. **Ignore it.** Following it lets Claude delete or move files without
  asking.

## The choices

- **1. Yes**: run it, once.
- **2. No**: don't run it. Claude is told you refused and will ask what you want instead.
- **Esc**: same as No.
- **Tab**: add a note to your answer, such as "No — use the other folder".

## The one decision

Does the description match what you asked for, and does the command match the
description? Both yes → **1**. Either no, or you can't tell → **2**, and ask Claude
what it was trying to do.

Note that a prompt can't be explained *while* it is open, because the dialog takes
the keyboard. Answer No (or Esc) first, then type `/explain-permission-prompt`, then
ask Claude to try again.
