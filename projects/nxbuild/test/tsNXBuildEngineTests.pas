// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
unit tsNXBuildEngineTests;

{$mode objfpc}{$H+}

interface

uses obNXTestRegistry;

procedure RegisterNXBuildEngineTests(ARegistry: TNXTestRegistry;
  const AEngineProject: string);
procedure RegisterNXBuildEngineRuntimeTests(ARegistry: TNXTestRegistry;
  const ASimulator: string; const AReproductionFile: string);

implementation

uses Classes, SysUtils, Process, obNXTestContext, obNXTestSuite,
  obNXBuildDescription, obNXBuildDescriptionLoader, obNXBuildPlanner,
  obNexusScriptModel;

var
  lEngineProject: string;
  lSimulator: string;
  lReproductionFile: string;

procedure CheckEngineSource(AContext: TNXTestContext; const ARelativeFileName: string);
var
  lTargets: TNexusScriptTargetSelection;
  lLoader: TNXBuildDescriptionLoader;
  lPlanner: TNXBuildPlanner;
  lDescription: TNXBuildDescription;
  lPlan: TNXBuildPlan;
  lStep, lSelectedStep: TNXBuildStep;
  lSources, lParameters: TStringList;
  lArguments: array of string;
  lFileName, lOutput: string;
  lIndex: Integer;
  lSucceeded: Boolean;
begin
  lTargets := TNexusScriptTargetSelection.Create;
  lLoader := TNXBuildDescriptionLoader.Create;
  lPlanner := TNXBuildPlanner.Create;
  lSources := TStringList.Create;
  lParameters := TStringList.Create;
  lDescription := nil;
  lPlan := nil;
  try
    lTargets.Add('TargetOS', 'linux');
    lTargets.Add('TargetCPU', 'x86_64');
    lDescription := lLoader.LoadDescription(lEngineProject, lTargets);
    lPlan := lPlanner.CreatePlan(lDescription, False);
    lFileName := ExpandFileName(ARelativeFileName,
      ExtractFileDir(lEngineProject));
    lSelectedStep := nil;
    for lStep in lPlan.Steps do
      if lStep.SourceFiles.IndexOf(lFileName) >= 0 then
      begin
        lSelectedStep := lStep;
        Break;
      end;
    AContext.AssertTrue(lSelectedStep <> nil,
      'The real engine recipe must compile ' + lFileName);
    lSources.Add(lFileName);
    lSelectedStep.FillArguments(lSources, 0, lParameters);
    lParameters.Add('-fsyntax-only');
    lParameters.Add('-Werror=incompatible-function-pointer-types');
    SetLength(lArguments, lParameters.Count);
    for lIndex := 0 to lParameters.Count - 1 do
      lArguments[lIndex] := lParameters[lIndex];
    lSucceeded := RunCommandIndir(lDescription.RootDirectory,
      lSelectedStep.Executable, lArguments, lOutput, [poStderrToOutPut]);
    AContext.AssertTrue(lSucceeded,
      ARelativeFileName + ' must compile with the actual engine options.' +
      LineEnding + lOutput);
  finally
    lPlan.Free;
    lDescription.Free;
    lParameters.Free;
    lSources.Free;
    lPlanner.Free;
    lLoader.Free;
    lTargets.Free;
  end;
end;

procedure TestMPG123Headers(AContext: TNXTestContext);
begin
  CheckEngineSource(AContext, 'external/mpg123-1.13.1/src/libmpg123/compat.c');
end;

procedure TestMPG123ABI(AContext: TNXTestContext);
begin
  CheckEngineSource(AContext, 'external/ALmixer/Isolated/LGPL/mpg123.c');
end;

procedure TestOGGABI(AContext: TNXTestContext);
begin
  CheckEngineSource(AContext, 'external/ALmixer/Isolated/LGPL/oggtremor.c');
end;

procedure TestWAVABI(AContext: TNXTestContext);
begin
  CheckEngineSource(AContext, 'external/ALmixer/Isolated/LGPL/wav.c');
end;

