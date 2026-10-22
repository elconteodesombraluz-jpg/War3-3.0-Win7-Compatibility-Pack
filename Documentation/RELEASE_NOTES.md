# Release notes — Warcraft III 3.0.1.24371 compatibility v1.2

This release supersedes the previous pack's Warcraft 3.0 runtime helpers, but keeps its validated Windows 7 providers byte-for-byte unchanged. It is specifically for Windows 7 SP1 x64 and exact Warcraft 3.0.1.24371 game/editor binary hashes documented in README.md.

The Warcraft runtime is based on TIMEBASE_HEARTBEAT_TEST_v7b: unchanged ClientSdk SHA-256, new 24371 `war3_loader.dll` hash, certificate ABI shim, decoded timebase at object+0x6C, guarded 4-byte refresh every approximately 10 seconds. UI nonresponsiveness is informational only.

The World Editor is based on TEST4, validated 2026-10-22: 10 verified writes over 110.9 seconds and normal user interaction. The integrated helper contains dummy.w3m and starts by ShellOpen. No Battle.net dependency.

Validation: the project tester confirmed the complete RC3 archive and its integrity checker work on Windows 7 SP1 x64 on October 22, 2026. TEST4 previously recorded 10 successful World Editor timebase refreshes across 110.9 seconds. This is not proof of compatibility on any other Windows build or with later Blizzard patches.

Verification hotfix (October 22, 2026): `VERIFY_PACKAGE.bat` now accepts a modified `WorldEditorPath=` value in the bundled `WorldEditorFix.ini`, while validating all other INI bytes and the remaining package files against their manifest hashes. The packaged INI remains pristine and the game/editor fixes and providers are unchanged.
