---
description: Flag the changes that need manual judgment, ranked and capped, as a numbered list to answer inline
argument-hint: '[--base <ref>] [focus text]'
disable-model-invocation: true
allowed-tools: Agent, Read, Glob, Grep, Bash(git:*), Bash(jq:*), Bash(find:*)
---

Surface the small subset of this session's changes that encode a **decision**
the user might make differently, and present them as a numbered list to be
answered by number.

This is not a correctness pass. `/review-gauntlet` finds defects; run it first.
Everything flagged here is flagged because a choice is embedded in it, not
because the code looks wrong.

Raw arguments: `$ARGUMENTS`

## 1. Resolve the range

```bash
git rev-parse HEAD
git status --short --untracked-files=all
git diff --shortstat
```

- `--base <ref>` present: range is `<ref>...HEAD`.
- Otherwise: working tree vs `HEAD`.
- Untracked files count as reviewable work. Only declare "nothing to review"
  when the scope is genuinely empty.
- Any text left after the flags is the user's focus. Pass it verbatim.

Locate the transcript by its unique filename rather than deriving the project
slug — the slug replaces `.` as well as `/`, which is avoidable error surface:

```bash
find ~/.claude/projects -maxdepth 2 -name "$CLAUDE_CODE_SESSION_ID.jsonl"
```

## 2. One analysis pass

One `Agent` (`general-purpose`, `model: "opus"`, `name: "rh-flag"`). One agent,
not four: `/review-gauntlet` decorrelates because different charters find
different *defects*, but this is routing, not finding. The four qualifiers below
land on overlapping hunks, so parallel passes would mostly produce duplicates
and then need a merge step to undo them. The subagent exists to keep a 300KB
transcript out of the main context window, not for parallelism.

Give it the transcript path, the range, and the focus text. Its charter:

> Read the diff at `<RANGE>` and the session transcript at `<TRANSCRIPT>`.
> Filter the transcript with
> `jq -c 'select(.type == "assistant" or .type == "user")'` first — `attachment`
> lines are most of the bytes and none of the reasoning.
>
> You are not looking for bugs. You are looking for lines where **the code is
> internally consistent either way** and only the user can say which is right.
> Four classes:
>
> - `decision` — a defensible approach chosen over another defensible one, a
>   spec gap filled without asking, a deviation from an agreed plan, or a
>   `ponytail:` corner cut. **You must name the rejected alternative.** Without
>   it there is no decision to rule on and the flag is worthless.
> - `impact` — auth, credentials, money, destructive operations, migrations,
>   anything with a rollback story. Flagged because being wrong is expensive.
> - `unverified` — a non-trivial branch, parser, or loop with no test exercising
>   it, or a check that was skipped, stubbed, or could not run.
> - `taste` — naming, API shape, file boundaries, whether an abstraction earns
>   its place. No correct answer; only the user's preference.
>
> Rank by one question: *would a different answer change the code?*
> `decision > impact > unverified > taste`. **Hard cap of 7** in the main list;
> the rest go to a one-line `Also touched` appendix. Seven is a number that
> gets read; twenty gets scrolled past.
>
> Every flag needs a repo-relative `file:line`. Return the list in the exact
> format below and nothing else.

If the transcript is missing or unreadable, run the pass on the diff alone and
say so above the list. Degraded output beats no output, but a diff-only run
must be marked as one — `decision` is the class that needs the transcript, so
its absence means something different when the transcript could not be read.

If nothing qualifies, say so and stop.

## 3. Print the list

Numbered from 1, most important first — the ranking above *is* the order, so
`[1]` is always the flag most likely to change the code.

```
Nothing here is a bug. Each one is a fork where the code works either way.

1. decision · src/net/retry.rs:120
   Chose retry with backoff, 3 attempts, over fail fast and let the caller retry.
   The caller already holds a timeout, so retrying here stays bounded. ~4 lines to switch.

2. impact · migrations/003_add_billing.sql:12
   Drops and recreates the index with no rollback written.
   A down-migration is ~15 lines.

3. taste · src/util/fmt.rs:8
   Named it `render` to match the trait; `format` reads better but shadows std.

Also touched: src/lib.rs (re-export), src/util/fmt.rs (formatting only)

Reply with the numbers you want changed — "3. call it format, shadowing is fine".
Anything you don't mention, I'll take as accepted.
```

Two or three lines per flag. Enough to rule on without opening the file, not so
much that seven of them stop being readable — the user will ask for detail on
the ones that need it.

Keep it plain text. No table: the reasons do not fit in cells, and a table is
harder to quote a single row out of.

Then stop. Do not fix anything and do not offer to.

## 4. Acting on the reply

**Silence is approval.** A number the user did not mention is settled — do not
re-raise it, do not ask again. The list was read; that is the ruling. Only ask
about a number if the reply is genuinely ambiguous about *which* number it
refers to.

For each number the user does answer:

- **Stay inside the blast radius.** A note on `[1]` authorizes changing that
  decision, not refactoring the file it lives in. If a note asks for something
  the surrounding code cannot support, say so rather than half-applying it.
- Group the edits by file.
- Run the smallest relevant validation for what you touched, and report the
  command and what it printed.
- Then say, per number, what changed — or what you left alone and why.

If the user answers again after that, it is a new round over the same list:
same rules, same numbering. The numbers stay stable for the life of the list.
