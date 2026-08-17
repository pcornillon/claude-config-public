# Install and configure

Eight steps, each one command. The first six are mechanical and take a few minutes;
the last two are the ones that make this yours rather than someone else's.

## 1. Fork this repo

```sh
gh repo fork pcornillon/claude-config-public --clone=false
```

Or press **Fork** on GitHub. Fork rather than clone: step 7 is rewriting
`global/CLAUDE.md` into your own working rules, and those edits need somewhere to be
committed. A fork also gives you the **Sync fork** button when a later version is
published. A plain clone of someone else's repo leaves you unable to push.

## 2. Clone your fork

```sh
git clone https://github.com/<your-github-username>/claude-config-public.git
cd claude-config-public
```

Put it wherever you keep repositories. Nothing here cares where that is — the
install records the path it was run from. Every command below runs from inside that
directory.

## 3. Tell git your name

```sh
git config --global user.name "Your Name"
```

Do this before installing. `global/CLAUDE.md` ships with a placeholder where a name
belongs, and `install.sh` fills it in from `git config user.name`, so the install
asks you nothing. With no git name set it falls back to your Unix login name, which
is probably not what you want written into your own rules. If you get it wrong, edit
the file afterwards — it is yours now.

## 4. Check what is missing

```sh
./check-prereqs.sh
```

It reports in four tiers and installs nothing:

- **Core** — `claude`, `git`, `python3`, `jq`. Nothing works without these.
- **Multi-machine** — a git remote and an ssh key, needed only if you use this
  configuration on more than one computer.
- **claude-switchboard** — Hammerspoon, if you want the session panel.
- **claude-switchboard, fully working** — the Accessibility permission, which macOS will
  not let any script grant.

Each missing item prints what it is for, where to get it, and the command that installs
it.

## 5. Install

```sh
./install.sh
```

It links four things into `~/.claude/`: `settings.json`, `CLAUDE.md`, `skills`,
`commands`. `~/.claude` itself is never a symlink — it also holds machine-local state.
Nothing outside `~/.claude/` is touched.

**If you already have a `~/.claude/`**, two different things happen. An existing
*file* — `settings.json` or `CLAUDE.md` — is copied to `<name>.pre-install.bak` and
replaced with the symlink. An existing *directory* named `skills` or `commands` stops
the install cold, with a message telling you to merge its contents into this repo by
hand and re-run. That is deliberate: deleting a directory of skills you wrote is not
something a script should decide to do.

**Restart `claude`** afterwards. The payload is read at session start, so nothing here
takes effect in a session that is already running.

## 6. Confirm it worked

```sh
./install.sh --check
```

It verifies the four symlinks, that `settings.json` is valid JSON, and that every hook
script it names exists — changing nothing. Run it whenever you want to know whether
this machine is still wired up.

The hooks need a real session to prove themselves. Start a new `claude`, send it one
prompt, let it finish, then:

```sh
ls -R ~/.claude/archive
```

- `usage-log.csv` has gained a row for that session
- `transcripts/<session-id>.md` has appeared — a prose log of the session, rewritten
  in full every turn

Two more, once you are working in a project with a `SESSIONS/` log:

- end a turn without writing its `## P` entry — a "log guard (warn-only)" message
  should name the gap
- exit while still behind and start another session in the same repo — it should open
  knowing about the debt. The breadcrumb is `~/.claude/log-debt.jsonl`, machine-local.

## 7. Make the rules yours — the important step

`global/CLAUDE.md` is a real set of working rules, not a template: it is specific
because specific rules are the only kind anyone follows. Some will fit you, some will
not, and a few will look strange until the second time they save you.

Read it start to finish once. Then delete what does not fit and rewrite the rest.
Suggested order:

1. **How to talk to me** — the tone, the asks, the response structure. Most personal,
   most worth changing first.
2. **The project spine** — the six files and what each is for. Change the names if you
   like, but keep one file that says *where things stand* and one that says *why*.
3. **Session protocol** — how sessions get logged. The heaviest section; if you adopt
   nothing else, adopt the rule that a decision gets written down when it is made.
4. **Conventions** — small and mechanical. Safe to keep as-is.

It applies to every repository on this machine, so a change here is the
highest-leverage edit available to you.

## 8. Start a project

```
/new-project my-project-name
```

It interviews you, copies the template, creates the five spine folders, runs `git init`,
and opens a session log. It deliberately does **not** create a GitHub remote — that is
outward-facing, and it asks first.

## Two machines

Push this repo somewhere private, clone it on the second machine, and run `./install.sh`
there. The configuration travels by git rather than by a sync folder, so you get history
and diffs. `./check-prereqs.sh multi` checks that half.

## Taking a later version

This repo is regenerated from the configuration it was built from, and pushed to the
same branch — so the history is continuous and an update is an ordinary pull:

```sh
cd <where you cloned this>
git pull            # after pressing "Sync fork" on GitHub, if you forked (step 1)
./install.sh        # re-points hook paths and re-fills your name; safe to re-run
```

`CHANGELOG.md` says what each build brought.

Git merges anything you have not touched. **You will get conflicts exactly where you
edited the same lines upstream changed** — most often in `global/CLAUDE.md`, which is
the file you are *encouraged* to rewrite. That is the trade: the file is yours, so
keeping it in step with upstream is a merge, not a download. Two things make it easier:

- **Commit your edits.** A clean tree turns a pull from a mess into a merge.
- **When a conflict is not worth resolving, take yours.** `git checkout --ours
  global/CLAUDE.md`. Upstream's rules are a starting point, not a dependency.

Two files `install.sh` rewrites in place, which will therefore look modified: the hook
paths in `global/settings.json` (repointed at wherever you cloned this) and the owner
name in the markdown. Re-running `./install.sh` after a pull fixes both.

## Where things get written

Session transcripts are written to `${CLAUDE_ARCHIVE_DIR:-~/.claude/archive}` by a hook,
regenerated in full each turn. Set `CLAUDE_ARCHIVE_DIR` if you want them somewhere else —
a synced folder, for instance, so both machines can read them.
