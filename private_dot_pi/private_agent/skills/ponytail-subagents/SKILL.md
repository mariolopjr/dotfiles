---
name: ponytail-subagents
description: Orchestrate coding work with pi-subagents while applying Ponytail minimalism to parent planning and every implementation child. Use when delegating a multi-task coding change without over-engineering.
---

# Ponytail Subagents

Load `pi-subagents` and `ponytail` before orchestrating. Parent remains
orchestrator and final decision-maker.

## Parent

Apply Ponytail ladder before dispatching:

1. Skip speculative work or solve trivial work directly.
2. Reuse existing code, standard library, native features, or installed
   dependencies before proposing new code or a child task.
3. Delegate only when a child adds independent evidence, isolated execution,
   or materially faster progress.
4. Build dependency graph from actual code seams. Run only independent
   read/review work in parallel. Keep dependent work serial.
5. Keep one writer per cwd. Use managed worktrees only for intentionally
   independent writers.

For a task list with dependencies, do not create one agent per item by default.
Dispatch a scout only when code context is missing, then group dependent small
changes into one narrow worker handoff. Use `runs.lanes` only for known,
independent chains with multiple stages.

## Children

Every implementation child must receive `skill: "ponytail"` explicitly. Builtin
agents do not inherit parent skills by default. Give each worker a narrow,
complete contract: approved scope, source seam, constraints, validation, and
stop rules.

Ask each Ponytail worker to trace relevant callers before editing, choose the
highest applicable Ponytail ladder rung, make the smallest root-cause change,
and preserve requested validation, security, error handling, accessibility, and
explicit requirements.

Do not give `ponytail` to a scout merely for ritual. For an over-engineering
reviewer, use `skill: "ponytail-review"`; retain normal correctness and
validation reviewers when needed.

## Verification

Use smallest focused check that can fail for each non-trivial changed behavior.
After a worker changes code, inspect actual diff, accept only evidence-backed
review findings, and do not loop for optional polish.

Report task grouping, dependency order, delegated workers, validation, and any
intentionally deferred work concisely.
