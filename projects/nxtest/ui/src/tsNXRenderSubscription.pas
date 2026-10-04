unit tsNXRenderSubscription;

{$mode objfpc}{$H+}

interface

procedure RunNXRenderSubscriptionTests(const AReportPath: string);

implementation

uses
  Classes, SysUtils, Math, fpg_base, fpg_main, fpg_panel, Lua51,
  obNXRender, obNXSkin, tpNXSkin, tpNXRender, obNXSkinPalette, obNXPanelRender, obNXRenderPanel,
  obNXLuaRender, obNXLuaSkin, obNXPascalSkin, obNXRenderRecordingCanvas,
  obNXRenderAppearance;

type
  TNXTextState = class(TNexusControlState)
  private
    FText: string;
  published
    property Text: string read FText write FText;
  end;

  TNXPanelStateProbe = class(TNXRenderPanel)
  public
    procedure EnterPointer;
    procedure LeavePointer;
    property RenderStates: TNXRenderStates read GetRenderStates;
  end;

  TNXExtendedPanelState = class(TNXPanelFrameState)
  private
    FSeverity: Integer;
    FBadgeText: string;
    FArgb: LongWord;
    FScale: Double;
    FUnicodeText: UnicodeString;
  published
    property Severity: Integer read FSeverity write FSeverity;
    property BadgeText: string read FBadgeText write FBadgeText;
    property Argb: LongWord read FArgb write FArgb;
    property Scale: Double read FScale write FScale;
    property UnicodeText: UnicodeString read FUnicodeText write FUnicodeText;
  end;

  TNXUnsupportedState = class(TNexusControlState)
  private
    FChild: TPersistent;
  published
    property Child: TPersistent read FChild write FChild;
  end;

  TNXInt64State = class(TNexusControlState)
  private
    FValue: Int64;
  published
    property Value: Int64 read FValue write FValue;
  end;

  TNXUnreadableState = class(TNexusControlState)
  private
    FValue: Integer;
  published
    property Value: Integer write FValue;
  end;

  TNXFailingLuaSkin = class(TNXLuaSkin)
  public
    constructor Create; override;
  end;

procedure TNXPanelStateProbe.EnterPointer;
begin
  HandleMouseEnter;
end;

procedure TNXPanelStateProbe.LeavePointer;
begin
  HandleMouseExit;
end;

constructor TNXFailingLuaSkin.Create;
begin
  inherited Create;
  raise Exception.Create('intentional partial skin construction');
end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

procedure RunLua(ASkin: TNXLuaSkin; const ACode: string);
var
  lTop: Integer;
  lMask: TFPUExceptionMask;
begin
  lTop := lua_gettop(ASkin.LuaState);
  lMask := GetExceptionMask;
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
    exOverflow, exUnderflow, exPrecision]);
  try
    if luaL_dostring(ASkin.LuaState, PChar(ACode)) <> 0 then
      raise Exception.Create('Lua test: ' + string(lua_tostring(ASkin.LuaState, -1)));
  finally
    lua_settop(ASkin.LuaState, lTop);
    SetExceptionMask(lMask);
  end;
end;

procedure RejectSubscription(ASkin: TNXSkin; const AName: string;
  AState: TNexusControlState; const AMessage: string);
var
  lBinding: TNXRenderSubscription;
  lError: string;
begin
  lError := '';
  try
    lBinding := ASkin.Subscribe(AName, AState);
    lBinding.Free;
  except
    on lException: Exception do lError := lException.Message;
  end;
  Check(Pos(AMessage, lError) > 0, 'Expected binding rejection: ' + AMessage + '; got ' + lError);
end;

procedure TestPanelParity(AReport: TStrings);
var
  lPascal: TNXPascalSkin;
  lLua: TNXLuaSkin;
  lState: TNXPanelFrameState;
  lPascalBinding, lLuaBinding: TNXRenderSubscription;
  lNativeCanvas, lLuaCanvas: TNXRenderRecordingCanvas;
  lStyle: TPanelStyle;
  lBorder: TPanelBorder;
  lExpected: TStringList;
  lFirstColor, lLastColor, lHighlight: LongWord;
  lWidth, lPass: Integer;
