Warcraft III 3.0 World Editor Windows 7 Fix v1.1
==================================================

Purpose
-------
This helper fixes the October 7, 2026 Warcraft III 3.0 World Editor freeze on
the exact validated Windows 7 SP1 x64 build.

It is independent of Battle.net. Battle.net may be running or completely closed.
The helper does not use Battle.net to start World Editor.

Why dummy.w3m is included
-------------------------
Launching World Editor.exe directly followed a different startup path on the
validated machine and could invoke Battle.net / produce editor rendering and
trigger problems.

START_WORLD_EDITOR_FIXED.bat therefore asks Windows to open the bundled
dummy.w3m through the normal .w3m file association. This reproduces the clean
standalone World Editor startup path. The helper then attaches to that World
Editor process, verifies the exact supported binaries, validates the runtime
object/signature, and activates the guarded timebase fix.

After the green status appears, you may close dummy.w3m and open any other map
inside the SAME World Editor process.

Validated October 2026 hashes
-----------------------------
World Editor.exe
f46f0a72d32cbdd366f4a0f7de54d35ad2ccad9d00e23749269910afd75c34e3

worldedit_loader.dll
aefd841b006117d11582b018031fe9d7a2c8f48150c688e54f1c64b7f66c67cd

dummy.w3m
77b4313c9a7498eb3a49a7b4228885f8080b61a369006888c29e5486a8533088

How the fix works
-----------------
The October worldedit_loader uses the same regenerated loader implementation as
the validated Warcraft III v1.1 runtime path.

The relevant process-local object contains an encoded millisecond timestamp at
object+0x2C. The fatal path uses a 30,000 ms threshold. On the affected Windows 7
path, allowing the timestamp to become stale can route World Editor into the
terminal loader wait.

v1.1:
- validates the exact World Editor and worldedit_loader hashes;
- validates the decoded object and the observed object+0x60 -> 0x909 signature;
- performs a guarded initial 4-byte timebase refresh only if needed;
- rechecks approximately every 250 ms;
- refreshes exactly 4 process-local DATA bytes only when decoded age reaches
  10,000 ms;
- verifies every write immediately;
- patches no code byte and changes no Blizzard file or map on disk.

The process-local changes disappear when World Editor exits.

Use
---
1. Close any already-running World Editor.
2. Battle.net may be open or closed; the fix does not depend on it.
3. Run START_WORLD_EDITOR_FIXED.bat.
4. Do not manually launch World Editor.exe.
5. Wait for the green message:
   WORLD EDITOR WIN7 FIX ACTIVE - USE THE EDITOR NORMALLY
6. Close dummy.w3m or open your normal map from inside that same editor process.
7. Use World Editor normally.
8. Close World Editor normally when finished.

Path detection
--------------
WorldEditorFix.ini defaults to:

WorldEditorPath=

Blank means auto-detect.

If auto-detection fails, set the full path manually, for example:

WorldEditorPath=E:\Games\War3\Warcraft III\_retail_\x86_64\World Editor.exe

No provider installation is required specifically for this World Editor helper.

Validation
----------
The v1.1 mechanism was validated on Windows 7 SP1 x64 with Battle.net already
running. The same helper is intentionally Battle.net-independent: its startup
mechanism is the Windows .w3m ShellOpen association, not Battle.net.

In the validation run, World Editor remained responsive across repeated
30-second windows, performed 8 guarded heartbeat refreshes, and exited normally.

Log
---
WORLD_EDITOR_WIN7_FIX_v1.1.txt