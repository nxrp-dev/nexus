program PrunedLazarusSmoke;

{$mode objfpc}{$H+}

uses
  Interfaces,
  Forms,
  StdCtrls;

var
  lForm: TForm;
  lButton: TButton;

begin
  Application.Initialize;

  lForm := TForm.Create(nil);
  try
    lForm.Caption := 'Pruned Lazarus Smoke';

    lButton := TButton.Create(lForm);
    lButton.Parent := lForm;
    lButton.Caption := 'Smoke';

    WriteLn('pruned lazarus lcl smoke');
  finally
    lForm.Free;
  end;
end.