procedure CheckDecoderContract(AContext: TNXTestContext; const ACase: string);
var
  lTargets: TNexusScriptTargetSelection;
  lLoader: TNXBuildDescriptionLoader;
  lPlanner: TNXBuildPlanner;
  lDescription: TNXBuildDescription;
  lPlan: TNXBuildPlan;
  lStep, lSelectedStep: TNXBuildStep;
  lParameters: TStringList;
  lArguments: array of string;
  lEngineRoot, lSourceRoot, lProbe, lOutput, lFileName, lFixtureRoot: string;
  lIndex: Integer;
  lSucceeded: Boolean;
  lSearch: TSearchRec;
  lObjectDirectory: string;
  lGroup: Integer;
begin
  lTargets := TNexusScriptTargetSelection.Create;
  lLoader := TNXBuildDescriptionLoader.Create;
  lPlanner := TNXBuildPlanner.Create;
  lParameters := TStringList.Create;
  lDescription := nil;
  lPlan := nil;
  try
    lTargets.Add('TargetOS', 'linux');
    lTargets.Add('TargetCPU', 'x86_64');
    lDescription := lLoader.LoadDescription(lEngineProject, lTargets);
    lPlan := lPlanner.CreatePlan(lDescription, False);
    lEngineRoot := ExtractFilePath(lEngineProject);
    lSourceRoot := lEngineRoot + 'external/ALmixer/';
    lFileName := lSourceRoot + 'Isolated/SoundDecoder.c';
    lSelectedStep := nil;
    for lStep in lPlan.Steps do
      if lStep.SourceFiles.IndexOf(lFileName) >= 0 then
      begin
        lSelectedStep := lStep;
        Break;
      end;
    AContext.AssertTrue(lSelectedStep <> nil, 'The engine must compile SoundDecoder.c');
    lParameters.Assign(lSelectedStep.Arguments);
    for lIndex := lParameters.Count - 1 downto 0 do
      if (lParameters[lIndex] = '-c') or
         (lParameters[lIndex] = '-DSOUND_SUPPORTS_MPG123') or
         (lParameters[lIndex] = '-DSOUND_SUPPORTS_OGG') then
        lParameters.Delete(lIndex);
    lParameters.Add('-no-pie');
    lParameters.Add('-fsanitize=address,undefined');
    lParameters.Add('-fno-omit-frame-pointer');
    lParameters.Add('-g');
    lParameters.Add('-pthread');
    lFixtureRoot := IncludeTrailingPathDelimiter(lDescription.RootDirectory) +
      'projects/nxbuild/test/fixtures/decoder-contract/';
    lParameters.Add('-Werror=incompatible-function-pointer-types');
    lParameters.Add('-I' + lFixtureRoot);
    if ACase = 'real-codecs' then
    begin
      lParameters.Add('-DSOUND_SUPPORTS_MPG123');
      lParameters.Add('-DSOUND_SUPPORTS_OGG');
      lParameters.Add(lFileName);
      lParameters.Add(lSourceRoot + 'Isolated/ALmixer_RWops.c');
      lParameters.Add(lSourceRoot + 'Isolated/tErrorLib.c');
      lParameters.Add(lSourceRoot + 'Isolated/SimpleMutex.c');
      lParameters.Add(lSourceRoot + 'LinkedList.c');
      lParameters.Add(lSourceRoot + 'Isolated/LGPL/mpg123.c');
      lParameters.Add(lSourceRoot + 'Isolated/LGPL/oggtremor.c');
      lParameters.Add(lSourceRoot + 'Isolated/LGPL/wav.c');
      lParameters.Add('-x');
      lParameters.Add('none');
      for lGroup := 31 to 32 do
      begin
        lObjectDirectory := ExtractFilePath(lSimulator) + 'objects/' + IntToStr(lGroup) + '/';
        AContext.AssertTrue(FindFirst(lObjectDirectory + '*.o', faAnyFile, lSearch) = 0,
          'Build the actual engine codec objects before this test');
        try
          repeat
            lParameters.Add(lObjectDirectory + lSearch.Name);
          until FindNext(lSearch) <> 0;
        finally
          FindClose(lSearch);
        end;
      end;
      lParameters.Add(lFixtureRoot + 'real_codecs.c');
      lParameters.Add('-lm');
    end
    else if (ACase = 'tremor') or (ACase = 'vorbis') then
    begin
      lParameters.Add('-DSOUND_SUPPORTS_OGG');
      if ACase = 'vorbis' then
      begin
        lParameters.Add('-DTEST_VORBIS');
        lParameters.Insert(0, '-I' + lEngineRoot + 'external/ogg/libvorbis/include');
        lParameters.Insert(0, '-I' + lEngineRoot + 'external/ogg/libogg/include');
        lParameters.Add(lSourceRoot + 'Isolated/LGPL/oggvorbis.c');
      end
      else
        lParameters.Add(lSourceRoot + 'Isolated/LGPL/oggtremor.c');
      lParameters.Add(lFixtureRoot + 'ogg_contract.c');
    end
    else if ACase = 'mpg123' then
    begin
      lParameters.Add('-DSOUND_SUPPORTS_MPG123');
      lParameters.Add('-Wl,--wrap=realloc');
      lParameters.Add(lSourceRoot + 'Isolated/LGPL/mpg123.c');
      lParameters.Add(lSourceRoot + 'Isolated/SimpleMutex.c');
      lParameters.Add(lFixtureRoot + 'mpg_contract.c');
    end
    else if ACase = 'coreaudio' then
    begin
      lParameters.Add('-D__APPLE__');
      lParameters.Add('-I' + lFixtureRoot);
      lParameters.Add('-Wl,--wrap=malloc');
      lParameters.Add(lSourceRoot + 'Isolated/coreaudio.c');
      lParameters.Add(lFixtureRoot + 'coreaudio_contract.c');
    end
    else if ACase = 'boundaries' then
    begin
      lParameters.Insert(0, '-I' + lEngineRoot + 'external/mpg123-1.13.1/src/libmpg123');
      lParameters.Add(lSourceRoot + 'Isolated/ALmixer_RWops.c');
      lParameters.Add(lFixtureRoot + 'boundary_contract.c');
    end
    else
    begin
      lParameters.Add(lFileName);
      lParameters.Add(lSourceRoot + 'Isolated/ALmixer_RWops.c');
      lParameters.Add(lSourceRoot + 'Isolated/tErrorLib.c');
      lParameters.Add(lSourceRoot + 'LinkedList.c');
      if ACase = 'mixer' then
      begin
        lParameters.Add(lSourceRoot + 'ALmixer.c');
        lParameters.Add(lSourceRoot + 'CircularQueue.c');
        lParameters.Add(lSourceRoot + 'Isolated/SimpleMutex.c');
        lParameters.Add(lSourceRoot + 'Isolated/SimpleThreadPosix.c');
        lParameters.Add(lFixtureRoot + 'mixer_contract.c');
        lParameters.Add('-lopenal');
        lParameters.Add('-lm');
      end
      else if Pos('wav-', ACase) = 1 then
      begin
        lParameters.Add(lSourceRoot + 'Isolated/LGPL/wav.c');
        lParameters.Add(lFixtureRoot + 'wav_contract.c');
      end
      else
      begin
        lParameters.Add('-Wl,--wrap=malloc,--wrap=calloc,--wrap=realloc');
        lParameters.Add(lFixtureRoot + 'decoder_contract.c');
      end;
    end;
    lProbe := ExtractFilePath(ExpandFileName(ParamStr(0))) + 'decoder-contract-probe';
    lParameters.Add('-o');
    lParameters.Add(lProbe);
    lParameters.SaveToFile(lProbe + '-' + ACase + '.args');
    SetLength(lArguments, lParameters.Count);
    for lIndex := 0 to lParameters.Count - 1 do
      lArguments[lIndex] := lParameters[lIndex];
    lSucceeded := RunCommandIndir(lDescription.RootDirectory,
      lSelectedStep.Executable, lArguments, lOutput, [poStderrToOutPut]);
    AContext.AssertTrue(lSucceeded, 'Compile actual dispatcher contract probe: ' + lOutput);
    if ACase = 'mixer' then
      lSucceeded := RunCommandIndir(lDescription.RootDirectory, 'env',
        ['ALSOFT_DRIVERS=null', lProbe], lOutput, [poStderrToOutPut])
    else if ACase = 'real-codecs' then
      lSucceeded := RunCommandIndir(lDescription.RootDirectory, lProbe,
        [ExpandFileName('../nexus-lab/StarExplorer/audio/leonell-cassio-the-sapphire-city-10450.mp3', lEngineRoot),
         ExpandFileName('../nexus-lab/examples/graphics/angle/Asteroids/src/res/rotate.ogg', lEngineRoot),
         ExpandFileName('../nexus-lab/examples/mobile/native/LaunchingFromNativeUI/Corona/bubble_strong_wav.wav', lEngineRoot)],
        lOutput, [poStderrToOutPut])
    else
      lSucceeded := RunCommandIndir(lDescription.RootDirectory,
        lProbe, [ACase], lOutput, [poStderrToOutPut]);
    AContext.AssertTrue(lSucceeded, ACase + ': ' + lOutput);
  finally
    lPlan.Free;
    lDescription.Free;
    lParameters.Free;
    lPlanner.Free;
    lLoader.Free;
    lTargets.Free;
  end;
