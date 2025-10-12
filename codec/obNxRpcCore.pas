{$mode objfpc}{$H+}
{$M+} // enable RTTI for published props
unit obNxRpcCore;

interface

uses
  Classes, SysUtils, TypInfo, fgl,
  obNxTypes;

type
  ENxRpcError = class(Exception);

  TNXRPObject = class
  public
    constructor Create; virtual;
    function  TypeId: string; virtual;
    function  ToNxVal: TNxVal; virtual;
    procedure FromNxVal(const AVal: TNxVal); virtual;
  end;

  TNXRPClass = class of TNXRPObject;

  TNXRPRegistry = class
  private
    // registry map stored in implementation section
    // (avoid class var for wider FPC compatibility)
    class function _Map: specialize TFPGMap<string,TClass>; static;
  public
    class constructor Create;
    class destructor Destroy;
    class procedure RegisterType(const ATypeId: string; AClass: TNXRPClass);
    class function  CreateByTypeId(const ATypeId: string): TNXRPObject;
    class function  TryGetClass(const ATypeId: string; out AClass: TNXRPClass): Boolean;
  end;

  TNxNameOfFunc = function(const AItem: TNXRPObject): UnicodeString of object;
  TNxObjEnumerator = class(TObject)
  private
    FList: TList;
    FIdx: Integer;
  public
    constructor Create(AList: TList);
    function MoveNext: Boolean;
    function GetCurrent: TNXRPObject;
    property Current: TNXRPObject read GetCurrent;
  end;

  TNXRPList = class(TNXRPObject)
  private
    FItems: TList; // of TNXRPObject
    FOwnsObjects: Boolean;
    FCapacity: Integer;

    // name map (optional)
    FNameIndexEnabled: Boolean;
    FCaseSensitive: Boolean;
    FNameOf: TNxNameOfFunc;
    FNames: array of UnicodeString;
    FValues: array of UnicodeString;
    // multimap: normalized name -> list of indices
    FNameMap: specialize TFPGMapObject<UnicodeString, TList>;
    function  NormalizeName(const AName: UnicodeString): UnicodeString;
    procedure IndexAdd(const AIndex: Integer; const AName: UnicodeString);
    procedure IndexRemove(const AIndex: Integer; const AName: UnicodeString);
    procedure IndexShiftDown(const AFrom: Integer);
    function  GetName(AIndex: Integer): UnicodeString;
    procedure SetName(AIndex: Integer; const AValue: UnicodeString);
    function  GetValue(AIndex: Integer): UnicodeString;
    procedure SetValue(AIndex: Integer; const AValue: UnicodeString);
  protected
    function  GetItem(AIndex: Integer): TNXRPObject; virtual;
    procedure SetItem(AIndex: Integer; AItem: TNXRPObject); virtual;
  public
    constructor Create; override;
    destructor Destroy; override;

    // typing
    function  ElementTypeId: string; virtual; // empty => any

    // ownership
    property OwnsObjects: Boolean read FOwnsObjects write FOwnsObjects;

    // basic list ops
    function  Count: Integer; virtual;
    procedure Clear; virtual;
    procedure EnsureCapacity(ACapacity: Integer);
    property Capacity: Integer read FCapacity write FCapacity;

    property Items[AIndex: Integer]: TNXRPObject read GetItem write SetItem; default;
    function  IndexOf(AItem: TNXRPObject): Integer;
    procedure Add(AItem: TNXRPObject); virtual;
    procedure AddRange(const AItems: array of TNXRPObject);
    procedure Insert(AIndex: Integer; AItem: TNXRPObject);
    procedure RemoveAt(AIndex: Integer);
    function  Any: Boolean;
    function  First: TNXRPObject;
    function  Last: TNXRPObject;

    // enumeration
    function  GetEnumerator: TNxObjEnumerator;

    // name index
    procedure EnableNameIndex(ADefaultNameOf: TNxNameOfFunc = nil; ACaseSensitive: Boolean = False);
    procedure DisableNameIndex;
    procedure ReindexItem(AIndex: Integer);
    procedure ReindexAll;

    property Names[AIndex: Integer]: UnicodeString read GetName write SetName;
    property Values[AIndex: Integer]: UnicodeString read GetValue write SetValue;

    function  FindFirst(const AName: UnicodeString): TNXRPObject;
    procedure FindAll(const AName: UnicodeString; AOut: TNXRPList);
    // Serialization
    function  ToNxVal: TNxVal; override;
    procedure FromNxVal(const AVal: TNxVal); override;
  end;

