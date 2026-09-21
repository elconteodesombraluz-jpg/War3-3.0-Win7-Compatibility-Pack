Warcraft III 3.0 World Editor Windows 7 Fix v1.0 RC3

IMPORTANT:
This RC2 is rebuilt directly from the exact v1g SHELL-OPEN TEST that succeeded.
The ShellOpen / process-attach / C256 patch logic has not been refactored.

For this validation copy, WorldEditorFix.ini is intentionally preserved from the
successful test and therefore contains:
E:\Games\War3\Warcraft III\_retail_\x86_64\World Editor.exe

Test:
1. Close World Editor. Battle.net may remain open.
2. Run START_WORLD_EDITOR_FIXED.bat.
3. Do not open the map manually.
4. The BAT uses Windows ShellOpen on the bundled dummy.w3m.
5. It should attach to World Editor, find the exact +0x707 state, apply the same
   guarded 4-byte correction, and display WORLD EDITOR FIX ACTIVE.
6. Use the editor normally and close it normally.
7. Send WORLD_EDITOR_WIN7_FIX_v1.0_RC3.txt back if anything differs from v1g.

dummy.w3m SHA-256:
77b4313c9a7498eb3a49a7b4228885f8080b61a369006888c29e5486a8533088

START_WORLD_EDITOR_FIXED.bat SHA-256:
0ab62243088dae5d66cc5b0af4b57f1b0bdecc74faacac43c5d957ed819a5dab
