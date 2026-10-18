# fpGUI Collections AVL consolidation

Authorized 2026-10-18 by “make the change” and the direction to consolidate
generic containers around a common implementation.

## Scope and baseline

Convert fpGUI listview selection, both translation tools and the Lab AVL example
to `Generics.Collections`; retire the standalone FCL AVL implementation and
namespace registration once no consumers remain. Contnrs is retained.

Untouched sources, hashes and all generated verification files are outside
source checkouts at `/media/kcollins/dev/worktree/collections-avl`.
NexusFPC baseline: `8976685dafd97146ea8a14a576e161cfabc173ca`.

## Verified behavior and finding

- The baseline and converted GUI both pass 569 nxtest cases, including three
  new selection cases: idempotent notifications, Shift-range snapshots and
  clearing selection without destroying items.
- The Collections suite passes all 211 cases.
- Both old and converted translation mergers produce identical output for
  duplicate IDs, case-sensitive IDs, UTF-8, multiline strings, empty source
  catalogs and 600-entry catalogs with alternating removals.
- **Proven preexisting include-generator bug:** a valid PO header without a
  comment raises EAccessViolation in `CreateMsgItemClass`, which indexes
  `MsgItem^.Comment[1]` without checking for an empty string. The untouched
  executable exits 217. The direct nxtest process regression fails against
  that executable and passes after adding the empty-comment guard.

## Implementation

- Listview selection and Shift snapshots use typed Collections AVL sets.
  Copies contain item references; clearing a selection removes each reference
  before notifying and does not destroy listview items.
- Translation catalogs use `TAVLTreeMap<string, PMsgItem>` with the original
  case-sensitive `CompareStr` ordering. Keys are explicit strings, and message
  records retain explicit ownership. The include generator's object list is
  also a typed Collections list with object ownership enabled.
- The Lab demo uses a typed string/integer AVL map, checks traversal against
  its bitset and verifies that iteration makes no key comparisons. Its native
  recipe is registered in Lab Forge.
- FCL `src/avl_tree.pas`, `namespaced/Fcl.AVLTree.pas` and their namespace-map
  entry are removed. No compatibility unit, alias or replacement tree engine
  was introduced. Attribution history is preserved in root `ATTRIBUTIONS.md`.

## Final verification

| Check | Result |
| --- | --- |
| Untouched fpGUI plus selection behavior tests | 569 passed; 0 failed/errors/skipped |
| Converted fpGUI plus the same tests | 569 passed; 0 failed/errors/skipped |
| Full Collections suite | 211 passed; 0 failed/errors/skipped |
| PO-header nxtest against untouched include generator | Expected failure, exit 217 in child |
| PO-header nxtest against corrected include generator | 1 passed; 0 failed/errors/skipped |
| Four translation-merge fixtures | Byte-identical old/new output; second runs do not rewrite unchanged files |
| Include-generation fixture with a commented header | Byte-identical old/new output, including first-duplicate handling and input order |
| Lab AVL example | Builds and runs; bitset, traversal and consistency checks pass |
| Native translation project and Lab Forge | Target-aware nxbuild validation and NexusScript validation pass |
| Active Pascal/build/namespace references across the Nexus checkouts | No FGL or standalone FCL AVL imports remain |

The translation fixtures cover case-sensitive and duplicate IDs, UTF-8/BOM
inputs, multiline input, empty catalogs and 600-entry catalogs with alternating
removals. These compare existing output behavior; they are not a full PO-parser
review. The separate uncommented-header case proves the corrected crash.

`TranslationTools.nxproject` builds both tools and their direct nxtest runner.
Run that runner with the include-generator executable as its first argument.
Its temporary fixture is removed on both success and failure.

All generated files are under `/media/kcollins/dev/worktree/collections-avl`.
The worktree contains `baseline-hashes.json`, `BaselineGUI.nxproject`,
`BaselineTools.nxproject`, `Generics.nxproject`, `verify.py`, `verify-tools.py`,
`translation-results.json`, `results.json` and detailed logs.

Validation ran on Linux x86-64 with native NexusFPC. Other target builds were
not executed. Unrelated concurrent compiler and PasZLib changes were preserved.