implementation

var
  G_NXRP_Map: specialize TFPGMap<string,TClass> = nil;

{ TNXRPRegistry helpers }

class function TNXRPRegistry._Map: specialize TFPGMap<string,TClass>;
begin
  if G_NXRP_Map = nil then
    G_NXRP_Map := specialize TFPGMap<string,TClass>.Create;
  Result := G_NXRP_Map;
end;


{ TNXRPObject }

constructor TNXRPObject.Create;
begin
  inherited Create;
end;

function TNXRPObject.TypeId: string;
begin
  Result := ClassName;
end;

function TNXRPObject.ToNxVal: TNxVal;
var
  lMap: TNxVal;
  lFields: TNxVal;
  lType: PTypeInfo;
  lPropList: PPropList;
  lCount, lI: Integer;
  lPropInfo: PPropInfo;

  procedure AddField(const AName: UnicodeString; AValue: TNxVal);
  begin
    lFields.AsMap.SetKey(AName, AValue);
  end;

begin
  lType := PTypeInfo(Self.ClassInfo);
  lFields := TNxVal.Map;
  // enumerate published props
  lCount := GetPropList(lType, lPropList);
  try
    for lI := 0 to lCount-1 do
    begin
      lPropInfo := lPropList^[lI];
      case lPropInfo^.PropType^.Kind of
        tkBool:
          AddField(lPropInfo^.Name, TNxVal.Bool(GetOrdProp(Self, lPropInfo) <> 0));
        tkInteger, tkInt64, tkQWord:
          AddField(lPropInfo^.Name, TNxVal.Int(GetInt64Prop(Self, lPropInfo)));
        tkSString, tkLString, tkWString, tkUString:
          AddField(lPropInfo^.Name, TNxVal.Text(GetUnicodeStrProp(Self, lPropInfo)));
        tkClass:
          begin
            if TObject(GetObjectProp(Self, lPropInfo)) is TNXRPObject then
              AddField(lPropInfo^.Name, TNXRPObject(GetObjectProp(Self, lPropInfo)).ToNxVal)
            else
              raise ENxRpcError.CreateFmt('Unsupported class property %s', [lPropInfo^.Name]);
          end;
        else
          raise ENxRpcError.CreateFmt('Unsupported property kind for %s', [lPropInfo^.Name]);
      end;
    end;
  finally
    if lCount>0 then FreeMem(lPropList);
  end;

  lMap := TNxVal.Map;
  lMap.AsMap.SetKey('t', TNxVal.Text(TypeId));
  lMap.AsMap.SetKey('f', lFields);
  Result := lMap;
end;

procedure TNXRPObject.FromNxVal(const AVal: TNxVal);
var
  lFields: TNxVal;
  lType: PTypeInfo;
  lPropList: PPropList;
  lCount, lI: Integer;
  lPropInfo: PPropInfo;
  lFieldVal: TNxVal;
  lTVal: TNxVal;
  lObj: TNXRPObject;
