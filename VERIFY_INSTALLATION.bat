@echo off
setlocal EnableExtensions
set "ROOT=%~dp0"
set "PS=%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe"
if defined PROCESSOR_ARCHITEW6432 set "PS=%WINDIR%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
set "HASHSTATE=%ROOT%Tools\HashState.ps1"
set "REGSTATE=%ROOT%Tools\ProviderRegistrationState.ps1"
set "PASS=1"
title Warcraft III 3.0 Win7 Compatibility Pack - verify

echo.
echo Installed-provider verification
echo ===============================
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%HASHSTATE%" -Path "%WINDIR%\System32\War3Win7BattleNetCompat.dll" -Expected "d2dc7f30344f2f4482196301835fdc45231619fc4df3d74bf49bf809b5fcbc90"
if not "%ERRORLEVEL%"=="10" set "PASS=0"
echo.
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%HASHSTATE%" -Path "%WINDIR%\SysWOW64\War3Win7BattleNetCompat.dll" -Expected "e32754c90d6e44844103b02c681e4e1b7a09fc5ae349f2e1a2abc5ce304496ef"
if not "%ERRORLEVEL%"=="10" set "PASS=0"
echo.
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%REGSTATE%"
if errorlevel 1 set "PASS=0"
echo.
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%HASHSTATE%" -Path "%ROOT%Runtime\War3_Win7_Online_Fix_v1.0.bat" -Expected "9209ca2149eeb550d4ab00aa597c5660208481c16c76fb57b2ad906ec54e2592"
if not "%ERRORLEVEL%"=="10" set "PASS=0"
echo.
if "%PASS%"=="1" (
  echo VERIFY PASS=True
) else (
  echo VERIFY PASS=False
  echo Do not bypass a mismatch. Run INSTALL.bat only on the documented supported binary set.
)
echo.
pause
if "%PASS%"=="1" (exit /b 0) else (exit /b 2)
