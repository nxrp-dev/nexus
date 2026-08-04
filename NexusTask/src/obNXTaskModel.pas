unit obNXTaskModel;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs, tpNXTask;

type
  TNXTaskSourceRange = class
  private
    FFileName: string;
    FLine: Integer;
    FColumn: Integer;
  public
    constructor Create(const AFileName: string; ALine, AColumn: Integer);
    function Text: string;
    property FileName: string read FFileName write FFileName;
    property Line: Integer read FLine write FLine;
    property Column: Integer read FColumn write FColumn;
  end;

  TNXTaskDiagnostic = class
  private
    FSeverity: TNXTaskSeverity;
    FCode: string;
    FMessage: string;
    FRange: TNXTaskSourceRange;
    FRelated: TStringList;
  public
    constructor Create(ASeverity: TNXTaskSeverity; const ACode, AMessage: string;
      ARange: TNXTaskSourceRange);
    destructor Destroy; override;
    procedure AddRelated(const AText: string);
    function Text: string;
    property Severity: TNXTaskSeverity read FSeverity;
    property Code: string read FCode;
    property Message: string read FMessage;
    property Range: TNXTaskSourceRange read FRange;
    property Related: TStringList read FRelated;
  end;

  TNXTaskDiagnostics = class
  private
    FItems: TObjectList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Add(ASeverity: TNXTaskSeverity; const ACode, AMessage: string;
      ARange: TNXTaskSourceRange);
    procedure AddWithRelated(ASeverity: TNXTaskSeverity; const ACode,
      AMessage: string; ARange: TNXTaskSourceRange; const ARelated: string);
    function HasErrors: Boolean;
    function Count: Integer;
    function Item(AIndex: Integer): TNXTaskDiagnostic;
  end;

  TNXTaskReference = class
  private
    FExternalFile: string;
    FPath: string;
    FPropertyName: string;
    FSourceRange: TNXTaskSourceRange;
    FDeclarationFile: string;
  public
    constructor Create(const AExternalFile, APath, APropertyName: string;
      ASourceRange: TNXTaskSourceRange; const ADeclarationFile: string);
    destructor Destroy; override;
    function Identity(AKind: TNXTaskReferenceKind; const ABaseFile: string): string;
    property ExternalFile: string read FExternalFile;
    property Path: string read FPath;
    property PropertyName: string read FPropertyName;
    property SourceRange: TNXTaskSourceRange read FSourceRange;
    property DeclarationFile: string read FDeclarationFile;
  end;

  TNXTaskValue = class
  private
    FKind: TNXTaskValueKind;
    FStringValue: string;
    FIntegerValue: Int64;
    FFloatValue: Double;
    FBooleanValue: Boolean;
    FReference: TNXTaskReference;
    FSourceRange: TNXTaskSourceRange;
  public
    destructor Destroy; override;
    function Clone: TNXTaskValue;
    function CanonicalText: string;
    class function CreateString(const AValue: string; ARange: TNXTaskSourceRange): TNXTaskValue;
    class function CreateInteger(AValue: Int64; ARange: TNXTaskSourceRange): TNXTaskValue;
    class function CreateFloat(AValue: Double; ARange: TNXTaskSourceRange): TNXTaskValue;
    class function CreateBoolean(AValue: Boolean; ARange: TNXTaskSourceRange): TNXTaskValue;
    class function CreateReference(AReference: TNXTaskReference; ARange: TNXTaskSourceRange): TNXTaskValue;
    property Kind: TNXTaskValueKind read FKind;
    property StringValue: string read FStringValue;
    property IntegerValue: Int64 read FIntegerValue;
    property FloatValue: Double read FFloatValue;
    property BooleanValue: Boolean read FBooleanValue;
    property Reference: TNXTaskReference read FReference;
    property SourceRange: TNXTaskSourceRange read FSourceRange;
  end;

  TNXTaskProperty = class
  private
    FName: string;
    FValue: TNXTaskValue;
    FSourceRange: TNXTaskSourceRange;
    FDeclarationFile: string;
  public
    constructor Create(const AName: string; AValue: TNXTaskValue;
      ASourceRange: TNXTaskSourceRange; const ADeclarationFile: string);
    destructor Destroy; override;
    function Clone: TNXTaskProperty;
    property Name: string read FName;
    property Value: TNXTaskValue read FValue write FValue;
    property SourceRange: TNXTaskSourceRange read FSourceRange;
    property DeclarationFile: string read FDeclarationFile;
  end;

  TNXTaskNodeReference = class
  private
    FReference: TNXTaskReference;
  public
    constructor Create(AReference: TNXTaskReference);
    destructor Destroy; override;
    property Reference: TNXTaskReference read FReference;
  end;

  TNXTaskBodyItemKind = (tbikProperty, tbikChild, tbikExpansion);

  TNXTaskBodyItem = class
  private
    FKind: TNXTaskBodyItemKind;
    FItem: TObject;
  public
    constructor Create(AKind: TNXTaskBodyItemKind; AItem: TObject);
    property Kind: TNXTaskBodyItemKind read FKind;
    property Item: TObject read FItem;
  end;

  TNXTaskNode = class
  private
    FName: string;
    FAction: string;
    FTargets: TStringList;
    FProperties: TObjectList;
    FChildren: TObjectList;
    FExpansions: TObjectList;
    FBodyItems: TObjectList;
    FSourceRange: TNXTaskSourceRange;
    FDeclarationFile: string;
    FExpansionSite: string;
  public
    constructor Create(const AName, AAction: string; ASourceRange: TNXTaskSourceRange;
      const ADeclarationFile: string);
    destructor Destroy; override;
    procedure AddProperty(AProperty: TNXTaskProperty);
    procedure AddChild(AChild: TNXTaskNode);
    procedure AddExpansion(AExpansion: TNXTaskNodeReference);
    procedure ClearBody;
    procedure ClearChildren;
    function CloneShallow: TNXTaskNode;
    function PropertyByName(const AName: string): TNXTaskProperty;
    function ChildByName(const AName: string): TNXTaskNode;
    function HasTarget(const ATarget: string): Boolean;
    property Name: string read FName;
    property Action: string read FAction;
    property Targets: TStringList read FTargets;
    property Properties: TObjectList read FProperties;
    property Children: TObjectList read FChildren;
    property Expansions: TObjectList read FExpansions;
    property BodyItems: TObjectList read FBodyItems;
    property SourceRange: TNXTaskSourceRange read FSourceRange;
    property DeclarationFile: string read FDeclarationFile;
    property ExpansionSite: string read FExpansionSite write FExpansionSite;
  end;

  TNXTaskDocument = class
  private
    FFileName: string;
    FRoots: TObjectList;
    FDiagnostics: TNXTaskDiagnostics;
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;
    function RootByName(const AName: string): TNXTaskNode;
    property FileName: string read FFileName write FFileName;
    property Roots: TObjectList read FRoots;
    property Diagnostics: TNXTaskDiagnostics read FDiagnostics;
  end;

