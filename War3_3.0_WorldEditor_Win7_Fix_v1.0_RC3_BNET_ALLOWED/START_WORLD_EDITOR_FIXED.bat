@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>&1
color 0B
title Warcraft III 3.0 World Editor - Windows 7 Fix v1.0 RC3

echo ================================================================
echo Warcraft III 3.0 World Editor - Windows 7 Fix v1.0 RC3
echo ================================================================
echo One-click dummy-map SHELL OPEN + automatic guarded C256 correction.
echo.
echo This release candidate:
echo   - opens bundled dummy.w3m through the Windows file association
echo   - opens World Editor through dummy.w3m, not through the Battle.net launcher
echo   - verifies exact supported hashes
echo   - waits for the exact C256 +0x707 mismatch
echo   - changes exactly 4 bytes of process-local DATA
echo   - modifies no Warcraft III file on disk
echo.
echo Close any already-running World Editor first. Battle.net may remain open.
echo.

set "WE_ROOT=%~dp0"
set "WE_REPORT=%~dp0WORLD_EDITOR_WIN7_FIX_v1.0_RC3.txt"
set "WE_PS1=%TEMP%\WE300_W7_FIX_%RANDOM%_%RANDOM%.ps1"
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
$ErrorActionPreference = 'Stop'

$ExpectedExeSha    = '543c089d92307594341d9b655d81a9f5974b9fd73d9ad3952114b793851d848f'
$ExpectedLoaderSha = '21d83d9db2a6416c0c03361ff2b847ade879318eb0ad406a88799355762987dd'
$ExpectedDummySha  = '77b4313c9a7498eb3a49a7b4228885f8080b61a369006888c29e5486a8533088'

$Root    = $env:WE_ROOT
$Report  = $env:WE_REPORT
$IniPath = Join-Path $Root 'WorldEditorFix.ini'
$DummyPath = Join-Path $Root 'dummy.w3m'

function Log([string]$s) {
    $s | Out-File -LiteralPath $Report -Encoding UTF8 -Append
    Write-Host $s
}

