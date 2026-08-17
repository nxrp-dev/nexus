#ifndef NexusVersion
  #define NexusVersion "0.1.0"
#endif

#ifndef SourceRoot
  #define SourceRoot "..\..\..\dist\nexus-win64"
#endif

#ifndef OutputRoot
  #define OutputRoot "..\..\..\dist\installers"
#endif

[Setup]
AppId={{7E70871F-8A23-447E-8C08-6A6B66DF4EB4}
AppName=Nexus
AppPublisher=NexusRP
AppVersion={#NexusVersion}
DefaultDirName={autopf}\Nexus
DisableProgramGroupPage=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputRoot}
OutputBaseFilename=NexusSetup-x64-{#NexusVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Files]
Source: "{#SourceRoot}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Registry]
Root: HKLM; Subkey: "Software\NexusRP\Nexus"; ValueType: string; ValueName: "NexusRoot"; ValueData: "{app}"; Flags: uninsdeletevalue uninsdeletekeyifempty

[Code]
function FpcConfigText(const Root: String): String;
var
  FpcRoot: String;
begin
  FpcRoot := Root + '\toolchain\lazarus\fpc\$FPCVERSION';
  Result :=
    '-Fu' + FpcRoot + '\units\$fpctarget' + #13#10 +
    '-Fu' + FpcRoot + '\units\$fpctarget\*' + #13#10 +
    '-Fu' + FpcRoot + '\units\$fpctarget\rtl' + #13#10 +
    '-FD' + FpcRoot + '\bin\$FPCTARGET' + #13#10;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  Root: String;
begin
  if CurStep <> ssPostInstall then
    Exit;

  Root := ExpandConstant('{app}');
  SaveStringToFile(
    Root + '\toolchain\lazarus\lazarus.cfg',
    '--primary-config-path=' + Root + '\toolchain\lazarus' + #13#10,
    False);
  SaveStringToFile(
    Root + '\toolchain\lazarus\fpc\3.2.2\bin\x86_64-win64\fpc.cfg',
    FpcConfigText(Root),
    False);
end;
