@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>&1
color 0B
title Warcraft III 3.0 World Editor - Windows 7 Fix v1.1

echo ================================================================
echo Warcraft III 3.0 World Editor - Windows 7 Fix v1.1
echo ================================================================
echo One-click dummy-map SHELL OPEN + guarded encoded-timebase heartbeat.
echo.
echo This release:
echo   - opens bundled dummy.w3m through the normal Windows file association
echo   - does NOT launch World Editor.exe directly
echo   - Battle.net MAY remain open
echo   - verifies the exact October 2026 World Editor / worldedit_loader hashes
echo   - validates the regenerated timebase object and 0x909 signature
echo   - refreshes exactly 4 process-local DATA bytes only when needed
echo   - modifies no World Editor, Warcraft III, DLL, or map file on disk
echo.
echo Close any already-running World Editor first.
echo After launch, stay in the editor. A green overlay will appear when the fix is active.
echo.

set "WE_ROOT=%~dp0"
set "WE_REPORT=%~dp0WORLD_EDITOR_WIN7_FIX_v1.1.txt"
set "WE_PS1=%TEMP%\WE300_W7_FIX_v1_1_%RANDOM%_%RANDOM%.ps1"
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

"%WE_POWERSHELL%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%WE_PS1%"
set "WE_RC=%ERRORLEVEL%"
del /q "%WE_PS1%" >nul 2>&1

if not "%WE_RC%"=="0" (
  echo.
  echo Test stopped with code %WE_RC%.
  echo Report: "%WE_REPORT%"
  echo.
  pause
)
exit /b %WE_RC%

#PS1_BEGIN
$ErrorActionPreference='Stop'

$ExpectedExeSha='f46f0a72d32cbdd366f4a0f7de54d35ad2ccad9d00e23749269910afd75c34e3'
$ExpectedLoaderSha='aefd841b006117d11582b018031fe9d7a2c8f48150c688e54f1c64b7f66c67cd'
$ExpectedDummySha='77b4313c9a7498eb3a49a7b4228885f8080b61a369006888c29e5486a8533088'

$Root=$env:WE_ROOT
$Report=$env:WE_REPORT
$IniPath=Join-Path $Root 'WorldEditorFix.ini'
$DummyPath=Join-Path $Root 'dummy.w3m'
$ready=$false

function O([string]$s){
    $s | Out-File -LiteralPath $Report -Encoding UTF8 -Append
    Write-Host $s
}
function Save {}

function Get-Sha256([string]$Path){
    $sha=New-Object System.Security.Cryptography.SHA256CryptoServiceProvider
    $fs=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    try{
        return ([BitConverter]::ToString($sha.ComputeHash($fs))).Replace('-','').ToLowerInvariant()
    }finally{
        $fs.Close()
        $sha.Clear()
    }
}
function Read-IniPath([string]$Path){
    if(-not(Test-Path -LiteralPath $Path)){return ''}
    foreach($line in [IO.File]::ReadAllLines($Path)){
        $t=$line.Trim()
        if($t.Length-eq0 -or $t.StartsWith(';') -or $t.StartsWith('#')){continue}
        if($t.StartsWith('WorldEditorPath=',[StringComparison]::OrdinalIgnoreCase)){
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

public static class WETBWin32
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

    [DllImport("kernel32.dll")]
    public static extern uint GetTickCount();

    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool IsHungAppWindow(IntPtr hWnd);

    public static ulong DecodeObject(ulong g218b878, ulong g20df278)
    {
        unchecked
        {
            ulong x=(g20df278 ^ 0x10ADFFD4851EEA22UL);
            x=x-g20df278+0x5488CB87A2C1A6B0UL;
            return x ^ g218b878;
        }
    }
}
'@
Add-Type -TypeDefinition $native -Language CSharp -ErrorAction Stop

$overlay=@'
using System;
using System.Drawing;
using System.Threading;
using System.Windows.Forms;

public sealed class WEOverlayForm : Form
{
    protected override bool ShowWithoutActivation { get { return true; } }
    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cp=base.CreateParams;
            cp.ExStyle |= 0x08000000;
            cp.ExStyle |= 0x00000080;
            return cp;
        }
    }
}

