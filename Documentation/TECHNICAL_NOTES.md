# Technical notes — Warcraft III 3.0.1.24371 / Windows 7

## Compatibility boundaries

The provider layer is unchanged from v1.1: validated x64 and x86 crypto/Schannel components. INSTALL and REMOVE preserve their original executable and registration controls. Windows versions other than the specifically documented Windows 7 SP1 x64 binary set are **not** validated.

## Warcraft III runtime

Exact ClientSdk SHA-256 `04f798ac211b9fea1b741b4f1d520d7e5b3cf5f038241c909b7429b02a4cf134`, loader SHA-256 `ef88b6554036661f5974986b95912b08c8a7042795177f539a67cc4e710d23d7`. Based on tested v7b runtime payload. Existing ClientSdk runtime shim temporarily adapts the 88-byte CERT_CHAIN_ENGINE_CONFIG structure to an 80-byte Windows 7 compatible copy for the two validated calls and then restores IAT and frees hook memory. After first certificate call, a guarded timebase refresh is applied to a regenerated object and maintained every ~250 ms at >=10-second age. In-game status appears after the proven post-certificate stabilization delay. No war3_loader code byte is patched.

The 3.0.1 runtime uses an encoded timebase (`storedTick = raw XOR 0x79578000`) at object+0x6C, unlike the October 7 3.0 loader's old object+0x2C. The 30-second fatal-path threshold was established during v7b development. Writes are process-local 4-byte DATA only, immediately read back and guarded by exact signatures and plausible ages. The published v1.2 removes hard stop on GUI nonresponding status; maintenance continues even during long legitimate loads.

## World Editor standalone

Exact SHA-256:
- World Editor.exe `988a6a49f729cd3a20e91e82edd88b4d955be3757d66d8283e261f75b755ac22`
- worldedit_loader.dll `0e24a0270bdffa9edd68bbd7f7a2e8bafc3c232317fbda0cfabe23ea0407e3d9`
- dummy.w3m `77b4313c9a7498eb3a49a7b4228885f8080b61a369006888c29e5486a8533088`

The editor launches by ShellOpening the bundled dummy.w3m instead of directly executing World Editor.exe. It attaches to the resulting process, validates image hashes, and finds the global at loader+0x216A878. Decoded object key: 0xEC3F4C87D9BA4DC6. Encoded age at object+0x6C using XOR 0x79578000. TEST4's important guard refinement: the full object+0x68 DWORD varied (`0x0000004E` / `0x003C444E`), but its low byte remained 0x4E. The helper validates this invariant plus object+0x70 == 0x9D3F7240, checked twice with the global pointer and encoded timestamp before writing. Reads timebase again after the write. It refuses a stale age above 120 seconds or a mismatch.

Confirmed local 2026-10-22 TEST4 log: 10 successful `TIMEBASE_REFRESH_APPLIED=True` events in about 110,942 ms, `RESULT fixActivated=True writes=10`. This confirms successful operation in that trial, but not universal compatibility with other builds or system DLLs.

## What changed from old v1.1 pack

Do not reuse the old `war3_loader` or `worldedit_loader` hash, the old +0x2C offsets, or old C256 +0x707 condition. The separate 3.0.1 binary signatures are deliberately fail-closed. The persistent provider binaries were preserved unchanged. A direct archive integrity verifier is provided to detect incomplete file transfers without using a newer version of PowerShell.