function NXTaskQuoteString(const AValue: string): string;
function NXTaskCanonicalFloat(AValue: Double): string;

implementation

function NXTaskQuoteString(const AValue: string): string;
var
  lIndex: Integer;
  lChar: Char;
begin
  Result := '"';
  for lIndex := 1 to Length(AValue) do
  begin
    lChar := AValue[lIndex];
    case lChar of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      #10: Result := Result + '\n';
      #9: Result := Result + '\t';
    else
      Result := Result + lChar;
    end;
  end;
  Result := Result + '"';
end;

function NXTaskCanonicalFloat(AValue: Double): string;
var
  lSettings: TFormatSettings;
begin
  lSettings := DefaultFormatSettings;
  lSettings.DecimalSeparator := '.';
  Result := FloatToStr(AValue, lSettings);
  if Pos('.', Result) = 0 then
    Result := Result + '.0';
end;

constructor TNXTaskSourceRange.Create(const AFileName: string; ALine, AColumn: Integer);
begin
  inherited Create;
  FFileName := AFileName;
  FLine := ALine;
  FColumn := AColumn;
end;

function TNXTaskSourceRange.Text: string;
begin
  Result := Format('%s:%d:%d', [FFileName, FLine, FColumn]);
end;

constructor TNXTaskDiagnostic.Create(ASeverity: TNXTaskSeverity; const ACode,
  AMessage: string; ARange: TNXTaskSourceRange);
begin
  inherited Create;
  FSeverity := ASeverity;
  FCode := ACode;
  FMessage := AMessage;
  FRange := ARange;
  FRelated := TStringList.Create;
end;

destructor TNXTaskDiagnostic.Destroy;
begin
  FRelated.Free;
  FRange.Free;
  inherited Destroy;
end;

procedure TNXTaskDiagnostic.AddRelated(const AText: string);
begin
  FRelated.Add(AText);
end;

function TNXTaskDiagnostic.Text: string;
begin
  if FRange <> nil then
    Result := Format('%s %s %s %s',
      [NXTaskSeverityName(FSeverity), FCode, FRange.Text, FMessage])
  else
    Result := Format('%s %s %s', [NXTaskSeverityName(FSeverity), FCode, FMessage]);