begin
  if (AVal=nil) or (AVal.Kind<>nkMap) then raise ENxRpcError.Create('Object needs Map');
  if not AVal.AsMap.TryGet('f', lFields) then raise ENxRpcError.Create('Missing fields map');

  lType := PTypeInfo(Self.ClassInfo);
  lCount := GetPropList(lType, lPropList);
  try
    for lI := 0 to lCount-1 do
    begin
      lPropInfo := lPropList^[lI];
      if not lFields.AsMap.TryGet(lPropInfo^.Name, lFieldVal) then
        Continue;

      case lPropInfo^.PropType^.Kind of
        tkBool:
          SetOrdProp(Self, lPropInfo, Ord(lFieldVal.AsBool));
        tkInteger, tkInt64, tkQWord:
          SetInt64Prop(Self, lPropInfo, lFieldVal.AsInt);
        tkSString, tkLString, tkWString, tkUString:
          SetUnicodeStrProp(Self, lPropInfo, lFieldVal.AsText);
        tkClass:
          begin
            if (lFieldVal.Kind=nkMap) then
            begin
              
              if not lFieldVal.AsMap.TryGet('t', lTVal) then raise ENxRpcError.Create('Nested object missing t');
              lObj := TNXRPRegistry.CreateByTypeId(lTVal.AsText);
              lObj.FromNxVal(lFieldVal);
              SetObjectProp(Self, lPropInfo, lObj);
            end
            else
              raise ENxRpcError.CreateFmt('Property %s expects object', [lPropInfo^.Name]);
          end;
      else
        raise ENxRpcError.CreateFmt('Unsupported property kind for %s', [lPropInfo^.Name]);
      end;
    end;
  finally
    if lCount>0 then FreeMem(lPropList);
  end;
end;

{ TNXRPRegistry }

class constructor TNXRPRegistry.Create;
begin
  
end;

class destructor TNXRPRegistry.Destroy;
begin
  if G_NXRP_Map<>nil then G_NXRP_Map.Free; G_NXRP_Map:=nil;
end;

class procedure TNXRPRegistry.RegisterType(const ATypeId: string; AClass: TNXRPClass);
begin
  if _Map.IndexOf(ATypeId) <> -1 then
    raise ENxRpcError.CreateFmt('Duplicate type id: %s', [ATypeId]);
  _Map.Add(ATypeId, TClass(AClass));
end;

class function TNXRPRegistry.CreateByTypeId(const ATypeId: string): TNXRPObject;
var
  lCls: TNXRPClass;
begin
  if not TryGetClass(ATypeId, lCls) then
    raise ENxRpcError.CreateFmt('Unknown type id: %s', [ATypeId]);
  Result := lCls.Create;
end;

class function TNXRPRegistry.TryGetClass(const ATypeId: string; out AClass: TNXRPClass): Boolean;
var lIdx: Integer;
begin
  lIdx := _Map.IndexOf(ATypeId);
  Result := lIdx >= 0;
  if Result then AClass := TNXRPClass(_Map.Data[lIdx]);
end;

{ TNxObjEnumerator }

constructor TNxObjEnumerator.Create(AList: TList);
begin
  FList := AList;
  FIdx := -1;
end;

function TNxObjEnumerator.MoveNext: Boolean;
begin
  Inc(FIdx);
  Result := FIdx < FList.Count;
end;

function TNxObjEnumerator.GetCurrent: TNXRPObject;
begin
  Result := TNXRPObject(FList[FIdx]);
end;

{ TNXRPList }

constructor TNXRPList.Create;
begin
  inherited Create;
  FItems := TList.Create;
  FOwnsObjects := True;
  FCapacity := 0;
  FNameIndexEnabled := False;
  FCaseSensitive := False;
  FNameOf := nil;
  SetLength(FNames, 0);
  SetLength(FValues, 0);
  FNameMap := specialize TFPGMapObject<UnicodeString,TList>.Create;
end;

destructor TNXRPList.Destroy;
var lI: Integer;
begin
  if FOwnsObjects then
    for lI := 0 to FItems.Count-1 do
      TObject(FItems[lI]).Free;
  FItems.Free;
  FNameMap.Free;
  inherited;
end;

function TNXRPList.ElementTypeId: string;
begin
  Result := '';
end;

function TNXRPList.Count: Integer; begin Result := FItems.Count; end;

procedure TNXRPList.Clear;
var lI: Integer;
begin
  if FOwnsObjects then
    for lI := 0 to FItems.Count-1 do
      TObject(FItems[lI]).Free;
  FItems.Clear;
  SetLength(FNames, 0);
  SetLength(FValues, 0);
  FNameMap.Clear;
