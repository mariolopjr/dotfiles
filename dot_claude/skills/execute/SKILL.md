---
name: execute
description: Implement a plan task by task, ticking each off in the plan file as it lands.
argument-hint: <plan path> [--agents]
disable-model-invocation: true
---

Plan: `$ARGUMENTS`

Read the plan and the spec it names. The spec is the authority, the plan is
its argument; conflicts resolve toward the spec. On main or master, create
a branch first. Use a worktree when the working tree is dirty or the user
asks for one.

Checked boxes and `git log` are the progress record. Resume at the first
unchecked task and never redo a checked one. Context can be compacted
mid-run; the plan file is what survives it.

Per task:

1. Failing test where behavior changes, then the implementation. Ponytail
   governs the diff.
2. Run the task's check. It passes or the task is not done.
3. Commit, tick the box, append any ruling under the task.

Rule, don't stall. An ambiguity, a plan defect, or a conflict between tasks
gets a one-line ruling under the task in the plan file: what you decided,
why, what it costs if wrong. Then keep going. Stop only for an irreversible
or outward-facing action (merge, push to a shared branch, publish, delete)
or a plan so broken that every path is a guess.

No check-ins between tasks. When every box is ticked, run the full suite,
list the rulings you made, and name `/review-gauntlet` as the next step.

## --agents

Read `agents.md` in this skill's directory and dispatch per task instead of
implementing inline.