public static class WEOverlay
{
    public static bool ShowStatus(string text, bool ok, int milliseconds)
    {
        try
        {
            Thread t=new Thread(delegate()
            {
                WEOverlayForm f=new WEOverlayForm();
                f.FormBorderStyle=FormBorderStyle.FixedToolWindow;
                f.StartPosition=FormStartPosition.Manual;
                f.ShowInTaskbar=false;
                f.TopMost=true;
                f.Width=680;
                f.Height=90;
                Rectangle wa=Screen.PrimaryScreen.WorkingArea;
                f.Left=wa.Left+(wa.Width-f.Width)/2;
                f.Top=wa.Top+40;
                f.BackColor=ok ? Color.FromArgb(25,80,35) : Color.FromArgb(110,25,25);
                Label l=new Label();
                l.Dock=DockStyle.Fill;
                l.TextAlign=ContentAlignment.MiddleCenter;
                l.ForeColor=Color.White;
                l.Font=new Font("Segoe UI",12.0f,FontStyle.Bold);
                l.Text=text;
                f.Controls.Add(l);
                System.Windows.Forms.Timer timer=new System.Windows.Forms.Timer();
                timer.Interval=Math.Max(250,milliseconds);
                timer.Tick+=delegate(object sender,EventArgs e){timer.Stop();f.Close();};
                f.Shown+=delegate(object sender,EventArgs e){timer.Start();};
                Application.Run(f);
                timer.Dispose();
                f.Dispose();
            });
            t.SetApartmentState(ApartmentState.STA);
            t.IsBackground=false;
            t.Start();
            return true;
        }
        catch{return false;}
    }
}
'@
$script:OverlayAvailable=$false
try{
    Add-Type -TypeDefinition $overlay -Language CSharp -ReferencedAssemblies @('System.Windows.Forms.dll','System.Drawing.dll') -ErrorAction Stop
    $script:OverlayAvailable=$true
}catch{}

function Status([string]$text,[bool]$ok,[int]$ms){
    O ('STATUS='+$text)
    if($script:OverlayAvailable){try{[void][WEOverlay]::ShowStatus($text,$ok,$ms)}catch{}}
}

