# Programming Practices Reference

Keep this file limited to practices that the Google Swift Style Guide covers.

## Compiler Warnings

Do not introduce new warnings. Remove warnings that are already easy to fix.
Deprecation warnings can be a reasonable exception when migration is not yet
practical.

## Initializers

- Use a synthesized memberwise initializer for `struct` when it is suitable.
- Do not call special literal protocol initializers directly.
- Omit `.init` in direct initializer calls unless the receiver is a metatype
  value.

```swift
let x = MyType(value: 1)
let y = MyType.init(value: 1)
```

## Properties

Read-only computed properties omit `get`.

## Shorthand Types

Use shorthand spellings when the compiler allows them.

```swift
let names: [String]
let counts: [String: Int]
let user: User?
```

## Optional Types

- Prefer `if let`, `guard let`, optional chaining, and `??`.
- If you only need to test for non-`nil`, compare to `nil` instead of binding
  and discarding the value.

## Errors

Use an `enum` conforming to `Error` when there are multiple possible error
states.

## Force Unwraps and Force Casts

Force unwraps and force casts are strongly discouraged. When one is used
outside tests, it should be extremely clear from context or documented with a
comment explaining the invariant that makes it safe.

Unit tests and test-only code may use them without extra documentation.

## Implicitly Unwrapped Optionals

Avoid IUOs when possible. Common allowed cases in the guide:
- `@IBOutlet` properties
- values initialized later by UI lifecycle or external setup
- Objective-C APIs imported with missing nullability information
- test fixtures initialized in `setUp()`

Keep IUOs from spreading through multiple layers of your own abstractions.

## Access Levels

- Omitting an explicit access level is permitted.
- Top-level declarations default to `internal`.
- Nested declarations default to the lesser of `internal` and the enclosing
  declaration's access level.
- Do not put an explicit access modifier on an extension declaration itself.
- If a member's access differs from the default, specify it on the member.

## Nesting and Namespacing

- Prefer nesting to express scoped or hierarchical relationships.
- Nested error types and flag enums are common and encouraged.
- A caseless `enum` is the canonical namespace pattern for related constants or
  helper functions.

## Early Exits and Control Flow

- Prefer `guard` for early exits and precondition checks.
- Prefer `for`-`where` instead of an `if` nested directly in the loop body when
  it is only filtering iteration.
- Avoid `fallthrough`; use clearer patterns unless there is a specific reason.

## Pattern Matching

- Bind only the values you use.
- Use tuple patterns when they improve clarity, not as decoration.

## Literals and Operators

- Numeric separators are recommended when they improve readability.
- Do not define custom operators without strong domain precedent.
- Overload existing operators only when the meaning is unsurprising and matches
  the operator's normal semantics.
