@echo off
setlocal EnableExtensions
set "ROOT=%~dp0"
set "SELF=%~f0"
set "PS=%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe"
if defined PROCESSOR_ARCHITEW6432 set "PS=%WINDIR%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
set "HASHSTATE=%ROOT%Tools\HashState.ps1"
set "AUTOKEY=%TEMP%\War3PackRemoveKey_%RANDOM%_%RANDOM%.txt"
set "REPORT=%ROOT%PACK_REMOVE_REPORT.txt"
set "X64INST=%WINDIR%\System32\War3Win7BattleNetCompat.dll"
set "X86INST=%WINDIR%\SysWOW64\War3Win7BattleNetCompat.dll"
set "X64HASH=d2dc7f30344f2f4482196301835fdc45231619fc4df3d74bf49bf809b5fcbc90"
set "X86HASH=e32754c90d6e44844103b02c681e4e1b7a09fc5ae349f2e1a2abc5ce304496ef"
title Warcraft III 3.0 Windows 7 Compatibility Pack - removal
cd /d "%ROOT%"

>"%REPORT%" echo Warcraft III 3.0 Windows 7 Compatibility Pack v1.0 - REMOVE
>>"%REPORT%" echo =============================================================

echo.
echo Warcraft III 3.0 Windows 7 Compatibility Pack - removal
echo =========================================================
echo Persistent provider components will be removed.
echo The Warcraft runtime fix itself is process-local and leaves no patched game file behind.
echo.

net session >nul 2>&1
if errorlevel 1 (
  echo Requesting Administrator privileges...
  "%PS%" -NoProfile -ExecutionPolicy Bypass -Command "$q=[char]34; Start-Process -FilePath $env:ComSpec -ArgumentList '/c',($q+$env:SELF+$q) -Verb RunAs"
  exit /b
)

for %%P in ("Warcraft III.exe" "Battle.net.exe" "Agent.exe") do (
  tasklist /FI "IMAGENAME eq %%~P" 2>NUL | find /I "%%~P" >NUL
  if not errorlevel 1 (
    echo ERROR: %%~P is still running. Close Warcraft III and Battle.net first.
    >>"%REPORT%" echo BLOCKED_RUNNING_PROCESS=%%~P
    pause
    exit /b 12
  )
)

rem Fail closed before deleting any unexpected provider image.
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%HASHSTATE%" -Path "%X86INST%" -Expected "%X86HASH%"
set "X86STATE=%ERRORLEVEL%"
if "%X86STATE%"=="20" goto :MISMATCH
if "%X86STATE%"=="30" goto :MISMATCH
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%HASHSTATE%" -Path "%X64INST%" -Expected "%X64HASH%"
set "X64STATE=%ERRORLEVEL%"
if "%X64STATE%"=="20" goto :MISMATCH
if "%X64STATE%"=="30" goto :MISMATCH
>>"%REPORT%" echo PRECHECK_X86=%X86STATE% PRECHECK_X64=%X64STATE%

if "%X86STATE%"=="10" (
  echo [1/2] Removing exact x86 SysWOW64 companion provider...
  echo X>"%AUTOKEY%"
  call "%ROOT%Provider\x86\REMOVE_X86_PROVIDER.bat" < "%AUTOKEY%"
  if errorlevel 1 (
    del /q "%AUTOKEY%" >nul 2>&1
    echo ERROR: x86 removal failed; x64 provider was left untouched.
    >>"%REPORT%" echo X86_REMOVE=FAIL
    pause
    exit /b 20
  )
  >>"%REPORT%" echo X86_REMOVE=PASS
) else (
  echo [1/2] x86 companion provider already absent.
  >>"%REPORT%" echo X86_REMOVE=ALREADY_ABSENT
)

echo.
echo [2/2] Removing original x64 provider registration/component...
echo X>"%AUTOKEY%"
call "%ROOT%Provider\x64\REMOVE.bat" < "%AUTOKEY%"
if errorlevel 1 (
  del /q "%AUTOKEY%" >nul 2>&1
  echo ERROR: x64 provider removal reported a problem. Review Provider\x64\REMOVE_REPORT.txt.
  >>"%REPORT%" echo X64_REMOVE=FAIL
  pause
  exit /b 21
)
>>"%REPORT%" echo X64_REMOVE=PASS

del /q "%AUTOKEY%" >nul 2>&1
>>"%REPORT%" echo RESULT=PASS

echo.
echo Removal completed. Reboot Windows once before retesting the unmodified system.
echo.
pause
exit /b 0

:MISMATCH
echo.
echo ERROR: an installed provider file has an unexpected SHA-256.
echo Removal is refusing to delete an image that does not belong to this pack.
echo Use the remover belonging to that other provider build or inspect it manually.
>>"%REPORT%" echo RESULT=FAIL_UNEXPECTED_PROVIDER_IMAGE
pause
exit /b 30
