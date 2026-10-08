(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit obNXSetupLoader;

{$mode delphi}{$H+}

interface

uses obNXSetupModel, obNexusScriptSourceProvider, obNexusScriptModel;

type
  TNXSetupLoader = class
  public
    class function LoadFile(const AFileName: string;
      AProvider: TNexusScriptSourceProvider = nil;
      ATargets: TNexusScriptTargetSelection = nil): TNXSetupDocument; static;
  end;

implementation

uses SysUtils, obNexusScriptAnalysis, obNexusScriptLive, obNXSetupSourceContext;

class function TNXSetupLoader.LoadFile(const AFileName: string;
  AProvider: TNexusScriptSourceProvider;
  ATargets: TNexusScriptTargetSelection): TNXSetupDocument;
var
  lAnalysis: TNexusScriptAnalysis;
  lLive: TNexusScriptLiveDocument;
  lDocument: TNXSetupDocument;
  lContext: TNXSetupSourceContext;
begin
  lContext := TNXSetupSourceContext.Create(AProvider, ATargets);
  lContext.EntryName := lContext.CanonicalName(AFileName);
  lAnalysis := nil;
  lLive := nil;
  lDocument := nil;
  try
    lAnalysis := TNexusScriptAnalysis.Create(AFileName, 1, lContext, ATargets);
    lAnalysis.Execute;
    if not lAnalysis.Succeeded then raise ENXSetup.Create(lAnalysis.Session.LastError);
    if lAnalysis.EntryCompiler.CompiledDocument.DialectDocument = nil then
      raise ENXSetup.Create('A Setup dialect is required.');
    if lAnalysis.Language.DiagnosticCount > 0 then
      raise ENXSetup.Create(lAnalysis.Language.Diagnostics[0].MessageText);
    if lAnalysis.Validator.Diagnostics.Count > 0 then
      raise ENXSetup.Create(lAnalysis.Validator.Diagnostics[0].MessageText);
    lLive := TNexusScriptLiveEmitter.Emit(lAnalysis.EntryCompiler.CompiledDocument);
    lContext.Freeze;
    lDocument := TNXSetupModelBuilder.Build(lLive, lContext);
    lLive := nil; // The successfully built document now owns its provenance.
    lContext := nil;
    Result := lDocument;
    lDocument := nil;
  finally
    lAnalysis.Free;
    lDocument.Free;
    lLive.Free;
    lContext.Free;
  end;
end;

end.
