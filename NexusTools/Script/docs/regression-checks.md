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

## Unresolved findings from the added checks

The strengthened `IncludeModuleCollections` case finds that `Concrete.Original`
retains reference metadata for `Base` but lacks the base's `Fields` in JSON.
The separately emitted base still has its fields. The test requires the referenced
base to retain its contents, not merely its name.

`StructuralReferenceAliasJSON` reproduces a second problem without any include
or module: `Thing Root { Thing Base { Value: original; } Original: @Root.Base;
Alias: @Original; }` compiles, but JSON emission reports
`Property has no completed artifact value.`

These remain ordinary failing tests, not skipped tests or expected failures.
The regression-test change does not modify production reference behavior.
The compiler suite must not be reported as passing until these are resolved.
