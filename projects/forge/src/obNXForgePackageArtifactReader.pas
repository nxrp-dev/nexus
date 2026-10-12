(* Copyright (c) 2026 Kevin Collins.
   SPDX-License-Identifier: MPL-2.0-no-copyleft-exception *)
unit obNXForgePackageArtifactReader;

{$mode delphi}{$H+}

interface

uses Classes, tpNXForgePackage;

type
  // Reads NXP004 and PE/ELF ABI-4 identities without executing package code.
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
    function ELFSection(AIndex: QWord): QWord;
    function ELFOffset(AAddress, ASize: QWord): QWord;
    function ELFString(AOffset, ALimit: QWord): string;
    function ELFSymbolName(ATable, ASymbol: QWord): string;
    function ELFRelocation(AAddress: QWord; out AKind, ASymbol, ATable, AAddend: QWord): Boolean;
    function ELFPointer(AAddress: QWord): QWord;
    function ELFShortText(AAddress: QWord): string;
    procedure CheckIdentity(const AName, ASDK, ABuild,
      AExpectedName, AExpectedSDK, AExpectedBuild: string);
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;
    function ReadMetadata: TNXForgePackageMetadata;
    function ReadELFImage: TNXForgePackageMetadata;
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

function TNXForgePackageArtifactReader.ELFSection(AIndex: QWord): QWord;
begin
  if AIndex >= FSectionCount then Invalid('Invalid ELF section index');
  Result := FSectionTable + AIndex * 64;
end;

function TNXForgePackageArtifactReader.ELFOffset(AAddress, ASize: QWord): QWord;
var
  lIndex: Integer;
  lSection, lAddress, lSize, lDelta: QWord;
begin
  for lIndex := 0 to FSectionCount - 1 do
  begin
    lSection := ELFSection(lIndex);
    if (Number(lSection + 4, 4) = 8) or (Number(lSection + 8, 8) and 2 = 0) then Continue;
    lAddress := Number(lSection + 16, 8);
    lSize := Number(lSection + 32, 8);
    if AAddress < lAddress then Continue;
    lDelta := AAddress - lAddress;
    if (lDelta >= lSize) or (ASize > lSize - lDelta) then Continue;
    Result := Number(lSection + 24, 8) + lDelta;
    RequireRange(Result, ASize);
    Exit;
  end;
  Invalid('ELF address has no file data');
  Result := 0;
end;

function TNXForgePackageArtifactReader.ELFString(AOffset, ALimit: QWord): string;
var
  lEnd: QWord;
begin
  if AOffset >= ALimit then Invalid('Invalid ELF string');
  lEnd := AOffset;
  while (lEnd < ALimit) and (Number(lEnd, 1) <> 0) do Inc(lEnd);
  if lEnd = ALimit then Invalid('Unterminated ELF string');
  Result := Text(AOffset, lEnd - AOffset);
end;

function TNXForgePackageArtifactReader.ELFSymbolName(ATable, ASymbol: QWord): string;
var
  lStrings, lStart, lSize, lName: QWord;
begin
  lStrings := ELFSection(Number(ATable + 40, 4));
  lStart := Number(lStrings + 24, 8);
  lSize := Number(lStrings + 32, 8);
  lName := Number(ASymbol, 4);
  if lName >= lSize then Invalid('Invalid ELF symbol name');
  Result := ELFString(lStart + lName, lStart + lSize);
end;

function TNXForgePackageArtifactReader.ELFRelocation(AAddress: QWord;
  out AKind, ASymbol, ATable, AAddend: QWord): Boolean;
var
  lIndex: Integer;
  lSection, lOffset, lLimit, lInfo, lSymbolIndex: QWord;
