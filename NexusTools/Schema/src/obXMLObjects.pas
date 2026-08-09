unit obXMLObjects;

{$mode delphi}{$H+}

interface

uses
  classes, fgl, SysUtils, TypInfo;

{$TYPEINFO ON}
type
  TXMLClass = class of TXMLObject;
  TXMLList = class;

  TXMLObject = class(TPersistent)
  private
    FOwnerList : TXMLList;
    FName : string;
    FExtraAttributes: TStringList;
  protected
    function GetName: string; virtual;
    procedure SetName(const Value: string); virtual;
  public
    constructor Create; reintroduce; virtual;
    destructor Destroy; override;

    function GetPropValue(const APropName : string) : variant; overload;
    procedure SetPropValue(const APropName : string; AValue : variant);
    function CloneSelf : TXMLObject;

    procedure AssignTo(ADestination : TPersistent); override;

    procedure CopyTo(ADestination : TPersistent); virtual;

    //properties
    property OwnerList : TXMLList read FOwnerList write FOwnerList;

    property ExtraAttributes : TStringList read FExtraAttributes;
  published
    property Name : string read GetName write SetName;
  end;

  TXMLList = class(TXMLObject)
  protected
    function GetItem(AIndex: Integer): TXMLObject; virtual; abstract;
    function GetCount: Integer; virtual; abstract;
  public
    procedure Clear; virtual; abstract;
    function Add(AObject: TXMLObject): Integer; virtual; abstract;
    function IndexOf(AName : string) : integer; overload;
    procedure AssignTo(ADestination : TPersistent); override;

    procedure CopyTo(ADestination : TPersistent); override;

    //Properties
    property Items[AIndex: Integer]: TXMLObject read GetItem; default;
    property Count: Integer read GetCount;
  end;

  TXMLObjectList<T: TXMLObject> = class(TXMLList)
  private
    FItems: TFPGObjectList<T>;
    function GetTypedItem(AIndex: Integer): T;
  protected
    function GetItem(AIndex: Integer): TXMLObject; override;
    function GetCount: Integer; override;
  public
    constructor Create; override;
    destructor Destroy; override;

    procedure Clear; override;
    function Add(AObject: TXMLObject): Integer; override;
    function AddObject(const AName: string): T;
    function FindByName(const AName: string): T;

    property Items[AIndex: Integer]: T read GetTypedItem; default;
  end;

implementation

{ TXMLObject }

constructor TXMLObject.Create;
begin
  inherited Create;

  FExtraAttributes := TStringList.Create;
  FExtraAttributes.CaseSensitive := False;
  FExtraAttributes.Duplicates := dupError;
end;

function TXMLObject.CloneSelf: TXMLObject;
begin
  Result := TXMLClass(ClassType).Create;
  Result.Assign(Self);
end;

procedure TXMLObject.AssignTo(ADestination: TPersistent);
var
  lPropCount : integer;
  lPropList : TPropList;
  lPropInfo : PPropInfo;
  lPropIdx : integer;
  lObject : TObject;
  lDestination : TXMLObject;
begin
  if (ADestination is Self.ClassType) then
  begin
    lDestination := TXMLObject(ADestination);
    lPropCount := GetPropList(lDestination.ClassInfo, tkAny, @lPropList, False);
    for lPropIdx := 0 to lPropCount - 1 do
    begin
      lPropInfo := lPropList[lPropIdx];
      if Assigned(lPropInfo.SetProc) then
      begin
        if Assigned(GetPropInfo(Self, lPropInfo.Name)) then
        begin
          if (lPropInfo.PropType^.Kind = tkClass) then
          begin
            lObject := GetObjectProp(Self, lPropInfo.Name);
            if (lObject is TXMLObject) then
              TXMLObject(lObject).AssignTo(GetObjectProp(lDestination, lPropInfo.Name) as TXMLObject);
          end
          else
          begin
            lDestination.SetPropValue(lPropInfo.Name, GetPropValue(lPropInfo.Name));
          end;
        end;
      end;
    end;
  end
  else
    inherited;
end;

function TXMLObject.GetPropValue(const APropName: string): variant;
begin
  Result := TypInfo.GetPropValue(Self, APropName);
end;

function TXMLObject.GetName: string;
begin
  Result := FName;
