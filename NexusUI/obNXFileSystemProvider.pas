unit obNXFileSystemProvider;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils;

type
  TNXFileSystemItemKind = (
    fsikFile,
    fsikDirectory,
    fsikDrive,
    fsikSpecialFolder
  );

  TNXFileSystemItem = record
    Name: string;
    FullPath: string;
    Kind: TNXFileSystemItemKind;
    Size: Int64;
    ModifiedAt: TDateTime;
    IsHidden: Boolean;
    IsReadOnly: Boolean;
  end;

  TNXFileSystemItemArray = array of TNXFileSystemItem;

  TNXFileSystemProvider = class
  protected
    function BuildItem(const AName, AFullPath: string;
      AKind: TNXFileSystemItemKind; const AInfo: TSearchRec): TNXFileSystemItem; virtual;
    function NormalizePath(const APath: string): string; virtual;
  public
    function DirectoryExists(const APath: string): Boolean; virtual;
    function FileExists(const APath: string): Boolean; virtual;
    function GetParentPath(const APath: string): string; virtual;
    function GetRoots: TNXFileSystemItemArray; virtual;
    function GetSpecialFolders: TNXFileSystemItemArray; virtual;
    function ListDirectory(const APath: string): TNXFileSystemItemArray; virtual;
  end;

implementation

procedure NXAddFileSystemItem(var AItems: TNXFileSystemItemArray;
  const AItem: TNXFileSystemItem);
var
  lIndex: Integer;
begin
  lIndex := Length(AItems);
  SetLength(AItems, lIndex + 1);
  AItems[lIndex] := AItem;
end;

function NXMakeFileSystemItem(const AName, AFullPath: string;
  AKind: TNXFileSystemItemKind): TNXFileSystemItem;
begin
  Result.Name := AName;
  Result.FullPath := AFullPath;
  Result.Kind := AKind;
  Result.Size := 0;
  Result.ModifiedAt := 0;
  Result.IsHidden := False;
  Result.IsReadOnly := False;
end;

function NXCompareFileSystemItems(const ALeft, ARight: TNXFileSystemItem): Integer;
begin
  if (ALeft.Kind <> fsikFile) and (ARight.Kind = fsikFile) then
    Exit(-1);
  if (ALeft.Kind = fsikFile) and (ARight.Kind <> fsikFile) then
    Exit(1);

  Result := CompareText(ALeft.Name, ARight.Name);
end;

procedure NXSortFileSystemItems(var AItems: TNXFileSystemItemArray);
var
  lLeft: Integer;
  lRight: Integer;
  lTemp: TNXFileSystemItem;
begin
  for lLeft := 0 to High(AItems) - 1 do
    for lRight := lLeft + 1 to High(AItems) do
      if NXCompareFileSystemItems(AItems[lLeft], AItems[lRight]) > 0 then
      begin
        lTemp := AItems[lLeft];
        AItems[lLeft] := AItems[lRight];
        AItems[lRight] := lTemp;
      end;
end;

function TNXFileSystemProvider.BuildItem(const AName, AFullPath: string;
  AKind: TNXFileSystemItemKind; const AInfo: TSearchRec): TNXFileSystemItem;
begin
  Result.Name := AName;
  Result.FullPath := NormalizePath(AFullPath);
  Result.Kind := AKind;
  Result.Size := AInfo.Size;
  Result.ModifiedAt := FileDateToDateTime(AInfo.Time);
  Result.IsHidden := (AInfo.Attr and faHidden) <> 0;
  Result.IsReadOnly := (AInfo.Attr and faReadOnly) <> 0;
end;

function TNXFileSystemProvider.NormalizePath(const APath: string): string;
begin
  Result := ExpandFileName(APath);
end;

function TNXFileSystemProvider.DirectoryExists(const APath: string): Boolean;
begin
  Result := SysUtils.DirectoryExists(APath);
end;

function TNXFileSystemProvider.FileExists(const APath: string): Boolean;
begin
  Result := SysUtils.FileExists(APath);
end;

function TNXFileSystemProvider.GetParentPath(const APath: string): string;
var
  lPath: string;
begin
  lPath := ExcludeTrailingPathDelimiter(ExpandFileName(APath));
  Result := ExtractFileDir(lPath);

  if Result = '' then
    Result := lPath;
end;

function TNXFileSystemProvider.GetRoots: TNXFileSystemItemArray;
var
  lDrive: Char;
  lPath: string;
