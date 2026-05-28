@echo off
setlocal

cd /d "%~dp0\.."

fpc -MObjFPC -Scgi ^
  "-Fu.\src" ^
  "-Fu.\src\protocol" ^
  "-Fu.\src\service" ^
  "-Fu..\NexusTest\src" ^
  "-Fu..\NexusLib\src" ^
  "-Fu..\lib\synapse" ^
  "-FuC:\lazarus\components\codetools" ^
  "-FuC:\lazarus\components\lazutils" ^
  ".\NexusLSTestModule\NexusLSTestModule.lpr"