begin
  lPascal := TNXPascalSkin.Create;
  lLua := TNXLuaSkin.Create;
  lState := TNXPanelFrameState.Create;
  lNativeCanvas := TNXRenderRecordingCanvas.Create;
  lLuaCanvas := TNXRenderRecordingCanvas.Create;
  lExpected := TStringList.Create;
  lPascalBinding := nil;
  lLuaBinding := nil;
  try
    lState.Left := 2;
    lState.Top := 3;
    lState.Width := 20;
    lState.Height := 15;
    lPascalBinding := lPascal.Subscribe(cNXPanelFrame, lState);
    lLuaBinding := lLua.Subscribe(cNXPanelFrame, lState);
    for lPass := 1 to 2 do
    begin
      lHighlight := $FF54575B;
      if lPass = 2 then
        lHighlight := $FF123456;
      lPascal.Colors.Defaults.SetColor(siHighlight, lHighlight);
      lLua.Colors.Defaults.SetColor(siHighlight, lHighlight);
      for lStyle := Low(TPanelStyle) to High(TPanelStyle) do
        for lBorder := Low(TPanelBorder) to High(TPanelBorder) do
        begin
          lState.Style := lStyle;
          lState.BorderStyle := lBorder;
          lNativeCanvas.Reset;
          lLuaCanvas.Reset;
          lPascalBinding.Render(lNativeCanvas);
          lLuaBinding.Render(lLuaCanvas);
          lExpected.Clear;
          if lStyle <> bsFlat then
          begin
            if lStyle = bsRaised then
            begin
              lFirstColor := lHighlight;
              lLastColor := $FF1E1E1E;
            end
            else
            begin
              lFirstColor := $FF1E1E1E;
              lLastColor := lHighlight;
            end;
            lWidth := Ord(lBorder) + 1;
            if lBorder = bsSingle then
            begin
              lExpected.Add(Format('2,3,21,3;%s;1', [IntToHex(lFirstColor, 8)]));
              lExpected.Add(Format('2,4,2,17;%s;1', [IntToHex(lFirstColor, 8)]));
            end
            else
            begin
              lExpected.Add(Format('2,4,21,4;%s;2', [IntToHex(lFirstColor, 8)]));
              lExpected.Add(Format('3,4,3,17;%s;2', [IntToHex(lFirstColor, 8)]));
            end;
            lExpected.Add(Format('21,3,21,17;%s;%d', [IntToHex(lLastColor, 8), lWidth]));
            lExpected.Add(Format('2,17,22,17;%s;%d', [IntToHex(lLastColor, 8), lWidth]));
          end;
          Check(lNativeCanvas.Commands.Text = lExpected.Text, 'Native panel frame differs from expected commands.');
          Check(lLuaCanvas.Commands.Text = lExpected.Text, 'Lua panel frame differs from expected commands.');
        end;
    end;
    Check(lPascal.RenderRegistry.ResolutionCount = 1, 'Native capability resolved during paint.');
    Check(lLua.RenderRegistry.ResolutionCount = 1, 'Lua capability resolved during paint.');
    AReport.Add('PASS: 12 frame cases, ordered coordinates/colors/widths, flat, live palette updates, one-time name resolution');
  finally
    lLuaBinding.Free;
    lPascalBinding.Free;
    lExpected.Free;
    lLuaCanvas.Free;
    lNativeCanvas.Free;
    lState.Free;
    lLua.Free;
    lPascal.Free;
  end;
end;

procedure TestStateAndLifetime(AReport: TStrings);
var
  lSkin: TNXLuaSkin;
  lRenderer, lDuplicate: TNXLuaRenderer;
  lState: TNXExtendedPanelState;
  lBase: TNexusControlState;
  lUnsupported: TNXUnsupportedState;
  lWide: TNXInt64State;
  lUnreadable: TNXUnreadableState;
  lBinding, lOther, lNative: TNXRenderSubscription;
  lCanvas: TNXRenderRecordingCanvas;
  lError: string;
  lTop, lIndex: Integer;
  lMask: TFPUExceptionMask;
