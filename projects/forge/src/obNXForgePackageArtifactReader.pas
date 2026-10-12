(* Copyright (c) 2026 Kevin Collins.
   SPDX-License-Identifier: MPL-2.0-no-copyleft-exception *)
unit obNXForgePackageArtifactReader;

{$mode delphi}{$H+}

interface

uses Classes, tpNXForgePackage;

type
  // Reads NXP004 and Win64 ABI-4 identities without mapping or executing a DLL.
  TNXForgePackageArtifactReader = class
  private
    FData: TMemoryStream;
    FFileName: string;
    FSectionTable: QWord;
    FSectionCount: Word;
    FImageBase: QWord;
    procedure Invalid(const AMessage: string);
    procedure RequireRange(AOffset, ASize: QWord);
    function Number(AOffset: QWord; ASize: Byte): QWord;
    function Text(AOffset, ASize: QWord): string;
    function ShortText(var AOffset: QWord; ALimit: QWord): string;
    function ImageOffset(ARVA, ASize: QWord): QWord;
    function ImageText(AAddress: QWord): string;
    function ExportName(ARVA: QWord): string;
    procedure CheckIdentity(const AName, ASDK, ABuild,
      AExpectedName, AExpectedSDK, AExpectedBuild: string);
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;
    function ReadMetadata: TNXForgePackageMetadata;
    procedure CheckMetadata(const AName, ASDK, ABuild: string);
    procedure CheckImage(const AName, ASDK, ABuild: string);
  end;

implementation

uses SysUtils;

constructor TNXForgePackageArtifactReader.Create(const AFileName: string);
begin
  inherited Create;
  FFileName := AFileName;
  FData := TMemoryStream.Create;
  FData.LoadFromFile(AFileName);
end;

destructor TNXForgePackageArtifactReader.Destroy;
begin
  FData.Free;
  inherited Destroy;
end;

procedure TNXForgePackageArtifactReader.Invalid(const AMessage: string);
begin
  raise Exception.Create(AMessage + ': ' + FFileName);
end;

procedure TNXForgePackageArtifactReader.RequireRange(AOffset, ASize: QWord);
begin
  if (AOffset > QWord(FData.Size)) or (ASize > QWord(FData.Size) - AOffset) then
    Invalid('Truncated or invalid package artifact');
end;

function TNXForgePackageArtifactReader.Number(AOffset: QWord; ASize: Byte): QWord;
var
  lBytes: array[0..7] of Byte;
  lIndex: Integer;
begin
  RequireRange(AOffset, ASize);
  FData.Position := AOffset;
  FData.ReadBuffer(lBytes, ASize);
  Result := 0;
  for lIndex := 0 to ASize - 1 do
    Result := Result or (QWord(lBytes[lIndex]) shl (lIndex * 8));
end;

function TNXForgePackageArtifactReader.Text(AOffset, ASize: QWord): string;
begin
  RequireRange(AOffset, ASize);
  SetLength(Result, ASize);
  FData.Position := AOffset;
  if ASize > 0 then FData.ReadBuffer(Result[1], ASize);
end;

function TNXForgePackageArtifactReader.ShortText(var AOffset: QWord; ALimit: QWord): string;
var
  lSize: Byte;
begin
  if AOffset >= ALimit then Invalid('Truncated package string');
  lSize := Number(AOffset, 1);
  Inc(AOffset);
  if lSize > ALimit - AOffset then Invalid('Truncated package string');
  Result := Text(AOffset, lSize);
  Inc(AOffset, lSize);
end;

procedure TNXForgePackageArtifactReader.CheckIdentity(const AName, ASDK, ABuild,
  AExpectedName, AExpectedSDK, AExpectedBuild: string);
begin
  if not SameText(AName, AExpectedName) or (ASDK <> AExpectedSDK) or
    (ABuild <> AExpectedBuild) then
    Invalid('Package metadata/image identity does not match this SDK build');
end;

procedure TNXForgePackageArtifactReader.CheckMetadata(const AName, ASDK, ABuild: string);
var
  lMetadata: TNXForgePackageMetadata;
begin
  lMetadata := ReadMetadata;
  CheckIdentity(lMetadata.Name, lMetadata.SDK, lMetadata.Build, AName, ASDK, ABuild);
end;

function TNXForgePackageArtifactReader.ReadMetadata: TNXForgePackageMetadata;
var
  lOffset, lLimit, lSize: QWord;
  lEntry: Byte;
  lDependency: string;
  lIndex: Integer;
  lHasName, lHasIdentity, lHasEnd: Boolean;
  lDependencies: TStringList;
begin
  Result := Default(TNXForgePackageMetadata);
  RequireRange(0, 32);
  if Text(0, 6) <> 'NXP004' then Invalid('Unsupported package metadata; expected NexusFPC NXP004');
  lOffset := 32;
  lHasName := False;
  lHasIdentity := False;
  lHasEnd := False;
  lDependencies := TStringList.Create;
  try
    while lOffset < QWord(FData.Size) do
    begin
      lSize := Number(lOffset, 4);
      if Number(lOffset + 4, 1) <> 1 then Invalid('Invalid package metadata entry');
      lEntry := Number(lOffset + 5, 1);
      Inc(lOffset, 6);
      RequireRange(lOffset, lSize);
      lLimit := lOffset + lSize;
      case lEntry of
        93:
          begin
            if lHasName then Invalid('Duplicate package name');
            Result.Name := ShortText(lOffset, lLimit);
            lHasName := True;
          end;
        92:
          begin
            if lHasIdentity then Invalid('Duplicate package identity');
            ShortText(lOffset, lLimit); // Container filename.
            Result.SDK := ShortText(lOffset, lLimit);
            Result.Build := ShortText(lOffset, lLimit);
            lHasIdentity := True;
          end;
        245:
          while lOffset < lLimit do
          begin
            lDependency := ShortText(lOffset, lLimit);
            if lDependencies.IndexOf(lDependency) >= 0 then Invalid('Duplicate package dependency');
            lDependencies.Add(lDependency);
            lIndex := Length(Result.Requires);
            SetLength(Result.Requires, lIndex + 1);
            Result.Requires[lIndex].Name := lDependency;
            Result.Requires[lIndex].Build := ShortText(lOffset, lLimit);
          end;
        255:
          begin
            lHasEnd := True;
            Break; // Embedded PPUs follow the metadata terminator.
          end;
      end;
      lOffset := lLimit;
    end;
    if not lHasName or not lHasIdentity or not lHasEnd then Invalid('Incomplete package metadata');
    if (Result.Name = '') or (Result.SDK = '') or (Result.Build = '') then
      Invalid('Incomplete package identity');
  finally
    lDependencies.Free;
  end;
