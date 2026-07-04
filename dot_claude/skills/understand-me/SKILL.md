---
name: understand-me
description: Structured multi-phase interview for deeply understanding a plan or design before implementation. Invoke this skill — don't skip it — when: the user says "help me plan", "let's think through", "I want to design", "understand me", "interview me about", or similar; the user describes a system or feature and asks how to start; the user has a vague plan and says "just start" (surface requirements first). This skill runs a 5-phase methodology (align → dependencies → known unknowns → unknown unknowns → summary) that catches problems before they become implementation mistakes. Invoke even when you could answer directly — structured interviewing catches what ad-hoc questioning misses.
---

Your goal: reach thorough shared understanding of the user's plan through focused, intelligent dialogue — not a wall of questions, but a progressive conversation that resolves uncertainty in the right order.

## Process

**Phase 1: Align**
Ask 1-3 high-level questions first to understand the core intent:
- What is being built and why?
- Who is it for?
- What does success look like?

Don't proceed to details until you understand the purpose.

**Phase 2: Resolve dependencies in order**
Decisions depend on other decisions. Map the dependency graph and resolve foundational ones first. Example: "which database?" depends on "what kind of data?" — ask the latter first. Explicitly note when one decision blocks others.

**Phase 3: Known unknowns**
Work through things explicitly mentioned but not yet decided.

**Phase 4: Unknown unknowns**
Proactively surface what the user hasn't considered:
- Failure cases and error handling
- Security or privacy implications
- Interaction with existing systems
- Migration/rollout strategy
- Constraints (time, team, budget)

**Phase 5: Summarize and confirm**
Write a clear summary of the plan as understood — decisions made, open questions remaining, risks identified. Ask the user to confirm or correct it. This is the deliverable.

## How to question

- Ask 1-3 focused questions per turn, not 20. Let answers guide what to ask next.
- If a question can be answered by exploring the codebase, explore instead of asking.
- Group related questions together.

## When to stop

Stop when:
- The user confirms the summary is correct
- The user says they're satisfied
- No meaningful unknowns remain
