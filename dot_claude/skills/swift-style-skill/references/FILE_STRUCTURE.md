# File Structure Reference

## File Names

- Swift source files end in `.swift`.
- A file is usually named for its primary type: `MyType.swift`.
- Protocol-conformance extensions use `Type+Protocol.swift`.
- Broader grouped extensions can use `Type+Additions.swift`.

## File Comments

File comments are optional and usually unnecessary for files that contain a
single abstraction. Prefer documenting the type itself. File comments are most
useful when a file groups multiple related abstractions.

## Imports

- Import exactly the modules the file needs.
- Prefer whole-module imports to individual declarations or submodules.
- Individual declaration imports are allowed when importing the full module
  would pollute the global namespace.
- Submodule imports are allowed when the submodule exposes API not available
  from the top-level module.
- Imports are the first non-comment tokens in a file and are not line-wrapped.

Import groups:
1. Module or submodule imports not under test
2. Individual declaration imports
3. `@testable` imports

Sort each group lexicographically and separate groups with one blank line.

## Top-Level Declarations

- Most files contain one top-level type.
- Related helper types may share the file when they are closely related and
  commonly reviewed together.
- A class and its delegate protocol may share a file.
- Use a logical member order that you could explain to a reviewer.

## `// MARK:`

Use `// MARK:` comments to label logical sections when they improve navigation
and readability. `// MARK: -` inserts a divider in Xcode's jump menu.

## Overloaded Declarations

Overloads that appear in the same scope stay together with no unrelated code
between them.

## Extensions

Use extensions to organize functionality into logical units. The grouping should
be explainable and consistent.

## Documentation Comments

Use `///` for documentation comments.

At minimum, document:
- every `public` declaration
- every `open` declaration
- every `public` or `open` member of such a declaration

Common exceptions allowed by the guide:
- self-explanatory enum cases
- overrides or protocol requirement implementations
- test methods with descriptive names
- extension declarations themselves

Keep docs concise:
- first line is a single-sentence summary
- separate summary from tags with a blank `///` line
- use Apple's markup tags such as `- Parameter:`, `- Parameters:`,
  `- Returns:`, and `- Throws:`
