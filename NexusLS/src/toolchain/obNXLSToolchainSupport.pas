unit obNXLSToolchainSupport;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  obNXLSToolchainContracts;

const
  cFpcDownloadsURL = 'https://www.freepascal.org/download.html';
  cAndroidSdkDownloadsURL = 'https://developer.android.com/studio';
  cAndroidNDKDownloadsURL = 'https://developer.android.com/ndk/downloads';
  cJavaDownloadsURL = 'https://learn.microsoft.com/java/openjdk/download';

function NXLSCleanDirectory(const ADirectory: string): string;
function NXLSCleanFileName(const AFileName: string): string;
function NXLSNormalizedPath(const APath: string): string;
function NXLSToolchainLazbuildFile(const ALazarusDirectory: string): string;
function NXLSToolchainFileInDirectory(const ADirectory,
  AFileName: string): string;
function NXLSToolchainFpcFile(const AFpcDirectory: string): string;
function NXLSToolchainFpcDirectoryFromCompilerPath(
  const ACompilerPath: string): string;
function NXLSToolchainBundledFpcDirectory(
  const ALazarusDirectory: string): string;
function NXLSToolchainAndroidAdbFile(
  const AAndroidSdkDirectory: string): string;
function NXLSToolchainAndroidNdkBuildFile(
  const AAndroidNdkDirectory: string): string;
function NXLSToolchainJavaFile(const AJavaHome: string): string;

procedure NXLSAddDownloadSuggestion(AField: TNXLSToolchainField;
  const ALabel, AUrl, AReason: string);
procedure NXLSSuggestCommonLazarusInstallPaths(AField: TNXLSToolchainField);
procedure NXLSSuggestCommonFpcInstallPaths(AField: TNXLSToolchainField);
procedure NXLSSuggestCommonFpcCompilerPaths(AField: TNXLSToolchainField);
procedure NXLSSuggestCommonAndroidSdkPaths(AField: TNXLSToolchainField);
procedure NXLSSuggestCommonAndroidNdkPaths(AField: TNXLSToolchainField);
procedure NXLSSuggestCommonJavaHomePaths(AField: TNXLSToolchainField);

implementation

uses
  SysUtils;

function NXLSCleanDirectory(const ADirectory: string): string;
begin
  Result := Trim(ADirectory);
  if Result <> '' then
    Result := ExpandFileName(Result);
end;

function NXLSCleanFileName(const AFileName: string): string;
begin
  Result := Trim(AFileName);
  if Result <> '' then
    Result := ExpandFileName(Result);
end;

function NXLSNormalizedPath(const APath: string): string;
begin
  Result := Trim(APath);
  if Result <> '' then
    Result := ExpandFileName(Result);
end;

function NXLSToolchainLazbuildFile(const ALazarusDirectory: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ALazarusDirectory) + 'lazbuild';
  {$IFDEF MSWINDOWS}
  Result := Result + '.exe';
  {$ENDIF}
end;

function NXLSToolchainFileInDirectory(const ADirectory,
  AFileName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ADirectory) + AFileName;
end;

function NXLSToolchainExecutableInDirectory(const ADirectory,
  AFileName: string): string;
begin
  Result := NXLSToolchainFileInDirectory(ADirectory, AFileName);
  {$IFDEF MSWINDOWS}
  Result := Result + '.exe';
  {$ENDIF}
end;

function NXLSToolchainBatchInDirectory(const ADirectory,
  AFileName: string): string;
begin
  Result := NXLSToolchainFileInDirectory(ADirectory, AFileName);
  {$IFDEF MSWINDOWS}
  Result := Result + '.cmd';
  {$ENDIF}
end;

function NXLSToolchainFpcFile(const AFpcDirectory: string): string;
begin
  Result := '';
  if FileExists(NXLSToolchainExecutableInDirectory(
    IncludeTrailingPathDelimiter(AFpcDirectory) + 'bin', 'fpc')) then
    Exit(NXLSToolchainExecutableInDirectory(
      IncludeTrailingPathDelimiter(AFpcDirectory) + 'bin', 'fpc'));

  {$IFDEF MSWINDOWS}
  if FileExists(IncludeTrailingPathDelimiter(AFpcDirectory) + 'bin' +
    DirectorySeparator + 'x86_64-win64' + DirectorySeparator + 'fpc.exe') then
    Exit(IncludeTrailingPathDelimiter(AFpcDirectory) + 'bin' +
      DirectorySeparator + 'x86_64-win64' + DirectorySeparator + 'fpc.exe');
  {$ENDIF}
end;

function NXLSToolchainFpcDirectoryFromCompilerPath(
  const ACompilerPath: string): string;
var
  lBinDir: string;
begin
  Result := '';
  if ACompilerPath = '' then
    Exit;

  lBinDir := ExtractFileDir(ACompilerPath);
  if SameText(ExtractFileName(lBinDir), 'bin') then
    Exit(ExtractFileDir(lBinDir));

  lBinDir := ExtractFileDir(lBinDir);
  if SameText(ExtractFileName(lBinDir), 'bin') then
    Result := ExtractFileDir(lBinDir);