begin
  lSkin := TNXLuaSkin.Create;
  lState := TNXExtendedPanelState.Create;
  lBase := TNexusControlState.Create;
  lUnsupported := TNXUnsupportedState.Create;
  lWide := TNXInt64State.Create;
  lUnreadable := TNXUnreadableState.Create;
  lCanvas := TNXRenderRecordingCanvas.Create;
  lBinding := nil;
  lOther := nil;
  lNative := nil;
  try
    RunLua(lSkin, 'calls=0; snapshots={}; function inspectState(canvas,state) ' +
      'calls=calls+1; snapshots[calls]=state; retainedCanvas=canvas; ' +
      'if state.Severity then ' +
      'assert(state.Left==7 and state.Disabled==false and state.Style=="bsRaised"); ' +
      'assert(state.Pressed==(state.Severity==1)); ' +
      'assert(state.Hovered==(state.Severity~=2) and state.Focused==(state.Severity~=3)); ' +
      'assert(state.Severity==calls and state.Selected==true and state.BadgeText=="badge"..calls); ' +
      'assert(state.Argb==4294967295 and state.Scale==1.25); ' +
      'assert(state.UnicodeText==string.char(206,187)); state.Selected=false; ' +
      'state.Disabled=true; state.Hovered=false; end end; ' +
      'function failDraw(canvas,state) retainedCanvas=canvas; error("intentional draw failure") end');
    lRenderer := TNXLuaRenderer.Create(lSkin.LuaState, 'inspectState',
      TNexusControlState, lSkin.CanvasBridge, lSkin.CanvasRef);
    lSkin.RegisterRenderer('arbitrary.test.capability', lRenderer);
    lBinding := lSkin.Subscribe('arbitrary.test.capability', lState);
    lOther := lSkin.Subscribe('arbitrary.test.capability', lBase);
    Check(lRenderer.SchemaCount = 2, 'Actual descendant schemas were not cached separately.');
    lSkin.RegisterRenderer('native.extended', TNXPanelFrameRenderer.Create(lSkin.Colors));
    lNative := lSkin.Subscribe('native.extended', lState);
    lState.Left := 7;
    lState.Style := bsRaised;
    lState.Width := 20;
    lState.Height := 15;
    lState.Argb := High(LongWord);
    lState.Scale := 1.25;
    lState.UnicodeText := UnicodeString(WideChar($03BB));
    RunLua(lSkin, 'inspectState=function() error("global must not be re-resolved") end');
    for lIndex := 1 to 3 do
    begin
      case lIndex of
        1: lState.States := [nrsPressed, nrsHovered, nrsFocused];
        2: lState.States := [nrsFocused];
        3: lState.States := [nrsHovered];
      end;
      lState.Severity := lIndex;
      lState.States := lState.States + [nrsSelected];
      lState.BadgeText := 'badge' + IntToStr(lIndex);
      lBinding.Render(lCanvas);
      Check(lState.Selected, 'Lua modified Pascal-owned state.');
      Check(not lState.Disabled and (lState.Hovered = (lIndex <> 2)),
        'Lua modified the Pascal state flags.');
      lNative.Render(lCanvas);
    end;
    lOther.Render(lCanvas);
    Check(lCanvas.LineCount = 12, 'Typed native descendant binding did not render.');
    Check(lRenderer.SchemaCount = 2, 'Schema discovery repeated during painting.');
    Check(lRenderer.FunctionResolutionCount = 1, 'Function lookup repeated during painting.');
    Check(lSkin.RenderRegistry.ResolutionCount = 3, 'Capability resolution repeated during painting.');
    RejectSubscription(lSkin, 'missing', lState, 'not registered');
    RejectSubscription(lSkin, 'Arbitrary.test.capability', lState, 'not registered');
    RejectSubscription(lSkin, cNXPanelFrame, lBase, 'expects TNXPanelFrameState');
    RejectSubscription(lSkin, cNXPanelFrame, nil, 'requires state');
    RejectSubscription(lSkin, 'arbitrary.test.capability', lUnsupported, 'TNXUnsupportedState.Child');
    RejectSubscription(lSkin, 'arbitrary.test.capability', lWide, 'TNXInt64State.Value');
    RejectSubscription(lSkin, 'arbitrary.test.capability', lUnreadable, 'TNXUnreadableState.Value');
    lDuplicate := TNXLuaRenderer.Create(lSkin.LuaState, 'failDraw',
      TNexusControlState, lSkin.CanvasBridge, lSkin.CanvasRef);
    try
      lError := '';
      try
        lSkin.RegisterRenderer('arbitrary.test.capability', lDuplicate);
      except
        on lException: Exception do lError := lException.Message;
      end;
      Check(Pos('already registered', lError) > 0, 'Duplicate capability accepted.');
    finally
      lDuplicate.Free;
    end;
    lTop := lua_gettop(lSkin.LuaState);
    lError := '';
    try
      lDuplicate := TNXLuaRenderer.Create(lSkin.LuaState, 'absentFunction',
        TNexusControlState, lSkin.CanvasBridge, lSkin.CanvasRef,
        TNXPanelFrameColors.Create(lSkin.Colors));
      lDuplicate.Free;
    except
      on lException: Exception do lError := lException.Message;
    end;
    Check(Pos('absentFunction', lError) > 0, 'Missing Lua function accepted.');
    Check(lua_gettop(lSkin.LuaState) = lTop, 'Failed registration changed Lua stack.');
    lSkin.RegisterRenderer('failure', TNXLuaRenderer.Create(lSkin.LuaState,
      'failDraw', TNexusControlState, lSkin.CanvasBridge, lSkin.CanvasRef));
    FreeAndNil(lOther);
    lOther := lSkin.Subscribe('failure', lBase);
    lMask := GetExceptionMask;
    for lIndex := 1 to 3 do
    begin
      lError := '';
      try
        lOther.Render(lCanvas);
      except
        on lException: Exception do lError := lException.Message;
      end;
      Check(Pos('intentional draw failure', lError) > 0, 'Draw failure lost its diagnostic.');
      Check(lua_gettop(lSkin.LuaState) = lTop, 'Draw failure leaked Lua stack entries.');
      Check(GetExceptionMask = lMask, 'Draw failure changed FPU mask.');
      Check(lSkin.CanvasBridge.AttachedCanvas = nil, 'Draw failure retained a canvas.');
    end;
    RunLua(lSkin, 'local ok,msg=pcall(function() retainedCanvas:Line(1,2,3,4) end); ' +
      'assert(not ok and string.find(msg,"only available during drawing",1,true))');
    FreeAndNil(lBinding);
    FreeAndNil(lNative);
    FreeAndNil(lState);
    RunLua(lSkin, 'collectgarbage("collect"); assert(snapshots[1].Severity==1 and ' +
      'snapshots[2].Severity==2 and snapshots[3].Severity==3 and snapshots[4].Width==0); ' +
      'assert(snapshots[1].Selected==false)');
    FreeAndNil(lSkin);
    Check(not lOther.IsValid, 'Skin destruction left a callable subscription.');
    lError := '';
    try
      lOther.Render(lCanvas);
    except
      on lException: Exception do lError := lException.Message;
    end;
    Check(Pos('no longer valid', lError) > 0, 'Invalidated subscription did not report an error.');
    AReport.Add('PASS: inherited/extended/current scalar state, UTF-8, exact unsigned32, snapshots, pinned function, cached schemas, typed native descendant');
    AReport.Add('PASS: missing/duplicate/case-sensitive names, wrong/nil state, unsupported Int64/object/write-only properties, missing function');
    AReport.Add('PASS: draw errors, stable stack/FPU mask, detached canvas, retained snapshots after state destruction, skin-first teardown');
  finally
    lNative.Free;
    lOther.Free;
    lBinding.Free;
    lCanvas.Free;
    lUnreadable.Free;
    lWide.Free;
    lUnsupported.Free;
    lBase.Free;
    lState.Free;
    lSkin.Free;
  end;
end;

procedure TestResolvedPanelColors(AReport: TStrings);
const
  cAlias = 'AlternatePanel';
