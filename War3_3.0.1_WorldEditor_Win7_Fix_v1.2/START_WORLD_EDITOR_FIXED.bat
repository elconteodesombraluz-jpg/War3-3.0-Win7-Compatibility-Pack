@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>&1
color 0B
title Warcraft III 3.0.1.24371 World Editor - Win7 FIX v1.2

echo ================================================================
echo Warcraft III 3.0.1.24371 World Editor - Win7 FIX v1.2
echo ================================================================
echo One-click dummy-map ShellOpen + guarded 3.0.1 timebase heartbeat.
echo.
echo This release candidate:
echo   - opens bundled dummy.w3m through the Windows file association
echo   - launches World Editor through dummy.w3m
echo   - verifies exact supported hashes
echo   - validates the low-byte +68 and stable +70 runtime signature
echo   - refreshes only 4 DATA bytes when the decoded age reaches 10 s
echo   - modifies no Warcraft III file on disk
echo.
echo Close any already-running World Editor first. Battle.net may remain open.
echo.

set "WE_ROOT=%~dp0"
set "WE_REPORT=%~dp0WORLD_EDITOR_24371_FIX_v1.2.txt"
set "WE_PS1=%TEMP%\WE301_24371_FIX_%RANDOM%_%RANDOM%.ps1"
set "WE_SELF=%~f0"

for /f "tokens=1 delims=:" %%N in ('findstr /n /x /c:"#PS1_BEGIN" "%~f0"') do set "WE_SKIP=%%N"
if not defined WE_SKIP (
  echo ERROR: embedded PowerShell payload marker not found.
  pause
  exit /b 1
)

set "WE_POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if defined PROCESSOR_ARCHITEW6432 set "WE_POWERSHELL=%SystemRoot%\Sysnative\WindowsPowerShell\v1.0\powershell.exe"

echo Preparing runtime...
"%WE_POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$lines=Get-Content -LiteralPath $env:WE_SELF; $skip=[int]$env:WE_SKIP; $lines | Select-Object -Skip $skip | Set-Content -LiteralPath $env:WE_PS1 -Encoding UTF8"
if errorlevel 1 (
  echo ERROR: could not extract embedded PowerShell payload.
  pause
  exit /b 2
)
if not exist "%WE_PS1%" (
  echo ERROR: temporary PowerShell payload was not created.
  pause
  exit /b 3
)
for %%A in ("%WE_PS1%") do set "WE_PS1_SIZE=%%~zA"
if not defined WE_PS1_SIZE set "WE_PS1_SIZE=0"
if %WE_PS1_SIZE% LSS 1000 (
  echo ERROR: extracted PowerShell payload is unexpectedly small: %WE_PS1_SIZE% bytes.
  pause
  exit /b 4
)

"%WE_POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%WE_PS1%"
set "WE_RC=%ERRORLEVEL%"

del /q "%WE_PS1%" >nul 2>&1

echo.
if "%WE_RC%"=="0" (
  echo Fix session finished.
) else (
  echo Fix stopped with code %WE_RC%.
)
echo Report: "%WE_REPORT%"
echo.
pause
exit /b %WE_RC%

#PS1_BEGIN
$ErrorActionPreference='Stop'
$ExpectedExeSha    = '988a6a49f729cd3a20e91e82edd88b4d955be3757d66d8283e261f75b755ac22'
$ExpectedLoaderSha = '0e24a0270bdffa9edd68bbd7f7a2e8bafc3c232317fbda0cfabe23ea0407e3d9'
$ExpectedDummySha  = '77b4313c9a7498eb3a49a7b4228885f8080b61a369006888c29e5486a8533088'
$Root=$env:WE_ROOT
$Report=$env:WE_REPORT
$IniPath=Join-Path $Root 'WorldEditorFix.ini'
$DummyPath=Join-Path $Root 'dummy.w3m'