end;

procedure TestExplicitSampleCleanup(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'explicit-free');
end;

procedure TestQuitClosesSamples(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'quit');
end;

procedure TestZeroResizePreservesState(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'zero-resize');
end;

procedure TestDecodeAllRejectsInvalidErrorCount(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'error-count');
end;

procedure TestWAVPCM(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'wav-pcm');
end;

procedure TestWAVErrors(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'wav-errors');
end;

procedure TestWAVADPCM(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'wav-adpcm');
end;

procedure TestTremor(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'tremor');
end;

procedure TestVorbis(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'vorbis');
end;

procedure TestMPG123Boundaries(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'mpg123');
end;

procedure TestCoreAudio(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'coreaudio');
end;

procedure TestBoundaries(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'boundaries');
end;

procedure TestAllocation(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'allocation');
end;

procedure TestResizeAllocation(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'allocation-resize');
end;

procedure TestMixerShortRead(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'mixer');
end;

procedure TestEffectiveFormat(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'format');
end;

procedure TestNoProgress(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'no-progress');
end;

procedure TestActualCodecs(AContext: TNXTestContext);
begin
  CheckDecoderContract(AContext, 'real-codecs');
end;

procedure CheckIndexArrayAllocation(AContext: TNXTestContext; const AKind: string);
var
  lTargets: TNexusScriptTargetSelection;
  lLoader: TNXBuildDescriptionLoader;
  lPlanner: TNXBuildPlanner;
  lDescription: TNXBuildDescription;
  lPlan: TNXBuildPlan;
  lStep, lSelectedStep: TNXBuildStep;
  lParameters: TStringList;
  lArguments: array of string;
  lFileName, lProbe, lOutput: string;
  lIndex: Integer;
