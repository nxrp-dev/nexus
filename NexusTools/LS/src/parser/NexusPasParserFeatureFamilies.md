# NexusPas Parser Feature Families

This note summarizes the remaining `passrc` inventory after the active
NexusPas structural parser promotions.

Current inventory checkpoint:

| Status | Count |
| --- | ---: |
| Active adjusted NexusPas coverage | 712 |
| Deferred | 1250 |
| Tried and failed | 78 |
| Not applicable | 34 |

Focused suite checkpoint:

- Suite: `NexusPas.PassrcPort`
- Result: 71 passed / 71 total
- Parser fixes were not part of the promotion pass.

## Remaining Feature Families

### Resolver Semantics

Source buckets:

- `tcresolver.pas`
- `tcresolvegenerics.pas`

Needed capabilities:

- Unit and symbol resolution across scopes and units.
- Type alias and member resolution.
- Generic type and specialization resolution.
- Correct overload and visibility-aware lookup.
- Compiler-style lookup behavior beyond shallow symbol indexing.

These should not be promoted as parser-only tests until NexusPas has an
intentional resolver contract.

### Expression Parsing and Evaluation

Source bucket:

- `tcexprparser.pas`

Needed capabilities:

- Expression tree construction.
- Unary, binary, set, call, cast, array-index, inherited, and sub-identifier
  expression parsing.
- Literal interpretation where tests expect expression values or expression
  shapes.

Current NexusPas structural parsing preserves some declaration type text and
constant text, but does not claim a full expression parser/evaluator.

### Statement Parsing

Source bucket:

- `tcstatements.pas`

Needed capabilities:

- Statement AST or equivalent statement analysis contract.
- Assignment, calls, `if`, `case`, loops, `try`, `raise`, `with`, labels,
  `goto`, assembler, and nested statement handling.

These are separate from declaration-level parser coverage and should be treated
as a deliberate statement-parser feature.

### Use Analyzer

Source bucket:

- `tcuseanalyzer.pas`

Needed capabilities:

- Semantic usage analysis.
- Unused/assigned-but-unused variables and parameters.
- Unit usage diagnostics.
- Visibility and published-property awareness.
- Semantic handling for initialization, finalization, inherited calls, built-in
  functions, typeinfo, and attributes.

This belongs to a semantic analysis layer, not the current structural parser
promotion pass.

### Conditional and Macro Scanner Behavior

Source bucket:

- Remaining `tcscanner.pas` rows.

Needed capabilities:

- Conditional expression evaluation for `{$IF ...}`.
- Macro definition/expansion behavior.
- More complete compiler-directive expression semantics.
- ObjC scanner forms if NexusPas chooses to support them.

Current NexusPas supports simple directive metadata, `DEFINE`, `UNDEF`,
`IFDEF`, `IFNDEF`, `ELSE`, `ENDIF`, inactive regions, and unsupported-IF
diagnostics. The remaining scanner rows go beyond that contract.

### ObjC, External, and Attributes

Source bucket:

- Remaining `tcclasstype.pas` rows.

Needed capabilities:

- ObjC class/category/protocol syntax.
- External class syntax and external-name tails.
- Class/type/const attributes.
- Interface negative-shape validation, such as disallowed constructors,
  destructors, or fields.

These should stay deferred until NexusPas has an explicit contract for ObjC,
attributes, and stricter class/interface validation.

### Generic Constraints and Statement Specialization

Source bucket:

- Remaining `tcgenerics.pp` rows.

Needed capabilities:

- Generic constraint modeling.
- Interface constraints.
- Declaration constraint metadata.
- Inline specialization in statements.

NexusPas currently has shallow generic-looking declared-type text and generic
routine symbol coverage. Constraint semantics are not modeled yet.

### Advanced Record Negative Cases

Source bucket:

- Remaining `tctypeparser.pas` advanced-record rows.

Needed capabilities:

- Advanced record validation rules.
- Record operators and class operators.
- Disallowed record members and directives.
- More precise error/recovery behavior for malformed type declarations.

Representative failures already showed that record variants, malformed type
recovery, record const members, operator-shaped fields, and several advanced
record cases are not ready for active promotion.

## Practical Next Targets

Good next feature-family candidates, in likely order:

1. Statement parser contract, if editor features need statement context.
2. Expression parser contract, if constants, defaults, or member navigation need
   expression awareness.
3. Resolver semantics, if click-through/completion accuracy is the priority.
4. Conditional expression and macro handling, if system-source parsing keeps
   skipping valid declarations behind compiler defines.
5. Advanced record and generic constraints, once the above contracts are stable.

The remaining inventory should not be treated as easy promotion work. Each
family needs an intentional NexusPas feature contract before bulk activation.
