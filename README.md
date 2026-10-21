# Warcraft III 3.0.1.24371 — Windows 7 Compatibility Pack v1.2

Independent compatibility pack for **Windows 7 SP1 x64**, targeting the **exact Warcraft III 3.0.1.24371 binaries** listed below. This is an updated successor to the project's v1.1 pack for an earlier Warcraft 3.0 build. It is not affiliated with or endorsed by Blizzard, Microsoft, AVG or OpenAI.

**Status:** v1.2 validated on Windows 7 SP1 x64 by the project tester on October 22, 2026. The complete RC3 pack, including its package integrity verification and both Windows 7 compatibility helpers, was reported working. The World Editor TEST4 diagnostic recorded 10 guarded writes over 110.9 seconds. Only the exact documented binary hashes are supported; this report does not establish compatibility with other systems or later game builds.

## Contents

- `Provider/x64/` and `Provider/x86/` — original validated Schannel/ncrypt providers, **binary-identical to v1.1**, with original installer/removers and x86 audit source.
- `Runtime/War3_Win7_Online_Fix_v1.2.bat` — Warcraft 3.0.1 launcher, retaining the validated ClientSdk 88-to-80-byte certificate-chain shim and a guarded four-byte encoded-timebase heartbeat.
- `War3_3.0.1_WorldEditor_Win7_Fix_v1.2/` — World Editor standalone timebase correction, including **dummy.w3m**, BAT, README, and optional INI.
- Root shortcuts for installation, removal, launch, verification; `Tools/` diagnostics; `Documentation/` engineering notes.

## Installation (provider layer)

1. Exit Warcraft III and Battle.net (and Hide.me if installed). Extract the **entire** archive.
2. Run `VERIFY_PACKAGE.bat` to check archive integrity.
3. If the providers from the previous supported pack are already installed, **do not reinstall them**. `VERIFY_INSTALLATION.bat` checks their presence.
4. If providers are absent, right-click `INSTALL.bat` and select **Run as administrator**. It validates the exact Windows system/provider versions and fails closed for mismatches.
5. Reboot Windows after installing or changing providers. Start/sign into official Battle.net.
6. Run `START_WARCRAFT_III.bat`. Keep the console open while playing.

The persistent provider installation is needed for the Battle.net/Warcraft path, but **not** for using the World Editor fix by itself.

## World Editor (no provider or Battle.net dependency)

1. Close World Editor. Battle.net may remain open or closed.
2. Run the root `START_WORLD_EDITOR_FIXED.bat`.
3. The **included** dummy map opens through normal Windows `.w3m` ShellOpen association. Do not directly launch `World Editor.exe`.
4. Keep the console open, wait for the green fix-active line, then open your own map in the same Editor instance.

The helper tries the `WAR3_ROOT` environment variable, Warcraft III uninstall registry keys, and common locations. If detection fails, edit `War3_3.0.1_WorldEditor_Win7_Fix_v1.2/WorldEditorFix.ini` and set the `WorldEditorPath` manually. The helper never modifies a map or game DLL on disk.

## Supported exact Blizzard binary hashes (SHA-256)

| File | Required SHA-256 |
|---|---|
| ClientSdk.dll | `04f798ac211b9fea1b741b4f1d520d7e5b3cf5f038241c909b7429b02a4cf134` |
| war3_loader.dll | `ef88b6554036661f5974986b95912b08c8a7042795177f539a67cc4e710d23d7` |
| World Editor.exe | `988a6a49f729cd3a20e91e82edd88b4d955be3757d66d8283e261f75b755ac22` |
| worldedit_loader.dll | `0e24a0270bdffa9edd68bbd7f7a2e8bafc3c232317fbda0cfabe23ea0407e3d9` |

**No cross-build compatibility is implied.** Never bypass the hash guards or mix in another Windows 7 provider variant. The fix targets four bytes of process-local DATA, not disk files. It does not authenticate on a substitute server or distribute Blizzard executables.

## Supported Windows provider set

System32 x64: schannel `51dcfaa5fe70d231d609fc7c37a3262c30d613721420efd65f8c33578c371501`; ncrypt `962f201ee3b08e3fc4a0849251958c573ebcb3b32f588ec624ebc443a2400be9`; bcrypt `e101aa09220b126962ed5de00d7f15bcd645890f33afa1728fafd78d2e67ae90`; bcryptprimitives `715977e616e206724f91660ef5bd0c4f2c6d66e3891f03c28a864419102ce5b6`.

SysWOW64 x86: schannel `ae50b1f96e16020c9cfe894817d3ee440256b6a1c933b0a19b106ffaae5eef9a`; ncrypt `d1106de78aaa439e7249cb16e3ef78b2b9505f514ee2917b3a8e05412af9f7e9`; bcrypt `cdf412f5186596e92597fd7ac8bcbac23ec89ffb66f3ee31f362fc2e1f476b79`; bcryptprimitives `d80dcec4b5554e84491b06c624098123033b840f88157ef402edad2163b0a734`.

Pack provider x64 SHA-256 `d2dc7f30344f2f4482196301835fdc45231619fc4df3d74bf49bf809b5fcbc90`; x86 `e32754c90d6e44844103b02c681e4e1b7a09fc5ae349f2e1a2abc5ce304496ef`.

## Validation and logs

- Game: `Runtime/WAR3_WIN7_ONLINE_FIX_v1.2.txt`; normal startup requires the two guarded certificate calls and green online-ready status.
- Editor: `War3_3.0.1_WorldEditor_Win7_Fix_v1.2/WORLD_EDITOR_24371_FIX_v1.2.txt`.
- Source of confirmed World Editor evidence: 2026-10-22 TEST4 log, 10 `TIMEBASE_REFRESH_APPLIED=True` events, `fixActivated=True` after 110,942 ms.
- GUI nonresponsiveness is **telemetry only** and no longer causes the Warcraft heartbeat to stop. It is not a map-loading watchdog.

## Removing the pack

`REMOVE.bat` (administrator) removes the matching persistent Windows provider installation. If you merely want to stop the per-process runtime/editor fixes, close Warcraft III or World Editor and delete the extracted pack: those memory changes vanish automatically. Reboot after provider removal. Do not use a different provider package's removal script.

## Project

[War3-3.0-Win7-Compatibility-Pack](https://github.com/elconteodesombraluz-jpg/War3-3.0-Win7-Compatibility-Pack). See `Documentation/TECHNICAL_NOTES.md`, `CHANGELOG.md`, `RELEASE_NOTES.md`, and `LEGAL_NOTICE.txt`.
