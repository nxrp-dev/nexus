unit obNXForgeProcess;

{$mode delphi}{$H+}

interface

uses Classes, SysUtils;

type
  TNXForgeInvocation = class
  public
    OperationName: string;
    TemplatePath: string;
    Command: string;
    WorkingDirectory: string;
    StdOut: string;
    StdErr: string;
    Diagnostic: string;
    Started: Boolean;
    Exited: Boolean;
    ExitStatus: Integer;
    function Succeeded: Boolean;
  end;

procedure ExecuteForgeProcess(AInvocation: TNXForgeInvocation);

implementation

uses Process, Pipes;

function TNXForgeInvocation.Succeeded: Boolean;
begin
  Result := Exited and (ExitStatus = 0) and (Diagnostic = '');
end;

procedure DrainPipe(APipe: TInputPipeStream; AOutput: TMemoryStream);
var
  lBuffer: array[0..16383] of Byte;
  lCount: Integer;
begin
  lCount := APipe.NumBytesAvailable;
  if lCount > SizeOf(lBuffer) then lCount := SizeOf(lBuffer);
  if lCount <= 0 then Exit;
  lCount := APipe.Read(lBuffer, lCount);
  if lCount > 0 then AOutput.WriteBuffer(lBuffer, lCount);
end;

function StreamText(AStream: TMemoryStream): string;
begin
  SetLength(Result, AStream.Size);
  if AStream.Size > 0 then Move(AStream.Memory^, Result[1], AStream.Size);
end;

procedure ExecuteForgeProcess(AInvocation: TNXForgeInvocation);
var
  lProcess: TProcess;
  lOut, lErr: TMemoryStream;
begin
  lProcess := TProcess.Create(nil);
  lOut := TMemoryStream.Create;
  lErr := TMemoryStream.Create;
  try
    try
      lProcess.CommandLine := AInvocation.Command;
      lProcess.CurrentDirectory := AInvocation.WorkingDirectory;
      lProcess.Options := [poUsePipes, poNoConsole];
      lProcess.Execute;
      AInvocation.Started := True;
      lProcess.CloseInput;
      repeat
        DrainPipe(lProcess.Output, lOut);
        DrainPipe(lProcess.Stderr, lErr);
        if not lProcess.Running then
          if (lProcess.Output.NumBytesAvailable = 0) and
            (lProcess.Stderr.NumBytesAvailable = 0) then Break;
        Sleep(1);
      until False;
      AInvocation.ExitStatus := lProcess.ExitStatus;
      AInvocation.Exited := True;
    except
      on E: Exception do
      begin
        AInvocation.Diagnostic := E.Message;
        if AInvocation.Started and lProcess.Running then
        begin
          lProcess.Terminate(1);
          lProcess.WaitOnExit;
        end;
      end;
    end;
    AInvocation.StdOut := StreamText(lOut);
    AInvocation.StdErr := StreamText(lErr);
  finally
    lErr.Free;
    lOut.Free;
    lProcess.Free;
  end;
end;

end.