end;

procedure TNXRPList.EnsureCapacity(ACapacity: Integer);
begin
  FCapacity := ACapacity; // TList grows automatically; keep for API symmetry
end;

function TNXRPList.GetItem(AIndex: Integer): TNXRPObject;
begin
  Result := TNXRPObject(FItems[AIndex]);
end;

procedure TNXRPList.SetItem(AIndex: Integer; AItem: TNXRPObject);
var lOld: TNXRPObject; lName: UnicodeString;
begin
  if (ElementTypeId <> '') and (AItem.TypeId <> ElementTypeId) then
    raise ENxRpcError.CreateFmt('List expects %s, got %s', [ElementTypeId, AItem.TypeId]);
  lOld := TNXRPObject(FItems[AIndex]);
  if FNameIndexEnabled then
  begin
    lName := NormalizeName(GetName(AIndex));
    if lName<>'' then IndexRemove(AIndex, lName);
  end;
  FItems[AIndex] := AItem;
  if FOwnsObjects then lOld.Free;
  if FNameIndexEnabled then
  begin
    lName := NormalizeName(GetName(AIndex));
    if lName<>'' then IndexAdd(AIndex, lName);
  end;
end;

function TNXRPList.IndexOf(AItem: TNXRPObject): Integer;
begin
  Result := FItems.IndexOf(AItem);
end;

procedure TNXRPList.Add(AItem: TNXRPObject);
var lIdx: Integer; lName: UnicodeString;
begin
  if (ElementTypeId <> '') and (AItem.TypeId <> ElementTypeId) then
    raise ENxRpcError.CreateFmt('List expects %s, got %s', [ElementTypeId, AItem.TypeId]);
  lIdx := FItems.Add(AItem);
  SetLength(FNames, Length(FNames)+1);
  SetLength(FValues, Length(FValues)+1);
  FNames[High(FNames)] := '';
  FValues[High(FValues)] := '';
  if FNameIndexEnabled then
  begin
    lName := NormalizeName(GetName(lIdx));
    if lName<>'' then IndexAdd(lIdx, lName);
  end;
end;

procedure TNXRPList.AddRange(const AItems: array of TNXRPObject);
var lI: Integer;
begin
  for lI := 0 to High(AItems) do Add(AItems[lI]);
end;

procedure TNXRPList.Insert(AIndex: Integer; AItem: TNXRPObject);
var lI: Integer; lName: UnicodeString;
begin
  if (ElementTypeId <> '') and (AItem.TypeId <> ElementTypeId) then
    raise ENxRpcError.CreateFmt('List expects %s, got %s', [ElementTypeId, AItem.TypeId]);
  FItems.Insert(AIndex, AItem);
  // shift names/values
  SetLength(FNames, Length(FNames)+1);
  SetLength(FValues, Length(FValues)+1);
  for lI := High(FNames) downto AIndex+1 do
  begin
    FNames[lI] := FNames[lI-1];
    FValues[lI] := FValues[lI-1];
  end;
  FNames[AIndex] := '';
  FValues[AIndex] := '';
  if FNameIndexEnabled then
  begin
    IndexShiftDown(AIndex);
    lName := NormalizeName(GetName(AIndex));
    if lName<>'' then IndexAdd(AIndex, lName);
  end;
end;

procedure TNXRPList.RemoveAt(AIndex: Integer);
var lI, lLast: Integer; lName: UnicodeString; lObj: TObject;
begin
  if FNameIndexEnabled then
  begin
    lName := NormalizeName(GetName(AIndex));
    if lName<>'' then IndexRemove(AIndex, lName);
    IndexShiftDown(AIndex+1);
  end;
  lObj := TObject(FItems[AIndex]);
  FItems.Delete(AIndex);
  if FOwnsObjects then lObj.Free;

  // collapse Names/Values
  lLast := High(FNames);
  for lI := AIndex to lLast-1 do
  begin
    FNames[lI] := FNames[lI+1];
    FValues[lI] := FValues[lI+1];
  end;
  if lLast >= 0 then
  begin
    SetLength(FNames, lLast);
    SetLength(FValues, lLast);
  end;
