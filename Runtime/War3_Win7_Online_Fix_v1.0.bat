@echo off
setlocal EnableExtensions
set "SELF=%~f0"
set "OUT=%~dp0WAR3_WIN7_ONLINE_FIX_v1.0.txt"
set "PS1=%TEMP%\WAR3_WIN7_ONLINE_FIX_v1_0_%RANDOM%_%RANDOM%.ps1"
title Warcraft III 3.0 - Windows 7 Online Fix v1.0

echo.
echo Warcraft III 3.0 - Windows 7 ONLINE FIX v1.0
echo ==========================================================
echo Portable compatibility fix for Warcraft III 3.0.0.24268 on Windows 7 x64.
echo.
echo What it does:
echo   - auto-detects Warcraft III and Battle.net install paths
echo   - launches Warcraft III through the official Battle.net launcher
echo   - translates ClientSdk CERT_CHAIN_ENGINE_CONFIG cbSize 88 to a stack-local 80-byte Win7 copy
echo   - after certificate call #1, applies the guarded C256 +0x707 4-byte process-local correction
echo   - after certificate call #2, restores the original ClientSdk IAT and frees the startup hook page
echo   - after READY, keeps only the light v3s read-only 4-byte ~1 ms performance pulse
echo   - exits automatically shortly after Warcraft closes
echo.
echo Safety guards:
echo   - exact ClientSdk.dll SHA-256 required
echo   - exact war3_loader.dll SHA-256 required
echo   - C256 write occurs only for the exact historical +0x707 mismatch
echo   - no Warcraft code bytes are patched
echo   - no Event API is hooked or signaled
echo.
echo BEFORE RUNNING: Warcraft closed, Battle.net signed in, VPN/Hide.me off.
echo Install drive/path does not matter; the fix auto-detects it.
echo.

tasklist /FI "IMAGENAME eq Warcraft III.exe" 2>NUL | find /I "Warcraft III.exe" >NUL
if not errorlevel 1 (
  echo ERROR: Warcraft III is already running. Close it, then rerun this BAT.
  pause
  exit /b 1
)

"%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "$c=Get-Content -LiteralPath $env:SELF; $i=[Array]::IndexOf($c,'#===RELEASE_PS==='); if($i -lt 0){exit 91}; $c[($i+1)..($c.Length-1)] | Set-Content -LiteralPath $env:PS1 -Encoding UTF8"
if errorlevel 1 (
  echo ERROR extracting PowerShell payload.
  pause
  exit /b 1
)

"%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "RC=%ERRORLEVEL%"
del /q "%PS1%" >nul 2>&1

if not "%RC%"=="0" (
  echo.
  echo The fix stopped with an error. See:
  echo   %OUT%
  echo.
  pause
  exit /b %RC%
)

exit /b 0

#===RELEASE_PS===
$ErrorActionPreference='Stop'
$Out=$env:OUT
$ExpectedClientSdkSha='3a8762f6641f39da8099009adccfe1b2f9aa9613defe98273e38341de500b10e'
$ExpectedWar3LoaderSha='e32431e26f58d1201be3f48baed485114227864d8c6b871eae8e9528241ec8e9'
$L=New-Object System.Collections.Generic.List[string]