end;

constructor TNXTaskDiagnostics.Create;
begin
  inherited Create;
  FItems := TObjectList.Create(True);
end;

destructor TNXTaskDiagnostics.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

procedure TNXTaskDiagnostics.Add(ASeverity: TNXTaskSeverity; const ACode,
  AMessage: string; ARange: TNXTaskSourceRange);
begin
  FItems.Add(TNXTaskDiagnostic.Create(ASeverity, ACode, AMessage, ARange));
end;

procedure TNXTaskDiagnostics.AddWithRelated(ASeverity: TNXTaskSeverity;
  const ACode, AMessage: string; ARange: TNXTaskSourceRange; const ARelated: string);
var
  lDiagnostic: TNXTaskDiagnostic;
begin
  lDiagnostic := TNXTaskDiagnostic.Create(ASeverity, ACode, AMessage, ARange);
  lDiagnostic.AddRelated(ARelated);
  FItems.Add(lDiagnostic);
end;

function TNXTaskDiagnostics.HasErrors: Boolean;
var
  lIndex: Integer;
begin
  Result := False;
  for lIndex := 0 to FItems.Count - 1 do
    if Item(lIndex).Severity = tdsError then
      Exit(True);
end;

function TNXTaskDiagnostics.Count: Integer;
begin
  Result := FItems.Count;
end;

function TNXTaskDiagnostics.Item(AIndex: Integer): TNXTaskDiagnostic;
begin
  Result := TNXTaskDiagnostic(FItems[AIndex]);
end;

constructor TNXTaskReference.Create(const AExternalFile, APath, APropertyName: string;
  ASourceRange: TNXTaskSourceRange; const ADeclarationFile: string);
begin
  inherited Create;
  FExternalFile := AExternalFile;
  FPath := APath;
  FPropertyName := APropertyName;
  FSourceRange := ASourceRange;
  FDeclarationFile := ADeclarationFile;
end;

destructor TNXTaskReference.Destroy;
begin
  FSourceRange.Free;
  inherited Destroy;
end;

function TNXTaskReference.Identity(AKind: TNXTaskReferenceKind; const ABaseFile: string): string;
var
  lFile: string;
begin
  if FExternalFile <> '' then
    lFile := ExpandFileName(FExternalFile)
  else
    lFile := ExpandFileName(ABaseFile);
  if AKind = trkValue then
    Result := Format('value:%s:%s.%s', [lFile, FPath, FPropertyName])
  else
    Result := Format('node:%s:%s', [lFile, FPath]);
end;

destructor TNXTaskValue.Destroy;
begin
  FReference.Free;
  FSourceRange.Free;
  inherited Destroy;
end;

function TNXTaskValue.Clone: TNXTaskValue;
var
  lReference: TNXTaskReference;
  lRange: TNXTaskSourceRange;
begin
  if FSourceRange <> nil then
    lRange := TNXTaskSourceRange.Create(FSourceRange.FileName, FSourceRange.Line,
      FSourceRange.Column)
  else
    lRange := nil;
  case FKind of
    tvkString: Result := CreateString(FStringValue, lRange);
    tvkInteger: Result := CreateInteger(FIntegerValue, lRange);
    tvkFloat: Result := CreateFloat(FFloatValue, lRange);
    tvkBoolean: Result := CreateBoolean(FBooleanValue, lRange);
    tvkReference:
      begin
        if FReference.SourceRange <> nil then
          lRange := TNXTaskSourceRange.Create(FReference.SourceRange.FileName,
            FReference.SourceRange.Line, FReference.SourceRange.Column)
        else
          lRange := nil;
        lReference := TNXTaskReference.Create(FReference.ExternalFile, FReference.Path,
          FReference.PropertyName, lRange, FReference.DeclarationFile);
        if FSourceRange <> nil then
          lRange := TNXTaskSourceRange.Create(FSourceRange.FileName, FSourceRange.Line,
            FSourceRange.Column)
        else
          lRange := nil;
        Result := CreateReference(lReference, lRange);
      end;
  end;
end;

function TNXTaskValue.CanonicalText: string;
begin
  case FKind of
    tvkString: Result := 'string ' + NXTaskQuoteString(FStringValue);
    tvkInteger: Result := 'integer ' + IntToStr(FIntegerValue);
    tvkFloat: Result := 'float ' + NXTaskCanonicalFloat(FFloatValue);
    tvkBoolean:
      if FBooleanValue then
        Result := 'boolean true'
      else
        Result := 'boolean false';
    tvkReference:
      begin
        if FReference.ExternalFile <> '' then
          Result := 'reference [' + NXTaskQuoteString(FReference.ExternalFile) +
            ':' + FReference.Path + '.' + FReference.PropertyName + ']'
        else
          Result := 'reference [' + FReference.Path + '.' +
            FReference.PropertyName + ']';
      end;
  end;