end;

procedure TXMLObject.SetName(const Value: string);
begin
  FName := Value;
end;

procedure TXMLObject.SetPropValue(const APropName: string; AValue: variant);
begin
  TypInfo.SetPropValue(Self, APropName, AValue);
end;

procedure TXMLObject.CopyTo(ADestination: TPersistent);
var
  lPropCount : integer;
  lPropList : TPropList;
  lPropInfo : PPropInfo;
  lPropIdx : integer;
  lObject : TObject;
  lDestination : TXMLObject;
begin
  if (ADestination is Self.ClassType) then
  begin
    lDestination := TXMLObject(ADestination);
    lPropCount := GetPropList(lDestination.ClassInfo, tkAny, @lPropList, False);
    for lPropIdx := 0 to lPropCount - 1 do
    begin
      lPropInfo := lPropList[lPropIdx];
      if Assigned(lPropInfo.SetProc) then
      begin
        if (lPropInfo.PropType^.Kind = tkClass) then
          begin
            lObject := GetObjectProp(Self, lPropInfo.Name);
            if (lObject is TXMLObject) then
              TXMLObject(lObject).CopyTo(GetObjectProp(lDestination, lPropInfo.Name) as TXMLObject);
        end
        else
          lDestination.SetPropValue(lPropInfo.Name, GetPropValue(lPropInfo.Name));
      end;
    end;
  end;
end;

destructor TXMLObject.Destroy;
begin
  FExtraAttributes.Free;

  inherited;
end;

{ TXMLList }

function TXMLList.IndexOf(AName: string): integer;
var
  lIdx: integer;
begin
  Result := -1;
  for lIdx := 0 to Count - 1 do
    if (Items[lIdx]).Name = AName then
    begin
      Result := lIdx;
      Break;
    end;
end;

procedure TXMLList.AssignTo(ADestination: TPersistent);
var
  lDestination : TXMLList;
  lItemIdx : integer;
begin
  if (ADestination is ClassType) then
  begin
    lDestination := TXMLList(ADestination);
    lDestination.Clear;
    if Count > 0 then
    begin
      for lItemIdx := 0 to Count - 1 do
        lDestination.Add(Items[lItemIdx].CloneSelf);
    end;
  end;
  inherited;
end;

procedure TXMLList.CopyTo(ADestination: TPersistent);
var
  lDestination : TXMLList;
  lItemIdx : integer;
begin
  if (ADestination is ClassType) then
  begin
    lDestination := TXMLList(ADestination);
    if Count > 0 then
    begin
      for lItemIdx := 0 to Count - 1 do
        lDestination.Add(Items[lItemIdx].CloneSelf);
    end;
  end;
  inherited;
end;

{ TXMLObjectList<T> }

constructor TXMLObjectList<T>.Create;
begin
  inherited;

  FItems := TFPGObjectList<T>.Create(True);
end;

destructor TXMLObjectList<T>.Destroy;
begin
  FItems.Free;

  inherited;
end;

function TXMLObjectList<T>.Add(AObject: TXMLObject): Integer;
begin
  Result := FItems.Add(T(AObject));
  AObject.OwnerList := Self;
end;

function TXMLObjectList<T>.AddObject(const AName: string): T;
var
  lIdx: integer;
begin
  Result := T(TXMLClass(T).Create);
  Result.Name := AName;
  Result.OwnerList := Self;

  lIdx := IndexOf(AName);
  if lIdx = -1 then
    Add(Result)
  else
  begin
    FItems.Delete(lIdx);
    FItems.Insert(lIdx, Result);
  end;
end;

procedure TXMLObjectList<T>.Clear;
begin
  FItems.Clear;
end;

function TXMLObjectList<T>.FindByName(const AName: string): T;
var
  lIdx: integer;
begin
  lIdx := IndexOf(AName);
  if lIdx = -1 then
    Result := nil
  else
    Result := FItems[lIdx];
end;

function TXMLObjectList<T>.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TXMLObjectList<T>.GetItem(AIndex: Integer): TXMLObject;
begin
  Result := FItems[AIndex];
end;

function TXMLObjectList<T>.GetTypedItem(AIndex: Integer): T;
begin
  Result := FItems[AIndex];
end;

end.