function O([string]$s=''){
    [void]$L.Add($s)
    Write-Host $s
}
function Save{
    $L | Set-Content -LiteralPath $Out -Encoding UTF8
}
function Sha256([string]$p){
    $sha=New-Object Security.Cryptography.SHA256Managed
    try{
        $fs=[IO.File]::OpenRead($p)
        try{$h=$sha.ComputeHash($fs)}finally{$fs.Close()}
        return (($h | ForEach-Object {$_.ToString('x2')}) -join '')
    }finally{$sha.Dispose()}
}
function U16($b,[int]$o){[BitConverter]::ToUInt16($b,$o)}
function U32($b,[int]$o){[BitConverter]::ToUInt32($b,$o)}
function U64($b,[int]$o){[BitConverter]::ToUInt64($b,$o)}
function I64FromU64([uint64]$v){return [BitConverter]::ToInt64([BitConverter]::GetBytes([uint64]$v),0)}
function CStr($b,[int]$o){
    $e=$o
    while($e-lt$b.Length -and $b[$e]-ne0){$e++}
    return [Text.Encoding]::ASCII.GetString($b,$o,$e-$o)
}
function RvaToOff($sections,[uint32]$rva){
    foreach($s in $sections){
        $span=[Math]::Max([uint32]$s.VSize,[uint32]$s.RawSize)
        if($rva-ge$s.VA -and $rva-lt($s.VA+$span)){
            return [int]($s.RawPtr+($rva-$s.VA))
        }
    }
    return -1
}
function FindImportIatRva([string]$path,[string]$wantDll,[string]$wantFn){
    $b=[IO.File]::ReadAllBytes($path)
    $pe=[int](U32 $b 0x3c)
    if((U32 $b $pe)-ne0x00004550){throw 'Invalid PE signature.'}
    $nsec=U16 $b ($pe+6)
    $szopt=U16 $b ($pe+20)
    $opt=$pe+24
    if((U16 $b $opt)-ne0x20b){throw 'ClientSdk is not PE32+ x64.'}
    $dd=$opt+0x70
    $importRva=U32 $b ($dd+8)
    $sections=@()
    $secOff=$opt+$szopt
    for($i=0;$i-lt$nsec;$i++){
        $o=$secOff+$i*40
        $sections+=New-Object PSObject -Property @{
            VSize=(U32 $b ($o+8)); VA=(U32 $b ($o+12));
            RawSize=(U32 $b ($o+16)); RawPtr=(U32 $b ($o+20))
        }
    }
    $impOff=RvaToOff $sections $importRva
    if($impOff-lt0){throw 'Cannot map import directory.'}
    for($di=0;$di-lt1024;$di++){
        $d=$impOff+$di*20
        $oft=U32 $b $d
        $nameRva=U32 $b ($d+12)
        $ft=U32 $b ($d+16)
        if($oft-eq0 -and $nameRva-eq0 -and $ft-eq0){break}
        $nameOff=RvaToOff $sections $nameRva
        if($nameOff-lt0){continue}
        $dll=CStr $b $nameOff
        if($dll-ine$wantDll){continue}
        if($oft-ne0){$thunkRva=$oft}else{$thunkRva=$ft}
        $thunkOff=RvaToOff $sections $thunkRva
        for($ti=0;$ti-lt8192;$ti++){
            $to=$thunkOff+$ti*8
            $v=U64 $b $to
            if($v-eq0){break}
            if(($v-band0x8000000000000000)-ne0){continue}
            $hnOff=RvaToOff $sections ([uint32]$v)
            if($hnOff-lt0){continue}
            $fn=CStr $b ($hnOff+2)
            if($fn-ceq$wantFn){return [uint32]($ft+$ti*8)}
        }
    }
    throw ($wantDll+'!'+$wantFn+' IAT entry not found.')
}

$native=@'
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;
using System.Threading;

public static class W3ReleaseNative
{
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(uint access, bool inheritHandle, int processId);

