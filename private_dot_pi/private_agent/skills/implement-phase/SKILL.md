---
name: implement-phase
description: Orchestrate implementation of a named phase, task, or task list into one new branch from main. Use with `/skill:implement-phase <scope>` or when user asks to break down and parallelize implementation work.
---

# Implement Phase

Load `ponytail-subagents`, `pi-subagents`, and `ponytail` before dispatching.
Parent remains orchestrator and final decision-maker.

## Input

Arguments following `/skill:implement-phase` are scope. They may be a phase name,
a task, or task list, including `@path` references.

If scope is absent, ask only: `What phase, task, or task list should I implement?`
Do not inspect, branch, or dispatch until user answers. Otherwise, use supplied scope
as-is. Do not require a slug from user.

## Branch

Derive lowercase kebab-case slug from scope's concrete intent. Keep useful phase
identifiers, such as `P2.1` becoming `p2-1`; use 2 to 5 meaningful words, such as
`agent/p2-1-empire-species`. Check existing refs and append `-2`, `-3`, and so on if
needed.

Create exactly one integration branch from `main`: `agent/<derived-slug>`. Preserve
unrelated working-tree changes. Use a dedicated integration worktree when current
worktree is dirty. This is only final branch.

Independent write lanes use separate worktrees and temporary branches. Each worker
commits only its owned changes. Parent reviews and cherry-picks accepted commits onto
integration branch in dependency order. Never allow concurrent writers on same files
or a dependency chain.

## Execution

1. Read named references and trace relevant code and callers. Build a small dependency
   graph with explicit file ownership.
2. Make direct trivial changes. For remaining work, group dependent small changes into
   narrow handoffs and parallelize only independent lanes.
3. Route a worker to `openai-codex/gpt-5.6-luna:xhigh` only when task is one small,
   fully specified change with a bounded source seam. Route all other workers,
   scouting, and review to `openai-codex/gpt-5.6-terra:high`.
4. Give every implementation worker `skill: "ponytail"`, owned paths, constraints,
   acceptance criteria, focused validation, commit requirement, and stop conditions.
5. Apply Ponytail: reuse existing code, standard library, native features, and
   installed dependencies; fix root causes; add no speculative abstractions or
   unrelated cleanup.
6. Review worker evidence and diffs. Integrate accepted commits only. Resolve conflicts
   minimally on integration branch.
7. Run smallest relevant validation for each non-trivial behavior, then required
   repository checks. Do not claim checks passed unless run.

Ask only when blocked by an irreversible decision, missing credentials, or a
requirement code and repository evidence cannot resolve.

## Final report

State integration branch, task grouping and dependency order, commits integrated,
validation run and result, and intentionally deferred work.