function Get-Sha256([string]$Path) {
    $sha = New-Object System.Security.Cryptography.SHA256CryptoServiceProvider
    $fs = [IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    try {
        $hash = $sha.ComputeHash($fs)
        return ([BitConverter]::ToString($hash)).Replace('-','').ToLowerInvariant()
    } finally {
        $fs.Close()
        $sha.Clear()
    }
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

function Resolve-WorldEditorPath {
    $configured=Read-IniPath $IniPath
    if (-not [String]::IsNullOrEmpty($configured)) {
        $configured=[Environment]::ExpandEnvironmentVariables($configured)
        if (Test-Path -LiteralPath $configured -PathType Container) {
            $candidate=Join-Path $configured '_retail_\x86_64\World Editor.exe'
            if (Test-Path -LiteralPath $candidate) { return (Get-Item -LiteralPath $candidate).FullName }
        }
        if (Test-Path -LiteralPath $configured -PathType Leaf) {
            return (Get-Item -LiteralPath $configured).FullName
        }
        throw ('Configured WorldEditorPath does not exist: {0}' -f $configured)
    }

    $candidates=@()
    if ($env:ProgramFiles) {
        $candidates += (Join-Path $env:ProgramFiles 'Warcraft III\_retail_\x86_64\World Editor.exe')
    }
    ${pf86}=[Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if (-not [String]::IsNullOrEmpty(${pf86})) {
        $candidates += (Join-Path ${pf86} 'Warcraft III\_retail_\x86_64\World Editor.exe')
    }
    $candidates += 'C:\Games\Warcraft III\_retail_\x86_64\World Editor.exe'

    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c -PathType Leaf) { return (Get-Item -LiteralPath $c).FullName }
    }
    throw 'World Editor.exe was not auto-detected. Set WorldEditorPath in WorldEditorFix.ini.'
}

$native = @'
using System;
using System.Runtime.InteropServices;

public static class WEFixWin32
{
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(uint access, bool inheritHandle, int processId);

    [DllImport("kernel32.dll", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CloseHandle(IntPtr hObject);

    [DllImport("kernel32.dll", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr address, byte[] buffer, int size, out IntPtr bytesRead);

    [DllImport("kernel32.dll", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr address, byte[] buffer, int size, out IntPtr bytesWritten);

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool IsHungAppWindow(IntPtr hWnd);
}
'@
Add-Type -TypeDefinition $native -Language CSharp

function Read-Remote([IntPtr]$h,[UInt64]$addr,[int]$size) {
    if ($addr -lt [UInt64]0x10000) { throw ('invalid remote address 0x{0:X16}' -f $addr) }
    $buf = New-Object byte[] $size
    $got = [IntPtr]::Zero
    $ok = [WEFixWin32]::ReadProcessMemory($h,[IntPtr]([Int64]$addr),$buf,$size,[ref]$got)
    if (-not $ok -or $got.ToInt64() -ne $size) {
        throw ('ReadProcessMemory failed at 0x{0:X16} size={1} got={2} Win32={3}' -f $addr,$size,$got.ToInt64(),[Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
    return $buf
}

function Write-Remote4([IntPtr]$h,[UInt64]$addr,[UInt32]$value) {
    $buf=[BitConverter]::GetBytes($value)
    $wrote=[IntPtr]::Zero
    $ok=[WEFixWin32]::WriteProcessMemory($h,[IntPtr]([Int64]$addr),$buf,4,[ref]$wrote)
    if (-not $ok -or $wrote.ToInt64() -ne 4) {
        throw ('WriteProcessMemory failed at 0x{0:X16} wrote={1} Win32={2}' -f $addr,$wrote.ToInt64(),[Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
}

function C256-Expected([UInt32]$g210c0b0) {
    [UInt64]$M=[UInt64]4294967295
    [UInt64]$a4=(([UInt64]$g210c0b0+[UInt64]3395345826)-band $M)
    [UInt64]$invA4=($M -bxor $a4)
    [UInt64]$a8=((($invA4 -band [UInt64]1950337290)*11)-band $M)
    [UInt64]$ac=((($a4 -bor [UInt64]1950337290)*11)-band $M)
    [UInt64]$b0=(($a4 -bxor [UInt64]1950337290)-band $M)
    [UInt64]$b4=((($a4 -band [UInt64]2344630005)*9)-band $M)
    [UInt64]$b8=($a4 -band [UInt64]1950337290)
    [UInt64]$bc=(($ac+[UInt64]85899345920-(($b8*11)+$b4+$b0))-band $M)
    [UInt64]$x=(($bc+[UInt64]4294967296-$a8)-band $M)
    [UInt64]$c0=(($x -bxor [UInt64]3494960644)-band $M)
    [UInt64]$c4=(($x -bxor [UInt64]1129164038)-band $M)
    [UInt64]$c8=(($c4+[UInt64]1663572473)-band $M)
    [UInt64]$cc=(([UInt64]187680546+[UInt64]4294967296-$x)-band $M)
    [UInt64]$expected=((($cc -bxor $c4 -bxor $c8)+$c0+$a4)-band $M)
    return [UInt32]$expected
}

function Get-LoaderBase($p) {
    try {
        $p.Refresh()
        $m = $p.Modules | Where-Object { $_.ModuleName -ieq 'worldedit_loader.dll' } | Select-Object -First 1
        if ($null -eq $m) { return [UInt64]0 }
        return [UInt64]$m.BaseAddress.ToInt64()
    } catch {
        return [UInt64]0
    }
}

function Probe-C256([IntPtr]$h,[UInt64]$base) {
    [UInt64]$raw = [BitConverter]::ToUInt64((Read-Remote $h ($base+[UInt64]0x021BCA68) 8),0)
    [byte[]]$kb=[byte[]](0x6A,0xD6,0x77,0x21,0xB7,0xD0,0x9A,0xD1)
    [UInt64]$key=[BitConverter]::ToUInt64($kb,0)
    [UInt64]$obj=($raw -bxor $key)

    if ($obj -lt [UInt64]0x10000 -or $obj -ge [UInt64]0x0000800000000000) {
        return New-Object PSObject -Property @{
            Valid=$false; Raw=$raw; Obj=$obj; Actual=[UInt32]0; Expected=[UInt32]0; Delta=[UInt32]0; G=[UInt32]0; FatalGlobal=[UInt32]0
        }
    }

    [UInt32]$actual=[BitConverter]::ToUInt32((Read-Remote $h ($obj+[UInt64]0x20) 4),0)
    [UInt32]$g=[BitConverter]::ToUInt32((Read-Remote $h ($base+[UInt64]0x0210C0B0) 4),0)
    [UInt32]$expected=C256-Expected $g
    [UInt64]$M=[UInt64]4294967295
    [UInt32]$delta=[UInt32]((([UInt64]$expected+[UInt64]4294967296-[UInt64]$actual)-band $M))
    [UInt32]$fatalGlobal=[BitConverter]::ToUInt32((Read-Remote $h ($base+[UInt64]0x0215F24C) 4),0)

    return New-Object PSObject -Property @{
        Valid=$true; Raw=$raw; Obj=$obj; Actual=$actual; Expected=$expected; Delta=$delta; G=$g; FatalGlobal=$fatalGlobal
    }
}

'' | Out-File -LiteralPath $Report -Encoding UTF8
Log 'Warcraft III 3.0 World Editor - Windows 7 Fix v1.0 RC3'
Log '================================================================='
Log ('DATE={0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'))
Log ('PowerShell IntPtr.Size={0}' -f [IntPtr]::Size)
Log ('OS={0}' -f [Environment]::OSVersion.VersionString)

if ([IntPtr]::Size -ne 8) { Log 'FATAL=This test must run under 64-bit PowerShell.'; exit 10 }

try { $ExePath=Resolve-WorldEditorPath }
catch { Log ('FATAL={0}' -f $_.Exception.Message); exit 11 }

$LoaderPath=Join-Path (Split-Path -Parent $ExePath) 'worldedit_loader.dll'
Log ('EXE={0}' -f $ExePath)
Log ('LOADER={0}' -f $LoaderPath)
Log ('DUMMY={0}' -f $DummyPath)
Log 'MODE=one-click Windows shell-open of bundled dummy.w3m / automatic guarded 4-byte C256 correction'

if (-not (Test-Path -LiteralPath $LoaderPath -PathType Leaf)) { Log 'FATAL=worldedit_loader.dll not found next to World Editor.exe.'; exit 12 }
if (-not (Test-Path -LiteralPath $DummyPath -PathType Leaf)) { Log 'FATAL=dummy.w3m not found next to this BAT.'; exit 13 }

$exeSha=Get-Sha256 $ExePath
$loaderSha=Get-Sha256 $LoaderPath
$dummySha=Get-Sha256 $DummyPath
Log ('WorldEditor_SHA256={0}' -f $exeSha)
Log ('WorldEditor_SHA_MATCH={0}' -f ($exeSha -eq $ExpectedExeSha))
Log ('worldedit_loader_SHA256={0}' -f $loaderSha)
Log ('worldedit_loader_SHA_MATCH={0}' -f ($loaderSha -eq $ExpectedLoaderSha))
Log ('dummy_SHA256={0}' -f $dummySha)
Log ('dummy_SHA_MATCH={0}' -f ($dummySha -eq $ExpectedDummySha))

if ($exeSha -ne $ExpectedExeSha -or $loaderSha -ne $ExpectedLoaderSha -or $dummySha -ne $ExpectedDummySha) {
    Log 'FATAL=Hash mismatch. This TEST is intentionally build-specific.'
    exit 14
}

$existingWE=@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq 'World Editor' })
if ($existingWE.Count -gt 0) {
    Log 'FATAL=World Editor is already running. Close it before this one-click test.'
    exit 15
}
$existingBN=@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq 'Battle.net' })
Log ('BATTLE_NET_ALREADY_RUNNING={0}' -f ($existingBN.Count -gt 0))
Log 'PREFLIGHT_OK=True'

$beforeIds=@{}
@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq 'World Editor' }) | ForEach-Object { $beforeIds[$_.Id]=$true }

Log ('SHELL_OPEN_TARGET="{0}"' -f $DummyPath)
try {
    Start-Process -FilePath $DummyPath
} catch {
    Log ('FATAL=Windows shell could not open dummy.w3m: {0}' -f $_.Exception.Message)
    exit 17
}

$p=$null
$attachDeadline=(Get-Date).AddSeconds(60)
while ((Get-Date) -lt $attachDeadline) {
    $candidates=@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -eq 'World Editor' })
    foreach ($cand in $candidates) {
        if ($beforeIds.ContainsKey($cand.Id)) { continue }
        $path=$null
        try { $path=[string]$cand.MainModule.FileName } catch {}
        if (-not [String]::IsNullOrEmpty($path) -and $path -ieq $ExePath) {
            $p=$cand
            break
        }
    }
    if ($null -ne $p) { break }
    Start-Sleep -Milliseconds 100
}

if ($null -eq $p) {
    Log 'FATAL=No validated World Editor process appeared after shell-opening dummy.w3m.'
    exit 18
}
Log ('ATTACHED_PID={0}' -f $p.Id)
Log ('ATTACHED_PROCESS_PATH={0}' -f $ExePath)

$PROCESS_QUERY_INFORMATION=0x0400
$PROCESS_VM_READ=0x0010
$PROCESS_VM_WRITE=0x0020
$PROCESS_VM_OPERATION=0x0008

$ph=[IntPtr]::Zero
$deadline=(Get-Date).AddSeconds(10)
while ((Get-Date) -lt $deadline -and $ph -eq [IntPtr]::Zero) {
    try {
        $p.Refresh()
        if ($p.HasExited) { break }
        $ph=[WEFixWin32]::OpenProcess(($PROCESS_QUERY_INFORMATION -bor $PROCESS_VM_READ -bor $PROCESS_VM_WRITE -bor $PROCESS_VM_OPERATION),$false,$p.Id)
    } catch {}
    if ($ph -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 20 }
}
if ($ph -eq [IntPtr]::Zero) {
    try { $p.Refresh() } catch {}
    if ($p.HasExited) {
        Log ('FATAL=World Editor process exited after shell-open. ExitCode={0}' -f $p.ExitCode)
    } else {
        Log ('FATAL=OpenProcess failed Win32={0}' -f [Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
    exit 18
}

try {
    $loaderBase=[UInt64]0
    $patched=$false
    $patchAddr=[UInt64]0
    $patchTimeMs=[long]-1
    $sw=[Diagnostics.Stopwatch]::StartNew()
    $lastReadError=''

    Log 'AUTO_PATCH_WAIT_BEGIN=True'

    while ($sw.ElapsedMilliseconds -lt 120000 -and -not $patched) {
        try {
            $p.Refresh()
            if ($p.HasExited) {
                Log ('FATAL=World Editor exited before patch. ExitCode={0} t={1}ms' -f $p.ExitCode,$sw.ElapsedMilliseconds)
                exit 19
            }
        } catch {}

        if ($loaderBase -eq 0) {
            $loaderBase=Get-LoaderBase $p
            if ($loaderBase -ne 0) {
                Log ('WORLD_EDIT_LOADER_BASE=0x{0:X16} t={1}ms' -f $loaderBase,$sw.ElapsedMilliseconds)
            } else {
                Start-Sleep -Milliseconds 10
                continue
            }
        }

        try {
            $r=Probe-C256 $ph $loaderBase
            if ($r.Valid) {
                $guard = ($r.Actual -eq [UInt32]0x0E210193 -and
                          $r.Expected -eq [UInt32]0x0E21089A -and
                          $r.Delta -eq [UInt32]0x00000707 -and
                          $r.FatalGlobal -eq [UInt32]0x5F53F671)

                if ($guard) {
                    Log ('C256_MATCH_FOUND t={0}ms obj=0x{1:X16} actual=0x{2:X8} expected=0x{3:X8} delta=0x{4:X8} g=0x{5:X8} fatalGlobal=0x{6:X8}' -f $sw.ElapsedMilliseconds,$r.Obj,$r.Actual,$r.Expected,$r.Delta,$r.G,$r.FatalGlobal)
                    $patchAddr=$r.Obj+[UInt64]0x20
                    Write-Remote4 $ph $patchAddr $r.Expected
                    $v=Probe-C256 $ph $loaderBase
                    $patched=($v.Valid -and $v.Obj -eq $r.Obj -and $v.Actual -eq $r.Expected -and $v.Delta -eq [UInt32]0)
                    if (-not $patched) {
                        Log 'FATAL=4-byte write did not verify exactly. Restart World Editor before retrying.'
                        exit 21
                    }
                    $patchTimeMs=$sw.ElapsedMilliseconds
                    Log ('C256_PATCH_APPLIED=True t={0}ms addr=0x{1:X16} old=0x{2:X8} new=0x{3:X8} bytes=4 codePatched=False' -f $patchTimeMs,$patchAddr,$r.Actual,$r.Expected)
                    Log ('POSTPATCH_PROBE actual=0x{0:X8} expected=0x{1:X8} delta=0x{2:X8}' -f $v.Actual,$v.Expected,$v.Delta)
                    break
                }
            }
        } catch {
            $msg=$_.Exception.Message
            if ($msg -ne $lastReadError) {
                Log ('WAIT_PROBE_READ_ERROR t={0}ms error={1}' -f $sw.ElapsedMilliseconds,$msg)
                $lastReadError=$msg
            }
        }

        Start-Sleep -Milliseconds 5
    }

    if (-not $patched) {
        Log 'FATAL=Exact supported C256 mismatch did not appear within 120 seconds. No memory was written.'
        exit 22
    }

    Write-Host ''
    Write-Host '===============================================================' -ForegroundColor Green
    Write-Host 'WORLD EDITOR FIX ACTIVE' -ForegroundColor Green
    Write-Host 'dummy.w3m was opened through Windows shell association and the guarded 4-byte fix verified.'
    Write-Host 'You can now use the editor normally or open another map in this process.'
    Write-Host 'This window stays open while World Editor runs so the validated state can be monitored.'
    Write-Host '===============================================================' -ForegroundColor Green
    Write-Host ''

    $mainHwnd=[IntPtr]::Zero
    $lastHeartbeat=[long]-5000
    $patchLost=$false
    $hangCount=0

    while ($true) {
        try {
            $p.Refresh()
            if ($p.HasExited) {
                Log ('PROCESS_EXIT=True exitCode={0} t={1}ms' -f $p.ExitCode,$sw.ElapsedMilliseconds)
                break
            }
            if ($p.MainWindowHandle -ne [IntPtr]::Zero) { $mainHwnd=$p.MainWindowHandle }
        } catch {}

        try {
            $cur=Probe-C256 $ph $loaderBase
            if ($cur.Valid -and $cur.Actual -ne $cur.Expected -and -not $patchLost) {
                $patchLost=$true
                Log ('PATCH_NO_LONGER_PRESENT=True t={0}ms actual=0x{1:X8} expected=0x{2:X8} delta=0x{3:X8}' -f $sw.ElapsedMilliseconds,$cur.Actual,$cur.Expected,$cur.Delta)
            }
        } catch {}

        $hung=$false
        if ($mainHwnd -ne [IntPtr]::Zero) {
            try { $hung=[WEFixWin32]::IsHungAppWindow($mainHwnd) } catch {}
        }
        if ($hung) { $hangCount++ } else { $hangCount=0 }

        if (($sw.ElapsedMilliseconds-$lastHeartbeat) -ge 5000) {
            $lastHeartbeat=$sw.ElapsedMilliseconds
            Log ('HEARTBEAT t={0}ms IsHung={1} patchLost={2}' -f $sw.ElapsedMilliseconds,$hung,$patchLost)
        }

        if ($hangCount -ge 5) {
            Log ('HANG_DETECTED=True t={0}ms' -f $sw.ElapsedMilliseconds)
            try {
                $final=Probe-C256 $ph $loaderBase
                Log ('FINAL_PROBE valid={0} actual=0x{1:X8} expected=0x{2:X8} delta=0x{3:X8} fatalGlobal=0x{4:X8}' -f $final.Valid,$final.Actual,$final.Expected,$final.Delta,$final.FatalGlobal)
            } catch {
                Log ('FINAL_PROBE_ERROR={0}' -f $_.Exception.Message)
            }
            break
        }

        Start-Sleep -Milliseconds 100
    }

    Log ('RESULT patchApplied={0} patchTimeMs={1} patchLost={2} elapsedMs={3}' -f $patched,$patchTimeMs,$patchLost,$sw.ElapsedMilliseconds)
    Log 'NOTE=Exactly one guarded 4-byte DATA write was used; no code and no Warcraft III file on disk was modified.'
    Log 'NOTE=The process-local change disappears when World Editor exits.'
}
finally {
    if ($ph -ne [IntPtr]::Zero) { [void][WEFixWin32]::CloseHandle($ph) }
}

exit 0
