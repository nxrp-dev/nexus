# Object Pascal Standards

These standards apply to Object Pascal / Free Pascal code in this repository when referenced by the applicable `AGENTS.md`.

## Language And Compatibility

- This is Object Pascal / Free Pascal code.
- Respect Pascal visibility and type rules.
- Do not use clever workarounds to bypass language constraints.
- Do not use casts to bypass design or type problems unless explicitly approved.
- Do not add or keep compatibility APIs, overloads, aliases, convenience wrappers, or legacy shims unless explicitly requested or justified by a verified current integration requirement.
- Do not introduce dependencies or frameworks unless explicitly requested.

## Unit Naming

Use the project's intent-based unit prefixes:

- `ob` for object/class definitions.
- `ui` for GUI/forms/user-interface units.
- `ut` for utility/helper functions grouped by theme.
- `tp` for types and constants.

Do not invent new naming conventions unless explicitly asked.

## Shared Definition Ownership

- Do not use type aliases as convenience wrappers or compatibility shims.
- Shared definitions must have one real source of truth.
- If shared definitions are type declarations, constants, enums, records, or other pure type-level data, move the real definitions into an appropriate `tp...` unit and have each consumer use that unit directly.
- If shared definitions are object/class implementations, move the real definitions into an appropriate `ob...` unit and have each consumer use that unit directly.
- Do not re-export enum values, constants, type names, or classes from another unit to avoid updating `uses` clauses.

## Identifier Naming

- Function and procedure arguments must use the `A` prefix.
  - Example: `AName`, `AValue`, `AOwner`, `ARect`.
- Local variables must use the lowercase `l` prefix, with no exceptions.
  - Example: `lIndex`, `lEvent`, `lWindow`.
- Class fields should use the `F` prefix.
  - Example: `FRunning`, `FMainWindow`, `FRenderer`.
- Constants should use the `c` prefix where practical.
  - Example: `cDefaultWidth`, `cDefaultHeight`.

## Class Structure

- Fields belong in `private`.
- Behavior getters and setters belong in `protected`.
- Properties used by other objects belong in `public`.
- Persisted RTTI-visible properties belong in `published` when they are part of the serialized object model.
- Trivial getters and setters should be replaced by direct field-backed properties.
- Use properties to expose state intentionally.
- Do not expose fields directly.
- Keep constructors and destructors simple.
- Avoid lifecycle magic hidden in unrelated methods.
- Use protected getters/setters only when behavior is actually needed.

## Function Returns

- Use `Result` for function return values.
- Do not assign return values to the function name.

## Persistence And Object Model

- For structured framework data, design the correct Object Pascal object graph first, then persist that graph.
- RTTI and published properties are intentional modeling tools in this project, not reluctant fallbacks.
- Persisted lists that may contain descendants must preserve per-item class/type identity and reconstruct the correct descendant.
- Persistence aliases may be used for clean external names, but the default identity is the real Pascal class name.
- Do not let text storage leak into the internal model. For example, binary data is stored as binary and exposed through a published base64 property only at the persistence boundary.
- Tests for persistence should prefer construct, stream out, stream in, stream out, and byte-compare the two outputs, plus semantic checks.
- Avoid vague dynamic side channels. If dynamic attributes are needed, model them explicitly with a published `TStringList` or a real persisted object/list.
