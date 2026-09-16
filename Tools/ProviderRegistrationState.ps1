$ErrorActionPreference='Stop'
$cs=@"
using System;
using System.Runtime.InteropServices;
public static class W3PackProviderQuery {
 [DllImport("bcrypt.dll", CharSet=CharSet.Unicode)] public static extern int BCryptQueryProviderRegistration(string provider, UInt32 mode, UInt32 iface, out UInt32 cb, out IntPtr buffer);
 [DllImport("bcrypt.dll")] public static extern void BCryptFreeBuffer(IntPtr buffer);
}
"@
try{
    Add-Type -TypeDefinition $cs
    [UInt32]$cb=0
    $p=[IntPtr]::Zero
    $s=[W3PackProviderQuery]::BCryptQueryProviderRegistration('War3 Win7 Battle.net Compat v1.0',[UInt32]1,[UInt32]0x00010002,[ref]$cb,[ref]$p)
    try{$u=[UInt32]([Int64]$s -band 0xFFFFFFFFL)}finally{if($p-ne[IntPtr]::Zero){[W3PackProviderQuery]::BCryptFreeBuffer($p)}}
    Write-Host ('Provider registration status=0x'+$u.ToString('X8')+' returnedSize='+$cb)
    if($u-eq0){Write-Host 'STATE=REGISTERED';exit 0}
    if($u-eq[Convert]::ToUInt32('C0000225',16)){Write-Host 'STATE=ABSENT';exit 1}
    Write-Host 'STATE=ERROR_OR_UNKNOWN'
    exit 2
}catch{
    Write-Host ('ERROR: '+$_.Exception.Message)
    exit 3
}
