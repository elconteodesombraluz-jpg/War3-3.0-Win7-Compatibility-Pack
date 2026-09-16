@echo off
setlocal EnableExtensions
set "SELF=%~f0"
set "OUT=%~dp0REMOVE_REPORT.txt"
set "PS1=%TEMP%\War3Win7CompatRemove_%RANDOM%_%RANDOM%.ps1"
title Warcraft III - remove Windows 7 Battle.net compatibility v1.0
cd /d "%~dp0"

net session >nul 2>&1
if errorlevel 1 (
  echo ERROR: Run REMOVE.bat as Administrator.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$c=Get-Content -LiteralPath $env:SELF; $i=[Array]::IndexOf($c,'#===REMOVE_PS==='); if($i -lt 0){exit 91}; $c[($i+1)..($c.Length-1)] | Set-Content -LiteralPath $env:PS1 -Encoding UTF8"
if errorlevel 1 (echo ERROR extracting remover.& pause& exit /b 1)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "RC=%ERRORLEVEL%"
del /q "%PS1%" >nul 2>&1
echo.
if exist "%OUT%" type "%OUT%"
echo.
pause
exit /b %RC%

#===REMOVE_PS===
$ErrorActionPreference='Stop'
$Out=$env:OUT
$L=New-Object Collections.Generic.List[string]
function O([string]$s=''){[void]$L.Add($s);Write-Host $s}
function S{[IO.File]::WriteAllLines($Out,[string[]]$L.ToArray(),(New-Object Text.ASCIIEncoding))}
$cs=@"
using System;
using System.Runtime.InteropServices;
public static class War3Win7CompatRemove {
 [DllImport("bcrypt.dll", CharSet=CharSet.Unicode)] public static extern int BCryptRemoveContextFunctionProvider(UInt32 table,string context,UInt32 iface,string function,string provider);
 [DllImport("bcrypt.dll", CharSet=CharSet.Unicode)] public static extern int BCryptRemoveContextFunction(UInt32 table,string context,UInt32 iface,string function);
 [DllImport("bcrypt.dll", CharSet=CharSet.Unicode)] public static extern int BCryptUnregisterProvider(string provider);
 [DllImport("bcrypt.dll", CharSet=CharSet.Unicode)] public static extern int BCryptQueryProviderRegistration(string provider,UInt32 mode,UInt32 iface,out UInt32 cb,out IntPtr buffer);
 [DllImport("bcrypt.dll")] public static extern void BCryptFreeBuffer(IntPtr buffer);
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern bool DeleteFileW(string path);
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern bool MoveFileExW(string existing,string replacement,UInt32 flags);
}
"@
Add-Type -TypeDefinition $cs
function U([int]$x){return [UInt32]([Int64]$x -band 0xFFFFFFFFL)}
$NF=[Convert]::ToUInt32('C0000225',16)
$provider='War3 Win7 Battle.net Compat v1.0'
$dll='War3Win7BattleNetCompat.dll'
$context='SSL'
$iface=[UInt32]0x00010002
$table=[UInt32]1
$suites=@(
 'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256_P256',
 'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256_P384',
 'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256_P521'
)
function QueryProvider {
 [UInt32]$cb=0
 $p=[IntPtr]::Zero
 $s=[War3Win7CompatRemove]::BCryptQueryProviderRegistration($provider,$table,$iface,[ref]$cb,[ref]$p)
 try{return [pscustomobject]@{Status=(U $s);Size=$cb}}finally{if($p-ne[IntPtr]::Zero){[War3Win7CompatRemove]::BCryptFreeBuffer($p)}}
}
try{
 if(Test-Path -LiteralPath $Out){Remove-Item -LiteralPath $Out -Force}
 O 'Warcraft III Windows 7 Battle.net compatibility v1.0 - REMOVE'
 O '======================================================================='
 O 'Close Warcraft III and Battle.net before removal.'
 O 'Uses documented BCrypt removal APIs; no process-memory/network/authentication access.'
 O ('provider="'+$provider+'"')
 O ('System32 DLL="'+$dll+'"')
 O ''
 $ok=$true
 $q=QueryProvider
 O ('Provider query before remove = 0x'+$q.Status.ToString('X8')+'; returnedSize='+$q.Size)
 foreach($sn in $suites){
  $u=U ([War3Win7CompatRemove]::BCryptRemoveContextFunctionProvider($table,$context,$iface,$sn,$provider))
  O ('BCryptRemoveContextFunctionProvider "'+$sn+'" = 0x'+$u.ToString('X8'))
  if($u-ne0-and$u-ne$NF){$ok=$false}
 }
 foreach($sn in $suites){
  $u=U ([War3Win7CompatRemove]::BCryptRemoveContextFunction($table,$context,$iface,$sn))
  O ('BCryptRemoveContextFunction "'+$sn+'" = 0x'+$u.ToString('X8'))
  if($u-ne0-and$u-ne$NF){$ok=$false}
 }
 $u=U ([War3Win7CompatRemove]::BCryptUnregisterProvider($provider))
 O ('BCryptUnregisterProvider = 0x'+$u.ToString('X8'))
 if($u-ne0-and$u-ne$NF){$ok=$false}
 $q2=QueryProvider
 O ('Provider registration after remove = 0x'+$q2.Status.ToString('X8')+'; returnedSize='+$q2.Size)
 if($q2.Status-ne$NF){$ok=$false}
 $path=Join-Path ([Environment]::SystemDirectory) $dll
 $scheduled=$false
 if(Test-Path -LiteralPath $path){
  if([War3Win7CompatRemove]::DeleteFileW($path)){O 'DeleteFileW(unique compatibility DLL) = True'}
  else{
   $e=[Runtime.InteropServices.Marshal]::GetLastWin32Error()
   O ('DeleteFileW failed GetLastError=0x'+$e.ToString('X8'))
   $scheduled=[War3Win7CompatRemove]::MoveFileExW($path,$null,4)
   O ('MoveFileExW delete-on-reboot scheduled = '+$scheduled)
   if(-not$scheduled){$ok=$false}
  }
 }else{O 'System32 compatibility DLL already absent = True'}
 O ''
 O ('REMOVE CONFIGURATION PASS='+$ok)
 O 'Reboot Windows once after removal before retesting Warcraft III.'
 if($scheduled){O 'The reboot is also required to finish deleting the resident DLL.'}
 S
 if($ok){exit 0}else{exit 2}
}catch{O '';O ('ERROR: '+$_.Exception.Message);try{S}catch{};exit 1}