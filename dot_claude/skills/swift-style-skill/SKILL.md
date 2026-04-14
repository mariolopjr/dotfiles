---
name: swift-style-skill
description: >
  Apply the Google Swift Style Guide to Swift code generation, review, and
  refactoring. Covers naming, file structure, formatting, and source-backed
  programming practices. Use for Google Swift compliance, not architecture,
  framework design, or project policy outside the guide.
license: MIT
metadata:
  author: Michael Pchelnikov
  version: "2.0.0"
---

# Swift Style Skill

Use this skill for Swift naming, formatting, file structure, and style review
that should follow the Google Swift Style Guide strictly:
https://google.github.io/swift/

## Scope

- In scope: naming, imports, file structure, formatting, documentation, and
  guide-backed programming practices.
- Out of scope: architecture, framework idioms, dependency choices, concurrency
  strategy, or repo policy that is not in the guide.

## Workflow

1. Identify the task mode: `generate`, `review`, `refactor`, or `answer`.
2. Apply the core rules below immediately.
3. Open only one reference file unless the task genuinely spans categories.
4. Quote or cite only the rule relevant to the code under discussion.

Mode outputs:
- `generate` and `refactor`: apply the rules directly with minimal explanation.
- `review`: report only concrete violations or risks.
- `answer`: explain briefly and cite only the relevant rule.

## Agent Behavior

- Do not restate the full style guide in responses.
- When reviewing, report only concrete violations or risks visible in the code.
- When generating or refactoring, prefer the smallest change that reaches style
  compliance.
- If the user explicitly asks for Google Swift compliance, follow this skill
  over repo-local convention.
- Otherwise, if the file already uses a different style consistently and the
  task is normal maintenance, avoid churn and preserve local convention.

## Core Rules

- Types and modules: `UpperCamelCase`.
- Functions, methods, properties, parameters, locals, globals, and enum cases:
  `lowerCamelCase`.
- Follow Apple's API Design Guidelines for names and call-site clarity.
- 100-column limit, 2-space indentation, no tabs, no semicolons, K&R braces.
- Prefer whole-module imports; keep imports minimal, grouped, and sorted.
- One logical primary type per file; use `// MARK: -` for meaningful sections.
- Prefer shorthand types: `[T]`, `[K: V]`, `T?` when the compiler allows them.
- Avoid force unwraps, force casts, and IUOs unless the Google guide's
  exceptions apply.
- Use `guard` for early exits and avoid unnecessary `fallthrough`.
- Document `public` and `open` declarations, subject to the guide's exceptions.

## Routing

- Naming questions or violations: `references/NAMING.md`
- Imports, file layout, docs: `references/FILE_STRUCTURE.md`
- Wrapping, whitespace, braces, attributes: `references/FORMATTING.md`
- Optionals, access levels, nesting, guard, operators: `references/PRACTICES.md`
