# Warcraft III 3.0 Windows 7 Compatibility Pack v1.0

This independent compatibility pack is intended to restore the current Warcraft III 3.0 / Battle.net path on the specific Windows 7 SP1 x64 binary set on which it was developed and validated.

It is not affiliated with, supported by, or endorsed by Blizzard Entertainment, Microsoft, AVG, or OpenAI. Warcraft III still launches through the official Battle.net desktop launcher and connects to Blizzard's official services.

## What changed from the original provider project

The August 2026 release was a **Windows 7 Battle.net Compatibility Provider**. That solved the first compatibility boundary, but it turned out not to be the whole Warcraft III 3.0 problem. The complete working solution now has three layers:

1. **Windows crypto / Battle.net provider layer.** The original validated x64 Schannel/ncrypt compatibility provider is preserved unchanged. The pack also installs the separately audited x86 companion image needed by the 32-bit Battle.net/Agent Schannel path.
2. **Warcraft III 3.0 `ClientSdk.dll` / `crypt32.dll` ABI layer.** The current client passes an 88-byte `CERT_CHAIN_ENGINE_CONFIG`; the validated Windows 7 `crypt32.dll` accepts the older layout only up to 80 bytes. The runtime launcher temporarily translates the 88-byte call to an 80-byte stack-local copy. The caller's original structure is never changed. After the two validated startup calls, the original IAT entry is restored and the private hook page is freed.
3. **Warcraft III 3.0 `war3_loader` fatal-path correction.** On the validated game build, an exact `+0x707` mismatch at the identified predicate routes execution toward a noreturn/fatal path ending in an infinite wait. The launcher performs one guarded four-byte process-local data correction only if that exact mismatch is present. No Warcraft executable or DLL is patched on disk.

After READY, the launcher keeps a tiny read-only `ReadProcessMemory` pulse active while Warcraft runs. It was discovered accidentally during diagnostics and made the game feel modestly more responsive on the development machine. It is **not** claimed as a general FPS fix; the mechanism was not proven.

## Not simply a Proton port

A Proton/Wine workaround was useful evidence for understanding the modern `CERT_CHAIN_ENGINE_CONFIG` layout mismatch. The native Windows 7 work then independently traced and corrected the separate `war3_loader` fatal path, built the Windows provider layers, added fail-closed binary guards, and validated the complete path through the official Battle.net launcher. The current pack is therefore a native Windows 7 compatibility project, not a direct Proton binary port.

## Supported configuration — fail closed

Do **not** bypass hash checks and do not mix components from another Windows 7 provider variant.

### Original x64 provider / System32 binary set

- `schannel.dll` — `51dcfaa5fe70d231d609fc7c37a3262c30d613721420efd65f8c33578c371501`
- `ncrypt.dll` — `962f201ee3b08e3fc4a0849251958c573ebcb3b32f588ec624ebc443a2400be9`
- `bcrypt.dll` — `e101aa09220b126962ed5de00d7f15bcd645890f33afa1728fafd78d2e67ae90`
- `bcryptprimitives.dll` — `715977e616e206724f91660ef5bd0c4f2c6d66e3891f03c28a864419102ce5b6`
- x64 compatibility provider — `d2dc7f30344f2f4482196301835fdc45231619fc4df3d74bf49bf809b5fcbc90`

### x86 companion / SysWOW64 binary set

- `schannel.dll` — `ae50b1f96e16020c9cfe894817d3ee440256b6a1c933b0a19b106ffaae5eef9a`
- `ncrypt.dll` — `d1106de78aaa439e7249cb16e3ef78b2b9505f514ee2917b3a8e05412af9f7e9`
- `bcrypt.dll` — `cdf412f5186596e92597fd7ac8bcbac23ec89ffb66f3ee31f362fc2e1f476b79`
- `bcryptprimitives.dll` — `d80dcec4b5554e84491b06c624098123033b840f88157ef402edad2163b0a734`
- x86 compatibility provider — `e32754c90d6e44844103b02c681e4e1b7a09fc5ae349f2e1a2abc5ce304496ef`

### Validated Warcraft III runtime build

- Warcraft III `3.0.0.24268` — Forsaken Kingdom
- `ClientSdk.dll` — `3a8762f6641f39da8099009adccfe1b2f9aa9613defe98273e38341de500b10e`
- `war3_loader.dll` — `e32431e26f58d1201be3f48baed485114227864d8c6b871eae8e9528241ec8e9`

The runtime BAT checks the Warcraft hashes before applying any process-local offset. A later Warcraft update is expected to fail closed until it is independently re-audited.

## Installation