$script:U32Mask=[UInt64]4294967295
$script:U32Mod=[UInt64]4294967296
function Sub32([UInt32]$a,[UInt32]$b){
    [UInt64]$x=[UInt64]$a+$script:U32Mod-[UInt64]$b
    return [UInt32]($x -band $script:U32Mask)
}
function Xor32([UInt32]$a,[UInt32]$b){
    [UInt64]$x=([UInt64]$a -bxor [UInt64]$b)
    return [UInt32]($x -band $script:U32Mask)
}
function Read-Remote([IntPtr]$h,[UInt64]$addr,[int]$size){
    if($addr-lt[UInt64]0x10000){throw ('invalid remote address 0x{0:X16}' -f $addr)}
    $buf=New-Object byte[] $size
    $got=[IntPtr]::Zero
    $ok=[WETBWin32]::ReadProcessMemory($h,[IntPtr]([Int64]$addr),$buf,$size,[ref]$got)
    if(-not$ok -or $got.ToInt64()-ne$size){
        throw ('ReadProcessMemory failed at 0x{0:X16} size={1} got={2} Win32={3}' -f $addr,$size,$got.ToInt64(),[Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
    return $buf
}
function Write-Remote4([IntPtr]$h,[UInt64]$addr,[UInt32]$value){
    $buf=[BitConverter]::GetBytes($value)
    $put=[IntPtr]::Zero
    $ok=[WETBWin32]::WriteProcessMemory($h,[IntPtr]([Int64]$addr),$buf,4,[ref]$put)
    if(-not$ok -or $put.ToInt64()-ne4){
        throw ('WriteProcessMemory failed at 0x{0:X16} wrote={1} Win32={2}' -f $addr,$put.ToInt64(),[Runtime.InteropServices.Marshal]::GetLastWin32Error())
    }
}
function Read-U32([IntPtr]$h,[UInt64]$addr){return [BitConverter]::ToUInt32((Read-Remote $h $addr 4),0)}
function Read-U64([IntPtr]$h,[UInt64]$addr){return [BitConverter]::ToUInt64((Read-Remote $h $addr 8),0)}
function Get-LoaderBase($p){
    try{
        $p.Refresh()
        $m=$p.Modules | Where-Object {$_.ModuleName -ieq 'worldedit_loader.dll'} | Select-Object -First 1
        if($null-eq$m){return [UInt64]0}
        return [UInt64]$m.BaseAddress.ToInt64()
    }catch{return [UInt64]0}
}

function Resolve-TimebaseState($p,[IntPtr]$h){
    [UInt64]$lb=Get-LoaderBase $p
    if($lb-eq0){return $null}

    [UInt64]$g1=Read-U64 $h ($lb+[UInt64]0x0218B878)
    [UInt64]$g2=Read-U64 $h ($lb+[UInt64]0x020DF278)
    [UInt64]$obj=[WETBWin32]::DecodeObject($g1,$g2)
    if($obj-lt[UInt64]0x10000 -or $obj-ge[UInt64]0x0000800000000000){return $null}

    [UInt32]$raw=Read-U32 $h ($obj+[UInt64]0x2C)
    [UInt32]$v60=Read-U32 $h ($obj+[UInt64]0x60)
    [UInt32]$sig=Xor32 $v60 ([UInt32]803475063)
    if($sig-ne[UInt32]2313){return $null}

    [UInt32]$key=[UInt32]4281932680
    [UInt32]$stored=Xor32 $raw $key
    [UInt32]$now=[WETBWin32]::GetTickCount()
    [UInt32]$age=Sub32 $now $stored

    return (New-Object PSObject -Property @{
        LoaderBase=$lb; Object=$obj; Address=($obj+[UInt64]0x2C);
        Raw=$raw; StoredTick=$stored; CurrentTick=$now; Age=$age;
        V60=$v60; Signature=$sig
    })
}

$script:TimebaseReady=$false
$script:TimebaseObject=[UInt64]0
$script:TimebaseAddr=[UInt64]0
$script:InitialAge=[UInt32]0
$script:LastRaw=[UInt32]0
$script:Writes=[long]0

function Initialize-Timebase($p,[IntPtr]$h,[long]$t,[bool]$strict){
    if($script:TimebaseReady){return $true}
    try{$s=Resolve-TimebaseState $p $h}catch{if($strict){throw};return $false}
    if($null-eq$s){return $false}
    if([UInt32]$s.Age-gt[UInt32]120000){
        if($strict){throw ('Initial decoded timebase age outside guard range: '+[UInt64][UInt32]$s.Age+' ms')}
        return $false
    }

    $script:TimebaseObject=[UInt64]$s.Object
    $script:TimebaseAddr=[UInt64]$s.Address
    $script:InitialAge=[UInt32]$s.Age

    if([UInt32]$s.Age-lt[UInt32]1000){
        $script:LastRaw=[UInt32]$s.Raw
        $script:TimebaseReady=$true
        O ('TIMEBASE_INITIAL_ALREADY_FRESH=True t={0}ms loader=0x{1:X16} obj=0x{2:X16} ageMs={3}' -f $t,[UInt64]$s.LoaderBase,[UInt64]$s.Object,[UInt64][UInt32]$s.Age)
        return $true
    }

    [UInt32]$key=[UInt32]4281932680
    [UInt32]$newRaw=Xor32 ([UInt32]$s.CurrentTick) $key
    Write-Remote4 $h ([UInt64]$s.Address) $newRaw
    [UInt32]$verify=Read-U32 $h ([UInt64]$s.Address)
    if($verify-ne$newRaw){throw 'Initial 4-byte timebase refresh did not verify exactly.'}

    $script:LastRaw=$newRaw
    $script:TimebaseReady=$true
    O ('TIMEBASE_INITIAL_REFRESH=True t={0}ms loader=0x{1:X16} obj=0x{2:X16} addr=0x{3:X16} ageRemovedMs={4} oldRaw=0x{5:X8} newRaw=0x{6:X8} bytes=4 codePatched=False' -f
        $t,[UInt64]$s.LoaderBase,[UInt64]$s.Object,[UInt64]$s.Address,[UInt64][UInt32]$s.Age,[UInt32]$s.Raw,$newRaw)
    return $true
}

function Maintain-Timebase($p,[IntPtr]$h,[long]$t){
    $s=Resolve-TimebaseState $p $h
    if($null-eq$s){throw 'Validated World Editor timebase object/signature is no longer available.'}
    if([UInt32]$s.Age-lt[UInt32]10000){return}
    if([UInt32]$s.Age-gt[UInt32]120000){throw ('World Editor timebase age outside guard range: '+[UInt64][UInt32]$s.Age+' ms')}

    [UInt32]$key=[UInt32]4281932680
    [UInt32]$newRaw=Xor32 ([UInt32]$s.CurrentTick) $key
    Write-Remote4 $h ([UInt64]$s.Address) $newRaw
    [UInt32]$verify=Read-U32 $h ([UInt64]$s.Address)
    if($verify-ne$newRaw){throw 'Heartbeat 4-byte timebase refresh did not verify exactly.'}

    $script:LastRaw=$newRaw
    $script:TimebaseObject=[UInt64]$s.Object
    $script:TimebaseAddr=[UInt64]$s.Address
    $script:Writes++
    O ('TIMEBASE_HEARTBEAT_REFRESH=True t={0}ms ageMs={1} writeCount={2}' -f $t,[UInt64][UInt32]$s.Age,$script:Writes)
}

'' | Out-File -LiteralPath $Report -Encoding UTF8
O 'Warcraft III 3.0 World Editor - Windows 7 Fix v1.1'
O '================================================================='
O ('DATE={0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'))
O ('PowerShell IntPtr.Size={0}' -f [IntPtr]::Size)
O ('OS={0}' -f [Environment]::OSVersion.VersionString)
O 'STATIC_BASIS=October 2026 worldedit_loader .text and .data match the validated Warcraft III v1.1 loader implementation'
O 'MODE=ShellOpen dummy.w3m + guarded encoded-timebase heartbeat / Battle.net optional'

if([IntPtr]::Size-ne8){O 'FATAL=64-bit PowerShell required.';Status 'WORLD EDITOR FIX ERROR - SEE TXT LOG' $false 3500;exit 10}

try{$ExePath=Resolve-WorldEditorPath}catch{O ('FATAL='+$_.Exception.Message);Status 'WORLD EDITOR FIX ERROR - SEE TXT LOG' $false 3500;exit 11}
$LoaderPath=Join-Path (Split-Path -Parent $ExePath) 'worldedit_loader.dll'

O ('EXE='+$ExePath)
O ('LOADER='+$LoaderPath)
O ('DUMMY='+$DummyPath)

if(-not(Test-Path -LiteralPath $LoaderPath -PathType Leaf)){O 'FATAL=worldedit_loader.dll not found next to World Editor.exe.';Status 'WORLD EDITOR FIX ERROR - SEE TXT LOG' $false 3500;exit 12}
if(-not(Test-Path -LiteralPath $DummyPath -PathType Leaf)){O 'FATAL=dummy.w3m missing.';Status 'WORLD EDITOR FIX ERROR - SEE TXT LOG' $false 3500;exit 13}

$exeSha=Get-Sha256 $ExePath
$loaderSha=Get-Sha256 $LoaderPath
$dummySha=Get-Sha256 $DummyPath
O ('WorldEditor_SHA256='+$exeSha)
O ('worldedit_loader_SHA256='+$loaderSha)
O ('dummy_SHA256='+$dummySha)

if($exeSha-ne$ExpectedExeSha -or $loaderSha-ne$ExpectedLoaderSha -or $dummySha-ne$ExpectedDummySha){
    O 'FATAL=Exact October 2026 World Editor / loader / dummy hashes do not match. No memory was written.'
    Status 'WORLD EDITOR FIX HASH MISMATCH - NO WRITE' $false 4000
    exit 14
}
O 'HASH_GUARD_PASS=True'

$existing=@(Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.ProcessName -eq 'World Editor'})
if($existing.Count-gt0){
    O 'FATAL=World Editor already running. Close it before this launcher.'
    Status 'CLOSE WORLD EDITOR AND RUN THE FIX AGAIN' $false 3500
    exit 15
}
$bn=@(Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.ProcessName -eq 'Battle.net'})
O ('BATTLE_NET_RUNNING_AT_LAUNCH='+($bn.Count-gt0))
O 'BATTLE_NET_DEPENDENCY=False'

