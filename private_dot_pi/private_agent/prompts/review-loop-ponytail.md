---
description: Review/fix loop with an additional Ponytail complexity reviewer
---

Run a parent-controlled review loop for: $@

Follow pi-subagents' review-loop procedure. Preserve all normal dynamically
selected reviewer angles. Add exactly one additional fresh, read-only reviewer
in every review round; do not replace or merge normal reviewer roles.

Launch this additional reviewer with `skill: "ponytail-review"`. Scope it only
to concrete over-engineering findings using Ponytail tags: `delete`, `stdlib`,
`native`, `yagni`, and `shrink`. Require file/line evidence, P0/P1/P2, a merge
verdict, and `net: -N lines possible.` Never flag required validation,
correctness, security, or accessibility work.

Treat Ponytail findings as advisory. Apply only accepted, in-scope P1 fixes;
defer optional P2 cleanup. Do not loop for speculative cleanup. Present P2 and
Ponytail results in a numbered list starting from the most important.
