@echo off
setlocal
cd /d %~dp0
fpc -MObjFPC -Scgi -Fu.\src -Fu..\NexusLib\src .\sample\SampleTests\nxtest_sampletests.lpr
if errorlevel 1 exit /b 1
fpc -MObjFPC -Scgi -Fu.\src -Fu..\NexusLib\src .\sample\Host\nxtest_host.lpr
if errorlevel 1 exit /b 1
