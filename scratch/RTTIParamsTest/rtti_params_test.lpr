program rtti_params_test;

{$mode objfpc}{$H+}

uses
  Classes,
  SysUtils,
  TypInfo;

type
  TBaseParams = class(TPersistent)
  end;

  TSpecificParams = class(TBaseParams)
  end;

  TBaseCommand = class(TPersistent)
  private
    FParams: TBaseParams;
    procedure SetParams(AValue: TBaseParams);
  public
    constructor Create;
    destructor Destroy; override;
  published
    property params: TBaseParams read FParams write SetParams;
  end;

  TSpecificCommand = class(TBaseCommand)
  private
    function GetParams: TSpecificParams;
    procedure SetParams(AValue: TSpecificParams);
  published
    property params: TSpecificParams read GetParams write SetParams;
  end;

function PropClassType(APropInfo: PPropInfo): TClass;
var
  lTypeInfo: PTypeInfo;
begin
  Result := nil;
  if APropInfo = nil then
    Exit;

  lTypeInfo := APropInfo^.PropType;
  if lTypeInfo = nil then
    Exit;

  Result := GetTypeData(lTypeInfo)^.ClassType;
end;

constructor TBaseCommand.Create;
begin
  inherited Create;
end;

destructor TBaseCommand.Destroy;
begin
  FreeAndNil(FParams);
  inherited Destroy;
end;

procedure TBaseCommand.SetParams(AValue: TBaseParams);
begin
  FParams := AValue;
end;

function TSpecificCommand.GetParams: TSpecificParams;
begin
  Result := TSpecificParams(inherited params);
end;

procedure TSpecificCommand.SetParams(AValue: TSpecificParams);
begin
  inherited params := AValue;
end;

procedure DumpPublishedClassProps(AInstance: TObject);
var
  lClass: TClass;
  lCount: Integer;
  lIdx: Integer;
  lList: PPropList;
  lPropInfo: PPropInfo;
  lClassType: TClass;
begin
  lClass := AInstance.ClassType;
  Writeln('Class: ', lClass.ClassName);

  lCount := GetPropList(PTypeInfo(lClass.ClassInfo), [tkClass], nil);
  Writeln('Published class prop count: ', lCount);
  if lCount <= 0 then
    Exit;

  GetMem(lList, lCount * SizeOf(Pointer));
  try
    GetPropList(PTypeInfo(lClass.ClassInfo), [tkClass], lList);
    for lIdx := 0 to lCount - 1 do
    begin
      lPropInfo := lList^[lIdx];
      lClassType := PropClassType(lPropInfo);
      if lClassType = nil then
        Writeln('  ', lPropInfo^.Name, ': <nil typeinfo>')
      else
        Writeln('  ', lPropInfo^.Name, ': ', lClassType.ClassName);
    end;
  finally
    FreeMem(lList);
  end;
end;

procedure TestGetPropInfoByName;
var
  lCommand: TSpecificCommand;
  lPropInfo: PPropInfo;
  lClassType: TClass;
  lValue: TObject;
begin
  lCommand := TSpecificCommand.Create;
  try
    Writeln;
    Writeln('GetPropInfo(TSpecificCommand, "params")');
    lPropInfo := GetPropInfo(lCommand, 'params');
    if lPropInfo = nil then
    begin
      Writeln('  prop: nil');
      Exit;
    end;

    lClassType := PropClassType(lPropInfo);
    Writeln('  prop type: ', lClassType.ClassName);

    SetObjectProp(lCommand, lPropInfo, TSpecificParams.Create);
    lValue := GetObjectProp(lCommand, lPropInfo);
    if lValue = nil then
      Writeln('  object value: nil')
    else
      Writeln('  object value: ', lValue.ClassName);
  finally
    lCommand.Free;
  end;
end;

begin
  DumpPublishedClassProps(TBaseCommand.Create);
  Writeln;
  DumpPublishedClassProps(TSpecificCommand.Create);
  TestGetPropInfoByName;
end.
