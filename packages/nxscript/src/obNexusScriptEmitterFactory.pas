unit obNexusScriptEmitterFactory;

{$mode delphi}{$H+}

interface

uses
  obNexusScriptEmitter;

type
  TNexusScriptEmitterFactory = class
  public
    class function CreateEmitter(
      const AFormat: string): TNexusScriptEmitter; static;
  end;

implementation

uses
  obNXClassFactory,
  obNexusScriptJSON,
  obNexusScriptSQLite;

class function TNexusScriptEmitterFactory.CreateEmitter(
  const AFormat: string): TNexusScriptEmitter;
begin
  Result := TNexusScriptEmitter(TNXClassFactory.CreateObject(AFormat));
end;

end.
