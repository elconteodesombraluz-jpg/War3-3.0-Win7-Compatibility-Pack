Warcraft III 3.0.1.24371 World Editor Windows 7 Fix v1.2
=============================================================

Validated on Windows 7 SP1 x64, build 3.0.1.24371.
This is a standalone helper: Battle.net need not be running.

1. Close any running World Editor instance.
2. Run START_WORLD_EDITOR_FIXED.bat (or the pack's root shortcut).
3. The INCLUDED dummy.w3m opens through its normal Windows association.
4. Leave the console open; a green status confirms the 4-byte fix is active.
5. Close the dummy map if desired, open another map in the SAME editor,
   and keep the helper running until you close World Editor.

If auto-detection fails, set WorldEditorPath= to the complete exe path in
WorldEditorFix.ini. You may also set WAR3_ROOT to the Warcraft III folder.

The helper validates hashes and two probes of the decoded object,
including the low byte of object+0x68 and stable object+0x70 field. It
refreshes the encoded timestamp at object+0x6C only when age reaches 10 s,
then immediately verifies its 4-byte process-local write.

No game/editor binary, map, or DLL is modified on disk. On a hash mismatch,
there is no memory modification; do not bypass that safety check.

Supported exact hashes:
World Editor.exe: 988a6a49f729cd3a20e91e82edd88b4d955be3757d66d8283e261f75b755ac22
worldedit_loader.dll: 0e24a0270bdffa9edd68bbd7f7a2e8bafc3c232317fbda0cfabe23ea0407e3d9
dummy.w3m: 77b4313c9a7498eb3a49a7b4228885f8080b61a369006888c29e5486a8533088

Validated TEST4 log (2026-10-22): 10 successful refreshes in 110.9 s,
fixActivated=True. Continued responsiveness was reported by the tester.

Session log: WORLD_EDITOR_24371_FIX_v1.2.txt
