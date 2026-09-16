@echo off
setlocal EnableExtensions
set "SELF=%~f0"
set "SRC=%~dp0War3Win7BattleNetCompat_x86_v1b.dll"
set "DST=%WINDIR%\SysWOW64\War3Win7BattleNetCompat.dll"
set "PS1=%TEMP%\War3Win7_X86_Install_v1b_%RANDOM%_%RANDOM%.ps1"
set "OUT=%~dp0INSTALL_X86_REPORT.txt"
title Warcraft III - Windows 7 x86 provider v1b

echo.
echo Warcraft III - Windows 7 x86 compatibility provider v1b
echo ==========================================================
echo This installs ONLY the audited x86 provider image into SysWOW64.
echo It does NOT change CNG registration and does NOT modify the System32 x64 provider.
echo.
echo REQUIREMENTS: Warcraft/Battle.net closed and Hide.me fully quit.
echo.

if not exist "%SRC%" (
  echo ERROR: missing "%SRC%"
  pause
  exit /b 1
)

net session >nul 2>&1
if errorlevel 1 (
  echo Requesting Administrator privileges...
  set "PS=%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe"
  if defined PROCESSOR_ARCHITEW6432 set "PS=%WINDIR%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
  "%PS%" -NoProfile -ExecutionPolicy Bypass -Command "$q=[char]34; Start-Process -FilePath $env:ComSpec -ArgumentList '/c',($q+$env:SELF+$q) -Verb RunAs"
  exit /b
)

for %%P in ("Hide.me.exe" "Battle.net.exe" "Agent.exe" "Warcraft III.exe" "curl.exe") do (
  tasklist /FI "IMAGENAME eq %%~P" 2>NUL | find /I "%%~P" >NUL
  if not errorlevel 1 (
    echo ERROR: %%~P is still running. Close it completely, then rerun.
    pause
    exit /b 1
  )
)

set "PS=%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe"
if defined PROCESSOR_ARCHITEW6432 set "PS=%WINDIR%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"
"%PS%" -NoProfile -ExecutionPolicy Bypass -Command "$c=Get-Content -LiteralPath $env:SELF; $i=[Array]::IndexOf($c,'#===X86_PROVIDER_PS==='); if($i -lt 0){exit 91}; $c[($i+1)..($c.Length-1)] | Set-Content -LiteralPath $env:PS1 -Encoding UTF8"
if errorlevel 1 (
  echo ERROR: Could not extract embedded PowerShell.
  pause
  exit /b 1
)

"%PS%" -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "RC=%ERRORLEVEL%"
del /q "%PS1%" >nul 2>&1

echo.
echo Report: "%OUT%"
if not "%RC%"=="0" echo INSTALL NOT CLOSED.
echo.
pause
exit /b %RC%

#===X86_PROVIDER_PS===
$ErrorActionPreference='Stop'
$Src=$env:SRC
$Dst=$env:DST
$Out=$env:OUT
$ExpectedCandidate='e32754c90d6e44844103b02c681e4e1b7a09fc5ae349f2e1a2abc5ce304496ef'
$L=New-Object Collections.Generic.List[string]
$Pass=$true
function O([string]$s=''){[void]$L.Add($s);Write-Host $s}
function Save{[IO.File]::WriteAllLines($Out,[string[]]$L.ToArray(),(New-Object Text.ASCIIEncoding))}
function Sha([string]$p){
    if(!(Test-Path -LiteralPath $p -PathType Leaf)){return '<missing>'}
    $s=[Security.Cryptography.SHA256]::Create();$f=[IO.File]::OpenRead($p)
    try{return ([BitConverter]::ToString($s.ComputeHash($f))).Replace('-','').ToLowerInvariant()}
    finally{$f.Dispose();$s.Dispose()}
}
function CheckHash([string]$p,[string]$want,[string]$label){
    $h=Sha $p;$ok=($h-eq$want);O ($label+': '+$p);O ('  SHA256='+$h);O ('  expected='+$want+' PASS='+$ok);if(-not$ok){$script:Pass=$false};return $ok
}
try{
    if(Test-Path -LiteralPath $Out){Remove-Item -LiteralPath $Out -Force}
    O 'Warcraft III - Windows 7 x86 compatibility provider v1b'
    O '======================================================================='
    O 'GUARDED PERSISTENT COPY ONLY. NO CNG REGISTRATION CHANGE.'
    O ''
    O 'A. EXACT PRE-FLIGHT'
    $a1=CheckHash $Src $ExpectedCandidate 'x86 provider image'
    $a2=CheckHash (Join-Path $env:WINDIR 'SysWOW64\schannel.dll') 'ae50b1f96e16020c9cfe894817d3ee440256b6a1c933b0a19b106ffaae5eef9a' 'x86 schannel'
    $a3=CheckHash (Join-Path $env:WINDIR 'SysWOW64\ncrypt.dll') 'd1106de78aaa439e7249cb16e3ef78b2b9505f514ee2917b3a8e05412af9f7e9' 'x86 ncrypt'
    $a4=CheckHash (Join-Path $env:WINDIR 'SysWOW64\bcrypt.dll') 'cdf412f5186596e92597fd7ac8bcbac23ec89ffb66f3ee31f362fc2e1f476b79' 'x86 bcrypt'
    $a5=CheckHash (Join-Path $env:WINDIR 'SysWOW64\bcryptprimitives.dll') 'd80dcec4b5554e84491b06c624098123033b840f88157ef402edad2163b0a734' 'x86 bcryptprimitives'
    $a6=CheckHash (Join-Path $env:WINDIR 'System32\War3Win7BattleNetCompat.dll') 'd2dc7f30344f2f4482196301835fdc45231619fc4df3d74bf49bf809b5fcbc90' 'existing x64 provider'
    $targetAbsent=(-not(Test-Path -LiteralPath $Dst -PathType Leaf));O ('SysWOW64 target initially absent='+$targetAbsent);if(-not$targetAbsent){$Pass=$false}
    $preflight=($a1-and$a2-and$a3-and$a4-and$a5-and$a6-and$targetAbsent);O ('PRE-FLIGHT CLOSED='+$preflight)
    if(-not$preflight){throw 'Pre-flight did not close. Nothing was copied.'}
    O '';O 'B. INSTALL X86 PROVIDER IMAGE'
    [IO.File]::Copy($Src,$Dst,$false)
    $dstHash=Sha $Dst;$copyOk=($dstHash-eq$ExpectedCandidate);O ('Copy -> '+$Dst+' PASS='+$copyOk);O ('destination SHA256='+$dstHash)
    if(-not$copyOk){try{Remove-Item -LiteralPath $Dst -Force}catch{};throw 'Destination identity mismatch after copy.'}
    O '';O 'C. FINAL STATE';O ('SysWOW64 x86 provider present='+(Test-Path -LiteralPath $Dst -PathType Leaf));O 'Existing CNG registration was not modified.';O 'Existing System32 x64 provider was not modified.';O '';O 'RESULT: PASS - audited x86 provider installed in SysWOW64.'
}catch{O '';O ('ERROR: '+$_.Exception.GetType().FullName+': '+$_.Exception.Message);$Pass=$false;O 'RESULT: FAIL / NOT INSTALLED.'}
finally{try{Save}catch{}}
if($Pass){exit 0}else{exit 2}