end;

function TNXRPList.Any: Boolean; begin Result := FItems.Count>0; end;
function TNXRPList.First: TNXRPObject; begin if FItems.Count=0 then raise ENxRpcError.Create('List empty'); Result := TNXRPObject(FItems[0]); end;
function TNXRPList.Last: TNXRPObject; begin if FItems.Count=0 then raise ENxRpcError.Create('List empty'); Result := TNXRPObject(FItems[FItems.Count-1]); end;

function TNXRPList.GetEnumerator: TNxObjEnumerator;
begin
  Result := TNxObjEnumerator.Create(FItems);
end;

procedure TNXRPList.EnableNameIndex(ADefaultNameOf: TNxNameOfFunc; ACaseSensitive: Boolean);
begin
  FNameIndexEnabled := True;
  FCaseSensitive := ACaseSensitive;
  FNameOf := ADefaultNameOf;
  ReindexAll;
end;

procedure TNXRPList.DisableNameIndex;
begin
  FNameIndexEnabled := False;
  FNameMap.Clear;
end;

function TNXRPList.NormalizeName(const AName: UnicodeString): UnicodeString;
begin
  if FCaseSensitive then
    Result := AName
  else
    Result := LowerCase(AName);
end;

procedure TNXRPList.IndexAdd(const AIndex: Integer; const AName: UnicodeString);
var lIdx: Integer; lList: TList; lKey: UnicodeString;
begin
  lKey := NormalizeName(AName);
  if lKey='' then Exit;
  lIdx := FNameMap.IndexOf(lKey);
  if lIdx<0 then
  begin
    lList := TList.Create;
    FNameMap.Add(lKey, lList);
  end
  else
    lList := FNameMap.Data[lIdx];
  lList.Add(Pointer(AIndex));
end;

procedure TNXRPList.IndexRemove(const AIndex: Integer; const AName: UnicodeString);
var lIdx: Integer; lList: TList; lJ: Integer; lKey: UnicodeString;
begin
  lKey := NormalizeName(AName);
  if lKey='' then Exit;
  lIdx := FNameMap.IndexOf(lKey);
  if lIdx<0 then Exit;
  lList := FNameMap.Data[lIdx];
  for lJ := 0 to lList.Count-1 do
    if PtrInt(lList[lJ]) = AIndex then
    begin
      lList.Delete(lJ);
      Break;
    end;
  if lList.Count=0 then
  begin
    FNameMap.Delete(lIdx);
  end;
end;

procedure TNXRPList.IndexShiftDown(const AFrom: Integer);
var i,j: Integer; lList: TList;
begin
  for i := 0 to FNameMap.Count-1 do
  begin
    lList := FNameMap.Data[i];
    for j := 0 to lList.Count-1 do
      if PtrInt(lList[j]) >= AFrom then
        lList[j] := Pointer(PtrInt(lList[j])-1);
  end;
end;

function TNXRPList.GetName(AIndex: Integer): UnicodeString;
begin
  if (AIndex<0) or (AIndex>=Length(FNames)) then Exit('');
  Result := FNames[AIndex];
end;

procedure TNXRPList.SetName(AIndex: Integer; const AValue: UnicodeString);
var lOldNorm, lNewNorm: UnicodeString;
begin
  if FNameIndexEnabled then
  begin
    lOldNorm := NormalizeName(GetName(AIndex));
    if lOldNorm<>'' then IndexRemove(AIndex, lOldNorm);
  end;
  FNames[AIndex] := AValue;
  if FNameIndexEnabled then
  begin
    lNewNorm := NormalizeName(AValue);
    if lNewNorm<>'' then IndexAdd(AIndex, lNewNorm);
  end;
end;

