@echo off
setlocal EnableExtensions
set "ROOT=%~dp0"
set "PS=%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe"
if defined PROCESSOR_ARCHITEW6432 set "PS=%WINDIR%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
set "HASHSTATE=%ROOT%Tools\HashState.ps1"
set "REGSTATE=%ROOT%Tools\ProviderRegistrationState.ps1"
set "RUNTIME=%ROOT%Runtime\War3_Win7_Online_Fix_v1.0.bat"
set "X64INST=%WINDIR%\System32\War3Win7BattleNetCompat.dll"
set "X86INST=%WINDIR%\SysWOW64\War3Win7BattleNetCompat.dll"
title Warcraft III 3.0 Windows 7 Compatibility Pack v1.0

for %%P in ("Hide.me.exe") do (
  tasklist /FI "IMAGENAME eq %%~P" 2>NUL | find /I "%%~P" >NUL
  if not errorlevel 1 (
    echo ERROR: %%~P is running. Fully quit Hide.me before launching Warcraft III.
    pause
    exit /b 12
  )
)

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%HASHSTATE%" -Path "%X64INST%" -Expected "d2dc7f30344f2f4482196301835fdc45231619fc4df3d74bf49bf809b5fcbc90"
if not "%ERRORLEVEL%"=="10" (
  echo ERROR: the validated x64 provider is not installed. Run INSTALL.bat first.
  pause
  exit /b 20
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%HASHSTATE%" -Path "%X86INST%" -Expected "e32754c90d6e44844103b02c681e4e1b7a09fc5ae349f2e1a2abc5ce304496ef"
if not "%ERRORLEVEL%"=="10" (
  echo ERROR: the validated x86 provider is not installed. Run INSTALL.bat first.
  pause
  exit /b 21
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%REGSTATE%"
if errorlevel 1 (
  echo ERROR: the x64 compatibility provider registration is not present. Run INSTALL.bat.
  pause
  exit /b 22
)
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%HASHSTATE%" -Path "%RUNTIME%" -Expected "9209ca2149eeb550d4ab00aa597c5660208481c16c76fb57b2ad906ec54e2592"
if not "%ERRORLEVEL%"=="10" (
  echo ERROR: runtime launcher integrity check failed.
  pause
  exit /b 23
)

call "%RUNTIME%"
exit /b %ERRORLEVEL%
