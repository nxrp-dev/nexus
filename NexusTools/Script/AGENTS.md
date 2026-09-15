# NexusScript Agent Instructions

These rules apply to `NexusTools/Script`.

## Standards

- Follow `../../.ai/standards/pascal.md` for Object Pascal code.
- Keep the compiler domain-neutral. Maintained schema scripts belong under `NexusLib/script/`.
- Test-only and deliberately invalid fixtures stay with their test suites.

## Required Regression Checks

- After compiler, validation, inclusion, or presentation changes, build and run
  the complete `tests/NexusScriptTests.lpi` console suite.
- After shared compiler/model/session/validation changes or language-server
  changes, also build and run `ls/tests/NexusScriptLSTests.lpi`.
- Run both suites for changes whose effect on editor analysis is uncertain.
- Test success requires zero failures, errors, or unexpected skips. Report the
  actual totals and any unrun required checks.
- Expected-output fixtures express intended behavior. Do not regenerate or
  weaken them merely to match changed implementation output. Explain any
  intentional contract change and review its expected-output diff.
- See `docs/regression-checks.md` for commands and coverage.