end;

class function TNXTaskValue.CreateString(const AValue: string;
  ARange: TNXTaskSourceRange): TNXTaskValue;
begin
  Result := TNXTaskValue.Create;
  Result.FKind := tvkString;
  Result.FStringValue := AValue;
  Result.FSourceRange := ARange;
end;

class function TNXTaskValue.CreateInteger(AValue: Int64;
  ARange: TNXTaskSourceRange): TNXTaskValue;
begin
  Result := TNXTaskValue.Create;
  Result.FKind := tvkInteger;
  Result.FIntegerValue := AValue;
  Result.FSourceRange := ARange;
end;

class function TNXTaskValue.CreateFloat(AValue: Double;
  ARange: TNXTaskSourceRange): TNXTaskValue;
begin
  Result := TNXTaskValue.Create;
  Result.FKind := tvkFloat;
  Result.FFloatValue := AValue;
  Result.FSourceRange := ARange;
end;

class function TNXTaskValue.CreateBoolean(AValue: Boolean;
  ARange: TNXTaskSourceRange): TNXTaskValue;
begin
  Result := TNXTaskValue.Create;
  Result.FKind := tvkBoolean;
  Result.FBooleanValue := AValue;
  Result.FSourceRange := ARange;
end;

class function TNXTaskValue.CreateReference(AReference: TNXTaskReference;
  ARange: TNXTaskSourceRange): TNXTaskValue;
begin
  Result := TNXTaskValue.Create;
  Result.FKind := tvkReference;
  Result.FReference := AReference;
  Result.FSourceRange := ARange;
end;

constructor TNXTaskProperty.Create(const AName: string; AValue: TNXTaskValue;
  ASourceRange: TNXTaskSourceRange; const ADeclarationFile: string);
begin
  inherited Create;
  FName := AName;
  FValue := AValue;
  FSourceRange := ASourceRange;
  FDeclarationFile := ADeclarationFile;
end;

destructor TNXTaskProperty.Destroy;
begin
  FValue.Free;
  FSourceRange.Free;
  inherited Destroy;
end;

function TNXTaskProperty.Clone: TNXTaskProperty;
var
  lRange: TNXTaskSourceRange;
begin
  if FSourceRange <> nil then
    lRange := TNXTaskSourceRange.Create(FSourceRange.FileName, FSourceRange.Line,
      FSourceRange.Column)
  else
    lRange := nil;
  Result := TNXTaskProperty.Create(FName, FValue.Clone, lRange, FDeclarationFile);
end;

constructor TNXTaskNodeReference.Create(AReference: TNXTaskReference);
begin
  inherited Create;
  FReference := AReference;
end;

destructor TNXTaskNodeReference.Destroy;
begin
  FReference.Free;
  inherited Destroy;
end;

constructor TNXTaskBodyItem.Create(AKind: TNXTaskBodyItemKind; AItem: TObject);
begin
  inherited Create;
  FKind := AKind;
  FItem := AItem;
end;

constructor TNXTaskNode.Create(const AName, AAction: string;
  ASourceRange: TNXTaskSourceRange; const ADeclarationFile: string);
begin
  inherited Create;
  FName := AName;
  FAction := AAction;
  FSourceRange := ASourceRange;
  FDeclarationFile := ADeclarationFile;
  FTargets := TStringList.Create;
  FTargets.CaseSensitive := True;
  FProperties := TObjectList.Create(True);
  FChildren := TObjectList.Create(True);
  FExpansions := TObjectList.Create(True);
  FBodyItems := TObjectList.Create(True);
end;

destructor TNXTaskNode.Destroy;
begin
  FTargets.Free;
  FBodyItems.Free;
  FProperties.Free;
  FChildren.Free;
  FExpansions.Free;
  FSourceRange.Free;
  inherited Destroy;
end;

procedure TNXTaskNode.AddProperty(AProperty: TNXTaskProperty);
begin
  FProperties.Add(AProperty);
  FBodyItems.Add(TNXTaskBodyItem.Create(tbikProperty, AProperty));
end;

procedure TNXTaskNode.AddChild(AChild: TNXTaskNode);
begin
  FChildren.Add(AChild);
  FBodyItems.Add(TNXTaskBodyItem.Create(tbikChild, AChild));
end;

