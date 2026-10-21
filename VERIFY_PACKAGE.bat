@echo off
setlocal EnableExtensions
title Warcraft III Windows 7 Compatibility Pack - Verify archive
set "PS=%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe"
if defined PROCESSOR_ARCHITEW6432 set "PS=%WINDIR%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS%" (
  echo ERROR: Windows PowerShell not found.
  pause
  exit /b 3
)
rem The PowerShell verifier creates this small file ONLY after checking every hash.
rem Do not rely on PowerShell stdout encoding, findstr or a misleading exit code.
set "REPORT=%TEMP%\War3PackVerify_%RANDOM%_%RANDOM%.txt"
set "PROOF=%REPORT%.ok"
if exist "%PROOF%" del /F /Q "%PROOF%" >nul 2>&1
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0Tools\VerifyPackage.ps1" -SuccessFile "%PROOF%" >"%REPORT%" 2>&1
type "%REPORT%"
set "VERIFIED=0"
if exist "%PROOF%" set "VERIFIED=1"
if exist "%PROOF%" del /F /Q "%PROOF%" >nul 2>&1
if exist "%REPORT%" del /F /Q "%REPORT%" >nul 2>&1
if "%VERIFIED%"=="1" (
  echo Package integrity check PASSED.
  pause
  exit /b 0
)
echo Package integrity check FAILED. Do not install this copy.
pause
exit /b 2
