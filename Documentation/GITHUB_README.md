# Warcraft III 3.0 Windows 7 Compatibility Pack v1.1

This independent compatibility pack restores the current Warcraft III 3.0 / Battle.net path on the specific Windows 7 SP1 x64 binary set on which it was developed and validated.

It is not affiliated with, supported by, or endorsed by Blizzard Entertainment, Microsoft, AVG, or OpenAI. Warcraft III still launches through the official Battle.net desktop launcher and connects to Blizzard's official services.

## v1.1 update

The October 7, 2026 Warcraft III update changed `ClientSdk.dll` and `war3_loader.dll`, invalidating the v1.0 runtime hashes and the old `+0x707` C256 correction.

The persistent Windows provider layer did **not** need to change. v1.1 therefore preserves the validated x64 and x86 provider binaries unchanged and replaces only the Warcraft runtime logic.

The complete project now covers four compatibility layers:

1. **Windows crypto / Battle.net provider layer.** The original validated x64 Schannel/ncrypt compatibility provider is preserved unchanged. The pack also installs the audited x86 companion required by the 32-bit Battle.net/Agent Schannel path.
2. **Warcraft III `ClientSdk.dll` / `crypt32.dll` ABI layer.** The updated `ClientSdk.dll` still passes an 88-byte `CERT_CHAIN_ENGINE_CONFIG`; the validated Windows 7 `crypt32.dll` accepts the older layout only up to 80 bytes. The launcher temporarily supplies an 80-byte stack-local copy for the two validated startup calls, restores the original IAT entry, and frees the temporary hook page.
3. **Updated `war3_loader` timebase / fatal-path correction.** The new loader no longer uses the v1.0 raw `+0x707` predicate. The critical object contains an encoded timestamp at `object+0x2C`. On the validated Windows 7 path, allowing that timestamp to become at least 30,000 ms old routes execution into the same terminal loader wait. The v1.1 launcher performs a guarded initial four-byte refresh after certificate call #1, then refreshes the same validated process-local field only when its decoded age reaches 10,000 ms.
4. **World Editor `worldedit_loader` timebase / fatal-path correction.** The October 2026 World Editor loader uses the same validated encoded-timebase mechanism. The included `War3_3.0_WorldEditor_Win7_Fix_v1.1` helper opens the bundled `dummy.w3m` through the normal Windows `.w3m` association, attaches to that standalone World Editor process, validates the exact editor/loader hashes and runtime signature, and maintains the same guarded four-byte timebase below the 30-second fatal threshold. This helper is independent of Battle.net: Battle.net may be running or completely closed.

No Warcraft executable or DLL is modified on disk, and no `war3_loader` code byte is patched.

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

Validated against the Warcraft III 3.0 binaries distributed on October 7, 2026:

- `ClientSdk.dll` — `04f798ac211b9fea1b741b4f1d520d7e5b3cf5f038241c909b7429b02a4cf134`
- `war3_loader.dll` — `df44a65ef76ac2159f531693a751de22807dd454778090475292092c111e6461`

The runtime launcher fails closed if either hash differs.

### Validated World Editor runtime build

- `World Editor.exe` — `f46f0a72d32cbdd366f4a0f7de54d35ad2ccad9d00e23749269910afd75c34e3`
- `worldedit_loader.dll` — `aefd841b006117d11582b018031fe9d7a2c8f48150c688e54f1c64b7f66c67cd`

The World Editor helper also fails closed if the supported hashes, decoded object, or runtime signature do not match.

## Installation

1. Close Warcraft III and Battle.net completely. Fully quit Hide.me or other VPN software if installed.
2. Extract the complete ZIP to a normal writable folder.
3. Right-click `INSTALL.bat` and choose **Run as administrator**.
4. Do not bypass a failed precheck.
5. Reboot Windows once after installing or changing the persistent provider layer.
6. Start the official Battle.net launcher and sign in.
7. Launch Warcraft III with `START_WARCRAFT_III.bat`.
8. Wait for the green **WARCRAFT III WIN7 FIX ACTIVE - ONLINE READY** status before using Multiplayer / Custom Games.

