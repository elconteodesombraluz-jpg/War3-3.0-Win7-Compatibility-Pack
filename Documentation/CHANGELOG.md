# Changelog

## Warcraft III 3.0 Windows 7 Compatibility Pack v1.1 — 2026-10-07

- Re-audited the Warcraft runtime after the October 7, 2026 Blizzard update changed `ClientSdk.dll` and `war3_loader.dll`.
- Preserved the validated x64/x86 Windows provider layer unchanged.
- Confirmed the `CERT_CHAIN_ENGINE_CONFIG` 88→80 compatibility translation is still required; the ClientSdk certificate IAT RVA remains `0x00767170`.
- Removed the previous build's raw C256 `+0x707` correction.
- Identified the new `object+0x2C` field as an encoded millisecond timebase used by a 30,000 ms fatal-path threshold.
- Added guarded initial timebase refresh after certificate call #1.
- Added guarded runtime heartbeat maintenance: revalidate approximately every 250 ms and write only when decoded age reaches 10,000 ms.
- Added immediate readback verification for every four-byte process-local heartbeat write.
- Kept exact hash/object/signature fail-closed guards.
- Removed the v1.0 experimental read-only ~1 ms responsiveness pulse from the new runtime.
- Validated map download, private online game creation, a completed online game, more than 15 minutes of heartbeat operation, and normal shutdown.
- Re-audited the World Editor helper for the October build.
- Confirmed the new `worldedit_loader.dll` uses the same validated encoded-timebase mechanism as the updated Warcraft loader.
- Replaced the old World Editor `+0x707` helper with a guarded 10-second timebase heartbeat.
- Preserved the ShellOpen `dummy.w3m` launch path; the World Editor helper is independent of Battle.net and works whether Battle.net is open or closed.
- Validated normal World Editor use across repeated 30-second windows, 8 guarded heartbeat refreshes, and clean shutdown.

## Warcraft III 3.0 Windows 7 Compatibility Pack v1.0 — 2026-09-15

- Reframed the project from a provider-only utility into a complete Warcraft III 3.0 Windows 7 compatibility pack.
- Preserved the original public x64 provider v1.0 payload unchanged.
- Added the independently audited x86/PE32 companion provider for the Battle.net/Agent SysWOW64 Schannel path.
- Added a portable Warcraft III launcher that auto-detects Warcraft III and Battle.net locations.
- Added the process-local `CERT_CHAIN_ENGINE_CONFIG` 88→80 compatibility translation for the validated `ClientSdk.dll`.
- Added the guarded four-byte C256 `+0x707` process-local correction discovered by native `war3_loader` analysis.
- Restores the original ClientSdk IAT after the two startup certificate calls and releases the temporary hook page.
- Added the lightweight read-only ~1 ms performance pulse discovered during diagnostics; documented as an observed responsiveness improvement rather than an FPS guarantee.
- Added root install/remove/verify/launch wrappers with fail-closed hash checks and unexpected-provider protection.
- Added exact package-wide SHA-256 manifest and technical documentation.

## Historical provider v1.0 — 2026-08-20

- Initial Windows 7 Battle.net compatibility provider release.
- Restored the required Schannel/ncrypt provider-interface path on the original validated x64 Windows 7 binary set.
- Original public archive SHA-256: `3db1ba9ccc1b0bcf805b0e849d4df77ffd78d966b50d517187a359b4dc0f85c7`.