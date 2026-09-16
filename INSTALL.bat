@echo off
setlocal EnableExtensions
set "ROOT=%~dp0"
set "SELF=%~f0"
set "PS=%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe"
if defined PROCESSOR_ARCHITEW6432 set "PS=%WINDIR%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
set "HASHSTATE=%ROOT%Tools\HashState.ps1"
set "REGSTATE=%ROOT%Tools\ProviderRegistrationState.ps1"
set "AUTOKEY=%TEMP%\War3PackAutoKey_%RANDOM%_%RANDOM%.txt"
set "REPORT=%ROOT%PACK_INSTALL_REPORT.txt"
set "X64INST=%WINDIR%\System32\War3Win7BattleNetCompat.dll"
set "X86INST=%WINDIR%\SysWOW64\War3Win7BattleNetCompat.dll"
set "X64HASH=d2dc7f30344f2f4482196301835fdc45231619fc4df3d74bf49bf809b5fcbc90"
set "X86HASH=e32754c90d6e44844103b02c681e4e1b7a09fc5ae349f2e1a2abc5ce304496ef"
title Warcraft III 3.0 Windows 7 Compatibility Pack v1.0
cd /d "%ROOT%"

>"%REPORT%" echo Warcraft III 3.0 Windows 7 Compatibility Pack v1.0 - INSTALL
>>"%REPORT%" echo ==============================================================

echo.
echo Warcraft III 3.0 Windows 7 Compatibility Pack v1.0
echo ======================================================
echo Installs the persistent Windows compatibility-provider layer.
echo Warcraft III files on disk are never modified.
echo The process-local Warcraft runtime fix is used later by START_WARCRAFT_III.bat.
echo.

net session >nul 2>&1
if errorlevel 1 (
  echo Requesting Administrator privileges...
  "%PS%" -NoProfile -ExecutionPolicy Bypass -Command "$q=[char]34; Start-Process -FilePath $env:ComSpec -ArgumentList '/c',($q+$env:SELF+$q) -Verb RunAs"
  exit /b
)

for %%P in ("Hide.me.exe" "Warcraft III.exe" "Battle.net.exe" "Agent.exe" "curl.exe") do (
  tasklist /FI "IMAGENAME eq %%~P" 2>NUL | find /I "%%~P" >NUL
  if not errorlevel 1 (
    echo ERROR: %%~P is still running. Close it completely, then rerun INSTALL.bat.
    >>"%REPORT%" echo BLOCKED_RUNNING_PROCESS=%%~P
    pause
    exit /b 12
  )
)

if not exist "%HASHSTATE%" (
  echo ERROR: Tools\HashState.ps1 is missing.
  pause
  exit /b 13
)
if not exist "%REGSTATE%" (
  echo ERROR: Tools\ProviderRegistrationState.ps1 is missing.
  pause
  exit /b 14
)

