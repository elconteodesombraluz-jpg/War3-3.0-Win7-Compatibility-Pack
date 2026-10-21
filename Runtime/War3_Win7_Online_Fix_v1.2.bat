@echo off
setlocal EnableExtensions
set "SELF=%~f0"
set "OUT=%~dp0WAR3_WIN7_ONLINE_FIX_v1.2.txt"
set "PS1=%TEMP%\WAR3_WIN7_ONLINE_FIX_v1_2_%RANDOM%_%RANDOM%.ps1"
title Warcraft III - Windows 7 Compatibility Fix v1.2

echo.
echo Warcraft III - Windows 7 3.0.1.24371 ONLINE FIX v1.2
echo ==========================================================
echo Windows 7 SP1 x64 / Warcraft III 3.0.1.24371: validated certificate shim + guarded timebase heartbeat.
echo.
echo What it does:
echo   - auto-detects Warcraft III and Battle.net install paths
echo   - launches Warcraft III through the official Battle.net launcher
echo   - applies the proven unchanged ClientSdk certificate-chain compatibility shim
echo   - after certificate call #1, decodes the regenerated 3.0.1.24371 object
echo   - decodes the object+0x6C stored timestamp using the transform recovered from the fatal frame
echo   - requires the decoded timestamp age to be plausibly recent relative to GetTickCount
echo   - performs one guarded startup refresh, then maintains object+0x6C below the proven 30-second fatal threshold
echo   - restores the old-fix UX: 2 s hook-page delay + 8 s stabilization before GREEN
echo   - checks approximately every 250 ms and refreshes only when decoded age reaches 10 seconds
echo.
echo Safety guards:
echo   - exact unchanged ClientSdk.dll SHA-256 required
echo   - exact 3.0.1.24371 war3_loader.dll SHA-256 required
echo   - decoded object pointer must be plausible
echo   - recovered raw timestamp transform must round-trip exactly
echo   - decoded stored time must be 1,000..120,000 ms old at the guarded write
echo   - every correction is exactly 4 DATA bytes with immediate readback verification; no code byte is patched
echo   - the write is process-local and disappears when Warcraft exits
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
$ExpectedClientSdkSha='04f798ac211b9fea1b741b4f1d520d7e5b3cf5f038241c909b7429b02a4cf134'
$ExpectedWar3LoaderSha='ef88b6554036661f5974986b95912b08c8a7042795177f539a67cc4e710d23d7'
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

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenThread(uint access, bool inheritHandle, uint threadId);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern uint SuspendThread(IntPtr hThread);

    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern uint ResumeThread(IntPtr hThread);

    [DllImport("kernel32.dll", SetLastError=true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool GetThreadContext(IntPtr hThread, IntPtr lpContext);

    [DllImport("user32.dll", SetLastError=true)]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

    [DllImport("kernel32.dll")]
    public static extern uint GetTickCount();

    [DllImport("kernel32.dll")]
    public static extern ulong GetTickCount64();

    public static ulong Decode24371Object(ulong g216a878)
    {
        unchecked
        {
            return g216a878 ^ 0xEC3F4C87D9BA4DC6UL;
        }
    }

    // Exact relation proved by the v5b fatal frame:
    //
    //   frame94 = frame60 - (raw6C XOR 0x79578000)  (mod 2^32)
    //
    // Therefore object+0x6C stores the tick as a simple XOR encoding.
    public static uint Decode24371StoredTick(uint raw)
    {
        unchecked
        {
            return raw ^ 0x79578000U;
        }
    }

    public static uint Encode24371StoredTick(uint storedTick)
    {
        unchecked
        {
            return storedTick ^ 0x79578000U;
        }
    }
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
try{
    Add-Type -TypeDefinition $native -Language CSharp -ErrorAction Stop
}catch{
    try{
        @(
            'EARLY_CSHARP_COMPILE_ERROR=True',
            ('MESSAGE='+$_.Exception.Message),
            $_.Exception.ToString()
        ) | Set-Content -LiteralPath $Out -Encoding UTF8
    }catch{}
    Write-Host ('EARLY_CSHARP_COMPILE_ERROR: '+$_.Exception.Message) -ForegroundColor Red
    exit 97
}

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

function U64FromI64([Int64]$v){return [BitConverter]::ToUInt64([BitConverter]::GetBytes($v),0)}
function Hex64([UInt64]$v){return ('0x{0:X16}' -f $v)}

function GetModuleMap($p){
    $a=@()
    try{
        $p.Refresh()
        foreach($m in $p.Modules){
            [UInt64]$b=[UInt64]$m.BaseAddress.ToInt64()
            [UInt64]$s=[UInt64]$m.ModuleMemorySize
            $a += [pscustomobject]@{Name=[string]$m.ModuleName;Base=$b;End=$b+$s;Path=[string]$m.FileName}
        }
    }catch{}
    return @($a | Sort-Object Base)
}
function MapAddr([UInt64]$a,$mods){
    foreach($m in $mods){
        if($a-ge$m.Base -and $a-lt$m.End){return ('{0}+0x{1:X}' -f $m.Name,($a-$m.Base))}
    }
    return $null
}

function ReadU32Remote([IntPtr]$h,[UInt64]$a){
    return [BitConverter]::ToUInt32((ReadRemote $h ([Int64]$a) 4),0)
}
function ReadU64Remote([IntPtr]$h,[UInt64]$a){
    return [BitConverter]::ToUInt64((ReadRemote $h ([Int64]$a) 8),0)
}

# Avoid PowerShell's signed interpretation of 0xFFFFFFFF on older Windows.
$script:U32Mask=[UInt64]4294967295
$script:U32Mod =[UInt64]4294967296

function Add32([UInt32]$a,[UInt32]$b){
    [UInt64]$x=[UInt64]$a+[UInt64]$b
    return [UInt32]($x -band $script:U32Mask)
}
function Sub32([UInt32]$a,[UInt32]$b){
    [UInt64]$x=[UInt64]$a+$script:U32Mod-[UInt64]$b
    return [UInt32]($x -band $script:U32Mask)
}
function Mul32([UInt32]$a,[UInt32]$b){
    [UInt64]$x=[UInt64]$a*[UInt64]$b
    return [UInt32]($x -band $script:U32Mask)
}
function Xor32([UInt32]$a,[UInt32]$b){
    [UInt64]$x=([UInt64]$a -bxor [UInt64]$b)
    return [UInt32]($x -band $script:U32Mask)
}
function Or32([UInt32]$a,[UInt32]$b){
    [UInt64]$x=([UInt64]$a -bor [UInt64]$b)
    return [UInt32]($x -band $script:U32Mask)
}
function Not32([UInt32]$a){
    [UInt64]$x=($script:U32Mask -bxor [UInt64]$a)
    return [UInt32]$x
}

# Reconstructed from the new build around:
#   E49029..E49038
#   E4A5B6..E4A5E4
#   E4A64F..
# This produces the new frame[A0] value from the object field at frame[40].
function Compute-NewA0([UInt32]$objField,[UInt32]$c4c,[UInt32]$v9c,[UInt32]$v98,[UInt32]$v48){
    # New-build sequence:
    # E4A5B6..E4A5E4: temp = 6*a + (a XOR c4c) - frame[9C]
    # E4A64F..E4A65C: A0 = frame[48] - (temp + frame[98])
    [UInt32]$sixA=Mul32 $objField ([UInt32]6)
    [UInt32]$xorAC=Xor32 $objField $c4c
    [UInt32]$pre=Add32 $sixA $xorAC
    [UInt32]$temp=Sub32 $pre $v9c
    [UInt32]$with98=Add32 $temp $v98
    return (Sub32 $v48 $with98)
}

$script:NewObj=[UInt64]0
$script:NewObjLast=[UInt32]0
$script:NewObjHave=$false
$script:NewObjChanges=0
$script:NewObjFirstMs=[long]-1


function GetWar3LoaderBase($p){
    try{
        $p.Refresh()
        $m=$p.Modules | Where-Object {$_.ModuleName -ieq 'war3_loader.dll'} | Select-Object -First 1
        if($null-eq$m){return [UInt64]0}
        return [UInt64]$m.BaseAddress.ToInt64()
    }catch{return [UInt64]0}
}

function Decode24371Object($p,[IntPtr]$h){
    [UInt64]$wb=GetWar3LoaderBase $p
    if($wb-eq0){return $null}
    [UInt64]$g=ReadU64Remote $h ($wb+[UInt64]0x0216A878)
    [UInt64]$obj=[W3ReleaseNative]::Decode24371Object($g)
    if($obj-lt[UInt64]0x10000 -or $obj-ge[UInt64]0x0000800000000000){return $null}
    return (New-Object PSObject -Property @{Loader=$wb;Global=$g;Object=$obj})
}

function Probe-NewCandidateObject($p,[IntPtr]$h,[long]$ms,[bool]$forceLog){
    try{
        $d=Decode24371Object $p $h
        if($null-eq$d){return $false}
        [UInt64]$obj=[UInt64]$d.Object
        [UInt32]$raw=ReadU32Remote $h ($obj+[UInt64]0x6C)
        [UInt32]$v68=ReadU32Remote $h ($obj+[UInt64]0x68)
        [UInt32]$v70=ReadU32Remote $h ($obj+[UInt64]0x70)
        [UInt32]$stored=[W3ReleaseNative]::Decode24371StoredTick($raw)
        [UInt32]$round=[W3ReleaseNative]::Encode24371StoredTick($stored)
        [UInt32]$osTick=[W3ReleaseNative]::GetTickCount()
        [UInt64]$osTick64=[W3ReleaseNative]::GetTickCount64()
        [UInt32]$age=Sub32 $osTick $stored

        if(-not$script:NewObjHave){
            $script:NewObj=$obj
            $script:NewObjLast=$raw
            $script:NewObjHave=$true
            $script:NewObjFirstMs=$ms
            O ('24371_OBJECT_INITIAL t={0}ms obj=0x{1:X16} raw6C=0x{2:X8} object68=0x{3:X8} object70=0x{4:X8} global216A878=0x{5:X16}' -f
                $ms,$obj,$raw,$v68,$v70,[UInt64]$d.Global)
            O ('24371_TIMEBASE_INITIAL storedTick=0x{0:X8}({1}ms) osGetTickCount=0x{2:X8}({3}ms) age=0x{4:X8}({5}ms) encodeRoundTrip=0x{6:X8} exact={7} GetTickCount64={8}' -f
                $stored,[UInt64]$stored,$osTick,[UInt64]$osTick,$age,[UInt64]$age,$round,($round-eq$raw),$osTick64)
        }elseif($obj-ne$script:NewObj){
            O ('24371_OBJECT_POINTER_CHANGED t={0}ms old=0x{1:X16} new=0x{2:X16}' -f $ms,$script:NewObj,$obj)
            $script:NewObj=$obj
            $script:NewObjLast=$raw
            $script:NewObjChanges++
        }elseif($raw-ne$script:NewObjLast){
            O ('24371_OBJECT_6C_CHANGE t={0}ms obj=0x{1:X16} old=0x{2:X8} new=0x{3:X8}' -f $ms,$obj,$script:NewObjLast,$raw)
            O ('24371_TIMEBASE_CHANGE storedTick=0x{0:X8}({1}ms) osGetTickCount=0x{2:X8}({3}ms) ageMs={4}' -f
                $stored,[UInt64]$stored,$osTick,[UInt64]$osTick,[UInt64]$age)
            $script:NewObjLast=$raw
            $script:NewObjChanges++
        }elseif($forceLog){
            O ('24371_OBJECT_HEARTBEAT t={0}ms obj=0x{1:X16} raw6C=0x{2:X8} object68=0x{3:X8} object70=0x{4:X8} changes={5}' -f
                $ms,$obj,$raw,$v68,$v70,$script:NewObjChanges)
            O ('24371_TIMEBASE_HEARTBEAT storedTick=0x{0:X8}({1}ms) osGetTickCount=0x{2:X8}({3}ms) ageMs={4} roundTripExact={5}' -f
                $stored,[UInt64]$stored,$osTick,[UInt64]$osTick,[UInt64]$age,($round-eq$raw))
        }
        return $true
    }catch{
        if($forceLog){O ('24371_OBJECT_PROBE_ERROR t={0}ms {1}' -f $ms,$_.Exception.Message)}
        return $false
    }
}

$script:TimebasePatchApplied=$false
$script:TimebasePatchObject=[UInt64]0
$script:TimebasePatchAddr=[UInt64]0
$script:TimebasePatchOriginalRaw=[UInt32]0
$script:TimebasePatchNewRaw=[UInt32]0
$script:TimebasePatchStoredTick=[UInt32]0
$script:TimebasePatchExpectedTick=[UInt32]0
$script:TimebasePatchAge=[UInt32]0
$script:TimebasePatchMs=[long]-1
$script:TimebasePatchProbeLastMs=[long]-10000

function Try-TimebaseRefreshPatch($p,[IntPtr]$h,[long]$ms,[bool]$forceLog){
    if($script:TimebasePatchApplied){return $true}
    try{
        $d=Decode24371Object $p $h
        if($null-eq$d){
            if($forceLog){O ('24371_TIMEBASE_PATCH_WAIT t={0}ms reason=object-not-available' -f $ms)}
            return $false
        }

        [UInt64]$obj=[UInt64]$d.Object
        [UInt64]$addr=$obj+[UInt64]0x6C
        [UInt32]$raw=ReadU32Remote $h $addr
        [UInt32]$stored=[W3ReleaseNative]::Decode24371StoredTick($raw)
        [UInt32]$round=[W3ReleaseNative]::Encode24371StoredTick($stored)
        if($round-ne$raw){
            if($forceLog){O ('24371_TIMEBASE_PATCH_WAIT t={0}ms reason=raw-transform-roundtrip-mismatch raw=0x{1:X8} round=0x{2:X8}' -f $ms,$raw,$round)}
            return $false
        }

        [UInt32]$nowTick=[W3ReleaseNative]::GetTickCount()
        [UInt64]$nowTick64=[W3ReleaseNative]::GetTickCount64()
        [UInt32]$age=Sub32 $nowTick $stored

        if($forceLog -or (($ms-$script:TimebasePatchProbeLastMs)-ge1000)){
            $script:TimebasePatchProbeLastMs=$ms
            O ('24371_TIMEBASE_PATCH_PROBE t={0}ms obj=0x{1:X16} raw6C=0x{2:X8} storedTick=0x{3:X8}({4}ms) currentTick=0x{5:X8}({6}ms) age=0x{7:X8}({8}ms) GetTickCount64={9}' -f
                $ms,$obj,$raw,$stored,[UInt64]$stored,$nowTick,[UInt64]$nowTick,$age,[UInt64]$age,$nowTick64)
        }

        if($age-lt[UInt32]1000 -or $age-gt[UInt32]120000){
            if($forceLog){O ('24371_TIMEBASE_PATCH_WAIT t={0}ms reason=age-out-of-guard-range ageMs={1}' -f $ms,[UInt64]$age)}
            return $false
        }

        [UInt32]$newRaw=[W3ReleaseNative]::Encode24371StoredTick($nowTick)
        [UInt32]$newDecoded=[W3ReleaseNative]::Decode24371StoredTick($newRaw)
        if($newDecoded-ne$nowTick){
            throw ('24371 encoder self-check failed encoded=0x{0:X8} decoded=0x{1:X8} expected=0x{2:X8}' -f $newRaw,$newDecoded,$nowTick)
        }

        O ('24371_TIMEBASE_PATCH_GUARD_PASS=True t={0}ms object=0x{1:X16} oldRaw=0x{2:X8} oldDecodedTick=0x{3:X8} currentTick=0x{4:X8} ageMs={5} newRaw=0x{6:X8}' -f
            $ms,$obj,$raw,$stored,$nowTick,[UInt64]$age,$newRaw)
        O '24371_TIMEBASE_ALGEBRA=storedTick = raw6C XOR 0x79578000; refreshedRaw = currentTick XOR 0x79578000'

        WriteRemote $h ([Int64]$addr) ([BitConverter]::GetBytes([UInt32]$newRaw))
        [UInt32]$verifyRaw=ReadU32Remote $h $addr
        [UInt32]$verifyTick=[W3ReleaseNative]::Decode24371StoredTick($verifyRaw)
        if($verifyRaw-ne$newRaw -or $verifyTick-ne$nowTick){
            throw ('24371 timebase refresh readback mismatch raw=0x{0:X8} decoded=0x{1:X8}' -f $verifyRaw,$verifyTick)
        }

        $script:TimebasePatchApplied=$true
        $script:TimebasePatchObject=$obj
        $script:TimebasePatchAddr=$addr
        $script:TimebasePatchOriginalRaw=$raw
        $script:TimebasePatchNewRaw=$newRaw
        $script:TimebasePatchStoredTick=$stored
        $script:TimebasePatchExpectedTick=$nowTick
        $script:TimebasePatchAge=$age
        $script:TimebasePatchMs=$ms

        $script:NewObj=$obj
        $script:NewObjLast=$newRaw
        $script:NewObjHave=$true

        O ('24371_TIMEBASE_REFRESH_PATCH_APPLIED=True t={0}ms addr=0x{1:X16} oldRaw=0x{2:X8} newRaw=0x{3:X8} oldDecodedTick=0x{4:X8} refreshedTick=0x{5:X8} ageRemovedMs={6} bytes=4 codePatched=False' -f
            $ms,$addr,$raw,$newRaw,$stored,$nowTick,[UInt64]$age)
        return $true
    }catch{
        $msg=$_.Exception.Message
        if($msg -like '*readback mismatch*' -or $msg -like '*self-check failed*'){throw}
        if($forceLog){O ('24371_TIMEBASE_PATCH_PROBE_ERROR t={0}ms {1}' -f $ms,$msg)}
        return $false
    }
}


$script:HeartbeatWrites=[long]0
$script:HeartbeatLastWriteMs=[long]-1
$script:HeartbeatLastAge=[UInt32]0
$script:HeartbeatLastObj=[UInt64]0
$script:HeartbeatLastRaw=[UInt32]0
$script:HeartbeatLastTick=[UInt32]0

function Maintain-TimebaseHeartbeat($p,[IntPtr]$h,[long]$ms,[bool]$forceLog){
    $d=Decode24371Object $p $h
    if($null-eq$d){
        if($forceLog){O ('24371_HEARTBEAT_WAIT t={0}ms reason=object-not-available' -f $ms)}
        return $false
    }

    [UInt64]$obj=[UInt64]$d.Object
    [UInt64]$addr=$obj+[UInt64]0x6C
    [UInt32]$v68=ReadU32Remote $h ($obj+[UInt64]0x68)
    [UInt32]$v70=ReadU32Remote $h ($obj+[UInt64]0x70)

    # Revalidate the stable neighboring fields observed in the v4/v5b/v6b captures.
    # PowerShell 2 safety: 0x9D3F7240 is written as decimal UInt32
    # because the hex literal is first parsed as signed Int32 (-1656786368).
    if($v68-ne[UInt32]0x0000004E -or $v70-ne[UInt32]2638180928){
        throw ('24371_HEARTBEAT: object signature mismatch object68=0x{0:X8} object70=0x{1:X8}' -f $v68,$v70)
    }

    [UInt32]$raw=ReadU32Remote $h $addr
    [UInt32]$stored=[W3ReleaseNative]::Decode24371StoredTick($raw)
    [UInt32]$round=[W3ReleaseNative]::Encode24371StoredTick($stored)
    if($round-ne$raw){
        throw ('24371_HEARTBEAT: raw XOR round-trip mismatch raw=0x{0:X8} round=0x{1:X8}' -f $raw,$round)
    }

    [UInt32]$nowTick=[W3ReleaseNative]::GetTickCount()
    [UInt64]$nowTick64=[W3ReleaseNative]::GetTickCount64()
    [UInt32]$age=Sub32 $nowTick $stored

    $script:HeartbeatLastAge=$age
    $script:HeartbeatLastObj=$obj
    $script:HeartbeatLastRaw=$raw
    $script:HeartbeatLastTick=$stored

    if($forceLog){
        O ('24371_HEARTBEAT_STATE t={0}ms obj=0x{1:X16} raw6C=0x{2:X8} storedTick=0x{3:X8} currentTick=0x{4:X8} ageMs={5} writes={6} GetTickCount64={7}' -f
            $ms,$obj,$raw,$stored,$nowTick,[UInt64]$age,$script:HeartbeatWrites,$nowTick64)
    }

    # Keep a large safety margin below the proven 30,000 ms fatal threshold.
    if($age-lt[UInt32]10000){return $true}
    if($age-gt[UInt32]120000){
        throw ('24371_HEARTBEAT: decoded age outside guard range ageMs={0}' -f [UInt64]$age)
    }

    [UInt32]$newRaw=[W3ReleaseNative]::Encode24371StoredTick($nowTick)
    [UInt32]$newDecoded=[W3ReleaseNative]::Decode24371StoredTick($newRaw)
    if($newDecoded-ne$nowTick){
        throw ('24371_HEARTBEAT: encoder self-check failed raw=0x{0:X8} decoded=0x{1:X8} expected=0x{2:X8}' -f $newRaw,$newDecoded,$nowTick)
    }

    WriteRemote $h ([Int64]$addr) ([BitConverter]::GetBytes([UInt32]$newRaw))
    [UInt32]$verifyRaw=ReadU32Remote $h $addr
    [UInt32]$verifyTick=[W3ReleaseNative]::Decode24371StoredTick($verifyRaw)
    if($verifyRaw-ne$newRaw -or $verifyTick-ne$nowTick){
        throw ('24371_HEARTBEAT: readback mismatch raw=0x{0:X8} decoded=0x{1:X8}' -f $verifyRaw,$verifyTick)
    }

    $script:HeartbeatWrites++
    $script:HeartbeatLastWriteMs=$ms
    $script:HeartbeatLastRaw=$newRaw
    $script:HeartbeatLastTick=$nowTick
    $script:HeartbeatLastAge=[UInt32]0

    # Keep the existing watcher telemetry synchronized with our own write.
    $script:NewObj=$obj
    $script:NewObjLast=$newRaw
    $script:NewObjHave=$true

    O ('24371_TIMEBASE_HEARTBEAT_REFRESH_APPLIED=True t={0}ms obj=0x{1:X16} addr=0x{2:X16} oldRaw=0x{3:X8} oldDecodedTick=0x{4:X8} ageMs={5} newRaw=0x{6:X8} refreshedTick=0x{7:X8} writeCount={8}' -f
        $ms,$obj,$addr,$raw,$stored,[UInt64]$age,$newRaw,$nowTick,$script:HeartbeatWrites)
    return $true
}

function AnalyzeNewFatalFrame([IntPtr]$h,[UInt64]$currentRsp,[byte[]]$stk,$mods){
    O '------------------------------------------------------------------------'
    O 'TARGETED_24371_ONE_SHOT_FRAME_CORRELATION'
    O '------------------------------------------------------------------------'

    $loader=$mods | Where-Object {$_.Name -ieq 'war3_loader.dll'} | Select-Object -First 1
    if($null-eq$loader){O 'FRAME_ANALYSIS_ERROR=war3_loader module not found';return}
    [UInt64]$lb=$loader.Base
    [UInt64]$fatalRet=$lb+[UInt64]0x003973ED

    $retOff=-1
    for($i=0;$i-le($stk.Length-8);$i+=8){
        [UInt64]$q=[BitConverter]::ToUInt64($stk,$i)
        if($q-eq$fatalRet){$retOff=$i;break}
    }
    if($retOff-lt0){O ('24371_FRAME_ANCHOR_MATCH=False expectedReturn=0x{0:X16}' -f $fatalRet);return}

    [UInt64]$frameRsp=$currentRsp+[UInt64]$retOff+[UInt64]8
    O ('24371_FRAME_ANCHOR_MATCH=True fatalReturnOff=0x{0:X4} callerRSP=0x{1:X16}' -f $retOff,$frameRsp)

    try{$frame=ReadRemote $h ([Int64]$frameRsp) 0x230}
    catch{O ('24371_FRAME_READ_ERROR='+$_.Exception.Message);return}

    [UInt32]$v60=[BitConverter]::ToUInt32($frame,0x60)
    [UInt32]$v94=[BitConverter]::ToUInt32($frame,0x94)
    [UInt32]$v98=[BitConverter]::ToUInt32($frame,0x98)
    [UInt32]$v9c=[BitConverter]::ToUInt32($frame,0x9C)
    [UInt32]$va0=[BitConverter]::ToUInt32($frame,0xA0)
    [UInt64]$obj=[BitConverter]::ToUInt64($frame,0x208)
    [UInt32]$threshold=Add32 (Add32 $va0 $v98) $v9c
    [UInt32]$storedFromFrame=Sub32 $v60 $v94
    [UInt32]$osTick=[W3ReleaseNative]::GetTickCount()
    [UInt32]$captureLag=Sub32 $osTick $v60

    O ('24371_FATAL_FRAME current60=0x{0:X8} elapsed94=0x{1:X8}({2}ms) rhsThreshold=0x{3:X8}({4}ms) branchJAE={5}' -f
        $v60,$v94,[UInt64]$v94,$threshold,[UInt64]$threshold,([UInt64]$v94-ge[UInt64]$threshold))
    O ('24371_FRAME_DERIVED_STORED=current60-elapsed94=0x{0:X8}({1}ms) captureGetTickCount=0x{2:X8} captureLagMs={3}' -f
        $storedFromFrame,[UInt64]$storedFromFrame,$osTick,[UInt64]$captureLag)
    O ('24371_FRAME_OBJECT=0x{0:X16}' -f $obj)

    if($obj-ge[UInt64]0x10000 -and $obj-lt[UInt64]0x0000800000000000){
        try{
            [UInt32]$raw=ReadU32Remote $h ($obj+[UInt64]0x6C)
            [UInt32]$decoded=[W3ReleaseNative]::Decode24371StoredTick($raw)
            O ('24371_FRAME_OBJECT_6C raw=0x{0:X8} decodedStored=0x{1:X8} decodedMatchesFrameStored={2}' -f
                $raw,$decoded,($decoded-eq$storedFromFrame))
        }catch{O ('24371_FRAME_OBJECT_READ_ERROR='+$_.Exception.Message)}
    }

    if($script:TimebasePatchApplied){
        O ('24371_ONE_SHOT_CORRELATION patchObj=0x{0:X16} frameObj=0x{1:X16} sameObject={2} originalRaw=0x{3:X8} injectedRaw=0x{4:X8} injectedTick=0x{5:X8} initialAgeRemovedMs={6}' -f
            $script:TimebasePatchObject,$obj,($script:TimebasePatchObject-eq$obj),
            $script:TimebasePatchOriginalRaw,$script:TimebasePatchNewRaw,$script:TimebasePatchExpectedTick,[UInt64]$script:TimebasePatchAge)
        [UInt32]$ageFromInjected=Sub32 $v60 $script:TimebasePatchExpectedTick
        O ('24371_FRAME_AGE_FROM_INJECTED_TICK=0x{0:X8}({1}ms) fatalElapsed94=0x{2:X8} exactMatch={3}' -f
            $ageFromInjected,[UInt64]$ageFromInjected,$v94,($ageFromInjected-eq$v94))
    }
    if($script:HeartbeatWrites-gt0){
        [UInt32]$ageFromLatestHeartbeat=Sub32 $v60 $script:HeartbeatLastTick
        O ('24371_HEARTBEAT_CORRELATION writes={0} lastHeartbeatTick=0x{1:X8} lastHeartbeatRaw=0x{2:X8} frameAgeFromLatest=0x{3:X8}({4}ms) fatalElapsed94=0x{5:X8} exactMatch={6}' -f
            $script:HeartbeatWrites,$script:HeartbeatLastTick,$script:HeartbeatLastRaw,
            $ageFromLatestHeartbeat,[UInt64]$ageFromLatestHeartbeat,$v94,($ageFromLatestHeartbeat-eq$v94))
    }
    O 'TARGETED_24371_ONE_SHOT_FRAME_CORRELATION_COMPLETE=True'
}

function CaptureGuiHang($p,[IntPtr]$h){
    O '########################################################################'
    O 'NEW BUILD GUI HANG CAPTURE'
    O '########################################################################'
    try{$p.Refresh()}catch{}
    $mods=GetModuleMap $p
    foreach($mn in @('Warcraft III.exe','ClientSdk.dll','war3_loader.dll','ntdll.dll','KERNELBASE.dll','kernel32.dll')){
        $mm=$mods | Where-Object {$_.Name -ieq $mn} | Select-Object -First 1
        if($null-ne$mm){O ('MODULE {0} base=0x{1:X16} path="{2}"' -f $mm.Name,$mm.Base,$mm.Path)}
    }

    $hwnd=$p.MainWindowHandle
    O ('MAIN_HWND=0x{0:X16}' -f [UInt64]$hwnd.ToInt64())
    if($hwnd-eq[IntPtr]::Zero){O 'GUI_CAPTURE_ERROR=MainWindowHandle is NULL';return}

    [UInt32]$owner=0
    [UInt32]$tid=[W3ReleaseNative]::GetWindowThreadProcessId($hwnd,[ref]$owner)
    O ('GUI_TID={0} OWNER_PID={1}' -f $tid,$owner)
    if($tid-eq0){O 'GUI_CAPTURE_ERROR=GetWindowThreadProcessId failed';return}

    $THREAD_SUSPEND_RESUME=0x0002
    $THREAD_GET_CONTEXT=0x0008
    $THREAD_QUERY_INFORMATION=0x0040
    $CONTEXT_FULL=0x0010000B
    $CTX_SIZE=1232

    for($snap=1;$snap-le3;$snap++){
        $th=[W3ReleaseNative]::OpenThread(($THREAD_SUSPEND_RESUME-bor$THREAD_GET_CONTEXT-bor$THREAD_QUERY_INFORMATION),$false,$tid)
        if($th-eq[IntPtr]::Zero){O ('SNAPSHOT {0} OpenThread failed Win32={1}' -f $snap,[Runtime.InteropServices.Marshal]::GetLastWin32Error());return}
        $raw=[IntPtr]::Zero;$suspended=$false
        try{
            $raw=[Runtime.InteropServices.Marshal]::AllocHGlobal($CTX_SIZE+32)
            [Int64]$ctxAddr=($raw.ToInt64()+15)-band(-bnot 15)
            $ctx=[IntPtr]$ctxAddr
            for($off=0;$off-lt$CTX_SIZE;$off+=8){[Runtime.InteropServices.Marshal]::WriteInt64($ctx,$off,0)}
            [Runtime.InteropServices.Marshal]::WriteInt32($ctx,48,$CONTEXT_FULL)

            $sr=[W3ReleaseNative]::SuspendThread($th)
            if($sr-eq0xFFFFFFFF){O ('SNAPSHOT {0} SuspendThread failed Win32={1}' -f $snap,[Runtime.InteropServices.Marshal]::GetLastWin32Error());continue}
            $suspended=$true

            if(-not[W3ReleaseNative]::GetThreadContext($th,$ctx)){O ('SNAPSHOT {0} GetThreadContext failed Win32={1}' -f $snap,[Runtime.InteropServices.Marshal]::GetLastWin32Error());continue}

            [UInt64]$rax=U64FromI64([Runtime.InteropServices.Marshal]::ReadInt64($ctx,120))
            [UInt64]$rcx=U64FromI64([Runtime.InteropServices.Marshal]::ReadInt64($ctx,128))
            [UInt64]$rdx=U64FromI64([Runtime.InteropServices.Marshal]::ReadInt64($ctx,136))
            [UInt64]$rbx=U64FromI64([Runtime.InteropServices.Marshal]::ReadInt64($ctx,144))
            [UInt64]$rsp=U64FromI64([Runtime.InteropServices.Marshal]::ReadInt64($ctx,152))
            [UInt64]$rbp=U64FromI64([Runtime.InteropServices.Marshal]::ReadInt64($ctx,160))
            [UInt64]$rsi=U64FromI64([Runtime.InteropServices.Marshal]::ReadInt64($ctx,168))
            [UInt64]$rdi=U64FromI64([Runtime.InteropServices.Marshal]::ReadInt64($ctx,176))
            [UInt64]$r8 =U64FromI64([Runtime.InteropServices.Marshal]::ReadInt64($ctx,184))
            [UInt64]$r9 =U64FromI64([Runtime.InteropServices.Marshal]::ReadInt64($ctx,192))
            [UInt64]$r10=U64FromI64([Runtime.InteropServices.Marshal]::ReadInt64($ctx,200))
            [UInt64]$r11=U64FromI64([Runtime.InteropServices.Marshal]::ReadInt64($ctx,208))
            [UInt64]$r12=U64FromI64([Runtime.InteropServices.Marshal]::ReadInt64($ctx,216))
            [UInt64]$r13=U64FromI64([Runtime.InteropServices.Marshal]::ReadInt64($ctx,224))
            [UInt64]$r14=U64FromI64([Runtime.InteropServices.Marshal]::ReadInt64($ctx,232))
            [UInt64]$r15=U64FromI64([Runtime.InteropServices.Marshal]::ReadInt64($ctx,240))
            [UInt64]$rip=U64FromI64([Runtime.InteropServices.Marshal]::ReadInt64($ctx,248))
            $ripMap=MapAddr $rip $mods
            if($null-eq$ripMap){$ripMap='<not-in-loaded-module>'}

            O ('SNAPSHOT={0} RIP={1} MAP={2} RSP={3} RBP={4}' -f $snap,(Hex64 $rip),$ripMap,(Hex64 $rsp),(Hex64 $rbp))
            O ('REG RAX={0} RBX={1} RCX={2} RDX={3}' -f (Hex64 $rax),(Hex64 $rbx),(Hex64 $rcx),(Hex64 $rdx))
            O ('REG RSI={0} RDI={1} R8={2} R9={3}' -f (Hex64 $rsi),(Hex64 $rdi),(Hex64 $r8),(Hex64 $r9))
            O ('REG R10={0} R11={1} R12={2} R13={3} R14={4} R15={5}' -f (Hex64 $r10),(Hex64 $r11),(Hex64 $r12),(Hex64 $r13),(Hex64 $r14),(Hex64 $r15))

            try{
                $stk=ReadRemote $h ([Int64]$rsp) 2048
                O ('RAW_STACK_BASE={0} SIZE={1}' -f (Hex64 $rsp),$stk.Length)
                $mapped=0
                for($i=0;$i-le($stk.Length-8);$i+=8){
                    [UInt64]$q=[BitConverter]::ToUInt64($stk,$i)
                    $map=MapAddr $q $mods
                    if($null-ne$map){
                        O ('STACK_QWORD off=0x{0:X4} addr=0x{1:X16} value=0x{2:X16} map={3}' -f $i,($rsp+[UInt64]$i),$q,$map)
                        $mapped++
                        if($mapped-ge120){break}
                    }
                }
                O ('STACK_MAPPED_COUNT='+$mapped)
                if($snap-eq1){
                    AnalyzeNewFatalFrame $h $rsp $stk $mods
                }
            }catch{O ('STACK_READ_ERROR='+$_.Exception.Message)}
        }finally{
            if($suspended){[void][W3ReleaseNative]::ResumeThread($th)}
            if($raw-ne[IntPtr]::Zero){[Runtime.InteropServices.Marshal]::FreeHGlobal($raw)}
            [void][W3ReleaseNative]::CloseHandle($th)
        }
        Start-Sleep -Milliseconds 250
    }
    O 'GUI_HANG_CAPTURE_COMPLETE=True'
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

# Old-build C256 patch code intentionally removed from the 3.0.1.24371 test.

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
    O 'Warcraft III - Windows 7 3.0.1.24371 ONLINE FIX v1.2'
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
            if($count-ge1 -and $firstCallMs-lt0){
                $firstCallMs=$now
                O ('CERT_CALL_1_OK_MS='+$firstCallMs)
                [void](Probe-NewCandidateObject $game $h $now $true)
                [void](Try-TimebaseRefreshPatch $game $h $now $true)
            }
            $lastCount=$count
        }

        if($count-ge2){
            if($lastBool-ne1){throw ('Certificate call #2 returned FALSE; BOOL='+$lastBool)}
            if(-not$script:TimebasePatchApplied){
                [void](Try-TimebaseRefreshPatch $game $h $now $true)
            }
            if(-not$script:TimebasePatchApplied){
                throw 'Guarded timebase refresh was not available before certificate detach.'
            }
            O ('CERT_CALL_2_OK_MS='+$now)
            O 'CERT_AND_TIMEBASE_STAGE_PASS=True'
            break
        }

        if($count-eq0 -and $now-ge120000){throw 'Timed out waiting 120 seconds for certificate call #1.'}
        if($count-ge1 -and $firstCallMs-ge0){
            [void](Probe-NewCandidateObject $game $h $now $false)
            if((-not$script:TimebasePatchApplied) -and (($now-$script:TimebasePatchProbeLastMs)-ge100)){
                [void](Try-TimebaseRefreshPatch $game $h $now $false)
            }
            if(($now-$firstCallMs)-ge90000){throw 'Timed out waiting 90 seconds for certificate call #2 after call #1.'}
        }
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

    O 'OLD_BUILD_PATCH_SKIPPED_BY_DESIGN=True'
    O 'NO_DEBUGGER_ATTACH=True'
    O 'POST_CERT_TIMEBASE_HEARTBEAT_MONITOR_BEGIN=True'
    O 'STABILIZATION_DELAY_MS=8000 (matching old fix readiness margin after hook-page free)'
    O '24371_HEARTBEAT_POLICY=check every ~250ms; refresh only when decoded age >= 10000ms; fatal threshold proven at 30000ms'
    Save

    $post=[Diagnostics.Stopwatch]::StartNew()
    $nonResponding=0
    $responding=$true
    $hangEpisodeReported=$false
    $lastPostLog=[long]-5000
    $lastRespondingCheck=[long]-250
    $lastHeartbeatCheck=[long]-250
    $readyShown=$false

    while($true){
        $game=Get-Process -Id $gamePid -ErrorAction SilentlyContinue
        if($null-eq$game){
            O ('WARCRAFT_EXIT=True postCertMs={0} heartbeatWrites={1}' -f $post.ElapsedMilliseconds,$script:HeartbeatWrites)
            break
        }

        # Lightweight maintenance: no debugger, no stack scan, no window switching.
        if(($post.ElapsedMilliseconds-$lastHeartbeatCheck)-ge250){
            $lastHeartbeatCheck=$post.ElapsedMilliseconds
            try{
                [void](Maintain-TimebaseHeartbeat $game $h $post.ElapsedMilliseconds $false)
            }catch{
                # During normal teardown the loader/object may disappear just before the process.
                $hbException=$_.Exception
                $gone=$false
                for($ep=0;$ep-lt40;$ep++){
                    Start-Sleep -Milliseconds 50
                    $still=Get-Process -Id $gamePid -ErrorAction SilentlyContinue
                    if($null-eq$still){$gone=$true;break}
                    try{if($still.HasExited){$gone=$true;break}}catch{$gone=$true;break}
                }
                if($gone){
                    O ('WARCRAFT_EXIT_TEARDOWN_RACE_HANDLED=True postCertMs={0} heartbeatWrites={1} message="{2}"' -f
                        $post.ElapsedMilliseconds,$script:HeartbeatWrites,$hbException.Message)
                    break
                }
                throw $hbException
            }
        }

        if((-not$readyShown) -and $post.ElapsedMilliseconds-ge8000){
            if(-not$script:TimebasePatchApplied){throw 'Initial timebase refresh was lost before READY.'}
            $readyShown=$true
            $ready=$true
            O ('24371_TIMEBASE_HEARTBEAT_READY=True object=0x{0:X16} initialOriginalRaw=0x{1:X8} initialRefreshedRaw=0x{2:X8} initialRemovedAgeMs={3} maintenanceWrites={4}' -f
                $script:TimebasePatchObject,$script:TimebasePatchOriginalRaw,$script:TimebasePatchNewRaw,
                [UInt64]$script:TimebasePatchAge,$script:HeartbeatWrites)
            Save
            Status 'WARCRAFT III WIN7 FIX ACTIVE - ONLINE READY' $true 2600
        }

        if(($post.ElapsedMilliseconds-$lastRespondingCheck)-ge250){
            $lastRespondingCheck=$post.ElapsedMilliseconds
            try{$responding=[bool]$game.Responding}catch{}
            if($responding){
                if($hangEpisodeReported){
                    O ('POST_CERT_UI_HANG_ENDED=True t={0}ms maintenanceWrites={1}' -f $post.ElapsedMilliseconds,$script:HeartbeatWrites)
                    $hangEpisodeReported=$false
                }
                $nonResponding=0
            }else{$nonResponding++}
        }

        if(($post.ElapsedMilliseconds-$lastPostLog)-ge5000){
            $lastPostLog=$post.ElapsedMilliseconds
            [void](Maintain-TimebaseHeartbeat $game $h $post.ElapsedMilliseconds $true)
            O ('POST_CERT_HEARTBEAT t={0}ms Responding={1} consecutiveNonResponding={2} maintenanceWrites={3} lastAgeMs={4}' -f
                $post.ElapsedMilliseconds,$responding,$nonResponding,$script:HeartbeatWrites,[UInt64]$script:HeartbeatLastAge)
            Save
        }

        # Telemetry only: never stop the guarded heartbeat for a hung UI.
        # Isolated or prolonged loading stalls are not proof of a fatal deadlock.
        if($nonResponding-ge32 -and -not$hangEpisodeReported){
            $hangEpisodeReported=$true
            O ('POST_CERT_UI_HANG_OBSERVED=True t={0}ms maintenanceWrites={1}; heartbeat-continues=True' -f $post.ElapsedMilliseconds,$script:HeartbeatWrites)
            Save
        }

        Start-Sleep -Milliseconds 25
    }

}
catch{
    $exitCode=1
    O ('ERROR: '+$_.Exception.GetType().FullName+': '+$_.Exception.Message)
    try{Save}catch{}
    try{Status ('WAR3 24371 ONLINE FIX ERROR - SEE TXT LOG') $false 4500}catch{}
}
finally{
    if($h-ne[IntPtr]::Zero){
        if((-not$ready) -and $script:TimebasePatchApplied -and $script:TimebasePatchAddr-ne0){
            try{
                [UInt32]$curRaw=ReadU32Remote $h $script:TimebasePatchAddr
                if($curRaw-eq$script:TimebasePatchNewRaw){
                    WriteRemote $h ([Int64]$script:TimebasePatchAddr) ([BitConverter]::GetBytes([UInt32]$script:TimebasePatchOriginalRaw))
                    O 'CLEANUP_TIMEBASE_ORIGINAL_RESTORED_BECAUSE_NOT_READY=True'
                }else{
                    O ('CLEANUP_TIMEBASE_RESTORE_SKIPPED=current-value-changed 0x{0:X8}' -f $curRaw)
                }
            }catch{O ('CLEANUP_TIMEBASE_RESTORE_ERROR='+$_.Exception.Message)}
        }
        if($iatPatched -and $iatAddr-ne0 -and $origPtr-ne0){
            try{
                WriteIatPointer $h $iatAddr $origPtr
                O 'CLEANUP_IAT_RESTORED=True'
                $iatPatched=$false
            }catch{O ('CLEANUP_IAT_RESTORE_ERROR='+$_.Exception.Message)}
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