function Log([string]$s) {
    $s | Out-File -LiteralPath $Report -Encoding UTF8 -Append
    Write-Host $s
}
function Get-Sha256([string]$Path) {
    $sha=New-Object System.Security.Cryptography.SHA256CryptoServiceProvider
    $fs=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    try { return ([BitConverter]::ToString($sha.ComputeHash($fs))).Replace('-','').ToLowerInvariant() }
    finally { $fs.Close(); $sha.Clear() }
}
function Read-IniPath([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        $t=$line.Trim()
        if ($t.Length -eq 0 -or $t.StartsWith(';') -or $t.StartsWith('#')) { continue }
        if ($t.StartsWith('WorldEditorPath=',[StringComparison]::OrdinalIgnoreCase)) {
            return $t.Substring($t.IndexOf('=')+1).Trim().Trim('"')
        }
    }
    return ''
}
function Test-EditorPath([string]$p){
    if([String]::IsNullOrEmpty($p)){return $false}
    try{$p=[Environment]::ExpandEnvironmentVariables($p)}catch{}
    if(Test-Path -LiteralPath $p -PathType Container){
        $p=Join-Path $p '_retail_\x86_64\World Editor.exe'
    }
    return (Test-Path -LiteralPath $p -PathType Leaf)
}
function Resolve-WorldEditorPath{
    $configured=Read-IniPath $IniPath
    if(-not[String]::IsNullOrEmpty($configured)){
        $configured=[Environment]::ExpandEnvironmentVariables($configured)
        if(Test-Path -LiteralPath $configured -PathType Container){
            $candidate=Join-Path $configured '_retail_\x86_64\World Editor.exe'
            if(Test-Path -LiteralPath $candidate -PathType Leaf){return (Get-Item -LiteralPath $candidate).FullName}
        }
        if(Test-Path -LiteralPath $configured -PathType Leaf){return (Get-Item -LiteralPath $configured).FullName}
        throw ('Configured WorldEditorPath does not exist: '+$configured)
    }

    if($env:WAR3_ROOT){
        $candidate=Join-Path ([Environment]::ExpandEnvironmentVariables($env:WAR3_ROOT)) '_retail_\x86_64\World Editor.exe'
        if(Test-Path -LiteralPath $candidate -PathType Leaf){return (Get-Item -LiteralPath $candidate).FullName}
    }

    $reg=@(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Warcraft III',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Warcraft III',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Warcraft III'
    )
    foreach($k in $reg){
        try{
            if(Test-Path -LiteralPath $k){
                $v=Get-ItemProperty -LiteralPath $k -ErrorAction SilentlyContinue
                if($v -and $v.InstallLocation){
                    $candidate=Join-Path ([string]$v.InstallLocation) '_retail_\x86_64\World Editor.exe'
                    if(Test-Path -LiteralPath $candidate -PathType Leaf){return (Get-Item -LiteralPath $candidate).FullName}
                }
            }
        }catch{}
    }

    $candidates=@(
        'E:\Games\War3\Warcraft III\_retail_\x86_64\World Editor.exe',
        'C:\Games\War3\Warcraft III\_retail_\x86_64\World Editor.exe',
        'C:\Games\Warcraft III\_retail_\x86_64\World Editor.exe'
    )
    if($env:ProgramFiles){$candidates += (Join-Path $env:ProgramFiles 'Warcraft III\_retail_\x86_64\World Editor.exe')}
    ${pf86}=[Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if(-not[String]::IsNullOrEmpty(${pf86})){$candidates += (Join-Path ${pf86} 'Warcraft III\_retail_\x86_64\World Editor.exe')}
    foreach($c in $candidates){
        if(Test-Path -LiteralPath $c -PathType Leaf){return (Get-Item -LiteralPath $c).FullName}
    }
    throw 'World Editor.exe was not auto-detected. Set WorldEditorPath in WorldEditorFix.ini.'
}

$native=@'
using System;
using System.Runtime.InteropServices;
public static class WE24371Native {
 [DllImport("kernel32.dll",SetLastError=true)] public static extern IntPtr OpenProcess(uint a,bool inherit,int pid);
 [DllImport("kernel32.dll",SetLastError=true)] public static extern bool CloseHandle(IntPtr h);
 [DllImport("kernel32.dll",SetLastError=true)] public static extern bool ReadProcessMemory(IntPtr h,IntPtr a,byte[] b,int size,out IntPtr got);
 [DllImport("kernel32.dll",SetLastError=true)] public static extern bool WriteProcessMemory(IntPtr h,IntPtr a,byte[] b,int size,out IntPtr got);
 [DllImport("kernel32.dll")] public static extern uint GetTickCount();
 [DllImport("user32.dll")] public static extern bool IsHungAppWindow(IntPtr h);
 public static ulong DecodeObject(ulong raw) { unchecked { return raw ^ 0xEC3F4C87D9BA4DC6UL; } }
 public static uint DecodeTick(uint raw) { unchecked { return raw ^ 0x79578000U; } }
 public static uint EncodeTick(uint tick) { unchecked { return tick ^ 0x79578000U; } }
 public static uint Age(uint now,uint old) { unchecked { return now-old; } }
}
'@
Add-Type -TypeDefinition $native -Language CSharp

function Read-Remote([IntPtr]$h,[UInt64]$addr,[int]$size) {
    if ($addr -lt [UInt64]0x10000 -or $addr -ge [UInt64]0x0000800000000000) { throw ('invalid remote address 0x{0:X16}' -f $addr) }
    $buf=New-Object byte[] $size
    $got=[IntPtr]::Zero
    $ok=[WE24371Native]::ReadProcessMemory($h,[IntPtr]([Int64]$addr),$buf,$size,[ref]$got)
    if (-not $ok -or $got.ToInt64() -ne $size) {
        throw ('ReadProcessMemory addr=0x{0:X16} size={1} got={2} Win32={3}' -f $addr,$size,$got.ToInt64(),[Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
    return $buf
}
function ReadU32([IntPtr]$h,[UInt64]$addr) { return [BitConverter]::ToUInt32((Read-Remote $h $addr 4),0) }
function ReadU64([IntPtr]$h,[UInt64]$addr) { return [BitConverter]::ToUInt64((Read-Remote $h $addr 8),0) }
function Write-Remote4([IntPtr]$h,[UInt64]$addr,[UInt32]$value) {
    $buf=[BitConverter]::GetBytes($value)
    $got=[IntPtr]::Zero
    $ok=[WE24371Native]::WriteProcessMemory($h,[IntPtr]([Int64]$addr),$buf,4,[ref]$got)
    if (-not $ok -or $got.ToInt64() -ne 4) {
        throw ('WriteProcessMemory addr=0x{0:X16} wrote={1} Win32={2}' -f $addr,$got.ToInt64(),[Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
}
function Get-LoaderBase($p) {
    try {
        $p.Refresh()
        $m=$p.Modules | Where-Object {$_.ModuleName -ieq 'worldedit_loader.dll'} | Select-Object -First 1
        if ($null -eq $m) { return [UInt64]0 }
        return [UInt64]$m.BaseAddress.ToInt64()
    } catch { return [UInt64]0 }
}
function Probe-Timebase([IntPtr]$h,[UInt64]$base) {
    [UInt64]$glob=ReadU64 $h ($base+[UInt64]0x0216A878)
    [UInt64]$obj=[WE24371Native]::DecodeObject($glob)
    if ($obj -lt [UInt64]0x10000 -or $obj -ge [UInt64]0x0000800000000000) { throw ('object pointer not plausible 0x{0:X16}' -f $obj) }
    [UInt32]$v68=ReadU32 $h ($obj+[UInt64]0x68)
    [UInt32]$v70=ReadU32 $h ($obj+[UInt64]0x70)
    # TEST2 measured +68=0x0000004E, TEST3 measured +68=0x003C444E.
    # Only the low byte (0x4E) is invariant; the upper three bytes are mutable.
    # Require the stable +70 value AND the invariant byte, and keep the hash,
    # pointer, age, and second-read guards before any 4-byte memory write.
    if (($v68 -band [UInt32]255) -ne [UInt32]78 -or $v70 -ne [UInt32]2638180928) {
        throw ('object signature mismatch +68=0x{0:X8} (low-byte required 0x4E) +70=0x{1:X8}' -f $v68,$v70)
    }
    [UInt64]$addr=$obj+[UInt64]0x6C
    [UInt32]$raw=ReadU32 $h $addr
    [UInt32]$tick=[WE24371Native]::DecodeTick($raw)
    [UInt32]$now=[WE24371Native]::GetTickCount()
    [UInt32]$age=[WE24371Native]::Age($now,$tick)
    return New-Object PSObject -Property @{
        Obj=$obj; Addr=$addr; Raw=$raw; Tick=$tick; Now=$now; Age=$age; G=$glob; V68=$v68; V70=$v70
    }
}

'' | Out-File -LiteralPath $Report -Encoding UTF8
Log 'Warcraft III 3.0.1.24371 World Editor - Windows 7 FIX v1.2'
Log '===================================================================='
Log ('DATE={0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'))
Log ('PowerShell IntPtr.Size={0}' -f [IntPtr]::Size)
Log ('OS={0}' -f [Environment]::OSVersion.VersionString)
Log 'MODE=Old WE RC3 ShellOpen + war3 24371 timebase heartbeat; 4-byte process DATA only'
Log 'BATTLE_NET_DEPENDENCY=False'
if ([IntPtr]::Size -ne 8) { Log 'FATAL=64-bit PowerShell is required.'; exit 10 }
try { $ExePath=Resolve-WorldEditorPath }
catch { Log ('FATAL={0}' -f $_.Exception.Message); exit 11 }
$LoaderPath=Join-Path (Split-Path -Parent $ExePath) 'worldedit_loader.dll'
Log ('EXE={0}' -f $ExePath)
Log ('LOADER={0}' -f $LoaderPath)
Log ('DUMMY={0}' -f $DummyPath)
if (-not (Test-Path -LiteralPath $LoaderPath -PathType Leaf)) { Log 'FATAL=worldedit_loader.dll missing'; exit 12 }
if (-not (Test-Path -LiteralPath $DummyPath -PathType Leaf)) { Log 'FATAL=dummy.w3m missing'; exit 13 }
$exeSha=Get-Sha256 $ExePath
$loaderSha=Get-Sha256 $LoaderPath
$dummySha=Get-Sha256 $DummyPath
Log ('WorldEditor_SHA256={0}' -f $exeSha)
Log ('worldedit_loader_SHA256={0}' -f $loaderSha)
Log ('dummy_SHA256={0}' -f $dummySha)
Log ('HASH_GUARD_PASS={0}' -f ($exeSha -eq $ExpectedExeSha -and $loaderSha -eq $ExpectedLoaderSha -and $dummySha -eq $ExpectedDummySha))
if ($exeSha -ne $ExpectedExeSha -or $loaderSha -ne $ExpectedLoaderSha -or $dummySha -ne $ExpectedDummySha) {
    Log 'FATAL=Hash mismatch: exactly version 3.0.1.24371 is required. No writes.'
    exit 14
}
$existing=@(Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.ProcessName -eq 'World Editor'})
if ($existing.Count -gt 0) { Log 'FATAL=Close the existing World Editor before starting this test.'; exit 15 }
Log ('SHELL_OPEN_TARGET="{0}"' -f $DummyPath)
try { Start-Process -FilePath $DummyPath }
catch { Log ('FATAL=ShellOpen failed: {0}' -f $_.Exception.Message); exit 17 }
$p=$null
$deadline=(Get-Date).AddSeconds(60)
while ((Get-Date) -lt $deadline) {
    $candidates=@(Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.ProcessName -eq 'World Editor'})
    foreach ($cand in $candidates) {
        $path=''
        try { $path=[string]$cand.MainModule.FileName } catch {}
        if (-not [String]::IsNullOrEmpty($path) -and $path -ieq $ExePath) { $p=$cand; break }
    }
    if ($null -ne $p) { break }
    Start-Sleep -Milliseconds 100
}
if ($null -eq $p) { Log 'FATAL=No matching World Editor process within 60s.'; exit 18 }
Log ('ATTACHED_PID={0}' -f $p.Id)
$ACCESS=[UInt32](0x0400 -bor 0x0010 -bor 0x0020 -bor 0x0008)
$ph=[IntPtr]::Zero
$deadline=(Get-Date).AddSeconds(10)
while ((Get-Date) -lt $deadline -and $ph -eq [IntPtr]::Zero) {
    $ph=[WE24371Native]::OpenProcess($ACCESS,$false,$p.Id)
    if ($ph -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 20 }
}
if ($ph -eq [IntPtr]::Zero) { Log ('FATAL=OpenProcess failed Win32={0}' -f [Runtime.InteropServices.Marshal]::GetLastWin32Error()); exit 19 }
try {
    $sw=[Diagnostics.Stopwatch]::StartNew()
    $loaderBase=[UInt64]0
    $seen=$false
    $writes=0
    $lastStateLog=[long]-5000
    $lastErrorLog=[long]-10000
    $hangStart=[long]-1
    $lastHungLog=[long]-30000
    $probeFailCount=0
    $signatureLogged=$false
    Log 'TIMEBASE_GUARD_WAIT_BEGIN=True'
    while ($true) {
        $ms=$sw.ElapsedMilliseconds
        $p.Refresh()
        if ($p.HasExited) { Log ('PROCESS_EXIT=True t={0}ms writes={1}' -f $ms,$writes); break }
        if ($loaderBase -eq [UInt64]0) {
            $loaderBase=Get-LoaderBase $p
            if ($loaderBase -ne [UInt64]0) { Log ('WORLD_EDIT_LOADER_BASE=0x{0:X16}' -f $loaderBase) }
        }
        if ($loaderBase -ne [UInt64]0) {
            try {
                $d=Probe-Timebase $ph $loaderBase
                $probeFailCount=0
                if (-not $signatureLogged) {
                    Log ('OBJECT_SIGNATURE_ACCEPTED=True object68=0x{0:X8} low68=0x{1:X2} object70=0x{2:X8}' -f $d.V68,($d.V68 -band [UInt32]255),$d.V70)
                    $signatureLogged=$true
                }
                [UInt64]$age=[UInt64]$d.Age
                if ($ms-$lastStateLog -ge 5000) {
                    Log ('TIMEBASE_STATE t={0}ms obj=0x{1:X16} raw6C=0x{2:X8} decodedTick=0x{3:X8} currentTick=0x{4:X8} ageMs={5} writes={6} object68=0x{7:X8}' -f $ms,$d.Obj,$d.Raw,$d.Tick,$d.Now,$age,$writes,$d.V68)
                    $lastStateLog=$ms
                }
                if ($age -ge [UInt64]10000) {
                    if ($age -gt [UInt64]120000) {
                        if ($ms-$lastErrorLog -ge 10000) { Log ('TIMEBASE_GUARD_REJECT=age-out-of-range ageMs={0}; no write' -f $age); $lastErrorLog=$ms }
                    } else {
                        # Double-check that the pointer and original value have not changed before writing.
                        $pre=Probe-Timebase $ph $loaderBase
                        if ($pre.Obj -ne $d.Obj -or $pre.G -ne $d.G -or $pre.Raw -ne $d.Raw -or $pre.V68 -ne $d.V68 -or $pre.V70 -ne $d.V70 -or [UInt64]$pre.Age -lt [UInt64]10000 -or [UInt64]$pre.Age -gt [UInt64]120000) {
                            Log ('TIMEBASE_GUARD_RETRY=object-or-value-changed t={0}ms' -f $ms)
                        } else {
                            [UInt32]$freshNow=[WE24371Native]::GetTickCount()
                            [UInt32]$freshRaw=[WE24371Native]::EncodeTick($freshNow)
                            if ([WE24371Native]::DecodeTick($freshRaw) -ne $freshNow) { throw 'encoder self-test failed' }
                            Write-Remote4 $ph $pre.Addr $freshRaw
                            [UInt32]$verifyRaw=ReadU32 $ph $pre.Addr
                            if ($verifyRaw -ne $freshRaw) {
                                # Another legitimate writer could update the timestamp at the same time.
                                $verify=Probe-Timebase $ph $loaderBase
                                if ($verify.Obj -ne $pre.Obj -or [UInt64]$verify.Age -gt [UInt64]10000) {
                                    throw ('readback mismatch at 0x{0:X16} raw=0x{1:X8}' -f $pre.Addr,$verifyRaw)
                                }
                                Log ('TIMEBASE_READBACK_CONCURRENT_UPDATE=True t={0}ms' -f $ms)
                            }
                            $writes++
                            Log ('TIMEBASE_REFRESH_APPLIED=True t={0}ms obj=0x{1:X16} addr=0x{2:X16} oldRaw=0x{3:X8} newRaw=0x{4:X8} oldAgeMs={5} writes={6} bytes=4' -f $ms,$pre.Obj,$pre.Addr,$pre.Raw,$freshRaw,[UInt64]$pre.Age,$writes)
                            if (-not $seen) {
                                $seen=$true
                                Write-Host 'WORLD EDITOR WIN7 FIX ACTIVE - USE THE EDITOR NORMALLY' -ForegroundColor Green
                                Log 'TIMEBASE_FIX_READY=True'
                            }
                        }
                    }
                }
            } catch {
                $probeFailCount++
                if ($ms-$lastErrorLog -ge 10000) {
                    Log ('TIMEBASE_PROBE_ERROR t={0}ms count={1} error="{2}"' -f $ms,$probeFailCount,$_.Exception.Message)
                    $lastErrorLog=$ms
                }
            }
        }
        # The detector records hangs only. It never terminates the editor or stops the heartbeat.
        try {
            $hwnd=$p.MainWindowHandle
            if ($hwnd -ne [IntPtr]::Zero) {
                $hung=[WE24371Native]::IsHungAppWindow($hwnd)
                if ($hung) {
                    if ($hangStart -lt 0) { $hangStart=$ms; Log ('UI_HUNG_BEGIN=True t={0}ms' -f $ms) }
                    if ($ms-$lastHungLog -ge 30000) {
                        Log ('UI_HUNG_OBSERVED=True t={0}ms hungDurationMs={1} heartbeatWrites={2}' -f $ms,($ms-$hangStart),$writes)
                        $lastHungLog=$ms
                    }
                } else {
                    if ($hangStart -ge 0) { Log ('UI_HUNG_ENDED=True t={0}ms durationMs={1}' -f $ms,($ms-$hangStart)); $hangStart=-1 }
                }
            }
        } catch {}
        if (-not $seen -and $ms -ge 90000 -and $writes -eq 0) {
            Log 'FATAL=No guarded timebase refresh became available within 90s; no writes.'
            exit 21
        }
        Start-Sleep -Milliseconds 250
    }
    Log ('RESULT fixActivated={0} writes={1} elapsedMs={2}' -f $seen,$writes,$sw.ElapsedMilliseconds)
    Log 'NO_DISK_PATCH=True; NO_THREAD_TERMINATION=True'
}
finally { if ($ph -ne [IntPtr]::Zero) { [void][WE24371Native]::CloseHandle($ph) } }
exit 0
