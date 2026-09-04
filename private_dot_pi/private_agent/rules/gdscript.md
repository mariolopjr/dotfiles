---
globs: "**/*.gd"
---

# GDScript

Godot 4, distilled from the official style guide and typing docs, GDQuest's guidelines, and the
beehave, dialogue_manager, godot-open-rpg, and tabletop-club codebases.

## Declaration order

`@tool`/`@icon` -> `class_name X extends Y` -> `##` class doc -> signals -> enums -> constants ->
static vars -> `@export` vars -> public vars -> `_private` vars -> `@onready` vars -> virtual
methods in lifecycle order (`_init`, `_enter_tree`, `_ready`, `_process`) -> public methods ->
`_private` methods -> `_on_*` callbacks -> inner classes. Public before private within each group.
Two blank lines between functions.

## Static typing

- Type every parameter and return, `-> void` included. An untyped function is Variant in and out
  and turns off every compile-time check downstream
- `:=` only when the right side names its type: `var dir := Vector2.ZERO`. Spell the type out when
  the literal is ambiguous (`var health := 0` hides int vs float) or the call returns Variant
  (`get_node`, `pop_back`, `get`, JSON, `load`)
- Typed collections everywhere: `Array[BeehaveNode]`, `Dictionary[Vector2i, Gamepiece]`; nesting is
  unsupported. Type loop variables over untyped sources: `for prop_name: String in MODIFIABLE_STATS:`
- `as` returns null on mismatch with no error: pair with a null check next line, else branch on `is`
- `class_name` for shared types; preload-into-const only for types kept out of the global namespace
- Enums are ints: a typed enum parameter accepts any int, nothing validates the value
- Enable `untyped_declaration` and the `unsafe_*` warnings in Project Settings > Debug > GDScript,
  error on them in CI. Typing also compiles to faster opcodes, but the win is parse-time errors

## Properties

- A setter exists to hold an invariant or fan out a change, never to forward a value:
  ```gdscript
  var health := max_health:
      set(value):
          if value != health:
              health = clampi(value, 0, max_health)
              health_changed.emit()
              if health == 0:
                  health_depleted.emit()
  ```
  Compare before emitting so no-op writes stay silent. Writing the variable inside its own setter
  does not recurse
- `@export` setters run while the scene file loads, before children exist: a setter that touches
  child nodes guards with `if not is_inside_tree(): await ready`, and one that changes
  editor-visible requirements calls `update_configuration_warnings()`

## Signals

- Declare typed, with a `## Emitted when ...` doc:
  `signal gamepiece_moved(gp: Gamepiece, new_cell: Vector2i)`
- Past tense, no `on_` prefix, no emitter name repeated: `health_changed` on BattlerStats, not
  `battler_stats_changed`. Pair long actions as `talk_started` / `talk_finished`
- Emit and connect through the signal object: `arrived.emit()`,
  `gp.tree_exiting.connect(_on_tree_exiting.bind(gp))`. String forms skip parse-time checks
