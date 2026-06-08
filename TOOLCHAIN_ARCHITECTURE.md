# Toolchain Configuration Architecture Notes

## Ownership

Toolchain configuration behavior belongs to NexusLS.

The VS Code extension owns the GUI. It asks NexusLS what toolchains exist, what
fields they require, how those fields validate, and what suggestions should be
shown.

VS Code settings are storage for user choices. They are not the source of
toolchain behavior.

## Compatibility

This is active development code. Do not add compatibility bridges, fallback
settings, old-name aliases, or one-time migrations unless they are explicitly
approved as a current requirement.

If a new contract is wrong or incomplete, it should fail visibly so it can be
corrected before release.

## RPC Contracts

Objects that cross the JSON-RPC protocol boundary should derive through the
JSON-RPC object chain.

Published properties on RPC payload objects should also use JSON-RPC leaf types.
For example, a toolchain RPC contract should use `TNXJSONRPCString` and
`TNXJSONRPCBoolean`, not plain JSON leaf types.

Internal helper objects, validators, factories, and behavior-only classes do not
need JSON-RPC ancestry unless they themselves cross the protocol boundary.

## Toolchain Model

Supported toolchains are discovered from NexusLS, not hard-coded by the
extension UI.

Current toolchain kinds include:

- Lazarus
- Free Pascal
- Android

Toolchain kinds are selected by payload data. They are not protocol method
namespaces.

## Validation

Validation is field-level.

Each field may have one or more validators. Validators are responsible for:

- deciding whether the field value is valid
- setting field-specific messages
- providing local path suggestions
- providing install or download URL suggestions

Validation should explain what is wrong and, when possible, what the user can do
next.

Invalid partial toolchain settings may still be saved. Saving records the user's
current configuration; it does not mean the toolchain is ready to build.

## Suggestions

Suggestions are produced by NexusLS and rendered by the extension.

Path suggestions should use limited, explicit checks such as known install
locations or environment variables. Do not perform broad disk scans.

URL suggestions are allowed when a required external tool cannot be found
locally. Download links may change over time and should be updated as needed.

## Derived Values

Derived values belong in NexusLS next to the source toolchain configuration.

Examples include:

- Lazarus source directory derived from the Lazarus install directory
- bundled Free Pascal directory derived from a Lazarus install
- Free Pascal source directory derived from the Free Pascal install directory
- resolved compiler path derived from the Free Pascal install directory

The extension should not derive these values.

Some derived values may later become explicit overrideable properties, but the
knowledge for deriving and validating them should remain centralized in the
toolchain model.

## Current Layout

Toolchain support lives under `NexusLS/src/toolchain`.

Current unit boundaries:

- `obNXLSToolchainContracts.pas`
  - toolchain RPC/data contract classes
  - toolchain base class
  - concrete toolchain model classes
  - field and validator contract classes
- `obNXLSToolchainSupport.pas`
  - path normalization helpers
  - tool executable probing
  - limited install path suggestions
  - download URL suggestions
- `NexusLS/src/service/obNXLSToolchainService.pas`
  - thin NexusLS service routing facade

The next split, when needed, should separate:

- validators
- Lazarus toolchain
- Free Pascal toolchain
- Android toolchain

Do not split purely for aesthetics. Split when it makes ownership clearer and
keeps each unit responsible for one obvious part of the toolchain system.
