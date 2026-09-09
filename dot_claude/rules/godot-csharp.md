---
paths:
  - "**/*.cs"
  - "**/*.csproj"
---

# Godot C#

Godot 4.7, `Godot.NET.Sdk`. Distilled from the Godot C# docs, the `Godot.SourceGenerators`
diagnostics, and the transferable slice of codewithmukesh/dotnet-claude-kit. Godot idiom wins over
ASP.NET idiom every time: there is no DI container, no `TimeProvider`, no `IHttpClientFactory`, no
`CancellationToken` chain, no EF Core, no `HybridCache`. Advice built for a web request pipeline
does not apply to a frame loop.

## Project setup

Godot generates a two-property csproj. It is not enough:

```xml
<Project Sdk="Godot.NET.Sdk/4.7.1">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <TargetFramework Condition=" '$(GodotTargetPlatform)' == 'android' ">net9.0</TargetFramework>
    <EnableDynamicLoading>true</EnableDynamicLoading>
    <LangVersion>latest</LangVersion>            <!-- C# 12 without this line -->
    <Nullable>enable</Nullable>                  <!-- off by default; turn it on -->
    <WarningsAsErrors>Nullable</WarningsAsErrors>
    <AnalysisLevel>latest-recommended</AnalysisLevel>
  </PropertyGroup>
</Project>
```

- **`net8.0` does not cap the language.** With `<LangVersion>latest</LangVersion>` you get C# 14:
  `field`, extension members, partial properties, null-conditional assignment, `params` collections,
  and unbound `nameof` are compiler-only and need nothing from the runtime. The two exceptions that
  do: `System.Threading.Lock` and `[OverloadResolutionPriority]`, both `net9.0`. Set the property
  explicitly — the SDK default is C# 12 and the whole file below assumes you did not accept it
- Skip `<ImplicitUsings>enable</ImplicitUsings>`. With `using Godot;` also in scope it makes
  `Range` (Godot's Slider base) and `Environment` (WorldEnvironment's) ambiguous. Write usings
- Analyzer IDs are `GD0001`-`GD0402`: `GD0001` missing `partial`, `GD0101`-`GD0111` bad `[Export]`,
  `GD0201`-`GD0203` bad `[Signal]`, `GD0301`-`GD0303` non-Variant generic argument. All 22 already
  default to `Error` — they are contract violations the engine cannot recover from. Never downgrade
  one in `.editorconfig`

## Class declaration and layout

```csharp
[GlobalClass]
public partial class BattlerStats : Resource
```

- **`partial` on every type deriving from `GodotObject`**, and on every type that *contains* one
  (`GD0001`/`GD0002`). The source generator writes the other half
- `[GlobalClass]` is `class_name`: registers the type in the editor's create-node dialog. Without it
  the class is invisible to designers
- One `GodotObject` type per file, file named for the type. Two same-named classes in one script
  file is `GD0003`
- No generic script classes (`GD0402`), the engine cannot instantiate them
- `sealed` on anything not designed for inheritance, `internal` unless something outside needs it
- File-scoped namespaces
- Order: attributes -> `public partial class X : Y` -> `///` doc -> nested enums -> constants ->
  static fields -> `[Signal]` delegates -> `[Export]` members -> public properties -> private fields
  -> constructor -> Godot virtuals in lifecycle order (`_EnterTree`, `_Ready`, `_Process`,
  `_PhysicsProcess`, `_ExitTree`, `_Notification`) -> public methods -> private methods -> signal
  handlers -> nested types

**Primary constructors and records are wrong on Godot types, and right everywhere else.** The
engine instantiates nodes and resources through a parameterless constructor when loading a scene, so
a primary constructor taking dependencies makes the scene unloadable; and a `Resource` cannot be a
`record` because it has to be a `public partial class`. On a Godot type dependencies arrive as
`[Export]` or from the parent in `_Ready`. Where they do belong is "The plain C# layer" below.

## Exports

```csharp
[ExportGroup("Movement")]
[Export] public float Speed { get; set; } = 300f;
[Export(PropertyHint.Range, "0,100,1")] public int MaxHealth { get; set; } = 100;
[Export] public PackedScene? BulletScene { get; set; }
[Export] private Marker2D? _muzzle;
```

- Must be non-static (`GD0101`), a Variant-compatible type (`GD0102`), and readable and writable —
  no `readonly`, no getter-only, no init-only (`GD0103`/`GD0104`), no indexer (`GD0105`)
