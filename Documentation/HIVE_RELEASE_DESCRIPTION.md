# Warcraft III 3.0 Windows 7 Compatibility Pack v1.1

**Windows 7 SP1 x64 / Warcraft III 3.0 — October 7, 2026 runtime**

This independent pack restores the validated Warcraft III 3.0 / Battle.net path on the Windows 7 system for which it was developed.

**Not affiliated with or endorsed by Blizzard Entertainment, Microsoft, AVG, or OpenAI.** Warcraft III still launches through the official Battle.net desktop launcher and connects to Blizzard's official services.

## What the pack fixes

### 1. Battle.net / Schannel compatibility

The validated x64 provider and audited x86 companion restore the Schannel/ncrypt provider-interface path required by the current Battle.net/Agent stack on the supported Windows 7 binary set. These provider binaries are unchanged from pack v1.0.

### 2. Warcraft III certificate-chain ABI mismatch

The updated `ClientSdk.dll` still passes an 88-byte `CERT_CHAIN_ENGINE_CONFIG` to `CertCreateCertificateChainEngine`. The validated native Windows 7 `crypt32.dll` accepts the older layout only up to 80 bytes.

The launcher supplies an 80-byte stack-local copy for the two startup calls, never modifies the caller-owned 88-byte structure, restores the original IAT pointer, and frees the temporary hook page.

### 3. October 2026 `war3_loader` timebase fix

The old v1.0 `+0x707` correction does **not** apply to the updated loader.

The new fatal-path analysis identified an encoded millisecond timestamp at `object+0x2C`. The critical branch fires when the decoded age reaches at least `30000 ms`. On the validated Windows 7 path, the game's own refresh can arrive too late: the stale timestamp has already been copied into the fatal frame before the later update occurs.

v1.1 therefore performs a guarded initial four-byte refresh after certificate call #1 and maintains the same encoded field while Warcraft runs. It checks approximately every 250 ms and writes only when decoded age reaches 10 seconds, leaving a large margin below the 30-second fatal threshold.

Every write is exactly four process-local data bytes and is immediately verified. No Warcraft code byte or file on disk is modified.

## Validated game hashes

- `ClientSdk.dll`: `04f798ac211b9fea1b741b4f1d520d7e5b3cf5f038241c909b7429b02a4cf134`
- `war3_loader.dll`: `df44a65ef76ac2159f531693a751de22807dd454778090475292092c111e6461`

The pack fails closed if these hashes do not match.

## Tested result

- official Battle.net launch and authentication;
- Multiplayer / Custom Games navigation;
- online map download completed;
- private online game created;
- actual online game played to completion;
- >15 minutes of continuous heartbeat validation;
- clean normal shutdown.

## Installation

1. Close Warcraft III and Battle.net and fully quit Hide.me/VPN software.
2. Extract the ZIP.
3. Run `INSTALL.bat` as Administrator.
4. Do not bypass failed checks.
5. Reboot once after provider installation/change.
6. Open Battle.net and sign in.
7. Launch with `START_WARCRAFT_III.bat`.
8. Wait for the green **ONLINE READY** banner before using Multiplayer / Custom Games.

Existing v1.0 users whose exact provider binaries are already installed can reuse them; v1.1 changes the Warcraft runtime, not the provider payload.

## World Editor

The project includes the dedicated `War3_3.0_WorldEditor_Win7_Fix_v1.1` helper.

Validated hashes:

- `World Editor.exe`: `f46f0a72d32cbdd366f4a0f7de54d35ad2ccad9d00e23749269910afd75c34e3`
- `worldedit_loader.dll`: `aefd841b006117d11582b018031fe9d7a2c8f48150c688e54f1c64b7f66c67cd`

The World Editor helper is **independent of Battle.net**. Battle.net may be open or closed.

`START_WORLD_EDITOR_FIXED.bat` does not launch `World Editor.exe` directly. Instead, it ShellOpens the bundled `dummy.w3m` through the normal Windows `.w3m` file association, attaches to the resulting standalone editor process, validates the exact supported binaries and runtime object/signature, and maintains the same guarded encoded-timebase heartbeat used by the October Warcraft runtime fix.

Once **WORLD EDITOR WIN7 FIX ACTIVE** appears, `dummy.w3m` may be closed and any other map may be opened inside that same World Editor process. No editor executable, DLL, or map file is modified on disk.

## Integrity

See `SHA256SUMS.txt` for the complete package manifest and `Documentation/TECHNICAL_NOTES.md` for the reverse-engineering summary.