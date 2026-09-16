# Changelog

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