- **`[Export]` a `Node` reference instead of a `GetNode` path.** The scene serializes the NodePath
  and the engine assigns the node before `_Ready`. A renamed or moved node then breaks in the editor
  rather than at runtime. Only `Node`-derived types may export `Node` members (`GD0107`)
- `[Export] PackedScene` is the replacement for `preload()`. C# has no compile-time preload;
  `GD.Load<T>` at runtime is the fallback, an export is the version a designer can rewire
- Export setters run while the scene loads, before children exist. A setter touching children guards
  with `if (!IsNodeReady()) return;`; one changing editor requirements calls
  `UpdateConfigurationWarnings()`
- `[ExportToolButton]` only in a `[Tool]` class, only on an expression-bodied `Callable` property,
  never alongside `[Export]` (`GD0108`-`GD0111`)

## Properties

A setter exists to hold an invariant or fan out a change, never to forward a value. `field` carries
the value, so there is no backing field to declare:

```csharp
[Export]
public int Health
{
    get;
    set
    {
        value = Mathf.Clamp(value, 0, MaxHealth);
        if (value == field) return;
        field = value;
        EmitSignalHealthChanged(field);
        if (field == 0) EmitSignalHealthDepleted();
    }
} = 100;
```

Compare before emitting so no-op writes stay silent; assigning `field` inside its own setter does not
recurse. `[Export]` works on a `field`-backed property — the generator reads the default off the
property initializer, so keep the `= 100`.

## Signals

```csharp
/// <summary>Emitted when health changes, including on death.</summary>
[Signal] public delegate void HealthChangedEventHandler(int newHealth);
```

- The delegate name **must** end in `EventHandler` (`GD0201`), return `void` (`GD0203`), and take
  only Variant-compatible parameters (`GD0202`). The signal is named without the suffix
- **Emit through the generated `EmitSignalHealthChanged(value)`.** It is type-checked and allocates
  nothing. `EmitSignal(SignalName.HealthChanged, value)` is second best;
  `EmitSignal("HealthChanged", value)` allocates a `StringName` and skips every compile-time check
- **Connect with the C# event syntax**: `battler.HealthChanged += OnHealthChanged;`. It compiles to
  `Connect` and gives you a compiler error on a signature change. Reserve
  `Connect(SignalName.X, Callable.From(...), (uint)ConnectFlags.OneShot)` for flags and lambdas
- A lambda in a `Callable` captures `this` and keeps the managed wrapper alive. Prefer a method
  group. If you must use a lambda, you cannot `-=` it — connect with `OneShot` or hold the `Callable`
- Past tense, no `On` prefix, no emitter name repeated: `HealthChanged` on BattlerStats, not
  `BattlerStatsChanged`. Pair long actions as `TalkStarted` / `TalkFinished`
- Handlers are `On<Source><Signal>` for another node's signal, `On<Signal>` for your own
- Signals up, calls down: a child announces what happened, the parent decides what it means
- Only the owner emits its own signals, except on an autoload event bus: a plain `Node` holding
  nothing but documented signals, carrying cross-branch news only
- A `Resource` emits signals too — `HealthChanged` on the stats resource lets UI bind to data

## Node lifecycle and references

- The constructor runs before the node is in the tree: no `GetNode`, no tree access. Keep it
  parameterless and empty
- `_EnterTree` fires on every reparent, `_Ready` once, children before parents. Setup goes in
  `_Ready`. Call `base._Ready()` when the base class defines one — C# overrides do not chain
- There is no `@onready`. Resolve once in `_Ready` and cache the field, or `[Export]` it:
  ```csharp
  private AnimationPlayer _anim = null!;
  public override void _Ready() => _anim = GetNode<AnimationPlayer>("%Anim");
  ```
  `%UniqueName` survives scene reshuffles, `$Deep/Node/Path` breaks silently on reorder
- `GetNode<T>(string)` builds a `NodePath` from the string on every call. Never in per-frame code
- Cross-scene references arrive by `[Export]` or a signal, never `GetParent().GetParent()`
- Compose: the scene root stays dumb; AI, input, and visuals ride along as child nodes driving the
  root's public API
- `[Tool]` scripts guard runtime side effects with `if (Engine.IsEditorHint()) return;`
- `_GetConfigurationWarnings()` returns `string[]`; append to `base._GetConfigurationWarnings()`
- **Cross-language calls use the C# name verbatim.** GDScript calls `node.DoThing()`, not
  `node.do_thing()`. There is no snake_case bridge

## Per-frame cost

