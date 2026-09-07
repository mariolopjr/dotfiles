---
description: Four decorrelated review passes over one diff (built-in code review, requirements alignment, over-engineering, adversarial), merged into one numbered P0/P1/P2 report
argument-hint: '[--base <ref>] [--passes 1,2,3,4 | --no-ponytail] [focus text]'
disable-model-invocation: true
allowed-tools: Agent, Skill, Read, Glob, Grep, TaskOutput, TaskStop, ReportFindings, Bash(git:*), Bash(node:*), Bash(ls:*)
---

Run four independent read-only reviews of the same diff and merge them into
one numbered report. Report-only: do not fix anything, do not touch the
working tree, do not offer to start fixing.

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
- Passes are numbered 1 `code-review`, 2 `requirements`, 3 `ponytail`,
  4 `adversarial`. Default is all four.
- `--passes <list>` runs only the listed passes.
- `--no-ponytail` is shorthand for `--passes 1,2,4` — the round 2 default,
  and the only exclusion with a standing reason. Anything else, spell out
  `--passes`.
- Any text left after the flags is the user's focus. Pass it to the selected
  passes verbatim; never rewrite it.

## 2. Fire all four passes in one message

They are independent read-only passes over the same range, so they run
concurrently. "Adversarial last" is honored in the report, not the clock.

Each pass asks a **different question**. If you find yourself giving two
passes the same charter, the second one is wasted spend — keep them apart.

**Pass 1 — "is this code wrong?"** (`Agent`, `general-purpose`,
`model: "opus"`, `name: "rg-code-review"`):

> Invoke the `code-review` skill at effort `high` against `<RANGE>`, with
> focus: `<FOCUS>`. Do NOT pass `--fix` or `--comment` — this is report-only.
>
> Return its findings to me as text: file, line, severity, the defect, and
> the concrete failure scenario. Include each finding's CONFIRMED/PLAUSIBLE
> verdict if the skill's verify pass assigned one. Do not drop the
> PLAUSIBLE ones; I need them for corroboration scoring.

**Pass 2 — "is this the thing we agreed to build?"** (`Agent`,
`general-purpose`, `model: "opus"`, `name: "rg-requirements"`):

> Review the diff at `<RANGE>` against its **stated requirements** — the plan
> file, task text, issue, or commit messages in range. User focus: `<FOCUS>`.
> Find the requirements yourself; check `docs/superpowers/plans/`,
> `docs/superpowers/specs/`, and the commit bodies.
>
> Another reviewer is already scanning these lines for bugs. Do not duplicate
> that. Your charter is alignment and completeness:
> - Is any planned functionality missing or silently stubbed?
> - Are deviations from the plan justified improvements, or drift?
> - Do the tests verify real behavior, or assert against mocks?
> - Migration path, backward compatibility, and rollback if state or schema
>   changed.
> - Is the problem with the *plan* rather than the implementation? Say so.
>
> Read-only. Do not mutate the working tree, the index, HEAD, or branch
> state. Inspect with `git show` / `git diff` / `git log`. If you need
> another revision checked out, use `git worktree add` into a temp dir.
> Do all of this yourself — never spawn a subagent; three other reviewers are
> already on this diff and a seat you create counts for nothing.
>
> Every finding needs `file:line` and a concrete consequence.
> Severity: P0 blocks merge. P1 fix before release. P2 note only.
> Lead with what the change genuinely gets right, briefly.

**Pass 3 — "what can be deleted?"** (`Agent`, `general-purpose`,
`model: "sonnet"`, `name: "rg-ponytail"`):

> Review the diff at `<RANGE>` for over-engineering only. User focus:
> `<FOCUS>`. Read-only, and do all of it yourself — do not spawn subagents.
>
> Invoke the `ponytail-review` skill and follow it exactly: one line
> per finding, `<file>:L<line>: <tag> <what>. <replacement>.` with tags
> `delete:` / `stdlib:` / `native:` / `yagni:` / `shrink:`, ending with
> `net: -<N> lines possible.` — or `Lean already. Ship.` if there is nothing
> to cut.
>
> Correctness bugs, security, and performance are out of scope here; two
> other reviewers own them. Never flag a single smoke test or `assert`-based
> self-check as bloat.
>
> Then map each finding to a severity: P2 by default. P1 only for a whole
> speculative subsystem or an added dependency that the stdlib already
> covers. Never P0 — nothing here blocks a merge.

**Pass 4 — "why shouldn't this ship?"** (`Bash`, `run_in_background: true`):