rem Verify exact package payloads before executing anything.
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%HASHSTATE%" -Path "%ROOT%Provider\x64\War3Win7BattleNetCompat.dll" -Expected "%X64HASH%"
if not "%ERRORLEVEL%"=="10" (
  echo ERROR: x64 provider payload hash mismatch or missing.
  >>"%REPORT%" echo X64_PACKAGE_PAYLOAD=FAIL
  pause
  exit /b 15
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%HASHSTATE%" -Path "%ROOT%Provider\x64\War3Win7BattleNetCompatInstall.exe" -Expected "748823f38819be8b83d52d568a179e754fdaece3b1532c0ae961b40a1fd4da40"
if not "%ERRORLEVEL%"=="10" (
  echo ERROR: original x64 installer executable hash mismatch or missing.
  >>"%REPORT%" echo X64_INSTALLER_PAYLOAD=FAIL
  pause
  exit /b 16
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%HASHSTATE%" -Path "%ROOT%Provider\x86\War3Win7BattleNetCompat_x86_v1b.dll" -Expected "%X86HASH%"
if not "%ERRORLEVEL%"=="10" (
  echo ERROR: x86 provider payload hash mismatch or missing.
  >>"%REPORT%" echo X86_PACKAGE_PAYLOAD=FAIL
  pause
  exit /b 17
)
>>"%REPORT%" echo PACKAGE_PAYLOAD_HASHES=PASS

rem Inspect existing x64 provider file and provider registration.
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%HASHSTATE%" -Path "%X64INST%" -Expected "%X64HASH%"
set "X64STATE=%ERRORLEVEL%"
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%REGSTATE%"
set "REG=%ERRORLEVEL%"
>>"%REPORT%" echo X64_FILE_STATE=%X64STATE% REGISTRATION_STATE=%REG%

if "%X64STATE%"=="20" goto :X64_INCONSISTENT
if "%X64STATE%"=="30" goto :X64_INCONSISTENT
if "%REG%"=="2" goto :X64_INCONSISTENT
if "%REG%"=="3" goto :X64_INCONSISTENT
if "%X64STATE%"=="10" if "%REG%"=="0" goto :X64_READY
if "%X64STATE%"=="0" if "%REG%"=="1" goto :INSTALL_X64
goto :X64_INCONSISTENT

:INSTALL_X64
echo.
echo [1/2] Installing the original validated x64 provider...
>>"%REPORT%" echo X64_ACTION=INSTALL
echo X>"%AUTOKEY%"
call "%ROOT%Provider\x64\INSTALL.bat" < "%AUTOKEY%"
if errorlevel 1 (
  del /q "%AUTOKEY%" >nul 2>&1
  echo ERROR: x64 provider installation failed. Review Provider\x64\INSTALL_REPORT.txt.
  >>"%REPORT%" echo X64_INSTALL=FAIL
  pause
  exit /b 20
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%HASHSTATE%" -Path "%X64INST%" -Expected "%X64HASH%"
if not "%ERRORLEVEL%"=="10" (
  echo ERROR: x64 provider post-install hash verification failed.
  >>"%REPORT%" echo X64_POST_VERIFY=FAIL
  pause
  exit /b 21
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%REGSTATE%"
if errorlevel 1 (
  echo ERROR: x64 provider registration is not present after installation.
  >>"%REPORT%" echo X64_REGISTRATION_POST_VERIFY=FAIL
  pause
  exit /b 22
)
>>"%REPORT%" echo X64_INSTALL=PASS
goto :X64_READY

:X64_INCONSISTENT
echo.
echo ERROR: existing x64 provider state is partial, unexpected, or mismatched.
echo Run REMOVE.bat first if this is an old/partial installation, then retry.
echo Do not overwrite an unknown provider image.
>>"%REPORT%" echo X64_STATE=INCONSISTENT_FAIL_CLOSED
pause
exit /b 23

:X64_READY
echo [1/2] x64 provider ready.
>>"%REPORT%" echo X64_READY=True

rem Inspect/install x86 companion image.
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%HASHSTATE%" -Path "%X86INST%" -Expected "%X86HASH%"
set "X86STATE=%ERRORLEVEL%"
>>"%REPORT%" echo X86_FILE_STATE=%X86STATE%
if "%X86STATE%"=="20" goto :X86_MISMATCH
if "%X86STATE%"=="30" goto :X86_MISMATCH
if "%X86STATE%"=="10" goto :X86_READY
if not "%X86STATE%"=="0" goto :X86_MISMATCH

echo.
echo [2/2] Installing the audited x86 SysWOW64 companion provider...
>>"%REPORT%" echo X86_ACTION=INSTALL
echo X>"%AUTOKEY%"
call "%ROOT%Provider\x86\INSTALL_X86_PROVIDER.bat" < "%AUTOKEY%"
if errorlevel 1 (
  del /q "%AUTOKEY%" >nul 2>&1
  echo ERROR: x86 provider installation failed. Review Provider\x86\INSTALL_X86_REPORT.txt.
  >>"%REPORT%" echo X86_INSTALL=FAIL
  pause
  exit /b 30
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%HASHSTATE%" -Path "%X86INST%" -Expected "%X86HASH%"
if not "%ERRORLEVEL%"=="10" (
  echo ERROR: x86 provider post-install hash verification failed.
  >>"%REPORT%" echo X86_POST_VERIFY=FAIL
  pause
  exit /b 31
)
>>"%REPORT%" echo X86_INSTALL=PASS
goto :X86_READY

:X86_MISMATCH
echo.
echo ERROR: an unexpected SysWOW64 provider image already exists.
echo Nothing will overwrite it. Inspect/remove the old state manually or with its matching remover.
>>"%REPORT%" echo X86_STATE=MISMATCH_FAIL_CLOSED
pause
exit /b 32

:X86_READY
echo [2/2] x86 provider ready.
>>"%REPORT%" echo X86_READY=True

del /q "%AUTOKEY%" >nul 2>&1
>>"%REPORT%" echo RESULT=PASS

echo.
echo ======================================================
echo INSTALLATION PASS
echo ======================================================
echo Reboot Windows once before first use or after changing provider state.
echo Then start Battle.net, sign in, and launch the game with:
echo   START_WARCRAFT_III.bat
echo.
echo Keep PACK_INSTALL_REPORT.txt and the component reports if troubleshooting is needed.
echo.
pause
exit /b 0