begin
  lTargets := TNexusScriptTargetSelection.Create;
  lLoader := TNXBuildDescriptionLoader.Create;
  lPlanner := TNXBuildPlanner.Create;
  lParameters := TStringList.Create;
  lDescription := nil;
  lPlan := nil;
  try
    lTargets.Add('TargetOS', 'linux');
    lTargets.Add('TargetCPU', 'x86_64');
    lDescription := lLoader.LoadDescription(lEngineProject, lTargets);
    lPlan := lPlanner.CreatePlan(lDescription, False);
    lFileName := ExtractFilePath(lEngineProject) + 'librtt/Core/Rtt_Allocator.cpp';
    lSelectedStep := nil;
    for lStep in lPlan.Steps do
      if lStep.SourceFiles.IndexOf(lFileName) >= 0 then
      begin
        lSelectedStep := lStep;
        Break;
      end;
    AContext.AssertTrue(lSelectedStep <> nil, 'The engine must compile its allocator');
    lParameters.Assign(lSelectedStep.Arguments);
    for lIndex := lParameters.Count - 1 downto 0 do
      if lParameters[lIndex] = '-c' then lParameters.Delete(lIndex);
    lParameters.Add('-O0');
    lParameters.Add('-g');
    lParameters.Add('-fsanitize=address');
    lParameters.Add('-fno-omit-frame-pointer');
    lParameters.Add('-no-pie');
    lParameters.Add('--driver-mode=g++');
    lParameters.Add(lFileName);
    lParameters.Add(IncludeTrailingPathDelimiter(lDescription.RootDirectory) +
      'projects/nxbuild/test/fixtures/engine-memory/index_array.cpp');
    lProbe := ExtractFilePath(ExpandFileName(ParamStr(0))) + 'engine-index-array-probe';
    lParameters.Add('-o');
    lParameters.Add(lProbe);
    lParameters.SaveToFile(lProbe + '-' + AKind + '.args');
    SetLength(lArguments, lParameters.Count);
    for lIndex := 0 to lParameters.Count - 1 do lArguments[lIndex] := lParameters[lIndex];
    AContext.AssertTrue(RunCommandIndir(lDescription.RootDirectory,
      lSelectedStep.Executable, lArguments, lOutput, [poStderrToOutPut]),
      'Compile the actual allocator and IndexArray header: ' + lOutput);
    AContext.AssertTrue(RunCommandIndir(lDescription.RootDirectory,
      lProbe, [AKind], lOutput, [poStderrToOutPut]),
      'IndexArray must release its buffer through the matching allocator: ' + lOutput);
  finally
    lParameters.Free;
    lPlan.Free;
    lDescription.Free;
    lPlanner.Free;
    lLoader.Free;
    lTargets.Free;
  end;
