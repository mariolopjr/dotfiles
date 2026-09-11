---
description: Apply selected findings from a /review-gauntlet report in batches, verify each landed, and decide whether round 2 is required
argument-hint: '<indices | all-p0 | all-p1 | all> [--no-commit]'
disable-model-invocation: true
allowed-tools: Agent, SendMessage, TaskStop, Read, Edit, Write, Glob, Grep, Bash(git:*), Bash(ls:*)
---

Apply findings from the most recent `/review-gauntlet` report in this
conversation, then decide — by rule, not by vibe — whether a round 2 review
is required.

Raw arguments: `$ARGUMENTS`

If there is no `/review-gauntlet` report in context, stop and say so. Do not
re-derive findings yourself; this command fixes a report, it does not
produce one.

**Count the prior `/review-fix` runs in this conversation.** A round is one
`/review-gauntlet` plus one `/review-fix`, and the cap is two:

```
/review-gauntlet -> /review-fix -> /review-gauntlet --passes -> /review-fix -> stop
```

Each report carries its own flat index, so `[1]` in round 2 is a different
finding from `[1]` in round 1. Always name the round when referring to one.

On the **second** run, fix as normal but never print a round-3 command.
If P0s survive two full rounds, the change needs redesign rather than a
third pass of patches — say that instead.

## 1. Select

Parse `$ARGUMENTS` against the report's flat index:

- `1,3,7` and `1-10` and mixtures of both
- `all-p0`, `all-p1`, `all`
- empty → `all-p0`

Echo the selection back as a numbered list before touching anything, so a
mis-parsed range gets caught before it becomes commits.

**Triage the P0s first.** For each selected P0, state in one line whether it
genuinely blocks merge. Findings from pass 4 carry the highest false-positive
rate — the adversarial prompt is written to break confidence in the change,
so it emits findings by construction. Anything you judge non-blocking, say so
and drop it to P1 with a reason. Ask before proceeding if the selection
shrinks by more than half.

## 2. Capture the baseline

Round 2 needs to diff against the state that was reviewed, which is usually
uncommitted:

```bash
git rev-parse HEAD
git stash create   # empty when the tree is clean
```

`git stash create` writes the dirty tree to a dangling commit and changes
nothing — no stash entry, no index or worktree mutation. Use its SHA as the
baseline. When it prints nothing the tree is clean, so the baseline is HEAD.

Record the baseline SHA. Every later step refers to it.

## 3. Fix in batches

Group the selection by file and subsystem, then fix one group at a time.
Not one commit per finding: interacting fixes reviewed in isolation are
exactly the ones that break each other, and N separate review cycles cost N
times as much.

Per batch:
- Apply the fixes.
- Run the smallest relevant validation for what you touched.
- Commit, unless `--no-commit`. Subject names the indices:
  `fix: review findings 1, 4, 9 — <subsystem>`.

Stay inside the blast radius. A finding at `foo.rs:120` authorizes fixing
that defect, not refactoring `foo.rs`. If a fix genuinely needs to reach
further, say so in the batch's report line rather than widening quietly.

If a finding turns out to be wrong once you are in the code, do not fix it.
Record it as `rejected` with the technical reason.

## 4. Bookkeeping pass

Dispatch one `Agent` (`general-purpose`, `model: "haiku"`,
`name: "rf-bookkeeping"`) with the selected indices, each one's
`file:line`, and the baseline SHA:

> For each finding below, report exactly one of:
> `addressed` (the named file:line is inside `git diff <BASELINE>`),
> `untouched` (it is not), or `outside-radius` (the file was changed but not
> at or near the named lines).
>
> Then list every file in `git diff --name-only <BASELINE>` that no finding
> named, and report whether `git diff <BASELINE> --stat` matches the batch
> commit subjects.
>
> This is a mechanical bookkeeping check. Do NOT judge whether any fix is
> correct, sufficient, or safe — you are checking that edits landed where
> they were claimed, nothing more. Never write `looks good`.
>
> Write your full report to `<OUT>` in ONE Write call, whose last line is
> exactly `--- END OF REPORT ---`. Then reply to me with three lines and
> nothing else: the counts of `addressed`, `untouched` and `outside-radius`,
> how many findings you checked, and that path. Do not paste the report into
> your reply.

Name `<OUT>` yourself before dispatching — `<scratchpad>/rf-bookkeeping.md` —
and hand it over verbatim. A teammate's closing message is relayed through a
channel that silently truncates a long report, and a truncated bookkeeping
report is the worst one to lose: an `untouched` finding that never arrives
reads as a fix that landed. Read the file, check the sentinel, and check the
count against your selection. Anything missing, `SendMessage` the pass for the
rest before you stop it. Never accept the three-line reply as the report.

Haiku is scoped to bookkeeping on purpose. Judging whether a fix actually
closes a hole takes the capability that found it; a light model asked that
question rubber-stamps, and a rubber stamp is worse than no check because it
gets trusted. That judgment is round 2's job.

Any `untouched` finding that was not recorded `rejected` in step 3 is a
silently skipped fix. Surface it loudly.

**Then close the pane.** Once its report is read and whole, `TaskStop`
`rf-bookkeeping` to close its tmux pane. Round 2 spawns its own agents, so
nothing here needs it again — but a pass you stop can no longer be asked for a
missing tail, so read the file first.

## 5. Decide on round 2 — by rule

Evaluate in order; the first match wins. No model judgment here.

1. Any **P0** was fixed → **round 2 required.** P0 fixes touch the most
   fragile code in the diff, which is where a fix-induced bug lives.
2. Bookkeeping reported any **`outside-radius`** or unexplained changed file
   → **round 2 required.** Scope creep during fixing is its own bug source.
3. Only **P1/P2** were fixed, all inside radius → **no round 2.**

On the second `/review-fix`, rules 1 and 2 still evaluate, but a match
resolves to **REDESIGN**, not another review. Report which findings survived
two rounds and stop.

Passes to re-run: the ones that raised the fixed P0s, plus pass 1. **Never
pass 3.** Fixes add guards and error handling; ponytail is built to flag
added code as cuttable, so re-running it oscillates between deleting and
re-adding the same guard. Merge rule 3 already protected those lines in
round 1.

## 6. Report

```
## Fixed
[1] <file>:<line> — <what changed>  (commit <sha>)
...

## Rejected
[4] <why it was not a real finding>

## Skipped
[7] untouched, not rejected — needs attention

## Bookkeeping
<addressed N · untouched N · outside-radius N>
<unexplained files, if any>

## Round 2: REQUIRED (rule <n>) | NOT REQUIRED (rule 3)
/review-gauntlet --base <BASELINE> --no-ponytail
```

Use `--no-ponytail` when the passes to re-run are 1, 2 and 4. Spell out
`--passes` only when round 2 is narrower than that.

Print the round 2 command; do not run it. It is another four-model review —
worth one keystroke of confirmation before spending it.

<!-- ponytail: baseline is a dangling `git stash create` object, so it is
     GC-able across sessions. Fine for a fix-then-recheck loop inside one
     session; commit the reviewed state first if you need it to survive. -->
