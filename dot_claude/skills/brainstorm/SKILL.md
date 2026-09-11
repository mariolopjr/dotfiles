---
name: brainstorm
description: Turn an idea into an agreed design before any code. Ends with a design in chat or a spec file, never with implementation.
argument-hint: <idea or feature>
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash(git:*), Bash(ls:*), Write, AskUserQuestion
---

Design first: `$ARGUMENTS`

Read the code the change would touch before asking anything. Recent
commits and existing patterns answer most questions; the rest go to the
user. Ask only what changes the design, group questions that are
independent of each other, and lead with your recommended answer where you
have one.

Scale the artifact to the change. A change to a flow that already exists in
the repo gets a short design in chat: approach, files touched, how it is
tested. Stop there and wait for a yes. A change that adds a subsystem,
restructures how components fit, or alters an interface others depend on
gets a spec file, and `/plan` comes next.

Offer alternatives only where a real trade-off exists, recommendation
first. Cut speculative scope from every option. If the idea spans several
independent subsystems, say so before refining details and split it; each
piece gets its own spec.

## Spec

Write to `docs/specs/YYYY-MM-DD-<topic>.md`. Prefer references to prose:
name the files and functions involved, write interfaces as signatures,
state test cases as assertions. Cover:

- Goal and non-goals
- Design: components, interfaces, data flow
- Error handling
- Testing: what is covered and how
- Constraints: versions, naming, platform rules, exact values

Resolve every open question before saving; a spec with a TBD is not done.
Tell the user the path and stop. Implementation starts with
`/plan <spec>`, not here.
