@echo off
setlocal EnableExtensions
set "SELF=%~f0"
set "OUT=%~dp0INSTALL_REPORT.txt"
set "PS1=%TEMP%\War3Win7CompatInstall_%RANDOM%_%RANDOM%.ps1"
title Warcraft III - Windows 7 Battle.net compatibility v1.0
cd /d "%~dp0"

net session >nul 2>&1
if errorlevel 1 (
  echo ERROR: Run INSTALL.bat as Administrator.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$c=Get-Content -LiteralPath $env:SELF; $i=[Array]::IndexOf($c,'#===PRECHECK_PS==='); if($i -lt 0){exit 91}; $c[($i+1)..($c.Length-1)] | Set-Content -LiteralPath $env:PS1 -Encoding UTF8"
if errorlevel 1 (echo ERROR extracting precheck.& pause& exit /b 1)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "PRE=%ERRORLEVEL%"
del /q "%PS1%" >nul 2>&1
if not "%PRE%"=="0" (
  echo.
  echo PRECHECK FAILED. Nothing was installed. See INSTALL_REPORT.txt.
  pause
  exit /b %PRE%
)

echo.
echo Installing the Windows 7 Schannel compatibility provider...
"War3Win7BattleNetCompatInstall.exe" >> "%OUT%" 2>&1
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo INSTALLER RETURNED %RC%. Do not launch Warcraft III.
  echo INSTALLER RETURNED %RC%. >> "%OUT%"
  pause
  exit /b %RC%
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$p='%SystemRoot%\System32\War3Win7BattleNetCompat.dll'; $expected='d2dc7f30344f2f4482196301835fdc45231619fc4df3d74bf49bf809b5fcbc90'; $sha=[Security.Cryptography.SHA256]::Create(); try{$f=[IO.File]::OpenRead($p);try{$h=([BitConverter]::ToString($sha.ComputeHash($f))).Replace('-','').ToLowerInvariant()}finally{$f.Dispose()}}finally{$sha.Dispose()}; Add-Content -LiteralPath '%OUT%' -Value ('System32 DLL SHA256='+$h); if($h-ne$expected){exit 7}"
set "POST=%ERRORLEVEL%"
if not "%POST%"=="0" (
  echo POST-INSTALL HASH VERIFY FAILED. Run REMOVE.bat before further testing.
  pause
  exit /b %POST%
)

echo INSTALL/PRECHECK/HASH VERIFY PASS >> "%OUT%"
echo.
echo Installation verified.
echo REBOOT WINDOWS ONCE before launching Battle.net.
echo After reboot, launch Warcraft III only from the official Battle.net launcher.
echo.
pause
exit /b 0

#===PRECHECK_PS===
$ErrorActionPreference='Stop'
$Out=$env:OUT
$L=New-Object Collections.Generic.List[string]
function O([string]$s=''){[void]$L.Add($s);Write-Host $s}
function S{[IO.File]::WriteAllLines($Out,[string[]]$L.ToArray(),(New-Object Text.ASCIIEncoding))}
function HashFile([string]$p){$s=[Security.Cryptography.SHA256]::Create();$f=[IO.File]::Open($p,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite);try{return ([BitConverter]::ToString($s.ComputeHash($f))).Replace('-','').ToLowerInvariant()}finally{$f.Dispose();$s.Dispose()}}
try{
 if(Test-Path -LiteralPath $Out){Remove-Item -LiteralPath $Out -Force}
 O 'Warcraft III Windows 7 Battle.net compatibility v1.0 - PRECHECK'
 O '======================================================================='
 O 'No network/authentication data is accessed by this precheck.'
 $ok=$true
 $v=[Environment]::OSVersion.Version
 $os=($v.Major-eq6-and$v.Minor-eq1)
 O ('Windows version='+$v.ToString()+'; Windows 7 family='+$os)
 if(-not$os){$ok=$false}
 $os64=Test-Path -LiteralPath (Join-Path $env:WINDIR 'SysWOW64') -PathType Container
 $proc64=([IntPtr]::Size-eq8)
 O ('64-bit operating system='+$os64)
 O ('64-bit PowerShell process='+$proc64)
 if(-not$os64-or-not$proc64){$ok=$false}
 $checks=@(
   @((Join-Path $env:WINDIR 'System32\schannel.dll'),'51dcfaa5fe70d231d609fc7c37a3262c30d613721420efd65f8c33578c371501','schannel.dll'),
   @((Join-Path $env:WINDIR 'System32\ncrypt.dll'),'962f201ee3b08e3fc4a0849251958c573ebcb3b32f588ec624ebc443a2400be9','ncrypt.dll'),
   @((Join-Path $env:WINDIR 'System32\bcrypt.dll'),'e101aa09220b126962ed5de00d7f15bcd645890f33afa1728fafd78d2e67ae90','bcrypt.dll'),
   @((Join-Path $env:WINDIR 'System32\bcryptprimitives.dll'),'715977e616e206724f91660ef5bd0c4f2c6d66e3891f03c28a864419102ce5b6','bcryptprimitives.dll'),
   @((Join-Path (Split-Path -Parent $env:SELF) 'War3Win7BattleNetCompat.dll'),'d2dc7f30344f2f4482196301835fdc45231619fc4df3d74bf49bf809b5fcbc90','package DLL')
 )
 foreach($c in $checks){
   $exists=Test-Path -LiteralPath $c[0] -PathType Leaf
   if($exists){$h=HashFile $c[0]}else{$h='<missing>'}
   $match=($exists-and$h-eq$c[1])
   O ($c[2]+' SHA256='+$h+'; expected='+$match)
   if(-not$match){$ok=$false}
 }
 O ''
 O ('PRECHECK PASS='+$ok)
 if(-not$ok){
   O 'This RC is intentionally restricted to the exact Windows 7 x64 binary set on which it was audited.'
   O 'Do not bypass the precheck on a different binary set.'
 }
 S
 if($ok){exit 0}else{exit 2}
}catch{O ('ERROR: '+$_.Exception.Message);try{S}catch{};exit 1}