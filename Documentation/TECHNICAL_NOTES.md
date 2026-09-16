# Technical notes — Warcraft III 3.0 Windows 7 Compatibility Pack v1.0

## 1. Architecture

The working native-Windows-7 solution is composed of three independent compatibility layers. Keeping them separate matters because each addresses a different failure mode and each has a different lifetime.

### Layer A — Schannel / ncrypt provider compatibility

The initial Battle.net failure was isolated to the Windows Schannel/ncrypt provider-interface boundary. On the validated Windows 7 system, the historical compatible SSL provider path exposes the older table while the current ncrypt path expects the version-3 extension. The original x64 provider preserves slots 0..25 and exposes the real native callbacks used in slots 26 and 27 (`SslComputeSessionHash`, `SslGeneratePreMasterKey`). It preserves real nonzero error statuses and returns `NTE_NOT_SUPPORTED` if required symbols cannot be resolved.

The Battle.net/Agent path is 32-bit. A PE32/i386 companion build was therefore reconstructed and independently audited for the corresponding SysWOW64 system binaries. The x86 image is copied to `%WINDIR%\SysWOW64\War3Win7BattleNetCompat.dll`. It does not create a second CNG registration: the original provider registration is preserved, while Windows DLL redirection supplies the architecture-appropriate image to 32-bit clients.

On the validated machine, closing Hide.me completely and installing the x86 companion restored the x86 Schannel/curl path to HTTP 200 and allowed the current Battle.net Agent/launcher path to update and install Warcraft III 3.0.

## 2. ClientSdk / crypt32 ABI compatibility

Warcraft III 3.0.0.24268 ships `ClientSdk.dll` that passes an 88-byte `CERT_CHAIN_ENGINE_CONFIG` to `CertCreateCertificateChainEngine`. Native Windows 7 `crypt32.dll` on the validated system accepts the legacy 64/80-byte layouts and rejects the modern 88/96-byte forms with `E_INVALIDARG`.

The runtime launcher finds the `ClientSdk.dll!CertCreateCertificateChainEngine` IAT entry from the exact on-disk PE rather than relying on a hard-coded virtual address. It then installs a small process-local wrapper. When `cbSize != 88`, the call is forwarded without translation. When `cbSize == 88`, the wrapper copies the first 80 bytes to a stack-local structure, sets the local `cbSize` to 80, and calls the real Windows 7 API on that copy. The caller-owned 88-byte structure is never modified.

Exactly two translated startup calls were observed on the validated build and both return TRUE. After the second successful translated call, the original IAT pointer is restored exactly. After a short in-flight safety delay, the private executable hook page is released with `MEM_RELEASE`.

This 88→80 ABI translation is the part of the investigation that was initially informed by the Proton/Wine compatibility behavior. The implementation here is a native Windows 7 process-local shim.

## 3. Independent war3_loader fatal-path investigation

After the certificate ABI issue was fixed, online transitions could still route Warcraft into a permanent freeze. Network activity remained alive; the Warcraft GUI thread instead ended in `NtWaitForSingleObject` on a non-signaled auto-reset event with an infinite timeout.

The repeated terminal stack was:

`ntdll!NtWaitForSingleObject → KERNELBASE!WaitForSingleObjectEx → war3_loader+F4DAA1 → war3_loader+C28478 → war3_loader+1F90BCB`

Further static/live analysis established that this is a noreturn/fatal route through the flattened `C24140` dispatcher, not a missing normal producer for the final event. The recovered fatal-state path included:

`0x39411D30 → 0x5D245464 → 0x01573B0D → 0x18821727 → C268BB → 0x6A49A769 → C27AAF → C28462 → F4C6F0 → infinite wait`

The first useful arithmetic discriminator was isolated around `C25698..C256C2`. On fatal runs the computed value was `0x0E21089A` while the object field held `0x0E210193`, an exact difference of `+0x707`. That mismatch routed execution into the fatal state chain.

## 4. Guarded C256 correction

The validated runtime launcher waits until translated certificate call #1 succeeds, then locates the same process-local object and tests the field. It writes exactly four bytes **only** when all of the following are true:

- `ClientSdk.dll` SHA-256 matches the validated build;
- `war3_loader.dll` SHA-256 matches the validated build;
- the current object value is `0x0E210193`;
- the computed expected value is `0x0E21089A`;
- the exact delta is `0x707`.

The new process-local value is `0x0E21089A`. No `war3_loader` code byte is modified. The game files on disk are untouched.

Applying the correction immediately after certificate call #1, rather than waiting for certificate call #2, proved important on runs where the pre-menu online transition could otherwise enter the bad path before the second call.

## 5. Read-only performance pulse

During diagnostics, a high-cadence external watcher unexpectedly made the Reforged-era startup/menu feel noticeably more responsive on the validated Windows 7 machine. Controlled A/B tests separated the compatibility fix from the pulse.

The release uses the lightest variant that produced a useful subjective benefit: one read-only 4-byte `ReadProcessMemory` against the already-corrected C256 value followed by `Thread.Sleep(1)`. It runs only after READY and stops when Warcraft exits.

Telemetry did **not** show a CPU-frequency increase: the measured CPU stayed at the same reported frequency, and Windows timer resolution was already approximately 1 ms. Additional USER32/RPM experiments did not yield a sufficiently clean causal mechanism. Therefore the pack makes no FPS or universal performance claim. The pulse is retained only because it was harmless in the validated runs and improved the development-machine experience.

## 6. Cleanup and lifetime

The provider DLLs are persistent Windows compatibility components and require explicit installation/removal plus a reboot when their state changes.

The Warcraft ABI shim and C256 correction are process-local. The IAT hook is removed during startup; its private executable page is freed. The C256 data change disappears when Warcraft exits. The read-only pulse stops at process exit. No Warcraft file is rewritten.

## 7. Build identity

Validated Warcraft runtime:

- Warcraft III 3.0.0.24268 — Forsaken Kingdom
- `ClientSdk.dll`: `3a8762f6641f39da8099009adccfe1b2f9aa9613defe98273e38341de500b10e`
- `war3_loader.dll`: `e32431e26f58d1201be3f48baed485114227864d8c6b871eae8e9528241ec8e9`

Validated provider identities:

- x64: `d2dc7f30344f2f4482196301835fdc45231619fc4df3d74bf49bf809b5fcbc90`
- x86: `e32754c90d6e44844103b02c681e4e1b7a09fc5ae349f2e1a2abc5ce304496ef`

All components fail closed when their documented binary identity does not match.
