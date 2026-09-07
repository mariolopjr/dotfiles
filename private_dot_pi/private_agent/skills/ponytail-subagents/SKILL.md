---
name: ponytail-subagents
description: Orchestrate coding work with @gotgenes/pi-subagents while applying Ponytail minimalism to parent planning and every implementation child. Use when delegating a multi-task coding change without over-engineering.
---

# Ponytail Subagents

Use `@gotgenes/pi-subagents` and `ponytail`. Parent remains orchestrator and
final decision-maker.

## Parent

Apply Ponytail ladder before dispatching:

1. Skip speculative work or solve trivial work directly.
2. Reuse existing code, standard library, native features, or installed
   dependencies before proposing new code or a child task.
3. Delegate only when a child adds independent evidence, isolated execution,
   or materially faster progress.
4. Build dependency graph from actual code seams. Run only independent
   read/review work in parallel. Keep dependent work serial.
5. Keep one writer per cwd. Use `@gotgenes/pi-subagents-worktrees` only when
   installed and configured for intentionally independent writers; otherwise
   keep writers serial.

For a task list with dependencies, do not create one agent per item by default.
Dispatch a scout only when code context is missing, then group dependent small
changes into one narrow worker handoff.

## Children

Child sessions inherit parent skills and extensions by default. `skill` spawn
arguments and `skills` agent frontmatter are unsupported. Give each worker a
narrow, complete contract: approved scope, source seam, Ponytail constraints,
validation, and stop rules.

Ask each Ponytail worker to trace relevant callers before editing, choose the
highest applicable Ponytail ladder rung, make the smallest root-cause change,
and preserve requested validation, security, error handling, accessibility, and
explicit requirements.

Do not give Ponytail instructions to a scout merely for ritual. For an
over-engineering reviewer, explicitly request Ponytail review; retain normal
correctness and validation reviewers when needed.

## Verification

Use smallest focused check that can fail for each non-trivial changed behavior.
After a worker changes code, inspect actual diff, accept only evidence-backed
review findings, and do not loop for optional polish.

Report task grouping, dependency order, delegated workers, validation, and any
intentionally deferred work concisely.