begin
  Result := False;
  for lIndex := 0 to FSectionCount - 1 do
  begin
    lSection := ELFSection(lIndex);
    if Number(lSection + 4, 4) <> 4 then Continue;
    lOffset := Number(lSection + 24, 8);
    lLimit := lOffset + Number(lSection + 32, 8);
    while lOffset < lLimit do
    begin
      if Number(lOffset, 8) = AAddress then
      begin
        if Result then Invalid('Duplicate ELF descriptor relocation');
        lInfo := Number(lOffset + 8, 8);
        AKind := lInfo and $FFFFFFFF;
        ATable := ELFSection(Number(lSection + 40, 4));
        lSymbolIndex := lInfo shr 32;
        if lSymbolIndex >= Number(ATable + 32, 8) div 24 then Invalid('Invalid ELF relocation symbol');
        ASymbol := Number(ATable + 24, 8) + lSymbolIndex * 24;
        AAddend := Number(lOffset + 16, 8);
        Result := True;
      end;
      Inc(lOffset, 24);
    end;
  end;
end;

function TNXForgePackageArtifactReader.ELFPointer(AAddress: QWord): QWord;
var
  lKind, lSymbol, lTable, lAddend, lValue, lMagnitude: QWord;
begin
  if not ELFRelocation(AAddress, lKind, lSymbol, lTable, lAddend) then
    Exit(Number(ELFOffset(AAddress, 8), 8));
  if lKind = 8 then Exit(lAddend); // R_X86_64_RELATIVE, zero load bias.
  if (lKind <> 1) or (Number(lSymbol + 6, 2) = 0) then
    Invalid('ELF descriptor points outside its image');
  lValue := Number(lSymbol + 8, 8);
  if lAddend and (QWord(1) shl 63) <> 0 then
  begin
    lMagnitude := not lAddend + 1;
    if lValue < lMagnitude then Invalid('Invalid ELF relocation addend');
    Result := lValue - lMagnitude;
  end
  else
  begin
    if lAddend > High(QWord) - lValue then Invalid('Invalid ELF relocation addend');
    Result := lValue + lAddend;
  end;
end;

function TNXForgePackageArtifactReader.ELFShortText(AAddress: QWord): string;
var
  lSize, lOffset: QWord;
begin
  lSize := Number(ELFOffset(AAddress, 1), 1);
  lOffset := ELFOffset(AAddress, lSize + 1);
  Result := Text(lOffset + 1, lSize);
end;

function TNXForgePackageArtifactReader.ReadELFImage: TNXForgePackageMetadata;
var
  lIndex, lDependencyIndex: Integer;
  lSection, lType, lOffset, lSize, lEnd, lLinked, lInfo, lRoot: QWord;
  lDescriptor, lDependencies, lIdentities, lCount, lSlot: QWord;
  lKind, lSymbol, lTable, lAddend: QWord;
  lName: string;
  lNames: TStringList;