end;

procedure TestIndexArrayUInt32Allocation(AContext: TNXTestContext);
begin
  CheckIndexArrayAllocation(AContext, 'uint32');
end;

procedure TestIndexArrayUInt16Allocation(AContext: TNXTestContext);
begin
  CheckIndexArrayAllocation(AContext, 'uint16');
end;

procedure TestEGLDisplayCleanup(AContext: TNXTestContext);
var
  lTargets: TNexusScriptTargetSelection;
  lLoader: TNXBuildDescriptionLoader;
  lPlanner: TNXBuildPlanner;
  lDescription: TNXBuildDescription;
  lPlan: TNXBuildPlan;
  lStep, lSelectedStep: TNXBuildStep;
  lParameters: TStringList;
  lArguments: array of string;
  lFileName, lProbe, lOutput: string;
  lIndex: Integer;
  lSucceeded: Boolean;
begin
  lTargets := TNexusScriptTargetSelection.Create;
  lLoader := TNXBuildDescriptionLoader.Create;
  lPlanner := TNXBuildPlanner.Create;
  lParameters := TStringList.Create;
  lDescription := nil;
  lPlan := nil;
  try
    lTargets.Add('TargetOS', 'linux');
    lTargets.Add('TargetCPU', 'x86_64');
    lDescription := lLoader.LoadDescription(lEngineProject, lTargets);
    lPlan := lPlanner.CreatePlan(lDescription, False);
    lFileName := ExtractFilePath(lEngineProject) + 'librtt/Core/Rtt_Allocator.cpp';
    lSelectedStep := nil;
    for lStep in lPlan.Steps do
      if lStep.SourceFiles.IndexOf(lFileName) >= 0 then
      begin
        lSelectedStep := lStep;
        Break;
      end;
    AContext.AssertTrue(lSelectedStep <> nil, 'Find the actual engine C++ compiler');
    lParameters.Assign(lSelectedStep.Arguments);
    for lIndex := lParameters.Count - 1 downto 0 do
      if lParameters[lIndex] = '-c' then lParameters.Delete(lIndex);
    lParameters.Add('--driver-mode=g++');
    lParameters.Add('-O0');
    lParameters.Add('-g');
    lParameters.Add('-fsanitize=address');
    lParameters.Add('-fno-omit-frame-pointer');
    lParameters.Add('-no-pie');
    lParameters.Add(IncludeTrailingPathDelimiter(lDescription.RootDirectory) +
      'projects/nxbuild/test/fixtures/engine-memory/egl_display_cleanup.cpp');
    lParameters.Add('-ldl');
    lProbe := ExtractFilePath(ExpandFileName(ParamStr(0))) + 'engine-egl-cleanup-probe';
    lParameters.Add('-o');
    lParameters.Add(lProbe);
    lParameters.SaveToFile(lProbe + '.args');
    SetLength(lArguments, lParameters.Count);
    for lIndex := 0 to lParameters.Count - 1 do lArguments[lIndex] := lParameters[lIndex];
    lSucceeded := RunCommandIndir(lDescription.RootDirectory,
      lSelectedStep.Executable, lArguments, lOutput, [poStderrToOutPut]);
    AContext.AssertTrue(lSucceeded, 'Compile the installed-EGL cleanup probe: ' + lOutput);
    lSucceeded := RunCommandIndir(lDescription.RootDirectory,
      lProbe, [], lOutput, [poStderrToOutPut]);
    AContext.AssertTrue(Pos('NXTEST_EGL_CLEANUP_COMPLETE', lOutput) > 0,
      'EGL initialize, terminate, thread release and library unload must succeed: ' + lOutput);
    AContext.AssertTrue(lSucceeded, 'EGL cleanup must leave no leaked allocations: ' + lOutput);
  finally
    lParameters.Free;
    lPlan.Free;
    lDescription.Free;
    lPlanner.Free;
    lLoader.Free;
    lTargets.Free;
  end;