var
  lPascal: TNXPascalSkin;
  lLua: TNXLuaSkin;
  lState, lDisabled: TNXPanelFrameState;
  lPascalBinding, lLuaBinding, lDisabledBinding: TNXRenderSubscription;
  lNativeCanvas, lLuaCanvas: TNXRenderRecordingCanvas;
  lNativeColors, lLuaColors: TNXSkinRenderValues;

  procedure CheckPair(AHighlight, AShadow: LongWord);
  begin
    lNativeCanvas.Reset;
    lLuaCanvas.Reset;
    lPascalBinding.Render(lNativeCanvas);
    lLuaBinding.Render(lLuaCanvas);
    Check(lNativeCanvas.Commands.Text = lLuaCanvas.Commands.Text,
      'Native/Lua resolved panel colors differ.');
    Check(lNativeCanvas.Commands[0] =
      '2,3,21,3;' + IntToHex(AHighlight, 8) + ';1', 'Resolved highlight differs.');
    Check(lNativeCanvas.Commands[2] =
      '21,3,21,17;' + IntToHex(AShadow, 8) + ';1', 'Resolved shadow differs.');
  end;

begin
  lPascal := TNXPascalSkin.Create;
  lLua := TNXLuaSkin.Create;
  lState := TNXPanelFrameState.Create;
  lDisabled := TNXPanelFrameState.Create;
  lNativeCanvas := TNXRenderRecordingCanvas.Create;
  lLuaCanvas := TNXRenderRecordingCanvas.Create;
  lPascalBinding := nil;
  lLuaBinding := nil;
  lDisabledBinding := nil;
  try
    lState.Left := 2;
    lState.Top := 3;
    lState.Width := 20;
    lState.Height := 15;
    lState.Style := bsRaised;
    lState.BorderStyle := bsSingle;
    lState.States := [nrsHovered];
    lDisabled.Style := bsFlat;
    lDisabled.States := [nrsDisabled];
    RunLua(lLua, 'colorSnapshots={}; function captureColors(canvas,state,colors) ' +
      'colorSnapshots[#colorSnapshots+1]=colors; drawPanelFrame(canvas,state,colors) end');
    lPascal.RegisterRenderer(cAlias, TNXPanelFrameRenderer.Create(lPascal.Colors));
    lLua.RegisterRenderer(cAlias, TNXLuaRenderer.Create(lLua.LuaState,
      'captureColors', TNXPanelFrameState, lLua.CanvasBridge, lLua.CanvasRef,
      TNXPanelFrameColors.Create(lLua.Colors)));
    lPascalBinding := lPascal.Subscribe(cAlias, lState);
    lLuaBinding := lLua.Subscribe(cAlias, lState);
    lDisabledBinding := lLua.Subscribe(cAlias, lDisabled);
    lNativeColors := lPascal.Colors.AddRender(cAlias);
    lLuaColors := lLua.Colors.AddRender(cAlias);
    lNativeColors.Values.SetColor(siHighlight, $FF102030);
    lLuaColors.Values.SetColor(siHighlight, $FF102030);
    lNativeColors.States[nrsHovered].SetColor(siHighlight, $80402010);
    lLuaColors.States[nrsHovered].SetColor(siHighlight, $80402010);
    lNativeColors.States[nrsDisabled].SetColor(siHighlight, 0);
    lLuaColors.States[nrsDisabled].SetColor(siHighlight, 0);
    CheckPair($80402010, $FF1E1E1E);
    lDisabledBinding.Render(lLuaCanvas);
    CheckPair($80402010, $FF1E1E1E);
    RunLua(lLua, 'assert(colorSnapshots[1].Highlight==2151686160 and ' +
      'colorSnapshots[2].Highlight==0 and colorSnapshots[3].Highlight==2151686160)');
    lNativeColors.States[nrsFocused].SetColor(siHighlight, $FF556677);
    lLuaColors.States[nrsFocused].SetColor(siHighlight, $FF556677);
    lNativeColors.States[nrsPressed].SetColor(siHighlight, $FF778899);
    lLuaColors.States[nrsPressed].SetColor(siHighlight, $FF778899);
    lState.States := [nrsPressed, nrsHovered, nrsFocused];
    CheckPair($FF778899, $FF1E1E1E);
    lNativeColors.States[nrsPressed].Clear(siHighlight, [saColor]);
    lLuaColors.States[nrsPressed].Clear(siHighlight, [saColor]);
    CheckPair($80402010, $FF1E1E1E);
    lNativeColors.States[nrsHovered].Clear(siHighlight, [saColor]);
    lLuaColors.States[nrsHovered].Clear(siHighlight, [saColor]);
    CheckPair($FF556677, $FF1E1E1E);
    lState.States := [nrsDisabled, nrsPressed, nrsHovered, nrsFocused];
    CheckPair(0, $FF1E1E1E);
    lNativeColors.States[nrsDisabled].Clear(siHighlight, [saColor]);
    lLuaColors.States[nrsDisabled].Clear(siHighlight, [saColor]);
    CheckPair($FF102030, $FF1E1E1E);
    lNativeColors.Values.Clear(siHighlight, [saColor]);
    lLuaColors.Values.Clear(siHighlight, [saColor]);
    lPascal.Colors.Defaults.SetColor(siHighlight, $FF345678);
    lLua.Colors.Defaults.SetColor(siHighlight, $FF345678);
    CheckPair($FF345678, $FF1E1E1E);
    lNativeColors.States[nrsDisabled].SetColor(siShadow, $FFFFFFFF);
    lLuaColors.States[nrsDisabled].SetColor(siShadow, $FFFFFFFF);
    CheckPair($FF345678, $FFFFFFFF);
    // A different skin's palette must not leak through application-wide colors.
    lLua.Colors.Defaults.SetColor(siHighlight, $FFABCDEF);
    lLua.ApplyNamedColors;
    lNativeCanvas.Reset;
    lPascalBinding.Render(lNativeCanvas);
    Check(Pos(';FF345678;', lNativeCanvas.Commands[0]) > 0,
      'Another skin changed the native renderer palette.');
    RunLua(lLua, 'assert(colorSnapshots[1].Highlight==2151686160)');
    Check(lPascal.RenderRegistry.ResolutionCount = 1, 'Native renderer re-resolved its name.');
    Check(lLua.RenderRegistry.ResolutionCount = 2, 'Lua renderer re-resolved its name.');
    AReport.Add('PASS: real registered name, state/render/global color fallback, zero/unsigned32, alternating bindings, live edits, per-skin isolation, retained Lua color snapshots');
  finally
    lDisabledBinding.Free;
    lLuaBinding.Free;
    lPascalBinding.Free;
    lLuaCanvas.Free;
    lNativeCanvas.Free;
    lDisabled.Free;
    lState.Free;
    lLua.Free;
    lPascal.Free;
  end;
