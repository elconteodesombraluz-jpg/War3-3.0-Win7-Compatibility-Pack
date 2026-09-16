@echo off
setlocal EnableExtensions
set "SELF=%~f0"
set "DLL=%~dp0War3Win7BattleNetCompat_x86_candidate_v1b.dll"
set "PS1=%TEMP%\C02F_X86_CandidateAudit_v1_%RANDOM%_%RANDOM%.ps1"
set "OUT=%~dp0C02F_X86_PROVIDER_CANDIDATE_V1B_INDEPENDENT_AUDIT_v1.txt"
title Warcraft III - C02F x86 provider candidate v1b independent audit v1

echo.
echo Warcraft III - Win7 C02F x86 provider candidate v1b independent audit v1
echo ======================================================================
echo OFFLINE / READ-ONLY AUDIT.
echo Reads only the candidate DLL beside this BAT.
echo No DLL is loaded, executed, installed, registered, patched or modified.
echo No Warcraft III, Battle.net, LSASS, process memory, network or registry access.
echo.

if not exist "%DLL%" (
  echo ERROR: missing "%DLL%"
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$c=Get-Content -LiteralPath $env:SELF; $i=[Array]::IndexOf($c,'#===C02F_EMBEDDED_POWERSHELL==='); if($i -lt 0){exit 91}; $c[($i+1)..($c.Length-1)] | Set-Content -LiteralPath $env:PS1 -Encoding UTF8"
if errorlevel 1 (
  echo ERROR: Could not extract embedded PowerShell.
  pause
  exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "RC=%ERRORLEVEL%"
del /q "%PS1%" >nul 2>&1

echo.
echo Report: "%OUT%"
if not "%RC%"=="0" echo AUDIT NOT CLOSED - send the report.
echo.
pause
exit /b %RC%

#===C02F_EMBEDDED_POWERSHELL===
$ErrorActionPreference='Stop'
$Dll=$env:DLL
$Out=$env:OUT
$Log=New-Object Collections.Generic.List[string]
$Pass=$true

function O([string]$s=''){[void]$Log.Add($s);Write-Host $s}
function Save{[IO.File]::WriteAllLines($Out,[string[]]$Log.ToArray(),(New-Object Text.ASCIIEncoding))}
function U16([byte[]]$b,[int]$o){[BitConverter]::ToUInt16($b,$o)}
function U32([byte[]]$b,[int]$o){[BitConverter]::ToUInt32($b,$o)}
function Sha([string]$p){
  $s=[Security.Cryptography.SHA256]::Create();$f=[IO.File]::OpenRead($p)
  try{return ([BitConverter]::ToString($s.ComputeHash($f))).Replace('-','').ToLowerInvariant()}
  finally{$f.Dispose();$s.Dispose()}
}
function ReadZ([byte[]]$b,[int]$o,[int]$max=260){
  if($o-lt0-or$o-ge$b.Length){return ''}
  $e=$o;$lim=[Math]::Min($b.Length,$o+$max)
  while($e-lt$lim-and$b[$e]-ne0){$e++}
  if($e-le$o){return ''}
  return [Text.Encoding]::ASCII.GetString($b,$o,$e-$o)
}
function NewPe([string]$p){
  [byte[]]$b=[IO.File]::ReadAllBytes($p)
  if($b.Length-lt0x200){throw 'PE too small'}
  $nt=[int](U32 $b 0x3C)
  if((U32 $b $nt)-ne0x4550){throw 'Bad PE signature'}
  $num=U16 $b ($nt+6);$optSize=U16 $b ($nt+20);$opt=$nt+24
  $secs=New-Object Collections.ArrayList;$st=$opt+$optSize
  for($i=0;$i-lt$num;$i++){
    $o=$st+40*$i
    [byte[]]$nb=New-Object byte[] 8;[Array]::Copy($b,$o,$nb,0,8)
    [void]$secs.Add((New-Object PSObject -Property @{
      Name=([Text.Encoding]::ASCII.GetString($nb)).Trim([char]0)
      VS=(U32 $b ($o+8)); VA=(U32 $b ($o+12)); RS=(U32 $b ($o+16)); RP=(U32 $b ($o+20)); Ch=(U32 $b ($o+36))
    }))
  }
  return New-Object PSObject -Property @{
    B=$b;Nt=$nt;Opt=$opt;Num=[int]$num;OptSize=[int]$optSize;Sections=$secs
    Machine=(U16 $b ($nt+4));Timestamp=(U32 $b ($nt+8));Magic=(U16 $b $opt)
    Entry=(U32 $b ($opt+0x10));ImageBase=(U32 $b ($opt+0x1C))
    SectionAlignment=(U32 $b ($opt+0x20));FileAlignment=(U32 $b ($opt+0x24))
    SizeImage=(U32 $b ($opt+0x38));SizeHeaders=(U32 $b ($opt+0x3C));DataDir=($opt+0x60)
  }
}
function RvaToFile($pe,[UInt32]$r){
  if($r-lt$pe.SizeHeaders){if($r-lt$pe.B.Length){return [int]$r};return -1}
  foreach($s in $pe.Sections){
    [UInt64]$span=[Math]::Max([UInt64]$s.VS,[UInt64]$s.RS)
    if([UInt64]$r-ge[UInt64]$s.VA-and[UInt64]$r-lt([UInt64]$s.VA+$span)){
      [UInt64]$d=[UInt64]$r-[UInt64]$s.VA
      if($d-ge[UInt64]$s.RS){return -1}
      return [int]([UInt64]$s.RP+$d)
    }
  }
  return -1
}
function HexBytes([string]$s){
  $t=($s-replace'\s','')
  [byte[]]$a=New-Object byte[] ($t.Length/2)
  for($i=0;$i-lt$a.Length;$i++){$a[$i]=[Convert]::ToByte($t.Substring($i*2,2),16)}
  return $a
}
function CheckBytes($pe,[UInt32]$r,[string]$hex,[string]$label){
  [byte[]]$w=HexBytes $hex;$fo=RvaToFile $pe $r;$ok=$true
  if($fo-lt0-or$fo+$w.Length-gt$pe.B.Length){$ok=$false}
  else{for($i=0;$i-lt$w.Length;$i++){if($pe.B[$fo+$i]-ne$w[$i]){$ok=$false;break}}}
  O ($label+': RVA +'+$r.ToString('X')+' PASS='+$ok)
  if(-not$ok){$script:Pass=$false}
  return $ok
}
function CountBytes([byte[]]$h,[byte[]]$n){
  if($n.Length-eq0){return 0}
  $c=0
  for($i=0;$i-le$h.Length-$n.Length;$i++){
    $ok=$true
    for($j=0;$j-lt$n.Length;$j++){if($h[$i+$j]-ne$n[$j]){$ok=$false;break}}
    if($ok){$c++}
  }
  return $c
}
function Assert([bool]$ok,[string]$label){
  O ($label+'='+$ok)
  if(-not$ok){$script:Pass=$false}
}
function GetExports($pe){
  $a=New-Object Collections.ArrayList
  [UInt32]$r=U32 $pe.B $pe.DataDir
  if($r-eq0){return $a}
  $fo=RvaToFile $pe $r;if($fo-lt0){return $a}
  [UInt32]$nf=U32 $pe.B ($fo+20);[UInt32]$nn=U32 $pe.B ($fo+24)
  [UInt32]$fr=U32 $pe.B ($fo+28);[UInt32]$nr=U32 $pe.B ($fo+32);[UInt32]$or=U32 $pe.B ($fo+36)
  $ff=RvaToFile $pe $fr;$nfo=RvaToFile $pe $nr;$of=RvaToFile $pe $or
  for($i=0;$i-lt$nn;$i++){
    [UInt32]$nameRva=U32 $pe.B ($nfo+4*$i);$name=ReadZ $pe.B (RvaToFile $pe $nameRva)
    [UInt16]$ord=U16 $pe.B ($of+2*$i)
    if($ord-lt$nf){[void]$a.Add((New-Object PSObject -Property @{Name=$name;Rva=(U32 $pe.B ($ff+4*$ord));Ordinal=$ord}))}
  }
  return $a
}
function GetImports($pe){
  $a=New-Object Collections.ArrayList
  [UInt32]$r=U32 $pe.B ($pe.DataDir+8)
  if($r-eq0){return $a}
  $fo=RvaToFile $pe $r;if($fo-lt0){return $a}
  for($di=0;$di-lt128;$di++){
    $d=$fo+20*$di
    [UInt32]$oft=U32 $pe.B $d;[UInt32]$nameR=U32 $pe.B ($d+12);[UInt32]$ft=U32 $pe.B ($d+16)
    if($oft-eq0-and$nameR-eq0-and$ft-eq0){break}
    $dll=ReadZ $pe.B (RvaToFile $pe $nameR)
    [UInt32]$tr=if($oft-ne0){$oft}else{$ft}
    $tf=RvaToFile $pe $tr
    for($i=0;$i-lt512;$i++){
      [UInt32]$v=U32 $pe.B ($tf+4*$i)
      if($v-eq0){break}
      if(($v-band0x80000000)-ne0){$nm='#'+($v-band0xFFFF)}
      else{$nm=ReadZ $pe.B ((RvaToFile $pe $v)+2)}
      [void]$a.Add((New-Object PSObject -Property @{Dll=$dll;Name=$nm}))
    }
  }
  return $a
}

try{
  if(Test-Path -LiteralPath $Out){Remove-Item -LiteralPath $Out -Force}
  $expectedSha='e32754c90d6e44844103b02c681e4e1b7a09fc5ae349f2e1a2abc5ce304496ef'
  $pe=NewPe $Dll
  $sha=Sha $Dll

  O 'Warcraft III - Win7 C02F x86 provider candidate v1b independent audit v1'
  O '======================================================================='
  O 'OFFLINE / READ-ONLY AUDIT.'
  O ('candidate='+$Dll)
  O ('SHA256='+$sha)
  Assert ($sha-eq$expectedSha) 'exact candidate SHA256'
  Assert ($pe.B.Length-eq0x1400) 'file length 0x1400'
  O ''

  O '########################################################################'
  O 'A. PE32 / LOAD-SURFACE IDENTITY'
  O '########################################################################'
  Assert ($pe.Machine-eq0x014C) 'Machine x86 0x014C'
  Assert ($pe.Magic-eq0x010B) 'PE32 magic 0x010B'
  Assert ($pe.Entry-eq0) 'AddressOfEntryPoint is zero'
  Assert ($pe.Timestamp-eq0) 'PE timestamp is zero'
  Assert ($pe.SectionAlignment-eq0x1000-and$pe.FileAlignment-eq0x200) 'section/file alignment 0x1000/0x200'
  Assert ($pe.SizeImage-eq0x5000-and$pe.SizeHeaders-eq0x400) 'SizeOfImage/Headers 0x5000/0x400'
  Assert ($pe.Num-eq4) 'section count 4'
  $wantSecs=@(
    @('.text',0x6EE,0x1000,0x800,0x400,0x60000020),
    @('.rdata',0x539,0x2000,0x600,0xC00,0x40000040),
    @('.data',0xF8,0x3000,0x0,0x0,3221225536),
    @('.reloc',0x108,0x4000,0x200,0x1200,0x42000040)
  )
  for($i=0;$i-lt$wantSecs.Count;$i++){
    $s=$pe.Sections[$i];$w=$wantSecs[$i]
    $ok=($s.Name-eq$w[0]-and$s.VS-eq$w[1]-and$s.VA-eq$w[2]-and$s.RS-eq$w[3]-and$s.RP-eq$w[4]-and$s.Ch-eq$w[5])
    Assert $ok ('section['+$i+'] '+$w[0]+' exact geometry')
  }
  Assert ((U32 $pe.B ($pe.DataDir+5*8))-eq0x4000-and(U32 $pe.B ($pe.DataDir+5*8+4))-eq0x108) 'base relocation directory present'
  Assert ((U32 $pe.B ($pe.DataDir+4*8))-eq0) 'security directory absent'
  Assert ((U32 $pe.B ($pe.DataDir+3*8))-eq0) 'exception directory absent (x86)'
  O ''

  O '########################################################################'
  O 'B. EXPORT / IMPORT BOUNDARY'
  O '########################################################################'
  $ex=@(GetExports $pe)
  Assert ($ex.Count-eq1) 'exactly one named export'
  if($ex.Count-eq1){
    Assert ($ex[0].Name-eq'GetSChannelInterface') 'export name GetSChannelInterface'
    Assert ($ex[0].Rva-eq0x1000) 'GetSChannelInterface RVA +1000'
  }
  $im=@(GetImports $pe)
  $dlls=@($im|Select-Object -ExpandProperty Dll -Unique)
  Assert ($dlls.Count-eq1-and$dlls[0]-eq'KERNEL32.dll') 'only KERNEL32.dll is imported'
  $names=@($im|Select-Object -ExpandProperty Name)
  $expectedImports=@('GetProcAddress','GetProcessHeap','HeapAlloc','HeapFree','LoadLibraryW')
  Assert ($names.Count-eq5) 'exact import count 5'
  for($i=0;$i-lt$expectedImports.Count;$i++){Assert ($names[$i]-eq$expectedImports[$i]) ('import['+$i+'] '+$expectedImports[$i])}
  O ''

  O '########################################################################'
  O 'C. GetSChannelInterface x86 ABI CORRECTION'
  O '########################################################################'
  CheckBytes $pe 0x1000 '555357568B7C2418' 'prolog now loads ppTable from stdcall arg2 [ESP+18h]' | Out-Null
  CheckBytes $pe 0x1008 '85FF7431C70700000000' 'arg2 ppTable NULL-check and initial *ppTable=NULL' | Out-Null
  CheckBytes $pe 0x1195 'C7070030001031C0' 'successful publication writes table through arg2' | Out-Null
  CheckBytes $pe 0x11A1 'C20C00' 'stdcall ABI still consumes exactly 3 arguments' | Out-Null
  O 'Historical x64 provider contract: output table pointer is argument 2; argument 3 is not ppTable.'
  O ''

  O '########################################################################'
  O 'D. INTERFACE-v3 PUBLICATION'
  O '########################################################################'
  CheckBytes $pe 0x108C 'C7050030001003000000' 'write interface version=3' | Out-Null
  CheckBytes $pe 0x1106 'F20F1005E8300010F20F11056C300010' 'copy real slot26+slot27 into table +0x6C/+0x70' | Out-Null
  $locals=@(
    @(3,0x1116,'C70510300010C0110010'),
    @(4,0x1120,'C7051430001020120010'),
    @(7,0x112A,'C7052030001050120010'),
    @(9,0x1134,'C7052830001030140010'),
    @(11,0x113E,'C70530300010C0140010'),
    @(16,0x1148,'C7054430001010150010'),
    @(18,0x1152,'C7054C30001050150010'),
    @(20,0x115C,'C7055430001010160010'),
    @(23,0x1166,'C7056030001030160010'),
    @(24,0x1170,'C7056430001080160010'),
    @(25,0x117A,'C70568300010B0160010')
  )
  foreach($x in $locals){CheckBytes $pe ([UInt32]$x[1]) ([string]$x[2]) ('publish historical local wrapper slot'+$x[0]) | Out-Null}
  CheckBytes $pe 0x1195 'C7070030001031C0' 'publish v3 table pointer +3000 and return success' | Out-Null
  CheckBytes $pe 0x11A1 'C20C00' 'GetSChannelInterface x86 stdcall RET 0x0C' | Out-Null
  CheckBytes $pe 0x11B0 'B829000980' 'fail-closed init error NTE_NOT_SUPPORTED' | Out-Null
  O ''

  O '########################################################################'
  O 'E. C02F COMPATIBILITY SEMANTICS'
  O '########################################################################'
  CheckBytes $pe 0x12C5 '68B00200006A08' 'Enum allocates historical 0x2B0 zeroed block' | Out-Null
  CheckBytes $pe 0x131A '6A00' 'Enum nested Lookup reserved flags=0' | Out-Null
  CheckBytes $pe 0x1325 '682BC000006803030000' 'Enum native lookup uses C02B / TLS1.2' | Out-Null
  CheckBytes $pe 0x13C1 'C746082FC00000C7460C2FC00000' 'Enum patches suite/base to C02F' | Out-Null
  CheckBytes $pe 0x13CF '8996A4020000' 'Enum patches keyType in suite' | Out-Null
  CheckBytes $pe 0x1468 '8D7E0489F239C7' 'FreeBuffer identifies only tracked custom node+4 pointers' | Out-Null
  CheckBytes $pe 0x14B0 'FF25A4300010' 'FreeBuffer fallback delegates real SslFreeBuffer' | Out-Null
  CheckBytes $pe 0x14DA '81FA2FC00000BE2BC00000' 'GenerateMasterKey maps C02F to C02B only' | Out-Null
  CheckBytes $pe 0x1521 '3D2FC00000B92BC00000' 'ImportMasterKey maps C02F to C02B only' | Out-Null
  CheckBytes $pe 0x1552 '817C24142FC00000' 'LookupCipherSuiteInfo tests exact C02F' | Out-Null
  CheckBytes $pe 0x1570 '8D48E983F903BF17000000' 'LookupCipherSuiteInfo normalizes keyType to 23/24/25' | Out-Null
  CheckBytes $pe 0x1584 '682BC00000' 'LookupCipherSuiteInfo nested lookup uses C02B' | Out-Null
  CheckBytes $pe 0x15F7 'FF25C8300010' 'non-C02F LookupCipherSuiteInfo delegates unchanged' | Out-Null
  CheckBytes $pe 0x1614 '688A210010' 'OpenProvider substitutes Microsoft SSL Protocol Provider string' | Out-Null
  CheckBytes $pe 0x1638 '8D51E983FA03BA17000000' 'LookupCipherLengths normalizes keyType' | Out-Null
  CheckBytes $pe 0x1646 '3D2FC00000B92BC00000' 'LookupCipherLengths maps C02F to C02B' | Out-Null
  CheckBytes $pe 0x1684 '3D2FC00000B92BC00000' 'CreateClientAuthHash maps C02F to C02B' | Out-Null
  CheckBytes $pe 0x16B8 '8D51E983FA03BA17000000' 'PRF wrapper normalizes keyType' | Out-Null
  CheckBytes $pe 0x16C6 '3D2FC00000B92BC00000' 'PRF wrapper maps C02F to C02B' | Out-Null
  O ''

  O '########################################################################'
  O 'F. RESOLVER / STRING SURFACE'
  O '########################################################################'
  $ssl=@(
    'SslComputeClientAuthHash','SslComputeEapKeyBlock','SslComputeFinishedHash','SslCreateEphemeralKey',
    'SslCreateHandshakeHash','SslDecryptPacket','SslEncryptPacket','SslEnumCipherSuites','SslExportKey',
    'SslFreeBuffer','SslFreeObject','SslGenerateMasterKey','SslGenerateSessionKeys','SslGetKeyProperty',
    'SslGetProviderProperty','SslHashHandshake','SslImportMasterKey','SslImportKey','SslLookupCipherSuiteInfo',
    'SslOpenPrivateKey','SslOpenProvider','SslSignHash','SslVerifySignature','SslLookupCipherLengths',
    'SslCreateClientAuthHash','SslGetCipherSuitePRFHashAlgorithm','SslComputeSessionHash','SslGeneratePreMasterKey'
  )
  $allNames=$true
  foreach($n in $ssl){
    $c=CountBytes $pe.B ([Text.Encoding]::ASCII.GetBytes($n))
    if($c-ne1){$allNames=$false}
  }
  Assert $allNames 'all 28 Ssl export-name strings occur exactly once'
  $wide=@(
    'ncrypt.dll',
    'Microsoft SSL Protocol Provider',
    'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256_P256',
    'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256_P384',
    'TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256_P521',
    'RSA'
  )
  foreach($n in $wide){
    $c=CountBytes $pe.B ([Text.Encoding]::Unicode.GetBytes($n+[char]0))
    Assert ($c-eq1) ('UTF16 token "'+$n+'" exact once')
  }
  Assert ((CountBytes $pe.B ([Text.Encoding]::Unicode.GetBytes('schannel.dll'+[char]0)))-eq0) 'no schannel.dll dependency string'
  Assert ((CountBytes $pe.B ([Text.Encoding]::Unicode.GetBytes('bcrypt.dll'+[char]0)))-eq0) 'no bcrypt.dll dependency string'
  O ''

  O '########################################################################'
  O 'G. DECISION'
  O '########################################################################'
  if($Pass){
    O 'OFFLINE X86 PROVIDER CANDIDATE v1b INDEPENDENT AUDIT RESULT: CLOSED.'
    O 'The candidate is PE32/x86, exports only GetSChannelInterface, imports only the'
    O 'five historical KERNEL32 loader/heap APIs, publishes a 0x74-byte interface-v3'
    O 'table, preserves the historical C02F local-wrapper boundaries, and binds slots'
    O '26/27 to the real resolved ncrypt callbacks.'
    O ''
    O 'NEXT STEP: direct-load OFFLINE smoke test only. Do NOT copy to SysWOW64 yet.'
  }else{
    O 'OFFLINE X86 PROVIDER CANDIDATE v1b INDEPENDENT AUDIT RESULT: NOT CLOSED.'
    O 'Do not load, install, register or copy this candidate.'
  }
  O ''
  O 'No state changed.'
  O ('REPORT WRITTEN: '+$Out)
  Save
  if($Pass){exit 0}else{exit 2}
}catch{
  O ''
  O ('ERROR: '+$_.Exception.GetType().FullName+': '+$_.Exception.Message)
  O ($_.ScriptStackTrace)
  O 'No state changed.'
  try{Save}catch{}
  exit 1
}