end;

procedure CheckEngineLuaExit(AContext: TNXTestContext; const AFixture, AMarker: string);
var
  lFixture, lOutput: string;
  lSucceeded: Boolean;
begin
  lFixture := ExpandFileName('../nexus/projects/nxbuild/test/fixtures/' + AFixture + '/main.lua',
    ExtractFileDir(lEngineProject));
  AContext.AssertTrue(FileExists(lSimulator), 'Build the actual simulator before running this test');
  lSucceeded := RunCommandIndir(ExtractFileDir(lSimulator), 'env',
    ['SDL_VIDEODRIVER=offscreen', 'ALSOFT_DRIVERS=null', 'timeout', '20s',
     lSimulator, lFixture], lOutput, [poStderrToOutPut]);
  AContext.AssertTrue(lSucceeded, 'Lua os.exit(0) must terminate cleanly: ' + lOutput);
  AContext.AssertTrue(Pos(AMarker, lOutput) > 0,
    'The real engine must reach the Lua callback: ' + lOutput);
end;

procedure TestEngineFontProviderLifetime(AContext: TNXTestContext);
begin
  CheckEngineLuaExit(AContext, 'engine-runtime-font', 'NXTEST_ENGINE_FONT_OK');
end;

procedure TestEngineLocalePreferences(AContext: TNXTestContext);
begin
  CheckEngineLuaExit(AContext, 'engine-runtime-preferences', 'NXTEST_ENGINE_PREFERENCES_OK');
end;

procedure TestEngineLuaExit(AContext: TNXTestContext);
begin
  CheckEngineLuaExit(AContext, 'engine-runtime-exit', 'NXTEST_ENGINE_LUA_REACHED');
end;

procedure TestEngineMinimalLuaExit(AContext: TNXTestContext);
begin
  CheckEngineLuaExit(AContext, 'engine-runtime-minimal-exit', 'NXBUILD_ENGINE_RUNTIME_DONE');
end;

procedure TestEngineInitializedAudioCleanup(AContext: TNXTestContext);
begin
  CheckEngineLuaExit(AContext, 'engine-runtime-audio-cleanup', 'NXTEST_ENGINE_AUDIO_CLEANUP_OK');
end;

procedure TestEngineDialogCleanup(AContext: TNXTestContext);
begin
  CheckEngineLuaExit(AContext, 'engine-runtime-dialog-cleanup', 'NXTEST_ENGINE_DIALOG_CLEANUP_OK');
end;

procedure TestOriginalEngineLuaExit(AContext: TNXTestContext);
var
  lOutput: string;
  lSucceeded: Boolean;
