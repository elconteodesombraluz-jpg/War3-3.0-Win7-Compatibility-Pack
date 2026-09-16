param([string]$Path,[string]$Expected)
$ErrorActionPreference='Stop'
function Sha256([string]$p){
    $sha=[Security.Cryptography.SHA256]::Create()
    $fs=[IO.File]::Open($p,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    try{return ([BitConverter]::ToString($sha.ComputeHash($fs))).Replace('-','').ToLowerInvariant()}
    finally{$fs.Dispose();$sha.Dispose()}
}
try{
    if(!(Test-Path -LiteralPath $Path -PathType Leaf)){
        Write-Host ('ABSENT: '+$Path)
        exit 0
    }
    $h=Sha256 $Path
    Write-Host ('SHA256: '+$h)
    if($h -eq $Expected.ToLowerInvariant()){
        Write-Host 'STATE=EXACT'
        exit 10
    }
    Write-Host ('EXPECTED: '+$Expected.ToLowerInvariant())
    Write-Host 'STATE=MISMATCH'
    exit 20
}catch{
    Write-Host ('ERROR: '+$_.Exception.Message)
    exit 30
}