end;

procedure TestButtonProgressColors(AReport: TStrings);
var
  lSkin, lReference: TNXSkin;
  lCanvas: TNXRenderRecordingCanvas;
  lButton, lProgressColors: TNXSkinRenderValues;
  lProgress: TfpgStyleDrawProgressBar;
  lExpected: string;

  procedure CheckButton(AFlags: TfpgButtonFlags; const AColor: string);
  begin
    lCanvas.Reset;
    lReference.DrawButtonFace(lCanvas, 2, 3, 20, 15, AFlags);
    lExpected := lCanvas.Commands.Text;
    lCanvas.Reset;
    lSkin.DrawButtonFace(lCanvas, 2, 3, 20, 15, AFlags);
    Check(lCanvas.Commands.Text = StringReplace(lExpected, 'FF505860', AColor,
      [rfReplaceAll]), 'Button color override changed unrelated drawing commands.');
  end;

begin
  lSkin := TNXSkin.Create;
  lReference := TNXSkin.Create;
  lCanvas := TNXRenderRecordingCanvas.Create;
  try
    lSkin.DrawButtonFace(lCanvas, 2, 3, 20, 15, []);
    lExpected := lCanvas.Commands.Text;
    Check(Pos(';FF505860;', lExpected) > 0, 'Original button highlight was not retained.');
    lButton := lSkin.Colors.FindRender(cNXButtonRender);
    lButton.States[nrsHovered].SetColor(siHighlight, $FF123456);
    lButton.States[nrsFocused].SetColor(siHighlight, $FF456789);
    lButton.States[nrsDisabled].SetColor(siHighlight, 0);
    CheckButton([], 'FF505860');
    CheckButton([btfHover], 'FF123456');
    CheckButton([btfHasFocus], 'FF456789');
    CheckButton([btfHover, btfHasFocus], 'FF123456');
    CheckButton([btfDisabled], '00000000');
    CheckButton([btfDisabled, btfHover, btfHasFocus], '00000000');
    lButton.States[nrsDisabled].Clear(siHighlight, [saColor]);
    CheckButton([btfDisabled, btfHover, btfHasFocus], 'FF505860');
    lButton.States[nrsHovered].Clear(siHighlight, [saColor]);
    CheckButton([btfHover, btfHasFocus], 'FF456789');
    CheckButton([], 'FF505860');
    lButton.Values.SetColor(siHighlight, $FF234567);
    lSkin.ApplyNamedColors;
    CheckButton([], 'FF234567');
    lButton.Values.Clear(siHighlight, [saColor]);
    lSkin.Colors.Defaults.SetColor(siHighlight, $FF345678);
    CheckButton([], 'FF345678');
    lProgress := Default(TfpgStyleDrawProgressBar);
    lProgress.Rect.SetRect(2, 3, 20, 15);
    lProgress.Max := 100;
    lProgress.Position := 50;
    lCanvas.Reset;
    lSkin.DrawProgressBar(lCanvas, lProgress);
    lExpected := lCanvas.Commands.Text;
    Check(Pos(';FF5BBEF0;', lExpected) > 0, 'Original progress highlight was not retained.');
    lProgressColors := lSkin.Colors.FindRender(cNXProgressRender);
    lProgressColors.Values.SetColor(siHighlight, $FF456789);
    lCanvas.Reset;
    lSkin.DrawProgressBar(lCanvas, lProgress);
    Check(lCanvas.Commands.Text = StringReplace(lExpected, 'FF5BBEF0', 'FF456789',
      [rfReplaceAll]), 'Progress override changed unrelated drawing commands.');
    lProgressColors.Values.Clear(siHighlight, [saColor]);
    lCanvas.Reset;
    lSkin.DrawProgressBar(lCanvas, lProgress);
    Check(lCanvas.Commands.Text = StringReplace(lExpected, 'FF5BBEF0', 'FF345678',
      [rfReplaceAll]), 'Progress did not fall back to the global highlight.');
    AReport.Add('PASS: button abnormal state and render/global fallback; progress render/global fallback; gradients and other commands unchanged');
  finally
    lCanvas.Free;
    lReference.Free;
    lSkin.Free;
  end;
end;

procedure TestFillPainting(AReport: TStrings);
var
  lSkin: TNXSkin;
  lCanvas: TNXRenderRecordingCanvas;
  lFill: TNXSkinFill;
  lProgress: TfpgStyleDrawProgressBar;
