unit obNXLSDiagnosticsService;

{$mode objfpc}{$H+}

interface

uses
  fpjson,
  obNXLSServiceContext;

type
  TNXLSDiagnosticsService = class(TNXLSLSPService)
  private
    procedure AddDiagnostic(ADiagnostics: TJSONArray; const AMessage: string;
      ALine, AColumn: Integer);
    procedure PublishDiagnostics(ADocument: TNXLSDocument;
      ADiagnostics: TJSONArray);
    procedure ShowSyntaxError(const AMessage: string);
    function CodeToolsCheckSyntax(ADocument: TNXLSDocument;
      ADiagnostics: TJSONArray): Boolean;
    function StrictSyntaxCheck(ADocument: TNXLSDocument;
      ADiagnostics: TJSONArray): Boolean;
  public
    procedure CheckDocument(ADocument: TNXLSDocument); virtual;
  end;

implementation

uses
  Classes,
  SysUtils,
  Types,
  CodeCache,
  CodeToolManager,
  PParser,
  PScanner,
  PasTree;

type
  TNXLSPasTreeEngine = class(TPasTreeContainer)
  public
    function CreateElement(AClass: TPTreeElement; const AName: string;
      AParent: TPasElement; AVisibility: TPasMemberVisibility;
      const ASourceFilename: string; ASourceLinenumber: Integer): TPasElement; override;
    function FindElement(const AName: string): TPasElement; override;
  end;

  TNXLSCodeBufferFileResolver = class(TFileResolver)
  private
    FBuffer: TCodeBuffer;
  protected
    function CreateLineReaderFromBuffer(ABuffer: TCodeBuffer): TLineReader;
  public
    constructor Create(ABuffer: TCodeBuffer); reintroduce;
    function FindSourceFile(const AName: string): TLineReader; override;
  end;

  TNXLSSyntaxParser = class
  private
    FCode: TCodeBuffer;
    FCommandLine: TStringDynArray;
    FCPUTarget: string;
    FOSTarget: string;
    function CheckCommandLine(out AFileName: string; AScanner: TPascalScanner;
      AFileResolver: TBaseFileResolver): Boolean;
  public
    function Check(out AMessage: string; out ALine, AColumn: Integer): Boolean;

    property Code: TCodeBuffer read FCode write FCode;
    property CommandLine: TStringDynArray read FCommandLine write FCommandLine;
    property OSTarget: string read FOSTarget write FOSTarget;
    property CPUTarget: string read FCPUTarget write FCPUTarget;
  end;

const
  cPublishDiagnosticsMethod = 'textDocument/publishDiagnostics';
  cShowMessageMethod = 'window/showMessage';
  cDiagnosticSource = 'nexusls';

function TNXLSPasTreeEngine.CreateElement(AClass: TPTreeElement;
  const AName: string; AParent: TPasElement;
  AVisibility: TPasMemberVisibility; const ASourceFilename: string;
  ASourceLinenumber: Integer): TPasElement;
begin
  Result := AClass.Create(AName, AParent);
  Result.Visibility := AVisibility;
  Result.SourceFilename := ASourceFilename;
  Result.SourceLinenumber := ASourceLinenumber;
end;

function TNXLSPasTreeEngine.FindElement(const AName: string): TPasElement;
begin
  Result := nil;
end;

constructor TNXLSCodeBufferFileResolver.Create(ABuffer: TCodeBuffer);
begin
  inherited Create;
  FBuffer := ABuffer;
end;

function TNXLSCodeBufferFileResolver.CreateLineReaderFromBuffer(
  ABuffer: TCodeBuffer): TLineReader;
var
  lReader: TStreamLineReader;
begin
  lReader := TStreamLineReader.Create(ABuffer.FileName);
  lReader.InitFromString(ABuffer.Source);
  Result := lReader;
end;

function TNXLSCodeBufferFileResolver.FindSourceFile(
  const AName: string): TLineReader;
begin
  if (FBuffer <> nil) and SameFileName(AName, FBuffer.FileName) then
    Result := CreateLineReaderFromBuffer(FBuffer)
  else
    Result := inherited FindSourceFile(AName);
end;

function TNXLSSyntaxParser.CheckCommandLine(out AFileName: string;
  AScanner: TPascalScanner; AFileResolver: TBaseFileResolver): Boolean;
var
  lArg: string;
  lIdx: Integer;
