# Technical notes — Warcraft III 3.0 Windows 7 Compatibility Pack v1.1

## 1. Persistent provider layer

The x64 and x86 Windows compatibility providers are unchanged from v1.0. They restore the Schannel/ncrypt provider-interface path required by the validated Battle.net/Agent configuration.

Validated provider DLLs:

- x64: `d2dc7f30344f2f4482196301835fdc45231619fc4df3d74bf49bf809b5fcbc90`
- x86: `e32754c90d6e44844103b02c681e4e1b7a09fc5ae349f2e1a2abc5ce304496ef`

The persistent provider layer is unchanged. v1.1 updates the process-local Warcraft runtime helper and the separate World Editor helper.

## 2. ClientSdk certificate ABI compatibility

The October 7, 2026 `ClientSdk.dll` still imports `CRYPT32!CertCreateCertificateChainEngine`, with the IAT slot at RVA `0x00767170`.

The caller supplies an 88-byte `CERT_CHAIN_ENGINE_CONFIG`. The validated Windows 7 `crypt32.dll` accepts the older layout only up to 80 bytes. The runtime launcher therefore intercepts only the validated startup calls and, when `cbSize == 88`, passes a stack-local 80-byte copy with `cbSize` rewritten to 80. The caller-owned 88-byte structure is never modified.

After two successful translated calls, the original IAT pointer is restored exactly. Two seconds later the temporary executable hook page is freed.

## 3. October 7 loader change

The v1.0 Warcraft runtime used a guarded four-byte correction for an exact `+0x707` mismatch in the old `C25698..C256C2` predicate. The October 7 update changed the loader enough that transplanting `+0x707` was invalid.

Validated new hashes:

- `ClientSdk.dll`: `04f798ac211b9fea1b741b4f1d520d7e5b3cf5f038241c909b7429b02a4cf134`
- `war3_loader.dll`: `df44a65ef76ac2159f531693a751de22807dd454778090475292092c111e6461`

The new frozen GUI thread repeatedly terminated in:

`ntdll+0x698CA → KERNELBASE+0x10AC → KERNELBASE+0x2D30 → war3_loader+0xEB442D → war3_loader+0xE4B15B → war3_loader+0x11A8E89`

This is the same class of terminal loader wait as the previous build, but the decisive arithmetic is different.

## 4. Regenerated object and encoded timebase

The relevant process-local object is decoded from regenerated loader globals. In the validated build the object relationship is:

`obj = ((g20DF278 XOR 0x10ADFFD4851EEA22) - g20DF278 + 0x5488CB87A2C1A6B0) XOR g218B878`

The critical dword is `object+0x2C`.

The fatal frame established:

- `decodedStored = frame[0x40] XOR frame[0x4C]`
- `elapsed = frame[0x48] - decodedStored`
- `frame[0xA0] == elapsed`
- `threshold = frame[0xA8] - frame[0xA4]`
- `threshold == 0x7530 == 30000 ms`
- the fatal branch is taken when `frame[0xA0] >= threshold`

Across validation runs, `frame[0x4C]` was `0xFF391B88`, and the live field decodes as:

`storedTick = object+0x2C XOR 0xFF391B88`

The decoded value tracks the Windows millisecond tick counter.

The object is additionally guarded by the observed `object+0x60` signature:

`object+0x60 XOR 0x2FE40E77 == 0x00000909`

## 5. Why the one-shot v1.1 prototype was insufficient

A one-time refresh after certificate call #1 allowed the game to pass the initial online transition, complete significantly more navigation and begin downloading a map.

However, once the injected timestamp itself aged past 30 seconds, the fatal frame again captured the stale timestamp before the game's own later update. One validated failure showed:

- stored timestamp age in fatal frame: `38423 ms`
- threshold: `30000 ms`
- branch relation: true

The game's own writer refreshed `object+0x2C` shortly afterward, but by then the stale value had already been copied into the fatal frame.

## 6. v1.1 heartbeat correction

The final v1.1 runtime keeps the same exact-hash / object-signature guards and maintains the encoded timebase with a large margin below the fatal threshold.

Startup:

1. translated certificate call #1 succeeds;
2. the regenerated object and signature are validated;
3. if the decoded timestamp is plausibly recent, the launcher writes `GetTickCount() XOR 0xFF391B88` to `object+0x2C`;
4. the four-byte write is immediately read back and verified;
5. translated certificate call #2 succeeds;
6. the original IAT is restored and the hook page is freed;
7. an 8-second stabilization window is kept before READY.

Runtime:

- approximately every 250 ms, the object/signature are revalidated;
- if decoded age is below 10,000 ms, no write occurs;
- when decoded age reaches 10,000 ms, exactly four process-local data bytes are refreshed;
- decoded ages above 120,000 ms fail closed instead of being blindly rewritten;
- every write receives an immediate readback check.

No `war3_loader` code byte is patched.

## 7. Validation

The diagnostic heartbeat test ran for approximately 930.94 seconds after the certificate stage and performed 92 guarded refreshes without a fatal hang. During that session the user completed an online map download, left the lobby flow, created a private online game, played the game to completion, and exited normally.

A release-candidate cleanup run then validated normal shutdown handling without a false error:

`WARCRAFT_EXIT=True ... teardownRaceHandled=False`

## 8. v1.0 performance pulse

The old v1.0 release retained a separate read-only ~1 ms `ReadProcessMemory` pulse because it subjectively improved responsiveness on the earlier build.

That pulse is not part of v1.1. The October update changed the runtime path and the new heartbeat mechanism was validated independently. v1.1 avoids retaining an unrelated experimental behavior that was not revalidated on the new build.

## 9. Cleanup and lifetime

The Windows provider DLLs are persistent components and require explicit installation/removal plus a reboot when their state changes.

The certificate hook and timebase writes are process-local. The IAT hook is removed during startup, the private hook page is freed, and all process-memory changes disappear when Warcraft exits. No Warcraft file is rewritten.

## 10. World Editor v1.1

The October 2026 World Editor binaries validated for this helper are:

- `World Editor.exe`: `f46f0a72d32cbdd366f4a0f7de54d35ad2ccad9d00e23749269910afd75c34e3`
- `worldedit_loader.dll`: `aefd841b006117d11582b018031fe9d7a2c8f48150c688e54f1c64b7f66c67cd`

Static comparison showed the relevant October `worldedit_loader.dll` loader implementation uses the same regenerated encoded-timebase path validated for Warcraft III v1.1. The World Editor helper therefore uses the same guarded runtime policy:

- decode and validate the regenerated object;
- require the observed `object+0x60 -> 0x909` signature;
- decode `object+0x2C` with the validated `0xFF391B88` key;
- keep decoded age below the 30,000 ms fatal threshold;
- check approximately every 250 ms and write only at 10,000 ms age;
- write exactly four process-local data bytes and verify each write immediately.

The World Editor helper does **not** depend on Battle.net. Battle.net may be open or closed.

The bundled `dummy.w3m` is a launch target for the normal Windows `.w3m` ShellOpen path. This avoids directly starting `World Editor.exe`, which followed a different startup path on the validated system. After the helper reports READY, any other map may be opened inside the same World Editor process.

The validation run began with a naturally fresh timestamp (`46 ms` old), performed 8 guarded heartbeat refreshes over approximately 90.9 seconds, reported no hung-window state, and ended with a normal process exit.