- Callbacks are `_on_<source>_<signal>` for another node's signal, `_on_<signal>` for your own
- Only the owner emits its signals, except on an autoload event bus (open-rpg's `FieldEvents`): a
  plain Node holding only documented signals, each marked `@warning_ignore("unused_signal")`, that
  distant scenes emit and listen to. Bus events carry cross-branch news only
- Signals up, calls down: a child announces what happened, the parent decides what it means
- `CONNECT_ONE_SHOT` beats disconnecting inside the callback, `CONNECT_DEFERRED` when it frees or
  reparents. Freed nodes disconnect automatically; `is_instance_valid()` guards hide ownership bugs
- Resources emit signals too: `health_changed` on the stats Resource lets UI connect to data

## Node lifecycle and references

- `_init` runs before the tree exists: constructor args only, no `get_node`, no `@onready` values
- `_enter_tree` fires on every reparent, `_ready` once per node, children before parents. Setup
  goes in `_ready`. A child never assumes its parent is ready, it awaits `owner.ready`
- `@onready var follower: PathFollow2D = %PathFollow2D` — `%` names survive scene reshuffles,
  `$Deep/Node/Path` breaks silently on reorder
- Cross-scene references arrive by `@export var target: Node2D` or a signal, never
  `get_parent().get_parent()`
- Compose: the scene root stays dumb (open-rpg's Gamepiece occupies a cell and moves, nothing
  else); AI, input, and visuals ride along as child nodes driving the root's public API
- `@tool` scripts guard runtime side effects with `if Engine.is_editor_hint(): return`
- `super._ready()` when the base class defines one, overrides do not chain
- `queue_free()` defers to end of frame and the node answers calls until then. `free()` is for
  never-treed Objects. RefCounted frees on last reference, `NOTIFICATION_PREDELETE` for teardown

## _process cost

- Defining `_process`/`_physics_process` costs every frame even with an empty body: define only
  with per-frame work, gate with `set_process(false)` while idle (beehave's `enabled` setter). A
  state machine enables processing per state instead of testing `if state == ...` per frame
- Cheaper in order: signal, `Timer`, `create_tween()`, `call_deferred()`. `_process` is for values
  that change every frame
- Cache lookups in `@onready`. No `get_node`, `find_child`, `get_nodes_in_group`, `load`, string
  formatting, lambda creation, or `await` in per-frame code
- Physics queries and `move_and_slide()` go in `_physics_process`. `_process` runs at display rate
  and can fire twice or zero times per physics tick. Scale motion by `delta`
- Coarse work ticks coarse: beehave counts frames against `tick_rate` and returns early, and
  exposes a MANUAL mode so callers drive `tick()` themselves
- Order systems with `process_priority`, not by tree position
- A thousand nodes each running `_process` lose to one manager iterating a typed array

## API design for plugins and reusable nodes

- Overridable hooks are documented no-op methods (`before_run`, `tick`, `after_run`) called via a
  validating wrapper: beehave's `_safe_tick` push_errors a bad return instead of crashing later
- `_get_configuration_warnings()` on any node with child or export requirements; append to
  `super._get_configuration_warnings()`
- Return data as `class_name ... extends RefCounted` value objects (DialogueLine); take designer
  input as Resource subclasses with `@export`s and setters that recalculate (BattlerStats)
- Swappable behavior is a `Callable` member with a working default the user reassigns
  (dialogue_manager's `get_current_scene`)
- Prefix addon `class_name`s (`DMCompiler`, `BeehaveNode`): the global namespace is shared with
  every other installed addon
- `push_error`/`push_warning` for contract violations (they reach the debugger, `print` does not),
  `assert` for internal invariants (stripped from release builds), a bool or null return for
  failures the caller expects
- `&"name"` StringName literals for identity keys compared often

## Naming and format

- snake_case file matching its class (`battler_stats.gd` for BattlerStats), PascalCase
  `class_name`, `_prefix` private, CONSTANT_CASE constants, PascalCase enums with CONSTANT_CASE
  members. Booleans ask a question (`is_active`, `can_move`), methods drop the type name
  (`Inventory.add(item)`)
- Tabs, under 100 columns, double quotes, `and`/`or`/`not` over `&&`/`||`/`!`
- `##` docs on every public class, signal, export, and method; `[member x]`, `[method y]`,
  `[Gamepiece]` link the editor help. `#` comments explain why, sparingly

## Godot 3 to Godot 4

| Godot 3 | Godot 4 |
| --- | --- |
| `export var x` | `@export var x: Type` |
| `onready var` / `tool` | `@onready var` / `@tool` |
| `yield(obj, "sig")` | `await obj.sig` |
| `obj.connect("sig", self, "_on_x", [a])` | `obj.sig.connect(_on_x.bind(a))` |
| `emit_signal("sig", a)` | `sig.emit(a)` |
| `var x setget set_x, get_x` | `var x: int: set(v): ...` / `get: ...` |
| `scene.instance()` | `scene.instantiate()` |
| `KinematicBody2D` + `move_and_slide(vel)` | `CharacterBody2D`, set `velocity`, `move_and_slide()` |
| `PoolStringArray` | `PackedStringArray` |
| `Reference` / `Position2D` / `Spatial` / `Sprite` | `RefCounted` / `Marker2D` / `Node3D` / `Sprite2D` |
| `.empty()` | `.is_empty()` |
| `get_tree().change_scene(path)` | `get_tree().change_scene_to_file(path)` |
| `File` / `Directory` | `FileAccess` / `DirAccess` |
| `JSON.parse(text)` | `JSON.parse_string(text)` |
| `deg2rad` / `rad2deg` / `stepify` | `deg_to_rad` / `rad_to_deg` / `snapped` |
| `OS.get_screen_size()` | `DisplayServer.screen_get_size()` |
| `is_network_master()` | `is_multiplayer_authority()` |
| `Tween` node + `interpolate_property` | `create_tween().tween_property(...)` |
| implicit parent `_ready` | call `super._ready()` yourself |