end;

function NXLSToolchainBundledFpcDirectory(
  const ALazarusDirectory: string): string;
var
  lRoot: string;
  lSearch: TSearchRec;
begin
  Result := '';
  if ALazarusDirectory = '' then
    Exit;

  lRoot := IncludeTrailingPathDelimiter(ALazarusDirectory) + 'fpc';
  if not DirectoryExists(lRoot) then
    Exit;

  if FindFirst(IncludeTrailingPathDelimiter(lRoot) + '*', faDirectory,
    lSearch) = 0 then
  try
    repeat
      if (lSearch.Name <> '.') and (lSearch.Name <> '..') and
        ((lSearch.Attr and faDirectory) <> 0) and
        DirectoryExists(IncludeTrailingPathDelimiter(lRoot) + lSearch.Name) then
      begin
        Result := IncludeTrailingPathDelimiter(lRoot) + lSearch.Name;
        Exit;
      end;
    until FindNext(lSearch) <> 0;
  finally
    FindClose(lSearch);
  end;

  if Result = '' then
    Result := lRoot;
end;

function NXLSToolchainAndroidAdbFile(
  const AAndroidSdkDirectory: string): string;
begin
  Result := NXLSToolchainExecutableInDirectory(
    IncludeTrailingPathDelimiter(AAndroidSdkDirectory) + 'platform-tools',
    'adb');
end;

function NXLSToolchainAndroidNdkBuildFile(
  const AAndroidNdkDirectory: string): string;
begin
  Result := NXLSToolchainBatchInDirectory(AAndroidNdkDirectory, 'ndk-build');
end;

function NXLSToolchainJavaFile(const AJavaHome: string): string;
begin
  Result := NXLSToolchainExecutableInDirectory(
    IncludeTrailingPathDelimiter(AJavaHome) + 'bin', 'java');
end;

procedure NXLSAddDownloadSuggestion(AField: TNXLSToolchainField;
  const ALabel, AUrl, AReason: string);
begin
  AField.AddSuggestion('url', ALabel, AUrl, AReason);
end;

procedure NXLSSuggestCommonLazarusInstallPaths(AField: TNXLSToolchainField);

  procedure AddIfLazarusRoot(const ADirectory: string);
  var
    lDirectory: string;
  begin
    lDirectory := NXLSCleanDirectory(ADirectory);
    if FileExists(NXLSToolchainLazbuildFile(lDirectory)) then
      AField.AddSuggestion('path', 'Use ' + lDirectory, lDirectory,
        'lazbuild was found in this Lazarus install directory.');
  end;

begin
  AddIfLazarusRoot('C:\lazarus');
  AddIfLazarusRoot('C:\Program Files\Lazarus');
  AddIfLazarusRoot('C:\Program Files (x86)\Lazarus');
end;

procedure NXLSSuggestCommonFpcInstallPaths(AField: TNXLSToolchainField);

  procedure AddIfFpcRoot(const ADirectory: string);
  var
    lDirectory: string;
  begin
    lDirectory := NXLSCleanDirectory(ADirectory);
    if NXLSToolchainFpcFile(lDirectory) <> '' then
      AField.AddSuggestion('path', 'Use ' + lDirectory, lDirectory,
        'fpc was found in this Free Pascal install directory.');
  end;

  procedure AddLazarusBundledFpc;
  var
    lDirectory: string;
  begin
    lDirectory := NXLSToolchainBundledFpcDirectory('C:\lazarus');
    if lDirectory <> '' then
      AddIfFpcRoot(lDirectory);
  end;

begin
  AddIfFpcRoot(GetEnvironmentVariable('FPCDIR'));
  AddIfFpcRoot('C:\FPC');
  AddIfFpcRoot('C:\FPC\3.2.2');
  AddIfFpcRoot('C:\PP');
  AddLazarusBundledFpc;
end;

procedure NXLSSuggestCommonFpcCompilerPaths(AField: TNXLSToolchainField);

  procedure AddIfCompiler(const AFileName: string);
  var
    lFileName: string;
  begin
    lFileName := NXLSCleanFileName(AFileName);
    if FileExists(lFileName) then
      AField.AddSuggestion('path', 'Use ' + lFileName, lFileName,
        'fpc was found at this compiler path.');
  end;

  procedure AddFromFpcDirectory(const ADirectory: string);
  var
    lCompiler: string;
  begin
    lCompiler := NXLSToolchainFpcFile(NXLSCleanDirectory(ADirectory));
    if lCompiler <> '' then
      AddIfCompiler(lCompiler);
  end;

begin
  AddIfCompiler(GetEnvironmentVariable('PP'));
  AddFromFpcDirectory(GetEnvironmentVariable('FPCDIR'));
  AddFromFpcDirectory('C:\FPC');
  AddFromFpcDirectory('C:\FPC\3.2.2');
  AddFromFpcDirectory('C:\PP');
  AddFromFpcDirectory(NXLSToolchainBundledFpcDirectory('C:\lazarus'));