If the exact v1.0 provider layer is already installed, `INSTALL.bat` detects and reuses it. Updating from pack v1.0 to v1.1 does not require replacing identical provider binaries.

## Daily use

Use `START_WARCRAFT_III.bat`. The wrapper verifies the installed providers, provider registration, and the exact v1.1 runtime BAT before launch.

The console remains open because the v1.1 runtime maintains the guarded process-local timebase while Warcraft is running. It closes automatically after Warcraft exits. The runtime log is written to:

`Runtime\WAR3_WIN7_ONLINE_FIX_v1.1.txt`

## Validation result

On the development machine, the v1.1 mechanism was validated through:

- normal Battle.net / in-game authentication;
- Multiplayer / Custom Games navigation;
- completion of an online map download;
- leaving and creating a private online game;
- playing an actual online game to completion;
- more than 15 minutes of continuous heartbeat maintenance in the diagnostic validation run;
- normal Warcraft shutdown and clean launcher exit.

## World Editor use

The project now includes `War3_3.0_WorldEditor_Win7_Fix_v1.1`.

The World Editor helper is **not dependent on Battle.net**. Battle.net may be open or closed. The bundled `dummy.w3m` exists specifically so the helper can use the normal Windows `.w3m` ShellOpen path instead of launching `World Editor.exe` directly.

Run `START_WORLD_EDITOR_FIXED.bat` from that folder. Leave `WorldEditorPath=` blank in `WorldEditorFix.ini` for auto-detection, or set the full path manually if detection fails.

Wait for the green **WORLD EDITOR WIN7 FIX ACTIVE - USE THE EDITOR NORMALLY** message. You may then close `dummy.w3m` and open any other map inside the same World Editor process.

The helper has no persistent installation and requires no provider installation specifically for World Editor. Its guarded four-byte process-local timebase writes disappear when World Editor exits.

## Verification

`VERIFY_INSTALLATION.bat` checks the x64/x86 provider hashes, the x64 provider registration, and the exact v1.1 runtime BAT integrity.

## Removal

Run `REMOVE.bat` as administrator with Warcraft III and Battle.net closed, then reboot once. The runtime changes are process-local and disappear when Warcraft exits.

## What the pack does not do

It does not redirect Battle.net traffic, emulate Blizzard authentication, fabricate credentials/tokens, redirect Warcraft III to another server, replace Microsoft system DLLs, distribute Blizzard executables, or modify Warcraft files on disk.

It **does** make guarded four-byte process-local data writes to the validated Warcraft process while it runs. Those writes maintain the encoded timebase below the fatal 30-second threshold on the supported Windows 7 path.

The included World Editor helper follows the same fail-closed process-local approach. It does not modify `World Editor.exe`, `worldedit_loader.dll`, or map files on disk, and it does not require Battle.net to be running.

## Original provider preservation

`Provider/x64/` preserves the original public x64 provider release unchanged. Its original public archive SHA-256 was:

`3db1ba9ccc1b0bcf805b0e849d4df77ffd78d966b50d517187a359b4dc0f85c7`

The original x64 provider DLL remains `d2dc7f30344f2f4482196301835fdc45231619fc4df3d74bf49bf809b5fcbc90`.

## Other Windows 7 binary sets

Do not mix this provider build with the independent ArchitectOfRuin variant or other Windows 7 binary sets. Similar symptoms do not make their provider binaries interchangeable.

## Antivirus

AVG interfered with some compatibility files during development. If antivirus software blocks or quarantines a pack file, do not continue with an incomplete package. Verify hashes first.

## Project / support scope

This project was developed through iterative reverse engineering with ChatGPT by OpenAI and repeated experiments on the affected Windows 7 machine. The publisher is a novelist rather than a Windows internals or security engineer. Exact hashes and technical notes are included so experienced users can inspect and reproduce the work.

See `Documentation/TECHNICAL_NOTES.md`, `Documentation/CHANGELOG.md`, and `Documentation/LEGAL_NOTICE.txt`.