begin
  Result := True;
  AFileName := '';

  for lArg in FCommandLine do
  begin
    if lArg = '' then
      Continue;

    if (lArg[1] = '-') and (Length(lArg) > 1) then
    begin
      case lArg[2] of
        'd':
          AScanner.AddDefine(UpperCase(Copy(lArg, 3, MaxInt)));
        'u':
          AScanner.RemoveDefine(UpperCase(Copy(lArg, 3, MaxInt)));
        'F':
          if (Length(lArg) > 2) and (lArg[3] = 'i') then
            AFileResolver.AddIncludePath(Copy(lArg, 4, MaxInt));
        'I':
          AFileResolver.AddIncludePath(Copy(lArg, 3, MaxInt));
        'S':
          if Length(lArg) > 2 then
            for lIdx := 3 to Length(lArg) do
              case lArg[lIdx] of
                'c':
                  AScanner.Options := AScanner.Options + [po_cassignments];
                'd':
                  AScanner.SetCompilerMode('DELPHI');
                '2':
                  AScanner.SetCompilerMode('OBJFPC');
              end;
        'M':
          AScanner.SetCompilerMode(Copy(lArg, 3, MaxInt));
      end;
    end
    else if AFileName <> '' then
    begin
      Result := False;
      Exit;
    end
    else
      AFileName := lArg;
  end;
end;

function TNXLSSyntaxParser.Check(out AMessage: string; out ALine,
  AColumn: Integer): Boolean;
var
  lEngine: TNXLSPasTreeEngine;
  lFileResolver: TBaseFileResolver;
  lScanner: TPascalScanner;
  lParser: TPasParser;
  lModule: TPasModule;
  lFileName: string;
  lTarget: string;
begin
  Result := False;
  AMessage := '';
  ALine := 0;
  AColumn := 0;
  lEngine := nil;
  lFileResolver := nil;
  lScanner := nil;
  lParser := nil;
  lModule := nil;

  if FCode = nil then
  begin
    AMessage := 'Code buffer is required for syntax diagnostics.';
    Exit;
  end;

  try
    lEngine := TNXLSPasTreeEngine.Create;
    lFileResolver := TNXLSCodeBufferFileResolver.Create(FCode);
    lScanner := TPascalScanner.Create(lFileResolver);
    lScanner.LogEvents := lEngine.ScannerLogEvents;
    lScanner.OnLog := lEngine.OnLog;

    lScanner.AddDefine('FPK');
    lScanner.AddDefine('FPC');
    lTarget := UpperCase(FOSTarget);
    if lTarget <> '' then
      lScanner.AddDefine(lTarget);
    case lTarget of
      'LINUX', 'BEOS', 'QNX':
        lScanner.AddDefine('UNIX');
      'DARWIN':
        begin
          lScanner.AddDefine('DARWIN');
          lScanner.AddDefine('UNIX');
        end;
      'FREEBSD', 'NETBSD':
        begin
          lScanner.AddDefine('BSD');
          lScanner.AddDefine('UNIX');
        end;
      'SUNOS':
        begin
          lScanner.AddDefine('SOLARIS');
          lScanner.AddDefine('UNIX');
        end;
      'GO32V2':
        lScanner.AddDefine('DPMI');
      'AROS', 'MORPHOS', 'AMIGA':
        lScanner.AddDefine('HASAMIGA');
    end;

    lTarget := UpperCase(FCPUTarget);
    if lTarget <> '' then
      lScanner.AddDefine('CPU' + lTarget);
    if lTarget = 'X86_64' then
      lScanner.AddDefine('CPU64')
    else
      lScanner.AddDefine('CPU32');

    lParser := TPasParser.Create(lScanner, lFileResolver, lEngine);
    lParser.LogEvents := lEngine.ParserLogEvents;
    lParser.OnLog := lEngine.OnLog;

    if not CheckCommandLine(lFileName, lScanner, lFileResolver) then
    begin
      AMessage := 'Only one source file can be checked for syntax diagnostics.';
      Exit;
    end;

    if lFileName = '' then
    begin
      AMessage := 'Source file is required for syntax diagnostics.';
      Exit;
    end;

    lFileResolver.AddIncludePath(ExtractFilePath(lFileName));
    lScanner.OpenFile(FCode.FileName);
    try
      lParser.ParseMain(lModule);
      Result := True;
    except
      on E: Exception do
      begin
        AMessage := E.Message;
        ALine := lParser.CurSourcePos.Row;
        AColumn := lParser.CurSourcePos.Column;
      end;
    end;
  finally
    lModule.Free;
    lParser.Free;
    lScanner.Free;
    lFileResolver.Free;
    lEngine.Free;
  end;
end;

procedure TNXLSDiagnosticsService.AddDiagnostic(ADiagnostics: TJSONArray;
  const AMessage: string; ALine, AColumn: Integer);
var
  lDiagnostic: TJSONObject;
  lRange: TJSONObject;
  lStart: TJSONObject;
  lEnd: TJSONObject;
begin
  if ADiagnostics = nil then
    Exit;

  if ALine < 0 then
    ALine := 0;
  if AColumn < 0 then
    AColumn := 0;

  lDiagnostic := TJSONObject.Create;
  ADiagnostics.Add(lDiagnostic);

  lRange := TJSONObject.Create;
  lDiagnostic.Add('range', lRange);

  lStart := TJSONObject.Create;
  lStart.Add('line', ALine);
  lStart.Add('character', AColumn);
  lRange.Add('start', lStart);

  lEnd := TJSONObject.Create;
  lEnd.Add('line', ALine);
  lEnd.Add('character', AColumn + 1);
  lRange.Add('end', lEnd);

  lDiagnostic.Add('severity', 1);
  lDiagnostic.Add('source', cDiagnosticSource);
  lDiagnostic.Add('message', AMessage);
