Warcraft III 3.0 Windows 7 Compatibility Pack - x86 provider companion v1b
============================================================================

This directory contains the audited PE32/i386 companion image used by the 32-bit
Battle.net / Agent Schannel path on the validated Windows 7 SP1 x64 system.

Installed destination:
  %WINDIR%\SysWOW64\War3Win7BattleNetCompat.dll

SHA-256 of the exact x86 provider image:
  e32754c90d6e44844103b02c681e4e1b7a09fc5ae349f2e1a2abc5ce304496ef

The x86 installer does NOT create or alter CNG provider registration. The
original validated x64 provider is registered first; this companion image gives
32-bit clients the matching DLL name in SysWOW64.

The source and the independent audit BAT used before installation are preserved
under Source/ with their original candidate names. The promoted release DLL is
byte-for-byte identical to that audited candidate; only the package filename was
shortened.

Do not bypass the system-binary hash checks and do not mix this DLL with a
provider build intended for a different Windows 7 binary set.