- `_Process(double delta)` — `delta` is `double`, but `Vector2`/`Transform2D` math is `float`. Cast
  once at the top (`var dt = (float)delta;`) rather than scattering casts through the expression
- Overriding `_Process`/`_PhysicsProcess` costs a call every frame even with an empty body. Override
  only with per-frame work, and `SetProcess(false)` while idle. A state machine enables processing
  per state instead of testing `if (state == ...)` every frame
- Cheaper in order: signal, `Timer`, `CreateTween()`, `CallDeferred`. `_Process` is for values that
  change every frame
- **Nothing that allocates in per-frame code.** Godot uses the standard .NET GC with no incremental
  mode; Gen0 pressure shows up as frame hitches. That rules out LINQ (enumerators plus closures),
  string interpolation, `GetNode`, `new StringName(...)`, `Callable.From`, lambdas, and
  `GetNodesInGroup`
- `SignalName.X`, `MethodName.X`, `PropertyName.X` are cached `StringName`s the generator emits.
  Use them; a string literal in those positions allocates and does a native lookup per call
- `Vector2`, `Rect2`, `Transform2D`, `Color` are structs — free. Pass them by value
- Physics queries and `MoveAndSlide()` go in `_PhysicsProcess`. `_Process` runs at display rate and
  can fire twice or zero times per physics tick. Scale motion by `delta`
- Order systems with `ProcessPriority`, not by tree position
- A thousand nodes each overriding `_Process` lose to one manager iterating a `List<T>`

## Variant and collections

- `Godot.Collections.Array<T>` and `Dictionary<K,V>` are native-backed: every read and write
  marshals a `Variant`, and `foreach` boxes. They belong at the engine boundary only — `[Export]`,
  signal parameters, `Call`. Internal data is `System.Collections.Generic.List<T>` /
  `Dictionary<K,V>`
- Their type arguments must be Variant-compatible (`GD0301`); a generic method passing one through
  needs `[MustBeVariant]` on the parameter (`GD0302`)
- `Variant.From<T>(x)` / `variant.As<T>()` to cross deliberately. `variant.AsGodotObject()` returns
  null on a type mismatch with no error — null-check the next line
- `GD.Print` / `GD.PushError` / `GD.PushWarning` reach the Godot output panel and the debugger.
  `Console.WriteLine` reaches stdout only. `PushError` for contract violations, a bool or nullable
  return for failures the caller expects

## Lifetime and disposal

- `GodotObject` implements `IDisposable`, but **`QueueFree()` is how a node dies** — it defers to
  end of frame and the node answers calls until then. Never `Dispose()` a node in the tree, never
  wrap one in `using`
- `Resource` and other `RefCounted` types free on last reference. The C# wrapper counts as one
- After any `await`, or across frames, a stored node may already be freed: guard with
  `GodotObject.IsInstanceValid(node)` before touching it. Using a freed wrapper throws
  `ObjectDisposedException`
- A freed node disconnects its own signals automatically

## Async and threading

- `await ToSignal(GetTree().CreateTimer(1.0), SceneTreeTimer.SignalName.Timeout);` — this is the
  `await` that belongs in game code. There is no request pipeline to make async all the way
- Never `.Result` or `.Wait()` on the main thread
- `async void` is the only shape a signal handler can take, and it swallows exceptions into a
  process crash. Wrap the body in try/catch, or make it a one-line call into an `async Task` method
  whose faults you handle. Everywhere else `async void` is a bug
- The scene tree is not thread-safe. Work off `Task.Run` marshals back with
  `CallDeferred(MethodName.Apply)` before touching a node

## Errors

- Exceptions crossing the managed/native boundary in `_Ready` or `_Process` are logged and
  swallowed: the game keeps running in a broken state. Do not rely on an exception to stop anything
- Never catch bare `Exception` except at a boundary you own. Broad catches hide bugs
- Never catch and rethrow without adding context
- Validate at boundaries — save files, mod content, config, network. Do not defensively re-validate
  inside private methods that already received parsed data
- Prefer a `Result`-shaped return or a nullable over throwing for expected failures (not found,
  invalid content, bad save). Throw for programmer error

## The plain C# layer

Simulation, content parsing, math, and save serialization do not need to be Godot types, and should
not be. A class the engine never instantiates is ordinary C#, and the whole modern toolkit lands:

```csharp
public readonly record struct Cell(int X, int Y);

public sealed record Building(string Id, int Cost, Cell Footprint)
{
    public required IReadOnlyList<string> Inputs { get; init; }
}

public sealed class EconomyTick(ContentRegistry content, Rng rng)
{
    public TickResult Advance(WorldState state) => /* ... */;
}
```

