unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, obNxTypes,
  obNxBin, obNxRpcCore, obNxSanity;

type

  { TForm1 }

  TForm1 = class(TForm)
    procedure Button1Click(Sender: TObject);
  private

  public

  end;

type
  TUser = class(TNXRPObject)
  private
    FId: Int64;
    FName: UnicodeString;
  published
    property Id: Int64 read FId write FId;
    property Name: UnicodeString read FName write FName;
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.Button1Click(Sender: TObject);
begin
  RunNxrpSanityChecks;
end;

initialization
  TNXRPRegistry.RegisterType('TUser', TUser);

end.