begin
  lSkin := TNXSkin.Create;
  lCanvas := TNXRenderRecordingCanvas.Create;
  try
    lFill := Default(TNXSkinFill);
    lFill.Kind := sfSolid;
    lFill.Color := $FF102030;
    lSkin.Colors.FindRender(cNXButtonRender).Values.SetFill(siHighlight, lFill);
    lCanvas.Reset;
    lSkin.DrawButtonFace(lCanvas, 2, 3, 20, 15, []);
    Check(lCanvas.Commands[0] = 'fill:3,4,18,13;FF102030',
      'Button solid Fill was not drawn as a solid surface.');

    lFill.Kind := sfGradient;
    lFill.Color := $FF112233;
    lFill.StopColor := $FF445566;
    lFill.Direction := gdHorizontal;
    lSkin.Colors.FindRender(cNXButtonRender).States[nrsHovered].
      SetFill(siHighlight, lFill);
    lCanvas.Reset;
    lSkin.DrawButtonFace(lCanvas, 2, 3, 20, 15, [btfHover]);
    Check(lCanvas.Commands[0] = '3,4,3,17;FF112233;1',
      'Button hovered Fill did not use its horizontal gradient.');
    lCanvas.Reset;
    lSkin.DrawButtonFace(lCanvas, 2, 3, 20, 15,
      [btfDisabled, btfHover]);
    Check(lCanvas.Commands[0] = 'fill:3,4,18,13;FF102030',
      'Disabled button must suppress the hovered Fill.');

    lFill.Kind := sfSolid;
    lFill.Color := $FF223344;
    lSkin.Colors.FindRender(cNXProgressRender).Values.SetFill(siHighlight, lFill);
    lProgress := Default(TfpgStyleDrawProgressBar);
    lProgress.Rect.SetRect(2, 3, 20, 15);
    lProgress.Max := 100;
    lProgress.Position := 50;
    lCanvas.Reset;
    lSkin.DrawProgressBar(lCanvas, lProgress);
    Check(Pos('fill:3,4,9,13;FF223344', lCanvas.Commands.Text) > 0,
      'Progress solid Fill did not reach its painter.');

    lFill.Color := $FF334455;
    lSkin.Colors.FindRender(cNXBevelRender).Values.SetFill(siShadow, lFill);
    lCanvas.Reset;
    lSkin.DrawBevel(lCanvas, 2, 3, 20, 15, False);
    Check(lCanvas.Commands[0] = 'fill:2,3,20,15;FF334455',
      'Bevel must use its own Fill rather than the Button Fill.');
    AReport.Add('PASS: solid, horizontal-gradient, Disabled, progress and bevel Fill painters');
  finally
    lCanvas.Free;
    lSkin.Free;
  end;
end;

procedure TestPanelStateInput(AReport: TStrings);
var
  lSkin: TNXPascalSkin;
  lPanel: TNXPanelStateProbe;
begin
  lSkin := TNXPascalSkin.Create;
  lPanel := TNXPanelStateProbe.Create(nil, lSkin);
  try
    Check(lPanel.RenderStates = [], 'Panel must start in the normal state.');
    lPanel.EnterPointer;
    Check(lPanel.RenderStates = [nrsHovered], 'Panel did not report pointer entry.');
    lPanel.Focused := True;
    Check(lPanel.RenderStates = [nrsHovered, nrsFocused], 'Panel did not report focus.');
    lPanel.Enabled := False;
    Check(lPanel.RenderStates = [nrsDisabled, nrsHovered, nrsFocused],
      'Panel must report facts, leaving precedence to the palette.');
    lPanel.LeavePointer;
    lPanel.Focused := False;
    lPanel.Enabled := True;
    Check(lPanel.RenderStates = [], 'Panel flags did not return to normal.');
    AReport.Add('PASS: panel pointer/focus/enabled input produces the expected abnormal-state set');
  finally
    lPanel.Free;
    lSkin.Free;
  end;
end;

procedure TestControlLifetime(AReport: TStrings);
var
  lSkin: TNXPascalSkin;
  lPanel: TNXRenderPanel;
  lIndex: Integer;
  lError: string;
  lRect: TfpgRect;
begin
  for lIndex := 1 to 10 do
  begin
    lSkin := TNXPascalSkin.Create;
    lPanel := TNXRenderPanel.Create(nil, lSkin);
    lPanel.SetPosition(0, 0, 100, 80);
    lPanel.Style := bsFlat;
    lRect := lPanel.GetClientRect;
    Check((lRect.Left = 0) and (lRect.Width = 100), 'Flat client bounds changed.');
    lPanel.Style := bsRaised;
    lRect := lPanel.GetClientRect;
    Check((lRect.Left = 2) and (lRect.Width = 96), 'Framed client bounds changed.');
    if Odd(lIndex) then
    begin
      lSkin.Free;
      lPanel.Free;
    end
    else
    begin
      lPanel.Free;
      lSkin.Free;
    end;
    lError := '';
    try
      TNXFailingLuaSkin.Create.Free;
    except
      on lException: Exception do lError := lException.Message;
    end;
    Check(lError = 'intentional partial skin construction', 'Partial-construction teardown failed.');
  end;
  AReport.Add('PASS: real control teardown in both orders, inherited client insets, repeated partial Lua skin construction');
end;

procedure TestTextAppearance(AReport: TStrings);
const
  cStates: array[0..5] of TNXRenderStates = (
    [], [nrsSelected], [nrsSelected, nrsHovered],
    [nrsSelected, nrsDisabled, nrsHovered], [nrsDisabled], []);
var
  lSkin: TNXLuaSkin;
  lState: TNXTextState;
  lRender: TNXSkinRenderValues;
  lBinding: TNXRenderSubscription;
  lNativeCanvas, lLuaCanvas: TNXRenderRecordingCanvas;
  lValue: TNXSkinAppearance;
  lFont: TfpgFontResourceBase;
  lPass, lX, lY: Integer;
  lDescriptor, lCacheSize: Integer;