begin
  SetLength(Result, 0);

  {$IFDEF MSWINDOWS}
  for lDrive := 'A' to 'Z' do
  begin
    lPath := lDrive + ':\';
    if SysUtils.DirectoryExists(lPath) then
      NXAddFileSystemItem(Result, NXMakeFileSystemItem(lPath, lPath, fsikDrive));
  end;
  {$ELSE}
  NXAddFileSystemItem(Result, NXMakeFileSystemItem('/', '/', fsikDrive));
  {$ENDIF}
end;

function TNXFileSystemProvider.GetSpecialFolders: TNXFileSystemItemArray;
var
  lPath: string;
begin
  SetLength(Result, 0);

  {$IFDEF MSWINDOWS}
  lPath := GetEnvironmentVariable('USERPROFILE');
  if (lPath <> '') and SysUtils.DirectoryExists(lPath) then
    NXAddFileSystemItem(Result, NXMakeFileSystemItem('Home', lPath, fsikSpecialFolder));

  lPath := GetEnvironmentVariable('USERPROFILE');
  if lPath <> '' then
  begin
    if SysUtils.DirectoryExists(IncludeTrailingPathDelimiter(lPath) + 'Desktop') then
      NXAddFileSystemItem(Result, NXMakeFileSystemItem('Desktop',
        IncludeTrailingPathDelimiter(lPath) + 'Desktop', fsikSpecialFolder));
    if SysUtils.DirectoryExists(IncludeTrailingPathDelimiter(lPath) + 'Documents') then
      NXAddFileSystemItem(Result, NXMakeFileSystemItem('Documents',
        IncludeTrailingPathDelimiter(lPath) + 'Documents', fsikSpecialFolder));
    if SysUtils.DirectoryExists(IncludeTrailingPathDelimiter(lPath) + 'Downloads') then
      NXAddFileSystemItem(Result, NXMakeFileSystemItem('Downloads',
        IncludeTrailingPathDelimiter(lPath) + 'Downloads', fsikSpecialFolder));
  end;
  {$ELSE}
  lPath := GetEnvironmentVariable('HOME');
  if (lPath <> '') and SysUtils.DirectoryExists(lPath) then
  begin
    NXAddFileSystemItem(Result, NXMakeFileSystemItem('Home', lPath, fsikSpecialFolder));
    if SysUtils.DirectoryExists(IncludeTrailingPathDelimiter(lPath) + 'Desktop') then
      NXAddFileSystemItem(Result, NXMakeFileSystemItem('Desktop',
        IncludeTrailingPathDelimiter(lPath) + 'Desktop', fsikSpecialFolder));
    if SysUtils.DirectoryExists(IncludeTrailingPathDelimiter(lPath) + 'Documents') then
      NXAddFileSystemItem(Result, NXMakeFileSystemItem('Documents',
        IncludeTrailingPathDelimiter(lPath) + 'Documents', fsikSpecialFolder));
    if SysUtils.DirectoryExists(IncludeTrailingPathDelimiter(lPath) + 'Downloads') then
      NXAddFileSystemItem(Result, NXMakeFileSystemItem('Downloads',
        IncludeTrailingPathDelimiter(lPath) + 'Downloads', fsikSpecialFolder));
  end;
  {$ENDIF}
end;

function TNXFileSystemProvider.ListDirectory(const APath: string): TNXFileSystemItemArray;
var
  lInfo: TSearchRec;
  lKind: TNXFileSystemItemKind;
  lPath: string;
  lSearchPath: string;
begin
  SetLength(Result, 0);

  if not SysUtils.DirectoryExists(APath) then
    Exit;

  lPath := IncludeTrailingPathDelimiter(APath);
  lSearchPath := lPath + '*';

  if FindFirst(lSearchPath, faAnyFile, lInfo) = 0 then
  begin
    try
      repeat
        if (lInfo.Name = '.') or (lInfo.Name = '..') then
          Continue;

        if (lInfo.Attr and faDirectory) <> 0 then
          lKind := fsikDirectory
        else
          lKind := fsikFile;

        NXAddFileSystemItem(Result, BuildItem(lInfo.Name, lPath + lInfo.Name,
          lKind, lInfo));
      until FindNext(lInfo) <> 0;
    finally
      FindClose(lInfo);
    end;
  end;

  NXSortFileSystemItems(Result);
end;

end.
