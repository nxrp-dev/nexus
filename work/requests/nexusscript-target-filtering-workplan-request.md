# Request for Work Plan: NexusScript Target-Based Compilation Filtering

Draft a focused work plan for completing target-based compilation filtering in NexusScript.

## Goal

NexusScript definitions may carry Targets using the existing bracket-list syntax:

```nexusscript
Thing Example[Dev] {
}

Thing Shared[Dev, QA, Prod] {
}

Thing Universal {
}
```

Targets are compile-time selection criteria. This mechanism is primarily intended for build-oriented dialects, but it remains a core NexusScript capability.

The compiler should support both untargeted and targeted compilation.

## Intended Semantics

Untargeted compilation:

```text
Compile(File)
```

does not apply target filtering and produces the complete model.

Targeted compilation:

```text
Compile(File, Target=Dev)
```

filters definitions before normal composition and effective-value resolution.

Selection rules:

- A definition with no Targets applies to all Targets.
- A definition with one Target applies only when that Target is selected.
- Multiple Targets use OR semantics.
- `[Dev, QA, Prod]` means the definition applies to Dev OR QA OR Prod.
- A definition whose Target list does not contain the selected Target is excluded from targeted compilation.
- Existing Target identity remains case-sensitive.

Example:

```nexusscript
Thing A {
}

Thing B[Dev] {
}

Thing C[QA, Prod] {
}
```

Compiling for `Dev` includes `A` and `B`, and excludes `C`.

Untargeted compilation includes all three.

## Doctype Behavior

Do not add target-selection syntax to the doctype reference.

The doctype document is loaded normally. Definitions inside that document follow the same Target filtering rules as definitions anywhere else if they carry Targets.

Do not introduce any other doctype-specific Target behavior.

## Required Work

Review the current NexusScript Target representation and compiler pipeline, then produce the minimum work plan required to:

1. correct the existing public/model terminology from `Tags` to `Targets`, including source-model names, compiled-model names, artifact-model names, parser variables and diagnostics, tests, documentation, and emitted `_nx.Targets` metadata;
2. confirm how Targets are currently stored in the source and compiled model;
3. add an optional selected Target to the compilation request/API;
4. apply Target filtering while constructing the compiled model, before normal composition and effective-value resolution;
5. preserve existing untargeted compilation behavior as a full, unfiltered compilation;
6. apply the same selected Target through included, module, discovered, and doctype documents;
7. apply Target filtering recursively to definitions at all supported nesting levels;
8. preserve the parsed source model unchanged while producing a filtered compiled model;
9. add focused tests for untargeted definitions, single-Target definitions, multi-Target OR behavior, matching and non-matching Targets, case-sensitive matching, nested filtering, propagation through related documents, and untargeted compilation;
10. add a focused composition test proving that a selected definition can compose an included matching Target, while composition against an excluded Target fails through the existing unresolved-composition diagnostic.

## Scope

Keep the work plan limited to core NexusScript Target filtering.

Do not include PasBuild integration, dependency resolution, project modeling, CLI redesign, package management, or unrelated language changes.

Do not add new Target concepts, special keywords, selection modes, safety mechanisms, or extra requirements beyond what is needed to implement the semantics above.