end;

procedure TNXLSDiagnosticsService.PublishDiagnostics(ADocument: TNXLSDocument;
  ADiagnostics: TJSONArray);
var
  lParams: TJSONObject;
begin
  if (ADocument = nil) or (not Model.PublishDiagnosticsEnabled) then
    Exit;

  lParams := TJSONObject.Create;
  try
    lParams.Add('uri', ADocument.URI);
    if ADiagnostics = nil then
      lParams.Add('diagnostics', TJSONArray.Create)
    else
      lParams.Add('diagnostics', ADiagnostics.Clone);

    Model.SendNotification(cPublishDiagnosticsMethod, lParams);
  finally
    lParams.Free;
  end;
end;

procedure TNXLSDiagnosticsService.ShowSyntaxError(const AMessage: string);
var
  lParams: TJSONObject;
begin
  if (AMessage = '') or (not Model.ShowSyntaxErrorsEnabled) then
    Exit;

  lParams := TJSONObject.Create;
  try
    lParams.Add('type', 1);
    lParams.Add('message', AMessage);
    Model.SendNotification(cShowMessageMethod, lParams);
  finally
    lParams.Free;
  end;
end;

function TNXLSDiagnosticsService.CodeToolsCheckSyntax(ADocument: TNXLSDocument;
  ADiagnostics: TJSONArray): Boolean;
var
  lTool: TCodeTool;
  lLine: Integer;
  lColumn: Integer;
  lMessage: string;
begin
  Result := True;
  lTool := nil;

  if CodeToolBoss.Explore(ADocument.CodeBuffer, lTool, True) then
    Exit;

  Result := False;
  lLine := CodeToolBoss.ErrorLine - 1;
  lColumn := CodeToolBoss.ErrorColumn - 1;
  lMessage := CodeToolBoss.ErrorMessage;
  if lMessage = '' then
    lMessage := 'CodeTools syntax check failed.';

  AddDiagnostic(ADiagnostics, lMessage, lLine, lColumn);
  ShowSyntaxError(Format('%s @ %d:%d', [lMessage, lLine + 1, lColumn + 1]));
end;

function TNXLSDiagnosticsService.StrictSyntaxCheck(ADocument: TNXLSDocument;
  ADiagnostics: TJSONArray): Boolean;
var
  lParser: TNXLSSyntaxParser;
  lArgs: TStringDynArray;
  lIdx: Integer;
  lMessage: string;
  lLine: Integer;
  lColumn: Integer;
begin
  Result := True;
  lArgs := nil;

  lParser := TNXLSSyntaxParser.Create;
  try
    SetLength(lArgs, Model.EffectiveFPCOptionList.Count + 1);
    for lIdx := 0 to Model.EffectiveFPCOptionList.Count - 1 do
      lArgs[lIdx] := Model.EffectiveFPCOptionList[lIdx];
    lArgs[High(lArgs)] := ADocument.LocalPath;

    lParser.Code := ADocument.CodeBuffer;
    lParser.CommandLine := lArgs;
    lParser.OSTarget := {$i %FPCTARGETOS%};
    lParser.CPUTarget := {$i %FPCTARGETCPU%};

    if lParser.Check(lMessage, lLine, lColumn) then
      Exit;

    Result := False;
    if lMessage = '' then
      lMessage := 'Strict syntax check failed.';
    AddDiagnostic(ADiagnostics, lMessage, lLine - 1, lColumn - 1);
    ShowSyntaxError(Format('%s @ %d:%d', [lMessage, lLine, lColumn]));
  finally
    lParser.Free;
  end;
end;

procedure TNXLSDiagnosticsService.CheckDocument(ADocument: TNXLSDocument);
var
  lDiagnostics: TJSONArray;
  lCodeOK: Boolean;
begin
  if (ADocument = nil) or (ADocument.CodeBuffer = nil) then
    Exit;

  if not Model.CheckSyntaxEnabled then
    Exit;

  if (not Model.PublishDiagnosticsEnabled) and
    (not Model.ShowSyntaxErrorsEnabled) then
    Exit;

  lDiagnostics := TJSONArray.Create;
  try
    try
      lCodeOK := CodeToolsCheckSyntax(ADocument, lDiagnostics);
      if lCodeOK then
        lCodeOK := StrictSyntaxCheck(ADocument, lDiagnostics);

      if lCodeOK then
        PublishDiagnostics(ADocument, nil)
      else
        PublishDiagnostics(ADocument, lDiagnostics);
    except
      on E: Exception do
      begin
        AddDiagnostic(lDiagnostics, E.Message, 0, 0);
        ShowSyntaxError(E.Message);
        PublishDiagnostics(ADocument, lDiagnostics);
      end;
    end;
  finally
    lDiagnostics.Free;
  end;
end;

end.