procedure TNXTaskNode.AddExpansion(AExpansion: TNXTaskNodeReference);
begin
  FExpansions.Add(AExpansion);
  FBodyItems.Add(TNXTaskBodyItem.Create(tbikExpansion, AExpansion));
end;

procedure TNXTaskNode.ClearBody;
begin
  FBodyItems.Clear;
  FProperties.Clear;
  FChildren.Clear;
  FExpansions.Clear;
end;

procedure TNXTaskNode.ClearChildren;
var
  lIndex: Integer;
  lBodyItem: TNXTaskBodyItem;
begin
  FChildren.Clear;
  lIndex := FBodyItems.Count - 1;
  while lIndex >= 0 do
  begin
    lBodyItem := TNXTaskBodyItem(FBodyItems[lIndex]);
    if lBodyItem.Kind = tbikChild then
      FBodyItems.Delete(lIndex);
    Dec(lIndex);
  end;
end;

function TNXTaskNode.CloneShallow: TNXTaskNode;
var
  lIndex: Integer;
  lRange: TNXTaskSourceRange;
  lReference: TNXTaskReference;
  lNodeReference: TNXTaskNodeReference;
  lBodyItem: TNXTaskBodyItem;
  lProperty: TNXTaskProperty;
  lChild: TNXTaskNode;
begin
  if FSourceRange <> nil then
    lRange := TNXTaskSourceRange.Create(FSourceRange.FileName, FSourceRange.Line,
      FSourceRange.Column)
  else
    lRange := nil;
  Result := TNXTaskNode.Create(FName, FAction, lRange, FDeclarationFile);
  Result.Targets.Assign(FTargets);
  Result.ExpansionSite := FExpansionSite;
  for lIndex := 0 to FBodyItems.Count - 1 do
  begin
    lBodyItem := TNXTaskBodyItem(FBodyItems[lIndex]);
    case lBodyItem.Kind of
      tbikProperty:
        begin
          lProperty := TNXTaskProperty(lBodyItem.Item).Clone;
          Result.AddProperty(lProperty);
        end;
      tbikChild:
        begin
          lChild := TNXTaskNode(lBodyItem.Item).CloneShallow;
          Result.AddChild(lChild);
        end;
      tbikExpansion:
        begin
          lNodeReference := TNXTaskNodeReference(lBodyItem.Item);
          if lNodeReference.Reference.SourceRange <> nil then
            lRange := TNXTaskSourceRange.Create(
              lNodeReference.Reference.SourceRange.FileName,
              lNodeReference.Reference.SourceRange.Line,
              lNodeReference.Reference.SourceRange.Column)
          else
            lRange := nil;
          lReference := TNXTaskReference.Create(lNodeReference.Reference.ExternalFile,
            lNodeReference.Reference.Path, lNodeReference.Reference.PropertyName, lRange,
            lNodeReference.Reference.DeclarationFile);
          Result.AddExpansion(TNXTaskNodeReference.Create(lReference));
        end;
    end;
  end;
end;

function TNXTaskNode.PropertyByName(const AName: string): TNXTaskProperty;
var
  lIndex: Integer;
  lProperty: TNXTaskProperty;
begin
  Result := nil;
  for lIndex := 0 to FProperties.Count - 1 do
  begin
    lProperty := TNXTaskProperty(FProperties[lIndex]);
    if lProperty.Name = AName then
      Exit(lProperty);
  end;
end;

function TNXTaskNode.ChildByName(const AName: string): TNXTaskNode;
var
  lIndex: Integer;
  lChild: TNXTaskNode;
begin
  Result := nil;
  for lIndex := 0 to FChildren.Count - 1 do
  begin
    lChild := TNXTaskNode(FChildren[lIndex]);
    if lChild.Name = AName then
      Exit(lChild);
  end;
end;

function TNXTaskNode.HasTarget(const ATarget: string): Boolean;
begin
  Result := FTargets.IndexOf(ATarget) >= 0;
end;

constructor TNXTaskDocument.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
  FRoots := TObjectList.Create(True);
  FDiagnostics := TNXTaskDiagnostics.Create;
end;

destructor TNXTaskDocument.Destroy;
begin
  FRoots.Free;
  FDiagnostics.Free;
  inherited Destroy;
end;

function TNXTaskDocument.RootByName(const AName: string): TNXTaskNode;
var
  lIndex: Integer;
  lRoot: TNXTaskNode;
begin
  Result := nil;
  for lIndex := 0 to FRoots.Count - 1 do
  begin
    lRoot := TNXTaskNode(FRoots[lIndex]);
    if lRoot.Name = AName then
      Exit(lRoot);
  end;
end;

end.
