(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit utNXBenchmarkClock;

{$mode objfpc}{$H+}

interface

function NXBenchmarkCounter: Int64;
function NXBenchmarkFrequency: Int64;

implementation

uses
  {$IF DEFINED(WINDOWS)}
  Windows,
  {$ELSEIF DEFINED(LINUX)}
  UnixType, Linux,
  {$ELSE}
  {$FATAL Benchmark timing is implemented for Windows and Linux only.}
  {$ENDIF}
  SysUtils;

{$IFDEF LINUX}
const
  cNanosecondsPerSecond = 1000000000;
{$ENDIF}

function NXBenchmarkCounter: Int64;
{$IFDEF LINUX}
var
  lTime: TTimeSpec;
{$ENDIF}
begin
  {$IFDEF WINDOWS}
  if not QueryPerformanceCounter(Result) then
    RaiseLastOSError;
  {$ELSE}
  if clock_gettime(CLOCK_MONOTONIC, @lTime) <> 0 then
    RaiseLastOSError;
  Result := Int64(lTime.tv_sec) * cNanosecondsPerSecond + lTime.tv_nsec;
  {$ENDIF}
end;

function NXBenchmarkFrequency: Int64;
begin
  {$IFDEF WINDOWS}
  if not QueryPerformanceFrequency(Result) then
    RaiseLastOSError;
  {$ELSE}
  Result := cNanosecondsPerSecond;
  {$ENDIF}
end;

end.