$before=@{}
@(Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.ProcessName -eq 'World Editor'}) | ForEach-Object {$before[$_.Id]=$true}
O ('SHELL_OPEN_TARGET="'+$DummyPath+'"')
try{Start-Process -FilePath $DummyPath}catch{O ('FATAL=ShellOpen failed: '+$_.Exception.Message);Status 'WORLD EDITOR FIX ERROR - SEE TXT LOG' $false 3500;exit 16}

$p=$null
$attachDeadline=(Get-Date).AddSeconds(60)
while((Get-Date)-lt$attachDeadline){
    foreach($cand in @(Get-Process -ErrorAction SilentlyContinue | Where-Object {$_.ProcessName -eq 'World Editor'})){
        if($before.ContainsKey($cand.Id)){continue}
        $path=$null
        try{$path=[string]$cand.MainModule.FileName}catch{}
        if(-not[String]::IsNullOrEmpty($path) -and $path-ieq$ExePath){$p=$cand;break}
    }
    if($null-ne$p){break}
    Start-Sleep -Milliseconds 100
}
if($null-eq$p){O 'FATAL=No validated World Editor process appeared after ShellOpen.';Status 'WORLD EDITOR FIX ERROR - SEE TXT LOG' $false 3500;exit 17}
O ('ATTACHED_PID='+$p.Id)