```bash
node "$(ls -d ~/.claude/plugins/cache/openai-codex/codex/*/scripts/codex-companion.mjs | sort -V | tail -1)" adversarial-review [--base <ref>] "The sandbox is read-only: build tools cannot write their output directories, so do not run builds, tests, or linters. Review by reading the diff, and never raise a build or test failure you could not actually run as a finding." <FOCUS>
```

A different model family is the entire point of this pass — never substitute
a Claude subagent for it. It takes no `--model`; pin one in
`~/.codex/config.toml` if you want. Do not paraphrase its findings when
merging — carry the file, lines, and recommendation across intact.

The read-only note is not optional decoration. The plugin hardcodes
`sandbox: "read-only"` when it starts the thread (`codex-companion.mjs`,
`executeReviewRun`), and an explicit thread parameter beats `sandbox_mode` in
`~/.codex/config.toml`, so no config or CLI flag makes this pass able to
build. Without the note codex spends a turn discovering that and then reports
"tests unverified" as if it were a property of the change. Passes 1 and 2 run
the build and the suite; this one reads.

## 3. Merge

Wait for all four. Then emit ONE list, flat-numbered `[1]`, `[2]`, `[3]`…
in a single index space, ordered P0 first, then P1, then P2. One index space
so the user can say "fix 1, 4, 9" without ambiguity.

Merge rules, in order:

1. **Dedupe by `file:line`.** Same location from several passes is one entry
   at the highest severity any pass gave it, tagged with every source.
2. **Corroboration orders each tier.** A defect two or three passes found
   independently outranks one a single pass found — passes 1, 2 and 4 have
   different charters and different models, so agreement is real signal.
   Mark it `×2` / `×3` and sort it first within its tier. Corroboration
   never *promotes* a finding across tiers; it only breaks ties inside one.
3. **Safety outranks brevity.** A Pass 3 `delete:` or `shrink:` on lines that
   pass 1, 2 or 4 flagged for validation, error handling, security, or
   accessibility is dropped, not merged. Note the drop under Deferred.
4. **Codex `high` maps to P0, `medium` to P1, `low` to P2** — unless pass 1
   or 2 contradicts it with evidence, in which case take theirs and say why
   in the entry.
5. **Drop anything with no `file:line`.** Every pass was told to ground its
   findings; an ungrounded one did not follow instructions.

**Then close the panes.** Every pass is one-shot: nothing here messages a
pass again after the merge, and `/review-fix` spawns its own agents. Once the
merged report is written, `TaskStop` each named teammate that ran —
`rg-code-review`, `rg-requirements`, `rg-ponytail` — to close its tmux pane.
Only after the report is written; never stop a pass whose output you have not
read. Pass 4 is a background Bash task, not a teammate — leave it alone.

## 4. Output

```
## Verdict: BLOCK | OK with notes | OK
<one sentence, ship/no-ship, no hedging>

### P0 — blocks merge
[1] <file>:<line> · <sources, ×N if corroborated> · <what breaks, and the concrete failure scenario>
    Fix: <one line>

### P1 — fix before release
[2] ...

### P2 — noted
[3] ...

### Strengths
<2-3 lines, specific, from pass 2>

### Deferred
<pass 3 findings dropped by rule 3, one line each>

net: -<N> lines possible (pass 3)

### Next
Fix: /review-fix <indices | all-p0>   (batches, verifies, decides on round 2)
Re-check: /review-gauntlet --base <git merge-base HEAD main> --no-ponytail   (after the fixes land)
```

`BLOCK` if any P0. `OK with notes` if any P1. `OK` otherwise.

Omit `net:` when pass 3 was not among the selected passes.

If a tier holds more than about three P0s, say so in the verdict sentence
before listing them. Four independent passes agreeing that a change is
blocked ten different ways is a statement about the design, not a to-do
list — patching each spot leaves the design that produced them intact.

## No internal fix loop

A second round only means something if the diff changed between rounds, and
this command changes nothing — round two would re-review identical bytes and
re-emit identical findings. The second round is the `Re-check` line: fix the
P0s, then re-run at the merge base of the branch and its integration branch,
the same base round 1 used, so the passes see the whole body of work with the
fixes folded in. A pre-fix base shows the guards and tests without the code
they guard. Pass the SHA from `git merge-base HEAD main`, not `--base main`:
step 1's three-dot range resolves the merge base itself, but pass 4 shells out
to codex on a two-dot `git diff <base>`, where a `main` that moved ahead reads
as spurious deletions.

<!-- ponytail: no internal review->fix->review loop; report-only makes round 2
     a no-op. If this command ever applies fixes, add the loop then, capped at
     2 rounds, re-running only the pass that raised the P0. -->