begin
  lSkin := TNXLuaSkin.Create;
  lState := TNXTextState.Create;
  lNativeCanvas := TNXRenderRecordingCanvas.Create;
  lLuaCanvas := TNXRenderRecordingCanvas.Create;
  lBinding := nil;
  try
    RunLua(lSkin, 'appearanceSnapshots={}; function textAppearance(canvas,state,values) ' +
      'table.insert(appearanceSnapshots,values); retainedTextCanvas=canvas; ' +
      'canvas:Font(values.FontDesc); canvas:TextColor(values.Color); ' +
      'local x=state.Left+math.floor((state.Width-canvas:MeasureText(state.Text))/2); ' +
      'local y=state.Top+math.floor((state.Height-canvas:MeasureHeight())/2); ' +
      'canvas:Text(x,y,state.Text); end');
    lSkin.RegisterRenderer('Text', TNXLuaRenderer.Create(lSkin.LuaState,
      'textAppearance', TNXTextState, lSkin.CanvasBridge, lSkin.CanvasRef,
      TNXRenderAppearance.Create(lSkin.Colors, siText)));
    lBinding := lSkin.Subscribe('Text', lState);
    lRender := lSkin.Colors.FindRender(cNXTextRender);
    lRender.Values.SetFont(siText, 'Arial-10');
    lRender.States[nrsSelected].SetFont(siText, 'Arial-18:bold');
    lRender.States[nrsHovered].SetColor(siText, $FFFFFFFF);
    lRender.States[nrsDisabled].SetColor(siText, $FF72767B);
    lState.Left := 2;
    lState.Top := 3;
    lState.Width := 30;
    lState.Height := 12;
    lState.Text := 'State font';
    for lPass := Low(cStates) to High(cStates) do
    begin
      lState.States := cStates[lPass];
      lValue := lSkin.Colors.Resolve('Text', siText, lState.States);
      lFont := fpgApplication.FontManager.GetFont(lValue.FontDesc);
      lNativeCanvas.Reset;
      lNativeCanvas.SetFont(lFont);
      lNativeCanvas.SetTextColor(lValue.Color);
      // Floor, including negative overhang: identical to the Lua renderer.
      lX := lState.Left + Floor((lState.Width - lFont.GetTextWidth(lState.Text)) / 2);
      lY := lState.Top + Floor((lState.Height - lFont.GetHeight) / 2);
      if nrsSelected in lState.States then
        Check((lX < lState.Left) or (lY < lState.Top),
          'Oversized selected font did not exercise overhang.');
      lNativeCanvas.DrawString(lX, lY, lState.Text);
      lCacheSize := fpgApplication.FontManager.GetCacheSize;
      lLuaCanvas.Reset;
      lBinding.Render(lLuaCanvas);
      Check(lNativeCanvas.Commands.Text = lLuaCanvas.Commands.Text,
        'Native/Lua font, text color or measured alignment differs.');
      Check(lLuaCanvas.Font = lFont, 'Lua did not use the fpGUI-owned cached font.');
      Check(fpgApplication.FontManager.GetCacheSize = lCacheSize,
        'Lua created an additional font resource for the same descriptor.');
      Check((lState.Left = 2) and (lState.Top = 3) and
        (lState.Width = 30) and (lState.Height = 12), 'State font changed geometry.');
    end;
    RunLua(lSkin, 'assert(appearanceSnapshots[1].FontDesc=="Arial-10"); ' +
      'assert(appearanceSnapshots[4].FontDesc=="Arial-18:bold"); ' +
      'assert(appearanceSnapshots[4].Color==4285691515); ' +
      'appearanceSnapshots[4].FontDesc="local change"');
    Check(lSkin.Colors.Resolve('Text', siText, [nrsSelected]).FontDesc = 'Arial-18:bold',
      'Lua snapshot mutation changed the palette.');
    lRender.States[nrsSelected].SetFont(siText, 'Arial-14');
    lState.States := [nrsSelected];
    lBinding.Render(lLuaCanvas);
    RunLua(lSkin, 'assert(appearanceSnapshots[7].FontDesc=="Arial-14"); ' +
      'assert(appearanceSnapshots[2].FontDesc=="Arial-18:bold")');
    lSkin.Colors.RemoveRender('Text');
    lSkin.Colors.Defaults.SetFont(siText, 'Arial-11');
    lBinding.Render(lLuaCanvas);
    RunLua(lSkin, 'assert(appearanceSnapshots[8].FontDesc=="Arial-11")');
    // Every new canvas operation must remain unavailable outside a draw.
    for lDescriptor := 1 to 5 do
      RunLua(lSkin, 'local calls={' +
        'function() retainedTextCanvas:Font("Arial-10") end,' +
        'function() retainedTextCanvas:TextColor(0) end,' +
        'function() retainedTextCanvas:Text(0,0,"x") end,' +
        'function() retainedTextCanvas:MeasureText("x") end,' +
        'function() retainedTextCanvas:MeasureHeight() end}; ' +
        'local ok,msg=pcall(calls[' + IntToStr(lDescriptor) + ']); ' +
        'assert(not ok and string.find(msg,"only available during drawing",1,true))');
    FreeAndNil(lBinding);
    lSkin.ClearRenderers;
    RunLua(lSkin, 'assert(appearanceSnapshots[2].FontDesc=="Arial-18:bold")');
    Check(lFont.GetHeight > 0, 'Renderer teardown freed a borrowed font.');
    AReport.Add('PASS: native/Lua text parity, independent color/font fallback, Selected with Disabled, cached font ownership, retained snapshots, detached canvas, fixed geometry with overhang');
  finally
    lBinding.Free;
    lLuaCanvas.Free;
    lNativeCanvas.Free;
    lState.Free;
    lSkin.Free;
  end;
