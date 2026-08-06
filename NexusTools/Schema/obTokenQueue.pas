unit obTokenQueue;

{$mode delphi}{$H+}

interface

uses
  Classes,
  SysUtils,
  fgl,
  obNexusSchemaTypes;

type
  TToken = class(TObject)
  public
    Text: string;
    TokenType: TTokenType;

    Position: integer;
    Line: integer;
    Column: integer;
  end;

  TTokenList = TFPGObjectList<TToken>;

  TTokenQueue = class(TObject)
  private
    FTokens: TTokenList;
    FPosition: Integer;
    FCurrent: TToken;

    function GetCount: Integer;
    function GetItem(Index: Integer): TToken;
    procedure SetItem(Index: Integer; AObject: TToken);
    function GetCurrent: TToken;
    function GetTokenIndex(Index: Integer): Integer;
    function GetInsertIndex(Index: Integer): Integer;
    function IsIgnoredToken(AToken: TToken): Boolean;
    procedure NormalizeCommentToken(AToken: TToken);
  protected
  public
    constructor Create; virtual;
    destructor Destroy; override;

    procedure Clear;
    procedure Insert(Index: Integer; AObject: TToken);
    procedure InsertQueue(Index: Integer; AQueue: TTokenQueue);
    function Extract(Item: TToken): TToken;
    function ExtractIndex(Index: integer): TToken;
    function First: TToken;

    function Push(AObject: TToken): TToken;
    function Pop(AReleaseOwnership: boolean = false): TToken;
    function Peek: TToken;

    property Count: Integer read GetCount;
    property Items[Index: Integer]: TToken read GetItem write SetItem; default;
    property Current: TToken read GetCurrent;
  published
  end;

implementation

constructor TTokenQueue.Create;
begin
  inherited Create;

  FTokens := TTokenList.Create(True);
  FPosition := 0;
  FCurrent := nil;
end;

destructor TTokenQueue.Destroy;
begin
  FreeAndNil(FTokens);
  inherited Destroy;
end;

function TTokenQueue.GetCount: Integer;
var
  lIdx: Integer;
begin
  Result := 0;
  for lIdx := FPosition to FTokens.Count - 1 do
  begin
    NormalizeCommentToken(FTokens[lIdx]);
    if not IsIgnoredToken(FTokens[lIdx]) then
      Inc(Result);
  end;
end;

function TTokenQueue.GetItem(Index: Integer): TToken;
begin
  Result := FTokens[GetTokenIndex(Index)];
end;

procedure TTokenQueue.SetItem(Index: Integer; AObject: TToken);
begin
  FTokens[GetTokenIndex(Index)] := AObject;
end;

function TTokenQueue.GetCurrent: TToken;
begin
  Result := FCurrent;
end;

function TTokenQueue.GetTokenIndex(Index: Integer): Integer;
var
  lIdx: Integer;
  lTokenIdx: Integer;
begin
  lTokenIdx := 0;
  for lIdx := FPosition to FTokens.Count - 1 do
  begin
    NormalizeCommentToken(FTokens[lIdx]);
    if not IsIgnoredToken(FTokens[lIdx]) then
    begin
      if lTokenIdx = Index then
      begin
        Result := lIdx;
        Exit;
      end;
      Inc(lTokenIdx);
    end;
  end;

  raise EListError.CreateFmt('Token index out of bounds (%d)', [Index]);
end;

function TTokenQueue.GetInsertIndex(Index: Integer): Integer;
var
  lIdx: Integer;
  lTokenIdx: Integer;
begin
  if Index <= 0 then
  begin
    Result := FPosition;
    Exit;
  end;

  lTokenIdx := 0;
  for lIdx := FPosition to FTokens.Count - 1 do
  begin
    NormalizeCommentToken(FTokens[lIdx]);
    if not IsIgnoredToken(FTokens[lIdx]) then
    begin
      Inc(lTokenIdx);
      if lTokenIdx = Index then
      begin
        Result := lIdx + 1;
        Exit;
      end;
    end;
  end;

  Result := FTokens.Count;
end;

function TTokenQueue.IsIgnoredToken(AToken: TToken): Boolean;
begin
  Result := Assigned(AToken) and (AToken.TokenType = ttComment);
end;

procedure TTokenQueue.NormalizeCommentToken(AToken: TToken);
begin
  if not Assigned(AToken) or (AToken.TokenType <> ttComment) then
    Exit;

  if (Pos(#13, AToken.Text) > 0) or (Pos(#10, AToken.Text) > 0) then
  begin
    AToken.Text := ';';
    AToken.TokenType := ttOperator;
  end;
end;

procedure TTokenQueue.Clear;
begin
  FCurrent := nil;
  FPosition := 0;
  FTokens.Clear;
end;

procedure TTokenQueue.Insert(Index: Integer; AObject: TToken);
begin
  FTokens.Insert(GetInsertIndex(Index), AObject);
end;

procedure TTokenQueue.InsertQueue(Index: Integer; AQueue: TTokenQueue);
var
  lIdx: integer;
begin
  for lIdx := AQueue.Count - 1 downto 0 do
    Insert(Index, AQueue[lIdx]);
end;

function TTokenQueue.Extract(Item: TToken): TToken;
begin
  Result := FTokens.Extract(Item);

  if Result = FCurrent then
    FCurrent := nil;

  if FPosition > FTokens.Count then
    FPosition := FTokens.Count;
end;

function TTokenQueue.ExtractIndex(Index: integer): TToken;
begin
  Result := Extract(Self[Index]);
end;

function TTokenQueue.First: TToken;
begin
  if Count > 0 then
    Result := Self[0]
  else
    Result := nil;
end;

function TTokenQueue.Push(AObject: TToken): TToken;
begin
  FTokens.Add(AObject);
  Result := AObject;
end;

function TTokenQueue.Pop(AReleaseOwnership: boolean): TToken;
var
  lTokenIndex: Integer;
begin
  Result := Peek;

  if Result = nil then
    Exit;

  FCurrent := Result;

  if AReleaseOwnership then
  begin
    Result := FTokens.Extract(Result);
  end
  else
  begin
    lTokenIndex := GetTokenIndex(0);
    FPosition := lTokenIndex + 1;
  end;
end;

function TTokenQueue.Peek: TToken;
begin
  Result := First;
end;

end.
