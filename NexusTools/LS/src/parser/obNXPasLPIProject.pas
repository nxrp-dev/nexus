unit obNXPasLPIProject;

{$mode objfpc}{$H+}

interface

uses
  Classes;

type
  TNXPasLPIProject = class
  private
    FFileName: string;
    FIncludePaths: TStringList;
    FMainUnitIndex: Integer;
    FProjectDir: string;
    FProjectFiles: TStringList;
    FSourcePaths: TStringList;
    FTargetCPU: string;
    FTargetFileName: string;
    FTargetOS: string;
    FTitle: string;
    FUnitOutputDirectory: string;
    FUnitPaths: TStringList;
    procedure AddDelimitedPaths(AList: TStrings; const AValue: string);
    procedure Clear;
  public
    constructor Create;
    destructor Destroy; override;

    function LoadFromFile(const AFileName: string): Boolean;

    property FileName: string read FFileName;
    property IncludePaths: TStringList read FIncludePaths;
    property MainUnitIndex: Integer read FMainUnitIndex;
    property ProjectDir: string read FProjectDir;
    property ProjectFiles: TStringList read FProjectFiles;
    property SourcePaths: TStringList read FSourcePaths;
    property TargetCPU: string read FTargetCPU;
    property TargetFileName: string read FTargetFileName;
    property TargetOS: string read FTargetOS;
    property Title: string read FTitle;
    property UnitOutputDirectory: string read FUnitOutputDirectory;
    property UnitPaths: TStringList read FUnitPaths;
  end;

implementation

uses
  DOM,
  SysUtils,
  XMLRead;

function NXPasLPIAttrValue(ANode: TDOMNode; const AName: string): string;
var
  lAttr: TDOMNode;
begin
  Result := '';
  if (ANode = nil) or (ANode.Attributes = nil) then
    Exit;

  lAttr := ANode.Attributes.GetNamedItem(DOMString(AName));
  if lAttr <> nil then
    Result := string(lAttr.NodeValue);
end;

function NXPasLPINodeValue(ANode: TDOMNode): string;
begin
  Result := NXPasLPIAttrValue(ANode, 'Value');
  if (Result = '') and (ANode <> nil) then
    Result := string(Trim(ANode.TextContent));
end;

function NXPasLPIParentName(ANode: TDOMNode): string;
begin
  if (ANode <> nil) and (ANode.ParentNode <> nil) then
    Result := LowerCase(string(ANode.ParentNode.NodeName))
  else
    Result := '';
end;

constructor TNXPasLPIProject.Create;
begin
  inherited Create;
  FIncludePaths := TStringList.Create;
  FProjectFiles := TStringList.Create;
  FSourcePaths := TStringList.Create;
  FUnitPaths := TStringList.Create;
  FMainUnitIndex := -1;
end;

destructor TNXPasLPIProject.Destroy;
begin
  FUnitPaths.Free;
  FSourcePaths.Free;
  FProjectFiles.Free;
  FIncludePaths.Free;
  inherited Destroy;
end;

procedure TNXPasLPIProject.Clear;
begin
  FFileName := '';
  FIncludePaths.Clear;
  FMainUnitIndex := -1;
  FProjectDir := '';
  FProjectFiles.Clear;
  FSourcePaths.Clear;
  FTargetCPU := '';
  FTargetFileName := '';
  FTargetOS := '';
  FTitle := '';
  FUnitOutputDirectory := '';
  FUnitPaths.Clear;
end;

procedure TNXPasLPIProject.AddDelimitedPaths(AList: TStrings;
  const AValue: string);
var
  lIdx: Integer;
  lParts: TStringList;
begin
  if (AList = nil) or (Trim(AValue) = '') then
    Exit;

  lParts := TStringList.Create;
  try
    lParts.Delimiter := ';';
    lParts.StrictDelimiter := True;
    lParts.DelimitedText := AValue;
    for lIdx := 0 to lParts.Count - 1 do
      if Trim(lParts[lIdx]) <> '' then
        AList.Add(Trim(lParts[lIdx]));
  finally
    lParts.Free;
  end;
end;

function TNXPasLPIProject.LoadFromFile(const AFileName: string): Boolean;
var
  lDoc: TXMLDocument;

  procedure ScanNode(ANode: TDOMNode);
  var
    lChild: TDOMNode;
    lName: string;
    lParentName: string;
    lValue: string;
  begin
    if ANode = nil then
      Exit;

    lName := LowerCase(string(ANode.NodeName));
    lParentName := NXPasLPIParentName(ANode);
    lValue := NXPasLPINodeValue(ANode);

    if lValue <> '' then
    begin
      if lName = 'title' then
        FTitle := lValue
      else if lName = 'mainunit' then
        FMainUnitIndex := StrToIntDef(lValue, -1)
      else if (lName = 'filename') and (lParentName = 'target') then
        FTargetFileName := lValue
      else if (lName = 'filename') and (Pos('unit', lParentName) = 1) then
        AddDelimitedPaths(FProjectFiles, lValue)
      else if lName = 'otherunitfiles' then
        AddDelimitedPaths(FUnitPaths, lValue)
      else if lName = 'includefiles' then
        AddDelimitedPaths(FIncludePaths, lValue)
      else if (lName = 'sourcepath') or (lName = 'sourcepaths') or
        (lName = 'srcpath') then
        AddDelimitedPaths(FSourcePaths, lValue)
      else if lName = 'unitoutputdirectory' then
        FUnitOutputDirectory := lValue
      else if lName = 'targetcpu' then
        FTargetCPU := lValue
      else if lName = 'targetos' then
        FTargetOS := lValue;
    end;

    lChild := ANode.FirstChild;
    while lChild <> nil do
    begin
      ScanNode(lChild);
      lChild := lChild.NextSibling;
    end;
  end;

begin
  Result := False;
  Clear;
  if not FileExists(AFileName) then
    Exit;

  FFileName := ExpandFileName(AFileName);
  FProjectDir := ExtractFileDir(FFileName);
  lDoc := nil;
  try
    ReadXMLFile(lDoc, FFileName);
    ScanNode(lDoc.DocumentElement);
    Result := True;
  finally
    lDoc.Free;
  end;
end;

end.