end;

procedure RecordSkinDrawing(AReport: TStrings);
const
  cButtonFlags: array[0..8] of TfpgButtonFlags = (
    [], [btfDisabled], [btfHover], [btfIsPressed], [btfFlat],
    [btfIsDefault], [btfHasFocus], [btfHover, btfDisabled],
    [btfIsPressed, btfDisabled]);
var
  lSkin: TNXSkin;
  lCanvas: TNXRenderRecordingCanvas;
  lProgress: TfpgStyleDrawProgressBar;
  lCase, lLine: Integer;
begin
  lSkin := TNXSkin.Create;
  lCanvas := TNXRenderRecordingCanvas.Create;
  try
    for lCase := Low(cButtonFlags) to High(cButtonFlags) do
    begin
      lCanvas.Reset;
      lSkin.DrawButtonFace(lCanvas, 2, 3, 20, 15, cButtonFlags[lCase]);
      for lLine := 0 to lCanvas.Commands.Count - 1 do
        AReport.Add(Format('DRAW Button%d %s', [lCase, lCanvas.Commands[lLine]]));
    end;
    for lCase := 0 to 1 do
    begin
      lCanvas.Reset;
      lSkin.DrawBevel(lCanvas, 2, 3, 20, 15, lCase = 0);
      for lLine := 0 to lCanvas.Commands.Count - 1 do
        AReport.Add(Format('DRAW Bevel%d %s', [lCase, lCanvas.Commands[lLine]]));
    end;
    lProgress := Default(TfpgStyleDrawProgressBar);
    lProgress.Rect.SetRect(2, 3, 20, 15);
    lProgress.Max := 100;
    for lCase := 0 to 2 do
    begin
      lProgress.Position := lCase * 50;
      lCanvas.Reset;
      lSkin.DrawProgressBar(lCanvas, lProgress);
      for lLine := 0 to lCanvas.Commands.Count - 1 do
        AReport.Add(Format('DRAW Progress%d %s', [lCase, lCanvas.Commands[lLine]]));
    end;
  finally
    lCanvas.Free;
    lSkin.Free;
  end;
end;

procedure RecordRoleDrawing(AReport: TStrings);
const
  cNamedColors: array[0..9] of TfpgColor = (
    clText1, clText4, clMenuDisabled, clSelectionText, clGridSelectionText,
    clInactiveSelText, clGridInactiveSelText, clShadow1, clInactiveWgFrame, clHilite2);
var
  lSkin: TNXSkin;
  lCanvas: TNXRenderRecordingCanvas;
  lFlags: TfpgCheckBoxFlags;
  lRect: TfpgRect;
  lCase, lLine: Integer;
begin
  lSkin := TNXSkin.Create;
  lCanvas := TNXRenderRecordingCanvas.Create;
  try
    for lCase := Low(cNamedColors) to High(cNamedColors) do
      AReport.Add(Format('ROLE Named%d %s', [lCase,
        IntToHex(LongWord(fpgColorToRGB(cNamedColors[lCase])), 8)]));
    lRect.SetRect(2, 3, 20, 20);
    for lCase := 0 to 31 do
    begin
      lFlags := [];
      if (lCase and 1) <> 0 then Include(lFlags, cbfChecked);
      if (lCase and 2) <> 0 then Include(lFlags, cbfPressed);
      if (lCase and 4) <> 0 then Include(lFlags, cbfEnabled);
      if (lCase and 8) <> 0 then Include(lFlags, cbfReadOnly);
      if (lCase and 16) <> 0 then Include(lFlags, cbfHasFocus);
      lCanvas.Reset;
      lSkin.DrawCheckBox(lCanvas, lRect, lFlags);
      for lLine := 0 to lCanvas.Commands.Count - 1 do
        AReport.Add(Format('ROLE Check%d %s', [lCase, lCanvas.Commands[lLine]]));
      lCanvas.Reset;
      lSkin.DrawRadioButton(lCanvas, lRect, lFlags);
      for lLine := 0 to lCanvas.Commands.Count - 1 do
        AReport.Add(Format('ROLE Radio%d %s', [lCase, lCanvas.Commands[lLine]]));
    end;
    lCanvas.SetFont(fpgApplication.FontManager.GetFont('#Label1'));
    for lCase := 0 to 3 do
    begin
      lCanvas.Reset;
      if lCase < 2 then lCanvas.SetTextColor(clText1)
      else lCanvas.SetTextColor($FF123456);
      lSkin.DrawString(lCanvas, 2, 3, 'Text', (lCase mod 2) = 0);
      for lLine := 0 to lCanvas.Commands.Count - 1 do
        AReport.Add(Format('ROLE Text%d %s', [lCase, lCanvas.Commands[lLine]]));
    end;
  finally
    lCanvas.Free;
    lSkin.Free;
  end;
end;

procedure RunNXRenderSubscriptionTests(const AReportPath: string);
var
  lReport: TStringList;
begin
  fpgApplication.Initialize;
  lReport := TStringList.Create;
  try
    TestPanelParity(lReport);
    TestStateAndLifetime(lReport);
    TestResolvedPanelColors(lReport);
    TestButtonProgressColors(lReport);
    TestFillPainting(lReport);
    TestPanelStateInput(lReport);
    TestControlLifetime(lReport);
    TestTextAppearance(lReport);
    RecordSkinDrawing(lReport);
    RecordRoleDrawing(lReport);
    lReport.SaveToFile(AReportPath);
  finally
    lReport.Free;
  end;
end;

end.