end;

procedure NXLSSuggestCommonAndroidSdkPaths(AField: TNXLSToolchainField);

  procedure AddIfAndroidSdk(const ADirectory: string);
  var
    lDirectory: string;
  begin
    lDirectory := NXLSCleanDirectory(ADirectory);
    if FileExists(NXLSToolchainAndroidAdbFile(lDirectory)) then
      AField.AddSuggestion('path', 'Use ' + lDirectory, lDirectory,
        'adb was found under platform-tools in this Android SDK directory.');
  end;

begin
  AddIfAndroidSdk(GetEnvironmentVariable('ANDROID_HOME'));
  AddIfAndroidSdk(GetEnvironmentVariable('ANDROID_SDK_ROOT'));
  AddIfAndroidSdk(GetEnvironmentVariable('LOCALAPPDATA') + '\Android\Sdk');
  AddIfAndroidSdk('C:\Android\Sdk');
  AddIfAndroidSdk('C:\Android\sdk');
end;

procedure NXLSSuggestCommonAndroidNdkPaths(AField: TNXLSToolchainField);

  procedure AddIfAndroidNdk(const ADirectory: string);
  var
    lDirectory: string;
  begin
    lDirectory := NXLSCleanDirectory(ADirectory);
    if FileExists(NXLSToolchainAndroidNdkBuildFile(lDirectory)) and
      FileExists(NXLSToolchainFileInDirectory(lDirectory,
      'source.properties')) then
      AField.AddSuggestion('path', 'Use ' + lDirectory, lDirectory,
        'ndk-build and source.properties were found in this Android NDK directory.');
  end;

  procedure AddNdkChildren(const ASdkDirectory: string);
  var
    lSearch: TSearchRec;
    lRoot: string;
  begin
    lRoot := IncludeTrailingPathDelimiter(NXLSCleanDirectory(ASdkDirectory)) +
      'ndk';
    if not DirectoryExists(lRoot) then
      Exit;

    if FindFirst(IncludeTrailingPathDelimiter(lRoot) + '*', faDirectory,
      lSearch) = 0 then
    try
      repeat
        if (lSearch.Name <> '.') and (lSearch.Name <> '..') and
          ((lSearch.Attr and faDirectory) <> 0) then
          AddIfAndroidNdk(IncludeTrailingPathDelimiter(lRoot) + lSearch.Name);
      until FindNext(lSearch) <> 0;
    finally
      FindClose(lSearch);
    end;
  end;

begin
  AddIfAndroidNdk(GetEnvironmentVariable('ANDROID_NDK_HOME'));
  AddIfAndroidNdk(GetEnvironmentVariable('ANDROID_NDK_ROOT'));
  AddIfAndroidNdk(GetEnvironmentVariable('ANDROID_HOME') + '\ndk-bundle');
  AddIfAndroidNdk(GetEnvironmentVariable('ANDROID_SDK_ROOT') + '\ndk-bundle');
  AddNdkChildren(GetEnvironmentVariable('ANDROID_HOME'));
  AddNdkChildren(GetEnvironmentVariable('ANDROID_SDK_ROOT'));
  AddNdkChildren(GetEnvironmentVariable('LOCALAPPDATA') + '\Android\Sdk');
end;

procedure NXLSSuggestCommonJavaHomePaths(AField: TNXLSToolchainField);

  procedure AddIfJavaHome(const ADirectory: string);
  var
    lDirectory: string;
  begin
    lDirectory := NXLSCleanDirectory(ADirectory);
    if FileExists(NXLSToolchainJavaFile(lDirectory)) then
      AField.AddSuggestion('path', 'Use ' + lDirectory, lDirectory,
        'java was found under bin in this Java Home directory.');
  end;

  procedure AddJavaChildren(const ARoot: string);
  var
    lSearch: TSearchRec;
  begin
    if (ARoot = '') or (not DirectoryExists(ARoot)) then
      Exit;

    if FindFirst(IncludeTrailingPathDelimiter(ARoot) + '*', faDirectory,
      lSearch) = 0 then
    try
      repeat
        if (lSearch.Name <> '.') and (lSearch.Name <> '..') and
          ((lSearch.Attr and faDirectory) <> 0) then
          AddIfJavaHome(IncludeTrailingPathDelimiter(ARoot) + lSearch.Name);
      until FindNext(lSearch) <> 0;
    finally
      FindClose(lSearch);
    end;
  end;

begin
  AddIfJavaHome(GetEnvironmentVariable('JAVA_HOME'));
  AddJavaChildren('C:\Program Files\Java');
  AddJavaChildren('C:\Program Files\Eclipse Adoptium');
  AddJavaChildren('C:\Program Files\Microsoft');
  AddJavaChildren('C:\Program Files (x86)\Java');
end;

end.