    [DllImport("kernel32.dll", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool ReadProcessMemory(IntPtr hProcess, IntPtr address, byte[] buffer, int size, out IntPtr bytesRead);

    [DllImport("kernel32.dll", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr address, byte[] buffer, int size, out IntPtr bytesWritten);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr address, IntPtr size, uint allocationType, uint protect);

    [DllImport("kernel32.dll", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool VirtualFreeEx(IntPtr hProcess, IntPtr address, IntPtr size, uint freeType);

    [DllImport("kernel32.dll", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool VirtualProtectEx(IntPtr hProcess, IntPtr address, IntPtr size, uint newProtect, out uint oldProtect);

    [DllImport("kernel32.dll", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool FlushInstructionCache(IntPtr hProcess, IntPtr baseAddress, IntPtr size);

    [DllImport("kernel32.dll", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool CloseHandle(IntPtr hObject);
}

public sealed class W3ReleasePulseResult
{
    public long Polls;
    public long ReadFailures;
    public long ElapsedMs;
    public uint LastValue;
}

public static class W3ReleasePulse
{
    public static W3ReleasePulseResult Run(IntPtr h, ulong address, int maxMs)
    {
        W3ReleasePulseResult r = new W3ReleasePulseResult();
        Stopwatch sw = Stopwatch.StartNew();
        byte[] b = new byte[4];
        IntPtr got;
        int consecutiveFailures = 0;
        while (sw.ElapsedMilliseconds < maxMs)
        {
            bool ok = W3ReleaseNative.ReadProcessMemory(
                h, new IntPtr(unchecked((long)address)), b, 4, out got);
            if (ok && got.ToInt64() == 4)
            {
                r.Polls++;
                r.LastValue = BitConverter.ToUInt32(b, 0);
                consecutiveFailures = 0;
            }
            else
            {
                r.ReadFailures++;
                consecutiveFailures++;
                if (consecutiveFailures >= 64) break;
            }
            Thread.Sleep(1);
        }
        r.ElapsedMs = sw.ElapsedMilliseconds;
        return r;
    }
}
'@
Add-Type -TypeDefinition $native -Language CSharp -ErrorAction Stop

$overlay=@'
using System;
using System.Drawing;
using System.Threading;
using System.Windows.Forms;

public sealed class W3ReleaseOverlayForm : Form
{
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x08000000; // WS_EX_NOACTIVATE
            cp.ExStyle |= 0x00000080; // WS_EX_TOOLWINDOW
            return cp;
        }
    }
}

public static class W3ReleaseOverlay
{
    public static bool ShowStatus(string text, bool ok, int milliseconds)
    {
        try
        {
            Thread t = new Thread(delegate()
            {
                W3ReleaseOverlayForm f = new W3ReleaseOverlayForm();
                f.FormBorderStyle = FormBorderStyle.FixedToolWindow;
                f.StartPosition = FormStartPosition.Manual;
                f.ShowInTaskbar = false;
                f.TopMost = true;
                f.Width = 650;
                f.Height = 90;
                Rectangle wa = Screen.PrimaryScreen.WorkingArea;
                f.Left = wa.Left + (wa.Width - f.Width) / 2;
                f.Top = wa.Top + 40;
                f.BackColor = ok ? Color.FromArgb(25,80,35) : Color.FromArgb(110,25,25);
                Label l = new Label();
                l.Dock = DockStyle.Fill;
                l.TextAlign = ContentAlignment.MiddleCenter;
                l.ForeColor = Color.White;
                l.Font = new Font("Segoe UI", 12.0f, FontStyle.Bold);
                l.Text = text;
                f.Controls.Add(l);
                System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer();
                timer.Interval = Math.Max(250, milliseconds);
                timer.Tick += delegate(object sender, EventArgs e) { timer.Stop(); f.Close(); };
                f.Shown += delegate(object sender, EventArgs e) { timer.Start(); };
                Application.Run(f);
                timer.Dispose();
                f.Dispose();
            });
            t.SetApartmentState(ApartmentState.STA);
            t.IsBackground = false;
            t.Start();
            return true;
        }
        catch { return false; }
    }
}
'@
$script:OverlayAvailable=$false
try{
    Add-Type -TypeDefinition $overlay -Language CSharp -ReferencedAssemblies @('System.Windows.Forms.dll','System.Drawing.dll') -ErrorAction Stop
    $script:OverlayAvailable=$true
}catch{}

function Status([string]$text,[bool]$ok,[int]$milliseconds){
    O ('STATUS='+$text)
    if($script:OverlayAvailable){try{[void][W3ReleaseOverlay]::ShowStatus($text,$ok,$milliseconds)}catch{}}
}
function ReadRemote([IntPtr]$h,[Int64]$addr,[int]$n){
    $buf=New-Object byte[] $n
    $got=[IntPtr]::Zero
    if(-not[W3ReleaseNative]::ReadProcessMemory($h,[IntPtr]$addr,$buf,$n,[ref]$got)){
        throw ('ReadProcessMemory failed Win32='+[Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
    if($got.ToInt64()-ne$n){throw ('Short ReadProcessMemory: got '+$got.ToInt64()+' expected '+$n)}
    return $buf
}
function WriteRemote([IntPtr]$h,[Int64]$addr,[byte[]]$buf){
    $put=[IntPtr]::Zero
    if(-not[W3ReleaseNative]::WriteProcessMemory($h,[IntPtr]$addr,$buf,$buf.Length,[ref]$put)){
        throw ('WriteProcessMemory failed Win32='+[Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
    if($put.ToInt64()-ne$buf.Length){throw 'Short WriteProcessMemory.'}
}
function PutI32([Collections.Generic.List[byte]]$c,[int]$pos,[int]$v){
    $x=[BitConverter]::GetBytes($v)
    for($i=0;$i-lt4;$i++){$c[$pos+$i]=$x[$i]}
}
function WriteIatPointer([IntPtr]$h,[Int64]$iatAddr,[Int64]$ptr){
    $old=0
    if(-not[W3ReleaseNative]::VirtualProtectEx($h,[IntPtr]$iatAddr,[IntPtr]8,0x04,[ref]$old)){
        throw ('VirtualProtectEx(IAT RW) failed Win32='+[Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
    try{
        WriteRemote $h $iatAddr ([BitConverter]::GetBytes([int64]$ptr))
    }finally{
        $tmp=0
        [void][W3ReleaseNative]::VirtualProtectEx($h,[IntPtr]$iatAddr,[IntPtr]8,$old,[ref]$tmp)
    }
    [void][W3ReleaseNative]::FlushInstructionCache($h,[IntPtr]$iatAddr,[IntPtr]8)
}

$script:C256PatchApplied=$false
$script:C256PatchObject=[uint64]0
$script:C256PatchOriginal=[uint32]0
$script:C256PatchExpected=[uint32]0
$script:C256PatchMs=[long]-1
$script:C256ProbeLastMs=[long]-10000
$script:C256ProbeLastSummary=''

function C256ComputeExpected([uint32]$g210c0b0){
    [uint64]$M=[uint64]4294967295
    [uint64]$a4=(([uint64]$g210c0b0+[uint64]3395345826)-band $M)
    [uint64]$invA4=($M -bxor $a4)
    [uint64]$a8=((($invA4 -band [uint64]1950337290)*11)-band $M)
    [uint64]$ac=(((($a4 -bor [uint64]1950337290)*11))-band $M)
    [uint64]$b0=(($a4 -bxor [uint64]1950337290)-band $M)
    [uint64]$b4=((($a4 -band [uint64]2344630005)*9)-band $M)
    [uint64]$b8=($a4 -band [uint64]1950337290)
    [uint64]$bc=(($ac+[uint64]85899345920-(($b8*11)+$b4+$b0))-band $M)
    [uint64]$x=(($bc+[uint64]4294967296-$a8)-band $M)
    [uint64]$c0=(($x -bxor [uint64]3494960644)-band $M)
    [uint64]$c4=(($x -bxor [uint64]1129164038)-band $M)
    [uint64]$c8=(($c4+[uint64]1663572473)-band $M)
    [uint64]$cc=(([uint64]187680546+[uint64]4294967296-$x)-band $M)
    [uint64]$expected=((($cc -bxor $c4 -bxor $c8)+$c0+$a4)-band $M)
    return [uint32]$expected
}
function GetWar3LoaderBase($p){
    try{
        $p.Refresh()
        $m=$p.Modules | Where-Object {$_.ModuleName -ieq 'war3_loader.dll'} | Select-Object -First 1
        if($null-eq$m){return [uint64]0}
        return [uint64]$m.BaseAddress.ToInt64()
    }catch{return [uint64]0}
}
function TryC256Patch($p,[IntPtr]$h,[long]$nowMs,[bool]$strict){
    if($script:C256PatchApplied){return $true}
    [uint64]$wb=GetWar3LoaderBase $p
    if($wb-eq0){return $false}
    try{
        [uint64]$raw=[BitConverter]::ToUInt64((ReadRemote $h (I64FromU64 ($wb+[uint64]0x021BCA68)) 8),0)
        [byte[]]$kb=[byte[]](0x6A,0xD6,0x77,0x21,0xB7,0xD0,0x9A,0xD1)
        [uint64]$key=[BitConverter]::ToUInt64($kb,0)
        [uint64]$obj=($raw -bxor $key)
        if($obj-lt[uint64]0x10000 -or $obj-ge[uint64]0x0000800000000000){return $false}
        [uint32]$actual=[BitConverter]::ToUInt32((ReadRemote $h (I64FromU64 ($obj+[uint64]0x20)) 4),0)
        [uint32]$g=[BitConverter]::ToUInt32((ReadRemote $h (I64FromU64 ($wb+[uint64]0x0210C0B0)) 4),0)
        [uint32]$expected=C256ComputeExpected $g
        [uint64]$M=[uint64]4294967295
        [uint32]$delta=[uint32]((([uint64]$expected+[uint64]4294967296-[uint64]$actual)-band $M))
        $summary=('obj=0x{0:X16} actual=0x{1:X8} expected=0x{2:X8} delta=0x{3:X8}' -f $obj,$actual,$expected,$delta)
        if($summary-ne$script:C256ProbeLastSummary){O ('C256_PROBE t={0}ms {1}' -f $nowMs,$summary);$script:C256ProbeLastSummary=$summary}
        if($actual-eq$expected){
            $script:C256PatchApplied=$true
            $script:C256PatchObject=$obj
            $script:C256PatchOriginal=$actual
            $script:C256PatchExpected=$expected
            $script:C256PatchMs=$nowMs
            O 'C256_ALREADY_CORRECT=True'
            return $true
        }
        if($delta-ne[uint32]0x00000707){
            if($strict){throw ('C256 exact +0x707 guard failed; observed delta=0x{0:X8}' -f $delta)}
            return $false
        }
        WriteRemote $h (I64FromU64 ($obj+[uint64]0x20)) ([BitConverter]::GetBytes([uint32]$expected))
        [uint32]$verify=[BitConverter]::ToUInt32((ReadRemote $h (I64FromU64 ($obj+[uint64]0x20)) 4),0)
        if($verify-ne$expected){throw 'C256 4-byte write verification failed.'}
        $script:C256PatchApplied=$true
        $script:C256PatchObject=$obj
        $script:C256PatchOriginal=$actual
        $script:C256PatchExpected=$expected
        $script:C256PatchMs=$nowMs
        O ('C256_PATCH_APPLIED=True t={0}ms addr=0x{1:X16} old=0x{2:X8} new=0x{3:X8} bytes=4 codePatched=False' -f $nowMs,($obj+[uint64]0x20),$actual,$expected)
        return $true
    }catch{
        if($strict){throw}
        $m=$_.Exception.Message
        if($m -like '*verification failed*'){throw}
        return $false
    }
}

function TestWar3Root([string]$root){
    if([string]::IsNullOrEmpty($root)){return $false}
    try{$root=[Environment]::ExpandEnvironmentVariables($root)}catch{}
    $root=$root.Trim()
    if($root.StartsWith('"') -and $root.EndsWith('"') -and $root.Length-gt1){$root=$root.Substring(1,$root.Length-2)}
    if(!(Test-Path -LiteralPath $root)){return $false}
    $c=Join-Path $root '_retail_\x86_64\ClientSdk.dll'
    $w=Join-Path $root '_retail_\x86_64\war3_loader.dll'
    return ((Test-Path -LiteralPath $c) -and (Test-Path -LiteralPath $w))
}
function FindWar3Root{
    # Optional expert override, useful on unusual portable/manual installs.
    if($env:WAR3_ROOT -and (TestWar3Root $env:WAR3_ROOT)){
        return [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($env:WAR3_ROOT))
    }

    # Modern Battle.net/Reforged installs normally expose InstallLocation here.
    $direct=@(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Warcraft III',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Warcraft III',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Warcraft III'
    )
    foreach($k in $direct){
        try{
            if(Test-Path -LiteralPath $k){
                $p=Get-ItemProperty -LiteralPath $k -ErrorAction SilentlyContinue
                if($p -and $p.InstallLocation -and (TestWar3Root ([string]$p.InstallLocation))){
                    return [IO.Path]::GetFullPath([string]$p.InstallLocation)
                }
            }
        }catch{}
    }

    # Fallback: scan uninstall entries by display name.
    $roots=@(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach($r in $roots){
        try{
            if(!(Test-Path -LiteralPath $r)){continue}
            foreach($k in (Get-ChildItem -LiteralPath $r -ErrorAction SilentlyContinue)){
                try{
                    $p=Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue
                    if($p -and $p.DisplayName -and ([string]$p.DisplayName -like 'Warcraft III*')){
                        if($p.InstallLocation -and (TestWar3Root ([string]$p.InstallLocation))){
                            return [IO.Path]::GetFullPath([string]$p.InstallLocation)
                        }
                    }
                }catch{}
            }
        }catch{}
    }

    # Legacy/compatibility registry fallback.
    $legacy=@(
        'HKCU:\Software\Blizzard Entertainment\Warcraft III',
        'HKLM:\Software\Blizzard Entertainment\Warcraft III',
        'HKLM:\Software\Wow6432Node\Blizzard Entertainment\Warcraft III'
    )
    foreach($k in $legacy){
        try{
            if(Test-Path -LiteralPath $k){
                $p=Get-ItemProperty -LiteralPath $k -ErrorAction SilentlyContinue
                $v=$p.InstallPath
                if($v -and (TestWar3Root ([string]$v))){return [IO.Path]::GetFullPath([string]$v)}
                $v=$p.InstallLocation
                if($v -and (TestWar3Root ([string]$v))){return [IO.Path]::GetFullPath([string]$v)}
            }
        }catch{}
    }
    return $null
}
function TestBattleNetExe([string]$p){
    if([string]::IsNullOrEmpty($p)){return $false}
    try{$p=[Environment]::ExpandEnvironmentVariables($p)}catch{}
    $p=$p.Trim()
    if($p.StartsWith('"') -and $p.EndsWith('"') -and $p.Length-gt1){$p=$p.Substring(1,$p.Length-2)}
    return (Test-Path -LiteralPath $p)
}
function FindBattleNetExe{
    if($env:BATTLENET_EXE -and (TestBattleNetExe $env:BATTLENET_EXE)){
        return [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($env:BATTLENET_EXE))
    }

    # Best source when the user follows the documented prerequisite: Battle.net is already open/signed in.
    try{
        $bp=Get-Process -Name 'Battle.net' -ErrorAction SilentlyContinue | Select-Object -First 1
        if($bp){
            try{$pp=$bp.MainModule.FileName}catch{$pp=$null}
            if($pp -and (TestBattleNetExe $pp)){return [IO.Path]::GetFullPath([string]$pp)}
        }
    }catch{}

    # Registry fallback for non-running launcher.
    $roots=@(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach($r in $roots){
        try{
            if(!(Test-Path -LiteralPath $r)){continue}
            foreach($k in (Get-ChildItem -LiteralPath $r -ErrorAction SilentlyContinue)){
                try{
                    $p=Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue
                    if(!$p -or !$p.DisplayName -or ([string]$p.DisplayName -notlike '*Battle.net*')){continue}
                    if($p.InstallLocation){
                        foreach($name in @('Battle.net.exe','Battle.net Launcher.exe')){
                            $cand=Join-Path ([string]$p.InstallLocation) $name
                            if(TestBattleNetExe $cand){return [IO.Path]::GetFullPath($cand)}
                        }
                    }
                    if($p.DisplayIcon){
                        $cand=([string]$p.DisplayIcon) -replace ',\s*-?\d+\s*$',''
                        $cand=$cand.Trim()
                        if($cand.StartsWith('"') -and $cand.EndsWith('"') -and $cand.Length-gt1){$cand=$cand.Substring(1,$cand.Length-2)}
                        if(TestBattleNetExe $cand){return [IO.Path]::GetFullPath($cand)}
                    }
                }catch{}
            }
        }catch{}
    }

    foreach($base in @($env:ProgramFiles,${env:ProgramFiles(x86)},$env:LOCALAPPDATA)){
        if(!$base){continue}
        foreach($rel in @('Battle.net\Battle.net.exe','Battle.net\Battle.net Launcher.exe')){
            try{$cand=Join-Path $base $rel}catch{$cand=$null}
            if($cand -and (TestBattleNetExe $cand)){return [IO.Path]::GetFullPath($cand)}
        }
    }
    return $null
}

$h=[IntPtr]::Zero
$gamePid=0
$iatAddr=[int64]0
$origPtr=[int64]0
$remoteBase=[int64]0
$iatPatched=$false
$hookFreed=$false
$ready=$false
$exitCode=0

try{
    if(Test-Path -LiteralPath $Out){Remove-Item -LiteralPath $Out -Force}
    O 'Warcraft III 3.0 - Windows 7 ONLINE FIX v1.0'
    O '=========================================================='
    O ('PowerShell IntPtr.Size='+[IntPtr]::Size)
    O 'PATH_MODE=portable-auto-detect'
    if([IntPtr]::Size-ne8){throw 'This fix requires 64-bit PowerShell.'}

    $war3Root=FindWar3Root
    if(!$war3Root){throw 'Warcraft III install path could not be auto-detected. Ensure the Battle.net installation is registered, or set WAR3_ROOT to the Warcraft III folder.'}
    $clientDisk=Join-Path $war3Root '_retail_\x86_64\ClientSdk.dll'
    $loaderDisk=Join-Path $war3Root '_retail_\x86_64\war3_loader.dll'
    $bnet=FindBattleNetExe
    if(!$bnet){throw 'Battle.net.exe could not be auto-detected. Start/sign in to Battle.net, then rerun this BAT (or set BATTLENET_EXE).'}
    O ('Warcraft root='+$war3Root)
    O ('Battle.net exe='+$bnet)

    $clientSha=Sha256 $clientDisk
    $loaderSha=Sha256 $loaderDisk
    O ('ClientSdk SHA256='+$clientSha)
    O ('war3_loader SHA256='+$loaderSha)
    if($clientSha-ine$ExpectedClientSdkSha){throw 'ClientSdk.dll build mismatch; refusing to patch.'}
    if($loaderSha-ine$ExpectedWar3LoaderSha){throw 'war3_loader.dll build mismatch; refusing to use fixed offsets.'}
    $iatRva=FindImportIatRva $clientDisk 'CRYPT32.dll' 'CertCreateCertificateChainEngine'
    O ('Certificate IAT RVA=0x{0:X8}' -f $iatRva)
    O 'PREFLIGHT_OK=True'
    Save

    O 'Launching Warcraft III through Battle.net...'
    $psi=New-Object Diagnostics.ProcessStartInfo
    $psi.FileName=$bnet
    $psi.Arguments='--exec="launch W3"'
    $psi.UseShellExecute=$true
    [void][Diagnostics.Process]::Start($psi)

    $game=$null
    $detect=[Diagnostics.Stopwatch]::StartNew()
    while($detect.Elapsed.TotalSeconds-lt120){
        $game=Get-Process -Name 'Warcraft III' -ErrorAction SilentlyContinue | Select-Object -First 1
        if($null-ne$game){break}
        Start-Sleep -Milliseconds 1
    }
    if($null-eq$game){throw 'Warcraft III.exe was not detected within 120 seconds.'}
    $gamePid=$game.Id
    O ('Warcraft PID='+$gamePid)

    $client=$null
    $modDetect=[Diagnostics.Stopwatch]::StartNew()
    while($modDetect.Elapsed.TotalSeconds-lt10){
        $game=Get-Process -Id $gamePid -ErrorAction SilentlyContinue
        if($null-eq$game){throw 'Warcraft exited before ClientSdk.dll loaded.'}
        try{$client=$game.Modules | Where-Object {$_.ModuleName -ieq 'ClientSdk.dll'} | Select-Object -First 1}catch{}
        if($null-ne$client){break}
        Start-Sleep -Milliseconds 1
    }
    if($null-eq$client){throw 'ClientSdk.dll was not observed within 10 seconds.'}
    if($client.FileName-ine$clientDisk){throw ('Unexpected ClientSdk path: '+$client.FileName)}

    $clientBase=$client.BaseAddress.ToInt64()
    $iatAddr=$clientBase+[int64][uint32]$iatRva
    $h=[W3ReleaseNative]::OpenProcess(0x0478,$false,$gamePid)
    if($h-eq[IntPtr]::Zero){throw ('OpenProcess failed Win32='+[Runtime.InteropServices.Marshal]::GetLastWin32Error())}

    $origPtr=[BitConverter]::ToInt64((ReadRemote $h $iatAddr 8),0)
    $game.Refresh()
    $crypt=$game.Modules | Where-Object {$_.ModuleName -ieq 'crypt32.dll'} | Select-Object -First 1
    if($null-eq$crypt){throw 'crypt32.dll is not loaded in Warcraft.'}
    $cb=$crypt.BaseAddress.ToInt64(); $ce=$cb+$crypt.ModuleMemorySize
    if($origPtr-lt$cb -or $origPtr-ge$ce){throw 'Original certificate IAT pointer is not inside crypt32.dll.'}
    O ('Original certificate IAT pointer=0x{0:X16}' -f $origPtr)

    $remote=[W3ReleaseNative]::VirtualAllocEx($h,[IntPtr]::Zero,[IntPtr]4096,0x3000,0x40)
    if($remote-eq[IntPtr]::Zero){throw ('VirtualAllocEx failed Win32='+[Runtime.InteropServices.Marshal]::GetLastWin32Error())}
    $remoteBase=$remote.ToInt64()

    $code=New-Object Collections.Generic.List[byte]
    function AddB([byte[]]$a){foreach($x in $a){[void]$code.Add($x)}}

    AddB ([byte[]](0x48,0x85,0xC9))
    AddB ([byte[]](0x0F,0x84,0,0,0,0)); $jeDisp=$code.Count-4; $jeEnd=$code.Count
    AddB ([byte[]](0x83,0x39,0x58))
    AddB ([byte[]](0x0F,0x85,0,0,0,0)); $jneDisp=$code.Count-4; $jneEnd=$code.Count

    AddB ([byte[]](0x48,0x83,0xEC,0x78))
    $src=@(0x00,0x08,0x10,0x18,0x20,0x28,0x30,0x38,0x40,0x48)
    $dst=@(0x20,0x28,0x30,0x38,0x40,0x48,0x50,0x58,0x60,0x68)
    for($i=0;$i-lt10;$i++){
        $s=$src[$i]; $d=$dst[$i]
        if($s-eq0){AddB ([byte[]](0x48,0x8B,0x01))}else{AddB ([byte[]](0x48,0x8B,0x41,[byte]$s))}
        AddB ([byte[]](0x48,0x89,0x44,0x24,[byte]$d))
    }
    AddB ([byte[]](0xC7,0x44,0x24,0x20,0x50,0x00,0x00,0x00))
    AddB ([byte[]](0x48,0x8D,0x4C,0x24,0x20))
    AddB ([byte[]](0x48,0xB8)); AddB ([BitConverter]::GetBytes([int64]$origPtr)); AddB ([byte[]](0xFF,0xD0))

    $counterOff=0x200; $resultOff=0x204
    AddB ([byte[]](0x89,0x05,0,0,0,0)); $resultDisp=$code.Count-4; $resultEnd=$code.Count
    AddB ([byte[]](0xF0,0xFF,0x05,0,0,0,0)); $counterDisp=$code.Count-4; $counterEnd=$code.Count
    AddB ([byte[]](0x48,0x83,0xC4,0x78)); AddB ([byte[]](0xC3))
    $tail=$code.Count
    AddB ([byte[]](0x48,0xB8)); AddB ([BitConverter]::GetBytes([int64]$origPtr)); AddB ([byte[]](0xFF,0xE0))

    PutI32 $code $jeDisp ($tail-$jeEnd)
    PutI32 $code $jneDisp ($tail-$jneEnd)
    PutI32 $code $resultDisp ($resultOff-$resultEnd)
    PutI32 $code $counterDisp ($counterOff-$counterEnd)

    $page=New-Object byte[] 4096
    $code.CopyTo($page,0)
    WriteRemote $h $remoteBase $page
    [void][W3ReleaseNative]::FlushInstructionCache($h,[IntPtr]$remoteBase,[IntPtr]$code.Count)
    WriteIatPointer $h $iatAddr $remoteBase
    $iatPatched=$true
    $slot=[BitConverter]::ToInt64((ReadRemote $h $iatAddr 8),0)
    if($slot-ne$remoteBase){throw 'Certificate IAT hook verification failed.'}
    O ('STARTUP_HOOK_ACTIVE=True remote=0x{0:X16}' -f $remoteBase)
    Save

    $sw=[Diagnostics.Stopwatch]::StartNew()
    $lastCount=-1; $lastBool=0; $firstCallMs=[long]-1; $iatRepatches=0
    while($true){
        $game=Get-Process -Id $gamePid -ErrorAction SilentlyContinue
        if($null-eq$game){throw 'Warcraft exited during startup compatibility stage.'}
        $now=$sw.ElapsedMilliseconds

        if($iatPatched){
            $slot=[BitConverter]::ToInt64((ReadRemote $h $iatAddr 8),0)
            if($slot-ne$remoteBase){
                if($slot-eq$origPtr){
                    WriteIatPointer $h $iatAddr $remoteBase
                    $iatRepatches++
                    O ('STARTUP_IAT_REPATCHED=True t='+$now+'ms count='+$iatRepatches)
                }else{
                    throw ('Unexpected ClientSdk certificate IAT target: 0x{0:X16}' -f $slot)
                }
            }
        }

        $tele=ReadRemote $h ($remoteBase+$counterOff) 8
        $count=[BitConverter]::ToInt32($tele,0)
        $lastBool=[BitConverter]::ToInt32($tele,4)
        if($count-ne$lastCount){
            O ('CERT_STATE t={0}ms translatedCalls={1} lastBOOL={2}' -f $now,$count,$lastBool)
            if($count-ge1 -and $firstCallMs-lt0){$firstCallMs=$now;O ('CERT_CALL_1_OK_MS='+$firstCallMs)}
            $lastCount=$count
        }

        if((-not$script:C256PatchApplied) -and $count-ge1 -and $lastBool-eq1 -and (($now-$script:C256ProbeLastMs)-ge100)){
            $script:C256ProbeLastMs=$now
            [void](TryC256Patch $game $h $now $false)
        }

        if($count-ge2){
            if($lastBool-ne1){throw ('Certificate call #2 returned FALSE; BOOL='+$lastBool)}
            if(-not$script:C256PatchApplied){
                [void](TryC256Patch $game $h $now $true)
            }
            if(-not$script:C256PatchApplied){throw 'C256 exact +0x707 state was not available before detach.'}
            O ('CERT_CALL_2_OK_MS='+$now)
            break
        }

        if($count-eq0 -and $now-ge120000){throw 'Timed out waiting 120 seconds for certificate call #1.'}
        if($count-ge1 -and $firstCallMs-ge0 -and ($now-$firstCallMs)-ge90000){throw 'Timed out waiting 90 seconds for certificate call #2 after call #1.'}
        Start-Sleep -Milliseconds 5
    }

    WriteIatPointer $h $iatAddr $origPtr
    $slot=[BitConverter]::ToInt64((ReadRemote $h $iatAddr 8),0)
    if($slot-ne$origPtr){throw 'Original certificate IAT pointer restore verification failed.'}
    $iatPatched=$false
    O 'CERT_IAT_RESTORED_EXACT=True'

    Start-Sleep -Milliseconds 2000
    if(-not[W3ReleaseNative]::VirtualFreeEx($h,[IntPtr]$remoteBase,[IntPtr]::Zero,0x8000)){
        throw ('VirtualFreeEx startup hook page failed Win32='+[Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
    $hookFreed=$true
    O 'STARTUP_HOOK_PAGE_FREED=True'

    for($i=0;$i-lt80;$i++){
        if($null-eq(Get-Process -Id $gamePid -ErrorAction SilentlyContinue)){throw 'Warcraft exited before READY.'}
        Start-Sleep -Milliseconds 100
    }

    [uint32]$cur=[BitConverter]::ToUInt32((ReadRemote $h (I64FromU64 ($script:C256PatchObject+[uint64]0x20)) 4),0)
    if($cur-ne$script:C256PatchExpected){throw ('C256 value changed before READY: 0x{0:X8}' -f $cur)}
    $ready=$true
    O ('READY=True C256=0x{0:X8} IATrestored=True hookFreed=True' -f $cur)
    O 'PERF_PULSE=read-only 4-byte ReadProcessMemory + Thread.Sleep(1)'
    Save
    Status 'WARCRAFT III WIN7 FIX ACTIVE - ONLINE READY' $true 2600

    [uint64]$pulseAddr=$script:C256PatchObject+[uint64]0x20
    [long]$totalPolls=0; [long]$totalFailures=0
    $pulseSw=[Diagnostics.Stopwatch]::StartNew()
    while($true){
        $game=Get-Process -Id $gamePid -ErrorAction SilentlyContinue
        if($null-eq$game){break}
        $r=[W3ReleasePulse]::Run($h,$pulseAddr,1000)
        $totalPolls+=$r.Polls
        $totalFailures+=$r.ReadFailures
        if($r.ReadFailures-ge64 -and $r.ElapsedMs-lt500){
            $game=Get-Process -Id $gamePid -ErrorAction SilentlyContinue
            if($null-eq$game){break}
            throw 'Performance pulse lost read access while Warcraft was still running.'
        }
        if([uint32]$r.LastValue-ne0 -and [uint32]$r.LastValue-ne$script:C256PatchExpected){
            throw ('C256 runtime value changed unexpectedly to 0x{0:X8}' -f [uint32]$r.LastValue)
        }
    }
    O ('WARCRAFT_EXIT=True pulseElapsedMs={0} polls={1} readFailures={2}' -f $pulseSw.ElapsedMilliseconds,$totalPolls,$totalFailures)
    Save
}
catch{
    $exitCode=1
    O ('ERROR: '+$_.Exception.GetType().FullName+': '+$_.Exception.Message)
    try{Save}catch{}
    try{Status ('WAR3 WIN7 FIX ERROR - SEE TXT LOG') $false 4500}catch{}
}
finally{
    if($h-ne[IntPtr]::Zero){
        if($iatPatched -and $iatAddr-ne0 -and $origPtr-ne0){
            try{
                WriteIatPointer $h $iatAddr $origPtr
                O 'CLEANUP_IAT_RESTORED=True'
                $iatPatched=$false
            }catch{O ('CLEANUP_IAT_RESTORE_ERROR='+$_.Exception.Message)}
        }
        if((-not$ready) -and $script:C256PatchApplied -and $script:C256PatchObject-ne0 -and $script:C256PatchOriginal-ne$script:C256PatchExpected){
            try{
                WriteRemote $h (I64FromU64 ($script:C256PatchObject+[uint64]0x20)) ([BitConverter]::GetBytes([uint32]$script:C256PatchOriginal))
                O 'CLEANUP_C256_RESTORED_BECAUSE_NOT_READY=True'
            }catch{O ('CLEANUP_C256_RESTORE_ERROR='+$_.Exception.Message)}
        }
        if((-not$hookFreed) -and $remoteBase-ne0){
            try{
                if([W3ReleaseNative]::VirtualFreeEx($h,[IntPtr]$remoteBase,[IntPtr]::Zero,0x8000)){
                    O 'CLEANUP_HOOK_PAGE_FREED=True'
                }
            }catch{}
        }
        try{[void][W3ReleaseNative]::CloseHandle($h)}catch{}
    }
    try{Save}catch{}
}
exit $exitCode
