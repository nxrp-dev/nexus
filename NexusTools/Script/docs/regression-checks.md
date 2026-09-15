# NexusScript regression checks

These checks protect the language's behavior across compilation, includes,
validation, presentation, and editor updates. They supplement focused tests;
they do not replace reviewing an intentional contract change.

From the repository root:

```powershell
lazbuild -B NexusTools\Script\tests\NexusScriptTests.lpi
& .\output\NexusScript\console-tests\x86_64-win64\NexusScriptTests.exe
lazbuild -B NexusTools\Script\ls\tests\NexusScriptLSTests.lpi
& .\output\NexusScriptLS\console-tests\x86_64-win64\NexusScriptLSTests.exe
```

Both runners use the existing NexusTest cases, fail on errors or unexpected
skips, and enable heap and debug-line checks. The compiler suite is required for
compiler/validation/include/presentation corrections. The language-server suite
is additionally required for changes to shared compiler behavior or editor code.
These are repository verification requirements; no CI toolchain installation was
added by this change.

## Contract cases

| Case | Behavior protected |
| --- | --- |
| `IncludeFileEquivalence` | The same nine-table system in one file or included files has equivalent JSON, validation, and generated output. Only source provenance is removed from the JSON comparison, and the test separately requires the original provenance to differ. |
| `CompleteSQLContract` | Complete generated SQL is compared with a handwritten fixture, including columns, order, an index, and a foreign-key target. Only platform line endings are normalized. |
| `TargetedIncludeCollections` | Selected definitions and selected language fragments agree, excluded kinds/rules stay absent, and a shared dependency reached through module plus diamond includes contributes once. |
| `IncludeModuleCollections` | A module-only base is not generated independently. Including it exposes it once; a derived field override does not change the base or a reference to the original. Root-name conflicts are also checked with different casing. |
| `StructuralReferenceAliasJSON` | A property referencing another structural-reference property presents the original definition. This is isolated from includes so a failure cannot hide the include assertions. |
| `EmitterFailureAndLifetime` | An emission failure after staging valid content does not alter previous output; the emitter remains usable. Recompilation and destruction of source documents cannot corrupt copied JSON. |
| `IncludedDefinitionRefresh` (LS) | Editing an included overlay changes names and values in dependent analyses; removing all definitions leaves no stale contributions. |
| `IncludedLanguageRefresh` (LS) | Replacing an included rule removes the old rule and updates diagnostics; malformed dependencies fail, and subsequent correction restores clean analysis. |

The SQL expectation is
`tests/fixtures/include-collections/SQL.expected.txt`. It was written from the
small fixture's intended schema, not captured from generated output. No test or
helper rewrites it. Changes to the language contract require reviewing the
expected-output diff explicitly, rather than accepting whatever the compiler
currently emits.

The existing individual feature tests continue to cover composition, arrays,
references, targets, discovery, diagnostics, metadata, manifests, and external
data. The cases above protect their interactions.

## Findings from the added checks

The initial strengthened `IncludeModuleCollections` assertion incorrectly required
`Concrete.Original` to contain the base's structural `Fields` array. Existing
`ReferenceArrayProjection` tests explicitly require these arrays to be omitted
to bound recursive expansion. The corrected test checks that omission, original
reference identity, unchanged base fields, the derived override, and explicit
access through `@Base.Fields.ID.Type`. This corrects a test expectation, not the
language contract. See [the projection boundary](include-presentation.md#reference-projection-boundary).

`StructuralReferenceAliasJSON` reproduced a second problem without any include
or module: `Thing Root { Thing Base { Value: original; } Original: @Root.Base;
Alias: @Original; }` compiled, but JSON emission reported
`Property has no completed artifact value.`

The property-reference evaluator now clones the completed structural projection
and preserves its original reference identity. The regression passes, including
forward alias chains, independently owned projections, unchanged base values,
receiving names, original reference identity, and cycle rejection.