$PROCESS_QUERY_INFORMATION=0x0400
$PROCESS_VM_READ=0x0010
$PROCESS_VM_WRITE=0x0020
$PROCESS_VM_OPERATION=0x0008
$ph=[WETBWin32]::OpenProcess(($PROCESS_QUERY_INFORMATION-bor$PROCESS_VM_READ-bor$PROCESS_VM_WRITE-bor$PROCESS_VM_OPERATION),$false,$p.Id)
if($ph-eq[IntPtr]::Zero){O ('FATAL=OpenProcess failed Win32='+[Runtime.InteropServices.Marshal]::GetLastWin32Error());Status 'WORLD EDITOR FIX ERROR - SEE TXT LOG' $false 3500;exit 18}

try{
    $sw=[Diagnostics.Stopwatch]::StartNew()
    O 'TIMEBASE_WAIT_BEGIN=True'
    while($sw.ElapsedMilliseconds-lt120000 -and -not$script:TimebaseReady){
        try{
            $p.Refresh()
            if($p.HasExited){O ('FATAL=World Editor exited before timebase became available. ExitCode='+$p.ExitCode);exit 19}
        }catch{}
        [void](Initialize-Timebase $p $ph $sw.ElapsedMilliseconds $false)
        if(-not$script:TimebaseReady){Start-Sleep -Milliseconds 50}
    }
    if(-not$script:TimebaseReady){
        O 'FATAL=Validated timebase object/signature did not appear within 120 seconds. No unsupported write was used.'
        Status 'WORLD EDITOR FIX COULD NOT VALIDATE TIMEBASE' $false 4000
        exit 20
    }

    # Maintain during a short stabilization window before declaring READY.
    $stab=[Diagnostics.Stopwatch]::StartNew()
    $lastCheck=[long]-250
    while($stab.ElapsedMilliseconds-lt3000){
        $p=Get-Process -Id $p.Id -ErrorAction SilentlyContinue
        if($null-eq$p){O 'FATAL=World Editor exited during stabilization.';exit 21}
        if(($stab.ElapsedMilliseconds-$lastCheck)-ge250){
            $lastCheck=$stab.ElapsedMilliseconds
            Maintain-Timebase $p $ph $sw.ElapsedMilliseconds
        }
        Start-Sleep -Milliseconds 25
    }

    $ready=$true
    O ('READY=True object=0x{0:X16} initialAgeMs={1} heartbeatThresholdMs=10000 fatalThresholdMs=30000' -f $script:TimebaseObject,[UInt64]$script:InitialAge)
    Status 'WORLD EDITOR WIN7 FIX ACTIVE - USE THE EDITOR NORMALLY' $true 3000

    $lastBeat=[long]-250
    $lastLog=[long]-5000
    $hangCount=0
    $shutdownRace=$false

    while($true){
        $cur=Get-Process -Id $p.Id -ErrorAction SilentlyContinue
        if($null-eq$cur){break}
        $p=$cur

        if(($sw.ElapsedMilliseconds-$lastBeat)-ge250){
            $lastBeat=$sw.ElapsedMilliseconds
            try{
                Maintain-Timebase $p $ph $sw.ElapsedMilliseconds
            }catch{
                $e=$_.Exception
                $gone=$false
                for($i=0;$i-lt40;$i++){
                    Start-Sleep -Milliseconds 50
                    $still=Get-Process -Id $p.Id -ErrorAction SilentlyContinue
                    if($null-eq$still){$gone=$true;break}
                    try{if($still.HasExited){$gone=$true;break}}catch{$gone=$true;break}
                }
                if($gone){
                    $shutdownRace=$true
                    O ('PROCESS_EXIT_TEARDOWN_RACE_HANDLED=True message="'+$e.Message+'"')
                    break
                }
                throw $e
            }
        }

        $hung=$false
        try{
            $p.Refresh()
            if($p.MainWindowHandle-ne[IntPtr]::Zero){$hung=[WETBWin32]::IsHungAppWindow($p.MainWindowHandle)}
        }catch{}
        if($hung){$hangCount++}else{$hangCount=0}

        if(($sw.ElapsedMilliseconds-$lastLog)-ge5000){
            $lastLog=$sw.ElapsedMilliseconds
            O ('HEARTBEAT t={0}ms IsHung={1} consecutiveHungChecks={2} writes={3}' -f $sw.ElapsedMilliseconds,$hung,$hangCount,$script:Writes)
        }

        if($hangCount-ge80){
            O ('HANG_DETECTED=True t={0}ms writes={1}' -f $sw.ElapsedMilliseconds,$script:Writes)
            try{
                $s=Resolve-TimebaseState $p $ph
                if($null-ne$s){O ('HANG_TIMEBASE ageMs={0} raw=0x{1:X8} obj=0x{2:X16}' -f [UInt64][UInt32]$s.Age,[UInt32]$s.Raw,[UInt64]$s.Object)}
            }catch{O ('HANG_TIMEBASE_ERROR='+$_.Exception.Message)}
            Status 'WORLD EDITOR HANG DETECTED - SEE TXT LOG' $false 4500
            exit 22
        }

        Start-Sleep -Milliseconds 25
    }

    O ('PROCESS_EXIT=True elapsedMs={0} heartbeatWrites={1} teardownRaceHandled={2}' -f $sw.ElapsedMilliseconds,$script:Writes,$shutdownRace)
    O 'RESULT=PASS_NORMAL_EXIT'
}
catch{
    O ('ERROR='+$_.Exception.ToString())
    Status 'WORLD EDITOR FIX ERROR - SEE TXT LOG' $false 4500
    exit 30
}
finally{
    if($ph-ne[IntPtr]::Zero){[void][WETBWin32]::CloseHandle($ph)}
}
exit 0