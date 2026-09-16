# Warcraft III 3.0 Windows 7 Compatibility Pack v1.0

**Windows 7 SP1 x64 / Warcraft III 3.0.0.24268**

This resource has grown beyond the original **Windows 7 Battle.net Compatibility Provider**. The original provider is still included and preserved, but Warcraft III 3.0 exposed additional Windows 7 incompatibilities. The project is now a complete native Windows 7 compatibility pack.

**Independent project:** not affiliated with or endorsed by Blizzard Entertainment, Microsoft, AVG, or OpenAI. Warcraft III is still launched through the official Battle.net desktop launcher and connects to Blizzard's official services.

## What the pack fixes

### 1. Battle.net / Schannel compatibility

The original x64 provider restores the Schannel/ncrypt provider-interface path required by the current client on the validated Windows 7 binary set. The pack now also contains an independently audited x86 companion image in `SysWOW64`, which is required by the 32-bit Battle.net/Agent path.

### 2. Warcraft III 3.0 certificate-chain ABI mismatch

Current `ClientSdk.dll` passes an 88-byte `CERT_CHAIN_ENGINE_CONFIG` to `CertCreateCertificateChainEngine`; the validated native Windows 7 `crypt32.dll` accepts the older layout only up to 80 bytes. The launcher temporarily supplies an 80-byte stack-local copy for those startup calls. The caller-owned 88-byte structure is never modified, the original IAT pointer is restored after the two successful calls, and the temporary hook page is freed.

### 3. Native `war3_loader` fatal-path fix

After solving the certificate ABI issue, the remaining online freeze was traced to an internal noreturn/fatal path in `war3_loader`, not to a network timeout. On the validated build, the decisive process-local field differs from its computed value by exactly `+0x707` (`0x0E210193` vs `0x0E21089A`). The launcher applies one guarded four-byte process-local correction **only** when the exact validated hashes and exact predicate mismatch are present.

No Warcraft III executable or DLL is modified on disk.

### 4. Small responsiveness side effect

During diagnostics, a tiny external read-only memory pulse made Reforged-era startup/menu responsiveness feel better on the development machine. The release keeps the lightest successful variant. This is an accidental side benefit, **not** advertised as an FPS patch, and the exact mechanism is not proven.

## Not just the Proton solution

The Proton/Wine work was useful evidence for the `CERT_CHAIN_ENGINE_CONFIG` ABI problem. The later `war3_loader` fatal-path analysis, the exact `+0x707` predicate correction, the Windows provider work, and the release guards were derived and validated on native Windows 7. This pack is therefore broader than a Proton workaround transplanted to Windows.

## Installation

1. Close Warcraft III and Battle.net; fully quit Hide.me if installed.
2. Extract the complete ZIP.
3. Run `INSTALL.bat` as Administrator.
4. **Do not bypass failed hash/preflight checks.**
5. Reboot Windows once.
6. Open the official Battle.net launcher and sign in.
7. Use `START_WARCRAFT_III.bat` to launch Warcraft III.
8. Wait for the green **ONLINE READY** message before using Multiplayer / Custom Games.

Warcraft III and Battle.net may be installed on any drive; the runtime launcher auto-detects the paths.

## Validated game build

- Warcraft III 3.0.0.24268 — Forsaken Kingdom
- `ClientSdk.dll`: `3a8762f6641f39da8099009adccfe1b2f9aa9613defe98273e38341de500b10e`
- `war3_loader.dll`: `e32431e26f58d1201be3f48baed485114227864d8c6b871eae8e9528241ec8e9`

The provider layer is also restricted to the exact documented Windows 7 System32/SysWOW64 binary hashes. If your hashes differ, do not force-install or mix provider variants.

## Tested result on the development machine

- Battle.net launcher/Agent connectivity restored
- Warcraft III 3.0 launches through official Battle.net
- in-game Battle.net authentication works
- Multiplayer / Custom Games works
- map download works
- actual online/custom games were played
- runtime fix cleans up its temporary IAT hook/page after startup
- the console exits automatically after Warcraft closes

## Removal

Run `REMOVE.bat` as Administrator with Warcraft/Battle.net closed, then reboot once. The runtime Warcraft changes are process-local and disappear when the game exits.

## Integrity / source

The release ZIP contains `SHA256SUMS.txt`, the original x64 provider payload, the audited x86 companion plus its source/audit material, the runtime launcher, and technical notes.

The original provider v1.0 archive is preserved historically; its SHA-256 was:
`3db1ba9ccc1b0bcf805b0e849d4df77ffd78d966b50d517187a359b4dc0f85c7`.

For the full technical history and exact system hashes, see the included README and `Documentation/TECHNICAL_NOTES.md`.
