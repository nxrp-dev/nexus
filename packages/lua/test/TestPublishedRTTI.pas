program TestPublishedRTTI;

{$mode objfpc}{$H+}

uses
  Classes,
  SysUtils,
  TypInfo,
  Rtti;

type
  TAddLink = function(A, B: Integer): Integer of object;

  TProbe = class(TPersistent)
  private
    FAdd: TAddLink;
    FName: string;
    FOnChanged: TNotifyEvent;
    function LinkAdd(A, B: Integer): Integer;
    procedure DoOnChanged(ASender: TObject);
  public
    constructor Create;
    function Hidden(AValue: Integer): Integer;
  published
    property Add: TAddLink read FAdd;
    property Name: string read FName write FName;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
  end;

constructor TProbe.Create;
begin
  inherited Create;
  FAdd := @LinkAdd;
end;

function TProbe.Hidden(AValue: Integer): Integer;
begin
  Result := AValue;
end;

function TProbe.LinkAdd(A, B: Integer): Integer;
begin
  Result := A + B;
end;

procedure TProbe.DoOnChanged(ASender: TObject);
begin
end;

var
  Obj: TProbe;
  Context: TRttiContext;
  RttiType: TRttiType;
  Prop: TRttiProperty;
  MethodType: TRttiMethodType;
  Args: TValueArray;
  BoundMethod: TMethod;
  Callable: TValue;
  Value: TValue;

begin
  Obj := TProbe.Create;
  Context := TRttiContext.Create;
  try
    RttiType := Context.GetType(Obj.ClassInfo);

    Prop := RttiType.GetProperty('Add');
    if Prop = nil then
      raise Exception.Create('Published Add link property RTTI missing');
    if not (Prop.PropertyType is TRttiMethodType) then
      raise Exception.Create('Published Add link does not expose method-type RTTI');
    if not Prop.IsReadable then
      raise Exception.Create('Published Add link must be readable');
    if Prop.IsWritable then
      raise Exception.Create('Published Add link must be read-only');

    SetLength(Args, 2);
    Args[0] := TValue.FromOrdinal(TypeInfo(Integer), 20);
    Args[1] := TValue.FromOrdinal(TypeInfo(Integer), 22);
    MethodType := TRttiMethodType(Prop.PropertyType);
    BoundMethod := GetMethodProp(Obj, PPropInfo(Prop.Handle));
    TValue.Make(@BoundMethod, MethodType.Handle, Callable);
    Value := MethodType.Invoke(Callable, Args);
    if Value.AsOrdinal <> 42 then
      raise Exception.Create('RTTI method-property invoke failed');

    Prop := RttiType.GetProperty('Name');
    if Prop = nil then
      raise Exception.Create('Published Name property RTTI missing');

    Value := TValue.specialize From<string>('Nexus');
    Prop.SetValue(Obj, Value);
    if Obj.Name <> 'Nexus' then
      raise Exception.Create('RTTI property set failed');

    Obj.OnChanged := @Obj.DoOnChanged;
    Prop := RttiType.GetProperty('OnChanged');
    if Prop = nil then
      raise Exception.Create('Published OnChanged event property RTTI missing');
    if not (Prop.PropertyType is TRttiMethodType) then
      raise Exception.Create('Published OnChanged event does not expose method-type RTTI');
    if not Prop.IsWritable then
      raise Exception.Create('Published events must remain writable');

    WriteLn('RTTI bridge prerequisite test passed');
  finally
    Context.Free;
    Obj.Free;
  end;
end.
