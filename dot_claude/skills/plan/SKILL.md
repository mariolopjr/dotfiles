---
name: plan
description: Turn an approved spec into an ordered task list that /execute works through and ticks off.
argument-hint: <spec path>
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash(git:*), Bash(ls:*), Write
---

Spec: `$ARGUMENTS`

Read the spec and the code it names. Decide file structure first: what is
created, what is modified, one responsibility per file, following the
repo's existing layout. Task boundaries follow from that.

A task is the smallest unit with its own check that a reviewer could reject
on its own. Fold setup, config, and docs into the task that needs them.
Order tasks so each leaves the codebase working.

The executor is a capable engineer with the spec open. Do not write its
code; write what it cannot infer. Each task carries:

- Files created or modified
- Interface it produces, and what it consumes from earlier tasks, as signatures
- Check: the test or command that proves the task, and what it should show
- Decisions the spec leaves open, resolved here

Write to `docs/plans/YYYY-MM-DD-<topic>.md`:

```markdown
# <Feature> plan

Spec: <path>

## Constraints

<the spec's constraints, copied verbatim>

## Tasks

- [ ] Task 1: <name>
  Files:
  Interface:
  Check:
```

Before saving, walk the spec once: every requirement points to a task, and
names used across tasks match. Fix inline. Tell the user the path and
stop; `/execute <plan>` comes next.
