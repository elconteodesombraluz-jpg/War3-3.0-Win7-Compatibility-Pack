# Release notes — v1.1

Released for the Warcraft III 3.0 update distributed on October 7, 2026.

The persistent x64/x86 provider layer is unchanged from v1.0. Existing users with the exact validated providers already installed do not need a different provider build.

The Warcraft runtime has been re-audited for the new `ClientSdk.dll` and `war3_loader.dll` hashes:

- `ClientSdk.dll`: `04f798ac211b9fea1b741b4f1d520d7e5b3cf5f038241c909b7429b02a4cf134`
- `war3_loader.dll`: `df44a65ef76ac2159f531693a751de22807dd454778090475292092c111e6461`

The old raw C256 `+0x707` correction has been removed. The updated loader uses an encoded millisecond timebase in the validated object. The v1.1 runtime performs a guarded initial four-byte refresh after certificate call #1 and maintains that timebase below the observed 30-second fatal threshold while Warcraft runs.

The v1.0 experimental read-only ~1 ms responsiveness pulse is not carried forward.

Validation on the development machine included successful Multiplayer / Custom Games navigation, online map download, creation of a private online game, completion of an actual online game, and clean shutdown.

The World Editor helper is being re-audited separately for the October update. Do not force the previous World Editor helper onto the new binaries.