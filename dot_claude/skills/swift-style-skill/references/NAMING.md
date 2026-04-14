# Naming Reference

This file covers naming rules that come from the Google Swift Style Guide and
Apple's API Design Guidelines.

## Casing

| Symbol | Convention | Example |
|--------|------------|---------|
| Types, protocols, typealiases, modules | `UpperCamelCase` | `UserProfile`, `MyModule` |
| Functions, methods, properties, globals | `lowerCamelCase` | `fetchUser()`, `defaultTimeout` |
| Parameters and local variables | `lowerCamelCase` | `name`, `elapsedTime` |
| Enum cases | `lowerCamelCase` | `case notFound`, `case unexpectedEOF` |

## Acronyms and Initialisms

Treat acronyms as words within the surrounding case style.

- Entire acronym identifiers remain uppercase: `URL`, `HTTP`, `XML`
- In `lowerCamelCase`, acronyms are lowercase: `urlString`, `httpRequest`
- In `UpperCamelCase`, acronyms keep their usual capitalization:
  `URLSession`, `XMLParser`

```swift
// ✅
var url: URL
var urlString: String
class URLSessionProxy {}

// ❌
var URL: String
class UrlSessionProxy {}
```

## Call-Site Clarity

Name APIs so the use site reads clearly.

```swift
// ✅
list.insert(element, at: index)
users.remove(at: index)

// ❌
list.insertElement(element, atIndex: index)
users.removeElement(atIndex: index)
```

Omit needless words, but keep words that clarify role or meaning.

## Identifiers

Identifiers are usually ASCII. Unicode identifiers are allowed when they have a
clear, legitimate meaning in the problem domain and are well understood by the
team.

Avoid escaped keywords as identifiers when a clearer name is available.

## Initializers

Initializer arguments that correspond directly to stored properties use the same
name as the property.

```swift
struct Person {
  let name: String

  init(name: String) {
    self.name = name
  }
}
```

## Static and Class Properties

Static or class properties that return the declaring type are not suffixed with
the type name.

```swift
extension Color {
  static let red = Color(red: 1, green: 0, blue: 0)
}

extension Color {
  static let redColor = Color(red: 1, green: 0, blue: 0)
}
```

Global constants also use `lowerCamelCase`, not all-caps or `k` prefixes.

## Delegate Methods

Delegate methods are named using the source type as the base of the API.

```swift
func scrollViewDidBeginDragging(_ scrollView: UIScrollView)
func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
```

## Access Control vs Naming

Use access control keywords to hide implementation details. Do not use leading
underscores as a privacy convention unless forced by a language limitation.

## Boolean Names

Boolean properties and variables should read as assertions.

```swift
var isEmpty: Bool
var hasUnreadMessages: Bool
var canSubmit: Bool
```
