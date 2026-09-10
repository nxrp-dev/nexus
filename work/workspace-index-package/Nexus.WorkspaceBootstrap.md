# Nexus Workspace Bootstrap

This document tells an automated development bot how to orient itself in a
Nexus workspace. It is a starting map, not authority over the repository or a
substitute for reading the relevant source.

## Start Here

1. Read the root `AGENTS.md` before performing work.
2. When entering a subfolder, look for the nearest additional `AGENTS.md` and
   apply it to that subtree.
3. Follow the standards and protocols referenced by those instruction files.
   For Object Pascal work this normally includes `.ai/standards/pascal.md`.
   Architecture changes use `.ai/protocols/architecture-change.md`.
4. Read `Nexus.WorkspaceIndex.nxscript` for orientation. Use its descriptions,
   notes, and tags to identify the smallest relevant part of the workspace.
5. Verify every indexed claim against the current files. The index is curated
   guidance, not a generated or canonical inventory, and it may become stale.

Do not begin by reading the entire repository. Locate the relevant folder,
search for the named concepts and types, then read the owning units and focused
tests. Prefer `rg --files` for file discovery and `rg` for text search.

## Reading the Workspace Index

`Nexus.WorkspaceIndex.nxscript` is validated by
`WorkspaceIndex.Language.nxscript`.

- A `Workspace` is a repository or separately meaningful working tree.
- A `Folder` describes a directory.
- A `File` describes a specific file.
- A nested `Path` is relative to its containing folder's resolved path.
- A top-level folder path is relative to the workspace root.
- `Description` explains ownership or purpose.
- `Notes` provide non-canonical operating guidance.
- Definition tags such as `[Language, Toolchain]` are search and
  classification hints only.

Resolve the hierarchy from the workspace root downward. If a resolved path does
not exist, do not silently substitute a similarly named path. Search for the
current location and report that the index is stale when appropriate.

## NexusScript Essentials

NexusScript is a generic declarative language. A document contains definitions,
properties, child definitions, arrays, references, and dependency declarations.
A doctype supplies validation rules; it does not create a separate parser or
change the core grammar.

```nexusscript
doctype "WorkspaceIndex.Language.nxscript";

Workspace Nexus [Pascal, Toolchain] {
    Description: "Nexus repository";

    Folder Source [Pascal] {
        Path: "src";
        Description: "Source files";
    }
}
```

The fundamental forms are:

- `Kind Name { ... }` declares a definition.
- `PropertyName: value;` declares a property.
- A definition inside another definition is a child definition.
- `[value, value]` is an ordered array.
- `@Path.To.Member` is a reference.
- `left + right` composes text or compatible values.
- `Kind Name (Base, Other.Base) { ... }` composes definitions.
- `Kind Name [Tag, "Tag With Spaces"] { ... }` attaches local definition
  tags.

Parentheses and square brackets are not interchangeable. Parentheses request
composition from existing definitions. Square brackets declare tags. Tags are
case-sensitive, valueless identifiers and do not themselves affect validation,
composition, or reference resolution. Composition does not copy the base
definition's own tags.

Unquoted words are ordinary contiguous NexusScript text. Quote text when its
spelling must retain whitespace or language punctuation, and use the normal
string escapes inside quoted text.

## References and Composition

NexusScript references are resolved from their use site. Resolution is
lexical and bottom-up: qualified paths search outward through the containing
scopes for a usable first segment and then descend through that object. Do not
assume that every path is a fully qualified name beginning at the document
root.

Composition selectors follow the same scoped model. Local members are applied
over composed members according to compiler rules. When behavior depends on
the effective result, inspect the compiled definition or existing compiler
tests rather than reasoning from source order alone.

The generic JSON artifact exposes each compiled definition's retained
provenance under `_nx.SourceRange`. Use `SourceName`, `StartPosition`, and
`EndPosition` to find the declaration represented by composed, imported, or
structurally referenced output.

## Documents and Dependencies

- `doctype Path;` selects the NexusScript language definition used to validate
  the document.
- `module Path;` makes roots from another document addressable without adding
  that document to the artifact set.
- `module Root Path;` imports one selected root.
- `include Path;` adds another independently compiled document to the artifact
  set but does not create a reference namespace.
- `module discover Folder Mask;` and `include discover Folder Mask;` extend
  their corresponding existing mechanism to matching files.
- Adding `recursive` after `discover` includes matching files below the named
  folder as well.

Discovery folders are relative to the declaring document. Discovery excludes
the declaring document itself and an empty match is a no-op. There is no bare
`discover` declaration.

Dependency paths and doctype paths are part of the source contract. Confirm the
target documents are present beside the deployed file or at the declared
relative location before diagnosing compiler or validator behavior.

## Source, Compiled Model, and Artifact

Keep these layers distinct:

- The source model records what was declared and where.
- The compiled model contains resolved references, composition, effective
  values, imports, and retained provenance.
- A language definition validates the compiled document.
- The artifact layer serializes the completed model for consumers.

When a question concerns effective values, composition, or emitted output, the
compiled model is authoritative. When it concerns spelling, declaration
location, navigation, or an override, inspect the source model and source
ranges as well.

Generic JSON output is domain-shaped: definition, property, and child names
become JSON member names. Fixed metadata lives under `_nx`. Do not infer a
Schema-specific wrapper or grouping that is not present in the compiled model.

## Finding the Right Evidence

For a typical task, inspect only:

1. the applicable instruction and standards files;
2. the index entry for the relevant subsystem;
3. the owning Pascal unit or NexusScript document;
4. direct callers or consumers of the affected contract;
5. focused registered tests and fixtures.

Use implementation code to settle implementation behavior and current language
definitions to settle dialect behavior. Work plans, reviews, generated text,
and documentation can explain intent, but they do not override contradictory
current code or explicit human direction.

Do not guess about a path, compiler rule, platform behavior, or ownership
boundary. Verify it. If the available evidence conflicts, state the conflict
clearly before proposing a change.

