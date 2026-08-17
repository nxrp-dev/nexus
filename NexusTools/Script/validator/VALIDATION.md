# NexusScript Validator

The Validator is a final NexusScript consumer. It accepts an already compiled
subject document and an already compiled validator-definition document through
`TNexusScriptValidator.Validate`. It does not parse source, resolve references,
select validators from filenames, or mutate either document.

Validator definitions are ordinary NexusScript. The engine assigns meaning to
seven consumer-defined kinds:

- `Language`
- `Definition`
- `Property`
- `Child`
- `Value`
- `Array`
- `Reference`

`Parents` and `Children` are independent. `Parents` restricts where a child
kind may occur. `Children` restricts and counts what a parent accepts. If both
are present, both apply; neither requires a reciprocal declaration.

Validation uses final compiled structure. It separately retains and checks
source form when a rule requires `Text`, `Array`, `Reference`,
`TextComposition`, or `InlineDefinition`. Reference rules inspect the compiled
resolved target and never re-resolve source text.

`AllowedValues` is the finite-value constraint. On a `Value` rule it restricts
effective scalar text. On an `Array` rule it restricts every scalar entry.
Comparisons are case-insensitive, matching the Validator engine's finite
vocabulary. It does not provide predicates, expressions, or pattern matching.

Diagnostics are validator-owned and contain severity, code, message, primary
source range, and related source ranges. Codes beginning `NSV1` describe an
invalid validator definition. Codes beginning `NSV2` or `NSV3` describe an
invalid subject.

The bootstrap fixture is `fixtures/Validator.nxscript`. It is
compiled normally, normalized by the engine's concrete validator vocabulary,
and then validated against its own normalized rules. No parser mode or second
meta-validator is involved.

Documents associate their semantic document type explicitly with `doctype`.
The Validator API does not infer, locate, or enforce validator filenames; a
caller may pass a compiled document's `DoctypeDocument` to `Validate`.