begin
  Result := Default(TNXForgePackageMetadata);
  RequireRange(0, 64);
  if (Text(0, 7) <> #127'ELF'#2#1#1) or (Number(18, 2) <> 62) or
    not (Number(16, 2) in [2, 3]) then Invalid('Not an x86-64 ELF image');
  FSectionTable := Number(40, 8);
  FSectionCount := Number(60, 2);
  if (Number(58, 2) <> 64) or (FSectionCount = 0) or (FSectionTable < 64) then
    Invalid('Unsupported ELF section layout');
  RequireRange(FSectionTable, QWord(FSectionCount) * 64);
  for lIndex := 0 to FSectionCount - 1 do
  begin
    lSection := ELFSection(lIndex);
    lType := Number(lSection + 4, 4);
    if lType <> 8 then RequireRange(Number(lSection + 24, 8), Number(lSection + 32, 8));
    if (lType = 2) or (lType = 11) or (lType = 4) then
    begin
      if (Number(lSection + 56, 8) <> 24) or (Number(lSection + 32, 8) mod 24 <> 0) then
        Invalid('Invalid ELF table size');
      lLinked := ELFSection(Number(lSection + 40, 4));
      if (lType <> 4) and (Number(lLinked + 4, 4) <> 3) then Invalid('Invalid ELF string table');
      if (lType = 4) and (Number(lLinked + 4, 4) <> 2) and
        (Number(lLinked + 4, 4) <> 11) then Invalid('Invalid ELF relocation table');
      if lType = 4 then
      begin
        lOffset := Number(lSection + 24, 8);
        lEnd := lOffset + Number(lSection + 32, 8);
        while lOffset < lEnd do
        begin
          if Number(lOffset + 8, 8) shr 32 >= Number(lLinked + 32, 8) div 24 then
            Invalid('Invalid ELF relocation symbol');
          Inc(lOffset, 24);
        end;
      end;
    end;
  end;
  lInfo := 0;
  lRoot := 0;
  for lIndex := 0 to FSectionCount - 1 do
  begin
    lSection := ELFSection(lIndex);
    lType := Number(lSection + 4, 4);
    if (lType <> 2) and (lType <> 11) then Continue;
    lOffset := Number(lSection + 24, 8);
    lSize := Number(lSection + 32, 8);
    lEnd := lOffset + lSize;
    while lOffset < lEnd do
    begin
      lName := ELFSymbolName(lSection, lOffset);
      if Number(lOffset + 6, 2) <> 0 then
      begin
        if lName = 'FPC_PACKAGE_INFO' then lInfo := Number(lOffset + 8, 8);
        if lName = 'FPC_PACKAGE_ROOT' then lRoot := Number(lOffset + 8, 8);
      end;
      Inc(lOffset, 24);
    end;
  end;
  if lInfo <> 0 then lDescriptor := ELFPointer(lInfo)
  else if lRoot <> 0 then lDescriptor := lRoot
  else begin Invalid('Missing ELF package descriptor'); Exit; end;
  lOffset := ELFOffset(lDescriptor, 168);
  if (Number(lOffset, 8) <> $4E58504B) or (Number(lOffset + 8, 8) <> 4) or
    (Number(lOffset + 16, 8) <> 168) then Invalid('Unsupported ELF package descriptor');
  Result.Name := ELFShortText(ELFPointer(lDescriptor + 6 * 8));
  Result.SDK := ELFShortText(ELFPointer(lDescriptor + 18 * 8));
  Result.Build := ELFShortText(ELFPointer(lDescriptor + 19 * 8));
  lCount := Number(lOffset + 9 * 8, 8);
  if lCount > 65535 then Invalid('Invalid ELF dependency count');
  lDependencies := ELFPointer(lDescriptor + 10 * 8);
  lIdentities := ELFPointer(lDescriptor + 20 * 8);
  SetLength(Result.Requires, lCount);
  lNames := TStringList.Create;
  try
    for lDependencyIndex := 0 to Integer(lCount) - 1 do
    begin
      lSlot := ELFPointer(lDependencies + QWord(lDependencyIndex) * 8);
      if not ELFRelocation(lSlot, lKind, lSymbol, lTable, lAddend) then
        Invalid('Missing ELF dependency relocation');
      if (lKind <> 1) or (Number(lSymbol + 6, 2) <> 0) then Invalid('Invalid ELF dependency relocation');
      lName := ELFSymbolName(lTable, lSymbol);
      if Copy(lName, 1, 12) <> 'FPC_PACKAGE_' then Invalid('Invalid ELF package dependency');
      lName := Copy(lName, 13, MaxInt);
      if (lName = '') or (lNames.IndexOf(lName) >= 0) then Invalid('Invalid or duplicate ELF dependency');
      lNames.Add(lName);
      Result.Requires[lDependencyIndex].Name := lName;
      Result.Requires[lDependencyIndex].Build := ELFShortText(
        ELFPointer(lIdentities + QWord(lDependencyIndex) * 8));
    end;
  finally
    lNames.Free;
  end;
end;

end.