function TNXRPList.GetValue(AIndex: Integer): UnicodeString;
begin
  if (AIndex<0) or (AIndex>=Length(FValues)) then Exit('');
  Result := FValues[AIndex];
end;

procedure TNXRPList.SetValue(AIndex: Integer; const AValue: UnicodeString);
begin
  FValues[AIndex] := AValue;
end;

procedure TNXRPList.ReindexItem(AIndex: Integer);
begin
  if not FNameIndexEnabled then Exit;
  ReindexAll;
end;

procedure TNXRPList.ReindexAll;
var i: Integer; lName: UnicodeString;
begin
  FNameMap.Clear;
  if not FNameIndexEnabled then Exit;
  for i := 0 to Count-1 do
  begin
    lName := GetName(i);
    if lName<>'' then IndexAdd(i, lName);
  end;
end;

function TNXRPList.FindFirst(const AName: UnicodeString): TNXRPObject;
var lIdx, lListIdx: Integer; lList: TList; lNorm: UnicodeString;
begin
  Result := nil;
  if FNameIndexEnabled then
  begin
    lNorm := NormalizeName(AName);
    lIdx := FNameMap.IndexOf(lNorm);
    if lIdx<0 then Exit(nil);
    lList := FNameMap.Data[lIdx];
    if lList.Count=0 then Exit(nil);
    lListIdx := PtrInt(lList[0]);
    Result := Items[lListIdx];
  end
  else
  begin
    for lIdx := 0 to Count-1 do
      if NormalizeName(GetName(lIdx)) = NormalizeName(AName) then
        Exit(Items[lIdx]);
  end;
end;

procedure TNXRPList.FindAll(const AName: UnicodeString; AOut: TNXRPList);
var lIdx, lJ: Integer; lList: TList; lNorm: UnicodeString;
begin
  if AOut=nil then Exit;
  AOut.OwnsObjects := False;
  if FNameIndexEnabled then
  begin
    lNorm := NormalizeName(AName);
    lIdx := FNameMap.IndexOf(lNorm);
    if lIdx<0 then Exit;
    lList := FNameMap.Data[lIdx];
    for lJ := 0 to lList.Count-1 do
      AOut.Add(Items[PtrInt(lList[lJ])]);
  end
  else
  begin
    for lIdx := 0 to Count-1 do
      if NormalizeName(GetName(lIdx)) = NormalizeName(AName) then
        AOut.Add(Items[lIdx]);
  end;
end;

function TNXRPList.ToNxVal: TNxVal;
var
  lFields, lItems: TNxVal;
  lI: Integer;
begin
  lFields := TNxVal.Map;
  lItems := TNxVal.List;
  for lI := 0 to Count-1 do
    lItems.AsList.Add(Items[lI].ToNxVal);
  lFields.AsMap.SetKey('items', lItems);

  Result := TNxVal.Map;
  Result.AsMap.SetKey('t', TNxVal.Text(TypeId));
  Result.AsMap.SetKey('f', lFields);
end;

procedure TNXRPList.FromNxVal(const AVal: TNxVal);
var
  lFields, lItems: TNxVal;
  lI: Integer;
  lObjVal, lTypeVal: TNxVal;
  lObj: TNXRPObject;
begin
  if (AVal=nil) or (AVal.Kind<>nkMap) then raise ENxRpcError.Create('List needs Map');
  if not AVal.AsMap.TryGet('f', lFields) then raise ENxRpcError.Create('List missing fields');
  if not lFields.AsMap.TryGet('items', lItems) then Exit;

  Clear;
  for lI := 0 to lItems.AsList.Count-1 do
  begin
    lObjVal := lItems.AsList[lI];
    if (lObjVal.Kind<>nkMap) then raise ENxRpcError.Create('List item must be object map');
    if not lObjVal.AsMap.TryGet('t', lTypeVal) then raise ENxRpcError.Create('List item missing type');
    lObj := TNXRPRegistry.CreateByTypeId(lTypeVal.AsText);
    lObj.FromNxVal(lObjVal);
    Add(lObj);
  end;
end;

end.