end;

function TNXForgePackageArtifactReader.ImageOffset(ARVA, ASize: QWord): QWord;
var
  lIndex: Integer;
  lSection, lAddress, lSize, lDelta: QWord;
begin
  for lIndex := 0 to FSectionCount - 1 do
  begin
    lSection := FSectionTable + QWord(lIndex) * 40;
    lAddress := Number(lSection + 12, 4);
    lSize := Number(lSection + 16, 4);
    if ARVA < lAddress then Continue;
    lDelta := ARVA - lAddress;
    if (lDelta >= lSize) or (ASize > lSize - lDelta) then Continue;
    Result := Number(lSection + 20, 4) + lDelta;
    RequireRange(Result, ASize);
    Exit;
  end;
  Invalid('Invalid package image address');
  Result := 0;
end;

function TNXForgePackageArtifactReader.ImageText(AAddress: QWord): string;
var
  lOffset, lSize: QWord;
begin
  if AAddress < FImageBase then Invalid('Invalid package image string address');
  lOffset := ImageOffset(AAddress - FImageBase, 1);
  lSize := Number(lOffset, 1);
  lOffset := ImageOffset(AAddress - FImageBase, lSize + 1);
  Result := Text(lOffset + 1, lSize);
end;

function TNXForgePackageArtifactReader.ExportName(ARVA: QWord): string;
var
  lByte: Byte;
begin
  Result := '';
  repeat
    lByte := Number(ImageOffset(ARVA, 1), 1);
    if lByte = 0 then Exit;
    Result := Result + Chr(lByte);
    Inc(ARVA);
    // Only this export is relevant; avoid traversing unrelated long names.
  until Length(Result) > Length('FPC_PACKAGE_INFO');
end;

procedure TNXForgePackageArtifactReader.CheckImage(const AName, ASDK, ABuild: string);
var
  lPE, lOptional, lExports, lExportRVA, lExportSize: QWord;
  lFunctions, lNames, lOrdinals, lCount, lFunctionCount: QWord;
  lIndex, lOrdinal, lRVA, lDescriptor, lAddress: QWord;
begin
  if Number(0, 2) <> $5A4D then Invalid('Not a Win64 package image');
  lPE := Number(60, 4);
  if (Number(lPE, 4) <> $4550) or (Number(lPE + 4, 2) <> $8664) then
    Invalid('Not a Win64 package image');
  lOptional := lPE + 24;
  if (Number(lPE + 20, 2) < 120) or (Number(lOptional, 2) <> $20B) or
    (Number(lOptional + 108, 4) < 1) then Invalid('Unsupported package PE format');
  FImageBase := Number(lOptional + 24, 8);
  FSectionTable := lOptional + Number(lPE + 20, 2);
  FSectionCount := Number(lPE + 6, 2);
  RequireRange(FSectionTable, QWord(FSectionCount) * 40);
  lExportRVA := Number(lOptional + 112, 4);
  lExportSize := Number(lOptional + 116, 4);
  lExports := ImageOffset(lExportRVA, 40);
  lFunctionCount := Number(lExports + 20, 4);
  lCount := Number(lExports + 24, 4);
  lFunctions := ImageOffset(Number(lExports + 28, 4), lFunctionCount * 4);
  lNames := ImageOffset(Number(lExports + 32, 4), lCount * 4);
  lOrdinals := ImageOffset(Number(lExports + 36, 4), lCount * 2);
  lIndex := 0;
  while lIndex < lCount do
  begin
    if ExportName(Number(lNames + 4 * lIndex, 4)) = 'FPC_PACKAGE_INFO' then
    begin
      lOrdinal := Number(lOrdinals + 2 * lIndex, 2);
      if lOrdinal >= lFunctionCount then Invalid('Invalid package descriptor export ordinal');
      lRVA := Number(lFunctions + 4 * lOrdinal, 4);
      if (lRVA >= lExportRVA) and (lRVA < lExportRVA + lExportSize) then
        Invalid('Forwarded package descriptor export');
      lAddress := Number(ImageOffset(lRVA, 8), 8);
      if lAddress < FImageBase then Invalid('Invalid package descriptor address');
      lDescriptor := ImageOffset(lAddress - FImageBase, 168);
      if (Number(lDescriptor, 8) <> $4E58504B) or
        (Number(lDescriptor + 8, 8) <> 4) or
        (Number(lDescriptor + 16, 8) <> 168) then
        Invalid('Unsupported package image descriptor');
      CheckIdentity(ImageText(Number(lDescriptor + 6 * 8, 8)),
        ImageText(Number(lDescriptor + 18 * 8, 8)),
        ImageText(Number(lDescriptor + 19 * 8, 8)), AName, ASDK, ABuild);
      Exit;
    end;
    Inc(lIndex);
  end;
  Invalid('Missing package descriptor export');
end;

end.
