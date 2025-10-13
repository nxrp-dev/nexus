NXRP-X Core (v1.0) — FreePascal units (fixed)

Units:
- obNxTypes.pas   — TNxVal AST + containers (TNxMap/TNxList). Added TStringArray/TNxValArray typedefs.
- obNxBin.pas     — NXBIN codec (encode/decode, canonical maps, UTF-8 validation). Replaced '!=' with '<>' and fixed bit op.
- obNxFrame.pas   — Transport framing header + Synapse read/write helpers. Uses CompareMem for magic compare.
- obNxRpcCore.pas — TNXRPObject/TNXRPList (published-property streaming), registry, name-map lookups. Uses LowerCase for case-folding.

Notes:
- Requires FPC {$mode objfpc}{$H+} and Synapse for obNxFrame (blcksock).
- Register each TNXRPObject descendant with TNXRPRegistry.RegisterType('TypeId', TClass) before decoding.
- TNXRPList supports optional non-unique name index: EnableNameIndex(...).