- Primary constructors for collaborators, `record` for immutable data, `readonly record struct` for
  small values, `required`/`init` to make illegal states unrepresentable
- Keep it free of `using Godot;`. A layer with no engine types runs headless under a test runner,
  cannot accidentally marshal a `Variant`, and survives an engine upgrade untouched
- It crosses into Godot at one seam: a `Resource` or `Node` that reads the plain types and exposes
  them to the editor. Convert there, not in every call
- A separate `.csproj` is optional — the boundary that matters is the missing `using Godot;`, not
  the project file

## Modern C# on Godot types

What survives contact with a `partial` class the engine owns:

- `field` in property accessors, `[Export]` properties included
- Extension members for helpers on engine types you cannot subclass:
  ```csharp
  public static class NodeExtensions
  {
      extension(Node node)
      {
          public bool IsAlive => GodotObject.IsInstanceValid(node) && !node.IsQueuedForDeletion();
      }
  }
  ```
- Collection expressions: `List<int> ids = [1, 2, 3];`, `int[] all = [..a, ..b, 99];`
- Switch expressions and `is` patterns over if-else chains, but not nested three levels deep
- Partial properties, null-conditional assignment (`_target?.Health = 0;`), `params` collections
- `var` when the right side names the type (`var stats = new BattlerStats();`), the type spelled out
  when it does not (`Vector2 dir = Compute();`)
- Raw string literals for embedded JSON and shader source
- `Span<T>` / `stackalloc` for parsing and buffer work in hot paths
- **Not** `required` or `init` on `[Export]` members: `GD0103`/`GD0104` need them readable and
  writable. Not `record`, not a primary constructor — see above

## Naming and format

- PascalCase for types, methods, properties, public fields, **and `const`** — C# does not use
  `SCREAMING_CASE`, whatever GDScript habit says. camelCase for locals and parameters, `_camelCase`
  for private fields
- Booleans ask a question (`IsActive`, `CanMove`). Methods drop the type name
  (`Inventory.Add(item)`)
- `Async` suffix only on methods returning `Task`/`ValueTask`. `_Ready` and friends keep their
  engine names exactly
- Four spaces, Allman braces, under 120 columns
- `///` docs on every public type, signal, export, and method. `#` comments explain why, sparingly

## GDScript to C#

| GDScript | C# |
| --- | --- |
| `extends Node2D` + `class_name Player` | `[GlobalClass] public partial class Player : Node2D` |
| `@tool` | `[Tool]` |
| `@export var speed := 300.0` | `[Export] public float Speed { get; set; } = 300f;` |
| `@onready var s := %Sprite` | `[Export] private Sprite2D? _sprite;` or assign in `_Ready` |
| `$Path` / `%Unique` | `GetNode<T>("Path")` / `GetNode<T>("%Unique")` |
| `signal died(who: Node)` | `[Signal] public delegate void DiedEventHandler(Node who);` |
| `died.emit(self)` | `EmitSignalDied(this);` |
| `x.died.connect(_on_died)` | `x.Died += OnDied;` |
| `func _ready() -> void:` | `public override void _Ready()` |
| `_process(delta: float)` | `_Process(double delta)` — cast to `float` for math |
| `preload("res://b.tscn")` | `[Export] PackedScene`, or `GD.Load<PackedScene>(...)` |
| `scene.instantiate()` | `scene.Instantiate<Node2D>()` |
| `queue_free()` | `QueueFree()` |
| `is_instance_valid(x)` | `GodotObject.IsInstanceValid(x)` |
| `x as Type` (null on mismatch) | `x as Type` (same) / `x is Type t` |
| `print` / `push_error` / `push_warning` | `GD.Print` / `GD.PushError` / `GD.PushWarning` |
| `await get_tree().create_timer(1).timeout` | `await ToSignal(GetTree().CreateTimer(1), SceneTreeTimer.SignalName.Timeout)` |
| `Vector2.ZERO` / `deg_to_rad` | `Vector2.Zero` / `Mathf.DegToRad` |
| `Array[int]` (export) | `Godot.Collections.Array<int>` |
| `Array[int]` (internal) | `List<int>` |
| `_get_configuration_warnings()` | `_GetConfigurationWarnings()` returning `string[]` |
| `&"name"` | `SignalName.X` / `MethodName.X` / `PropertyName.X` |
| `call_deferred("f")` | `CallDeferred(MethodName.F)` |