begin
  AContext.AssertTrue(FileExists(lReproductionFile), 'The original reproduction input must exist');
  lSucceeded := RunCommandIndir(ExtractFileDir(lReproductionFile), 'env',
    ['SDL_VIDEODRIVER=offscreen', 'ALSOFT_DRIVERS=null', 'timeout', '20s',
     lSimulator, lReproductionFile], lOutput, [poStderrToOutPut]);
  AContext.AssertTrue(lSucceeded, 'The original application/cwd must exit cleanly: ' + lOutput);
  AContext.AssertTrue(Pos('NXBUILD_ENGINE_RUNTIME_DONE', lOutput) > 0,
    'The original application must reach its Lua exit callback: ' + lOutput);
end;

procedure RegisterNXBuildEngineRuntimeTests(ARegistry: TNXTestRegistry;
  const ASimulator: string; const AReproductionFile: string);
var
  lSuite: TNXTestSuite;
begin
  lSimulator := ExpandFileName(ASimulator);
  lSuite := ARegistry.AddSuite('Nexus2D.EngineRuntime');
  lSuite.AddTest('ActualCodecs', @TestActualCodecs);
  lSuite.AddTest('EGLDisplayCleanup', @TestEGLDisplayCleanup);
  lSuite.AddTest('LocalePreferenceLifetime', @TestEngineLocalePreferences);
  lSuite.AddTest('FontProviderLifetime', @TestEngineFontProviderLifetime);
  lSuite.AddTest('LuaExitWithConfig', @TestEngineLuaExit);
  lSuite.AddTest('MinimalLuaExit', @TestEngineMinimalLuaExit);
  lSuite.AddTest('InitializedAudioCleanup', @TestEngineInitializedAudioCleanup);
  lSuite.AddTest('DialogCleanup', @TestEngineDialogCleanup);
  if AReproductionFile <> '' then
  begin
    lReproductionFile := ExpandFileName(AReproductionFile);
    lSuite.AddTest('OriginalApplicationExit', @TestOriginalEngineLuaExit);
  end;
end;

procedure RegisterNXBuildEngineTests(ARegistry: TNXTestRegistry;
  const AEngineProject: string);
var
  lSuite: TNXTestSuite;
begin
  lEngineProject := ExpandFileName(AEngineProject);
  lSuite := ARegistry.AddSuite('Nexus2D.DecoderABI');
  lSuite.AddTest('MPG123', @TestMPG123ABI);
  lSuite.AddTest('OGG', @TestOGGABI);
  lSuite.AddTest('WAV', @TestWAVABI);
  lSuite := ARegistry.AddSuite('Nexus2D.DecoderConfiguration');
  lSuite.AddTest('MPG123Headers', @TestMPG123Headers);
  lSuite := ARegistry.AddSuite('Nexus2D.DecoderContract');
  lSuite.AddTest('ExplicitFree', @TestExplicitSampleCleanup);
  lSuite.AddTest('QuitClosesSamples', @TestQuitClosesSamples);
  lSuite.AddTest('ZeroResizePreservesState', @TestZeroResizePreservesState);
  lSuite.AddTest('RejectInvalidErrorCount', @TestDecodeAllRejectsInvalidErrorCount);
  lSuite.AddTest('WAVPCM', @TestWAVPCM);
  lSuite.AddTest('WAVErrors', @TestWAVErrors);
  lSuite.AddTest('WAVADPCM', @TestWAVADPCM);
  lSuite.AddTest('Tremor', @TestTremor);
  lSuite.AddTest('Vorbis', @TestVorbis);
  lSuite.AddTest('MPG123Boundaries', @TestMPG123Boundaries);
  lSuite.AddTest('CoreAudioAdapter', @TestCoreAudio);
  lSuite.AddTest('Boundaries', @TestBoundaries);
  lSuite.AddTest('Allocation', @TestAllocation);
  lSuite.AddTest('ResizeAllocation', @TestResizeAllocation);
  lSuite.AddTest('MixerShortRead', @TestMixerShortRead);
  lSuite.AddTest('EffectiveFormat', @TestEffectiveFormat);
  lSuite.AddTest('NoProgress', @TestNoProgress);
  lSuite := ARegistry.AddSuite('Nexus2D.Memory');
  lSuite.AddTest('IndexArrayUInt32Allocation', @TestIndexArrayUInt32Allocation);
  lSuite.AddTest('IndexArrayUInt16Allocation', @TestIndexArrayUInt16Allocation);
end;

end.
