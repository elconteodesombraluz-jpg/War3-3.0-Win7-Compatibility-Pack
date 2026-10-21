# Windows PowerShell 2+ on Windows 7 SP1.
# The proof file is created only AFTER every SHA-256 verification succeeds.
param([string]$SuccessFile)
$ErrorActionPreference='Stop'
$sha=$null
$verified=$false
try {
    if([String]::IsNullOrEmpty($SuccessFile)) { throw 'Missing success-file path.' }
    $ToolsDir=Split-Path -Parent $MyInvocation.MyCommand.Path
    $Root=[IO.Path]::GetFullPath((Join-Path $ToolsDir '..'))
    $Manifest=Join-Path $Root 'SHA256SUMS.txt'
    if(-not (Test-Path -LiteralPath $Manifest -PathType Leaf)) {
        throw 'SHA256SUMS.txt is missing.'
    }
    $lines=[IO.File]::ReadAllLines($Manifest)
    if($lines.Length -eq 0) { throw 'SHA256SUMS.txt is empty.' }
    $sha=New-Object Security.Cryptography.SHA256Managed
    $checked=0
    $failed=0
    $seen=@{}
    foreach($line in $lines) {
        if($line.Trim().Length -eq 0) { continue }
        if($line -cnotmatch '^([0-9a-f]{64})  (.+)$') {
            Write-Host ('INVALID MANIFEST LINE: '+$line)
            $failed++
            continue
        }
        $expected=$matches[1]
        $rel=$matches[2]
        if([IO.Path]::IsPathRooted($rel) -or $rel.Contains('..') -or
           $rel.Contains(':') -or $rel.Contains('\')) {
            Write-Host ('INVALID RELATIVE PATH: '+$rel)
            $failed++
            continue
        }
        if($seen.ContainsKey($rel)) {
            Write-Host ('DUPLICATE MANIFEST PATH: '+$rel)
            $failed++
            continue
        }
        $seen[$rel]=$true
        $path=Join-Path $Root ($rel.Replace('/','\'))
        if(-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Write-Host ('MISSING: '+$rel)
            $failed++
            continue
        }
        $fs=$null
        try {
            $fs=[IO.File]::OpenRead($path)
            $actual=([BitConverter]::ToString($sha.ComputeHash($fs))).Replace('-','').ToLowerInvariant()
        } finally {
            if($fs -ne $null) { $fs.Dispose() }
        }
        if($actual -ne $expected) {
            Write-Host ('HASH MISMATCH: '+$rel)
            $failed++
        } else {
            $checked++
        }
    }
    if($checked -eq 0) { throw 'No package files were successfully checked.' }
    Write-Host ('PACKAGE_CHECK filesOK={0} problems={1}' -f $checked,$failed)
    if($failed -ne 0) { throw 'Package manifest check failed.' }
    $verified=$true
} catch {
    Write-Host ('PACKAGE_VERIFICATION_ERROR: '+$_.Exception.Message)
} finally {
    if($sha -ne $null) { $sha.Dispose() }
}
if($verified) {
    try {
        # No further operations are required for the proof to be valid.
        [IO.File]::WriteAllText($SuccessFile,'PACKAGE_VERIFICATION_OK',[Text.Encoding]::ASCII)
        Write-Host 'PACKAGE_VERIFICATION_OK'
        exit 0
    } catch {
        Write-Host ('PACKAGE_VERIFICATION_ERROR: '+$_.Exception.Message)
    }
}
exit 2
