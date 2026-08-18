# Install and configure

Every command, in the order you type it. Each step says in a line or two what it does,
then gives the command, then shows what you should see. Steps 1-6 install this; step 7
is the one that makes it yours.

**1. Fork this repo.** Fork rather than clone: step 7 rewrites `global/CLAUDE.md` into
your own working rules, and you cannot push those edits to someone else's repo. A fork
also gives you the **Sync fork** button when a newer version is published.

```sh
gh repo fork pcornillon/claude-config-public --clone=false
```

Or press **Fork** on GitHub. Either way you now own
`https://github.com/<your-github-username>/claude-config-public`.

**2. Clone your fork**, wherever you keep repositories. Nothing here cares where that
is. Every command below runs from inside the clone.

```sh
cd ~/Git_Repos
git clone https://github.com/<your-github-username>/claude-config-public.git
cd claude-config-public
```

**3. Tell git your name**, before installing. `global/CLAUDE.md` ships with a
placeholder where a name belongs and `install.sh` fills it in from git. With no name
set it falls back to your Unix login name, which is probably not what you want written
into your own rules.

```sh
git config --global user.name "Your Name"
git config user.name                          # check it took
```

**4. See what is missing.** This installs nothing. It reports in four tiers, and each
missing item prints what it is for and the command that installs it.

```sh
./check-prereqs.sh
```

The last line you want is:

```
Core is complete.
```

Core is `claude`, `git`, `python3` and `jq`; nothing works without them. The other
three tiers are optional — a git remote and an ssh key if you work on two machines,
and two tiers for `claude-switchboard`, a session panel that is a separate repo.

**5. Install.**

```sh
./install.sh
```

It links four things into `~/.claude/` and prints a line for each:

```
OK   global/settings.json is valid JSON
OK   every hook script in settings.json exists
LINK settings.json -> global/settings.json
LINK CLAUDE.md -> global/CLAUDE.md
LINK skills -> global/skills
LINK commands -> global/commands

Linked.
```

`~/.claude` itself is never a symlink — it also holds machine-local state — and
nothing outside `~/.claude/` is touched.

**If you already had a `~/.claude/`**, two different things happen. An existing *file*
named `settings.json` or `CLAUDE.md` is copied to `<name>.pre-install.bak` and then
replaced. An existing *directory* named `skills` or `commands` stops the install
instead:

```
STOP <your home>/.claude/skills is a real directory, not a symlink.
     Merge its contents into <repo>/global/skills by hand, then re-run.
```

Deleting a directory of skills you wrote is not a decision a script should make. Move
them into `global/skills/` yourself and run `./install.sh` again.

**6. Restart `claude`, then confirm.** Hook configuration is read when a session
starts, so none of this reaches a session that is already open. Quit `claude`, start
it again, and run:

```sh
./install.sh --check
```

It changes nothing and ends with:

```
check: this machine is fully linked to /path/to/your/claude-config-public
```

That covers the links. The hooks need one real session to prove themselves. In
`claude`, send any prompt, let it answer, quit, then:

```sh
ls -R ~/.claude/archive
```

Two things should be there:

```
usage-log.csv          one row per session, with its token counts
transcripts/<id>.md    a prose log of the session, rewritten every turn
```

If `~/.claude/archive` does not exist at all, no hook has run — nearly always because
the session you used was already open before you installed.

**7. Make the rules yours.** The important step, and `TASKS.md` Task #1.
`global/CLAUDE.md` is a real set of working rules rather than a template: it is
specific because specific rules are the only kind anyone follows. Some will fit you,
some will not, and a few will look strange until the second time they save you.

Read it start to finish once, then delete what does not fit and rewrite the rest. A
useful order:

1. **How to talk to me** — tone, questions, response structure. Most personal, most
   worth changing first.
2. **The project spine** — the six files and what each is for. Rename them if you
   like, but keep one file that says *where things stand* and one that says *why*.
3. **Session protocol** — how sessions get logged. The heaviest section; if you adopt
   nothing else, adopt the rule that a decision gets written down when it is made.
4. **Conventions** — small and mechanical. Safe to keep as-is.

It applies to every repository on this machine, so this is the highest-leverage edit
available to you. Commit it when you are done: a clean tree makes the next update a
merge instead of a mess.

**8. Start your first project.** Type this inside `claude`, not in the shell:

```
/new-project my-project-name
```

It interviews you, copies the template, creates the five spine folders, runs
`git init`, and opens a session log. It deliberately does **not** create a GitHub
remote — that is outward-facing, so it asks first.

## Updating to a later version

New builds are pushed to the same branch, so an update is an ordinary `git pull`. One
thing makes it less ordinary than it sounds, and it has a fixed answer.

**`install.sh` rewrites files inside the repo.** It fills your name into
`global/CLAUDE.md`, `global/commands/*.md` and the project template, and it repoints
the hook paths in `global/settings.json` at wherever you cloned this. So `git status`
shows those as modified even if you have never edited anything yourself, and `git
pull` refuses to run whenever a new build touches one of them:

```
error: Your local changes to the following files would be overwritten by merge:
	global/CLAUDE.md
Please commit your changes or stash them before you merge.
Aborting
```

If you have **not** edited anything yourself, throw those rewrites away and let
`install.sh` redo them:

```sh
cd <your clone>
git checkout -- .
git pull
./install.sh
```

If you **have** rewritten `global/CLAUDE.md`, which is the whole point of step 7,
commit it first and merge:

```sh
cd <your clone>
git add -A
git commit -m "my rules"
git config pull.rebase false     # once per clone; git will not merge without this
git pull
./install.sh
```

A conflict there means the new build changed lines you had also changed. Yours is
almost always the version to keep:

```sh
git checkout --ours global/CLAUDE.md
git add global/CLAUDE.md
git commit
./install.sh
```

Upstream's rules are a starting point, not a dependency. If you forked in step 1,
press **Sync fork** on GitHub before pulling. `CHANGELOG.md` says what each build
brought.

## Two machines

Clone your fork on the second machine and run `./install.sh` there. The configuration
travels by git rather than by a sync folder, so you get history and diffs.
`./check-prereqs.sh multi` checks that half.

## Where things get written

Session transcripts go to `${CLAUDE_ARCHIVE_DIR:-~/.claude/archive}`, written by a
hook and regenerated in full each turn. Set `CLAUDE_ARCHIVE_DIR` to put them somewhere
else — a synced folder, for instance, so both machines can read them.
