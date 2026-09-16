@echo off
setlocal EnableExtensions
set "SELF=%~f0"
set "DST=%WINDIR%\SysWOW64\War3Win7BattleNetCompat.dll"
set "EXPECTED=e32754c90d6e44844103b02c681e4e1b7a09fc5ae349f2e1a2abc5ce304496ef"
set "PS1=%TEMP%\War3Win7_RemoveX86_%RANDOM%_%RANDOM%.ps1"
title Warcraft III Win7 Compatibility Pack - remove x86 provider

net session >nul 2>&1
if errorlevel 1 (
  echo Requesting Administrator privileges...
  set "PS=%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe"
  if defined PROCESSOR_ARCHITEW6432 set "PS=%WINDIR%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
  "%PS%" -NoProfile -ExecutionPolicy Bypass -Command "$q=[char]34; Start-Process -FilePath $env:ComSpec -ArgumentList '/c',($q+$env:SELF+$q) -Verb RunAs"
  exit /b
)

for %%P in ("Battle.net.exe" "Agent.exe" "Warcraft III.exe") do (
  tasklist /FI "IMAGENAME eq %%~P" 2>NUL | find /I "%%~P" >NUL
  if not errorlevel 1 (
    echo ERROR: %%~P is still running. Close Warcraft III and Battle.net first.
    pause
    exit /b 1
  )
)

>"%PS1%" echo $ErrorActionPreference='Stop'
>>"%PS1%" echo $p=$env:DST
>>"%PS1%" echo $want=$env:EXPECTED
>>"%PS1%" echo function Sha([string]$x){$s=[Security.Cryptography.SHA256]::Create();$f=[IO.File]::OpenRead($x);try{([BitConverter]::ToString($s.ComputeHash($f))).Replace('-','').ToLowerInvariant()}finally{$f.Dispose();$s.Dispose()}}
>>"%PS1%" echo if(!(Test-Path -LiteralPath $p -PathType Leaf)){Write-Host 'x86 provider is already absent.';exit 0}
>>"%PS1%" echo $h=Sha $p
>>"%PS1%" echo Write-Host ('Current SHA256='+$h)
>>"%PS1%" echo if($h -ne $want){Write-Host 'ERROR: refusing to delete an unexpected SysWOW64 provider image.';exit 2}
>>"%PS1%" echo Remove-Item -LiteralPath $p -Force
>>"%PS1%" echo if(Test-Path -LiteralPath $p){Write-Host 'ERROR: file still present.';exit 3}
>>"%PS1%" echo Write-Host 'Validated x86 compatibility provider removed.'

set "PS=%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe"
if defined PROCESSOR_ARCHITEW6432 set "PS=%WINDIR%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "RC=%ERRORLEVEL%"
del /q "%PS1%" >nul 2>&1
pause
exit /b %RC%