1. Close Warcraft III and Battle.net completely. Fully quit Hide.me on systems where it is installed.
2. Extract the complete ZIP to a normal writable folder.
3. Right-click `INSTALL.bat` and choose **Run as administrator**. The BAT can also request elevation itself.
4. The installer validates the original x64 payload, the x64 system binaries, the x86 system binaries, and the installed provider state. Unexpected existing provider files are not overwritten.
5. Do not bypass a failed precheck.
6. Reboot Windows once after installing/changing the persistent provider layer.
7. Start the official Battle.net desktop launcher and sign in.
8. Launch Warcraft III with `START_WARCRAFT_III.bat`.
9. Wait for the green **WARCRAFT III WIN7 FIX ACTIVE - ONLINE READY** status before using Multiplayer / Custom Games.

Warcraft III and Battle.net do not need to be on `C:`. The runtime launcher auto-detects both paths. The validated development machine stores Warcraft III on `E:`.

If the exact original x64 provider and x86 companion are already installed, the root installer detects and reuses them instead of overwriting them.

## Daily use

Use `START_WARCRAFT_III.bat`. It verifies the installed provider hashes, provider registration, and the exact runtime BAT before starting the validated process-local fix. Battle.net remains the official launcher and Blizzard remains the authentication/server endpoint.

The console remains open while Warcraft is running because the lightweight read-only pulse is active. It closes shortly after Warcraft exits. The runtime log is written under `Runtime\WAR3_WIN7_ONLINE_FIX_v1.0.txt`.

## Verification

`VERIFY_INSTALLATION.bat` checks the installed x64 and x86 provider hashes, the x64 CNG provider registration, and the runtime BAT integrity. It does not modify the system.

## Removal

1. Close Warcraft III and Battle.net.
2. Run `REMOVE.bat` as administrator.
3. The remover refuses to delete an installed provider DLL whose SHA-256 does not match this pack.
4. Reboot Windows once after removing the persistent provider layer.

The Warcraft runtime correction itself is process-local; no patched Warcraft file remains after the game exits.

## What the pack does not do

It does not redirect Battle.net traffic, emulate Blizzard authentication, fabricate credentials/tokens, bypass account authentication, redirect Warcraft III to another server, replace Microsoft system DLLs, distribute Blizzard executables, or patch Blizzard files on disk.

It **does** temporarily change four bytes of validated Warcraft process memory under an exact predicate/hash guard. That is intentionally documented rather than hidden behind the older provider-only wording that said the project did not patch Warcraft at all.

## Original provider preservation

`Provider/x64/` contains the six files from the original public `War3_Win7_BattleNet_Compat_v1.0.zip` release unchanged. The original archive had SHA-256:

`3db1ba9ccc1b0bcf805b0e849d4df77ffd78d966b50d517187a359b4dc0f85c7`

The original x64 runtime provider DLL remains:

`d2dc7f30344f2f4482196301835fdc45231619fc4df3d74bf49bf809b5fcbc90`

The original provider README is kept in that component directory for historical/technical reference. Its statement that the provider itself does not patch Warcraft remains true for that component; the complete pack now additionally contains the documented process-local runtime fix.

## Other Windows 7 binary sets

The older provider research was independently adapted by Blizzard forum user **Architect** for another Windows 7 system-binary set. Do not mix that provider build with this pack. Users whose system hashes differ should use a build explicitly developed for their exact binaries rather than disabling checks.

Developer references / other Windows 7 binary sets

This repository contains the compatibility pack validated on the exact Windows 7 and Warcraft III binary set documented here.

The following projects are provided as developer references only:

War3-Win7-BattleNet-Compat — the original compatibility-provider project from which this broader pack evolved.
ArchitectOfRuin/War3-Win7-BattleNet-Compat-Win7-18939 — an independent adaptation of the provider research for a different Windows 7 cryptographic binary set.

These projects are not interchangeable components of this pack, and compatibility between their provider binaries and this package is not guaranteed. Do not mix DLLs, installers, registry state, or components from different variants merely because they address a similar underlying problem.

They are linked primarily so developers working with other Windows 7 builds can compare implementations, hashes, ABI differences, and adaptation strategies.

## Antivirus

AVG interfered with some compatibility files during development. If an antivirus blocks or quarantines a pack file, do not continue with an incomplete installation. Verify `SHA256SUMS.txt` and allow/restore only the exact release payload.

## Project / support scope

This project was developed through a long iterative investigation with ChatGPT by OpenAI and repeated experiments on the affected Windows 7 machine. The publisher is a novelist rather than a Windows internals or security engineer. The technical notes and hashes are included so experienced users can inspect and reproduce the work; individual support for arbitrary Windows builds cannot be guaranteed.

See `Documentation/TECHNICAL_NOTES.md`, `Documentation/CHANGELOG.md`, and `Documentation/LEGAL_NOTICE.txt`.
