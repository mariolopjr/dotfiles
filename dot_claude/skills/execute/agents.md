# Agent mode

One implementer per task, one reviewer per task, one fix round. Never two
implementers in parallel; they conflict on files. Record
`BASE=$(git rev-parse HEAD)` before each dispatch. After the reviewer, tick
the box and append rulings exactly as in inline mode.

## Implementer

Agent, general-purpose. Smallest model that fits: haiku for a one-file task
with a complete interface, sonnet for multi-file work, the session model
when the task needs design judgment.

> Implement Task N from `<plan path>`; read only that task and the
> Constraints section. Spec for context: `<spec path>`. Earlier tasks
> produced: <interfaces this task consumes>.
>
> Failing test first where behavior changes, then the implementation, then
> the task's check. Commit when it passes. Do not spawn subagents. Reply in
> under 15 lines: status DONE, DONE_WITH_CONCERNS, or BLOCKED; commits;
> one-line test result; concerns.

BLOCKED: add context, use a stronger model, or split the task. Never resend
the same prompt unchanged.

## Reviewer

Agent, general-purpose, same or stronger model than the implementer.

> Review `git diff BASE..HEAD` against Task N in `<plan path>` and the
> Constraints section. The implementer's report is a claim, not evidence;
> judge the code. Read only what the diff touches plus call sites of any
> changed signature. Read-only.
>
> Reply with: spec compliance PASS or FAIL with the gap; then findings
> ranked, each with file, line, the defect, and the concrete failure. Skip
> style.

FAIL or a real defect: resume the implementer with the findings verbatim,
one round. Still open after that: rule on each finding under the task in
the plan file and move on. Minor findings go under the task as deferred;
`/review-gauntlet` triages them at the end.
