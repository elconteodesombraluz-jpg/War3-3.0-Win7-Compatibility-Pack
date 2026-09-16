# Release notes — v1.0

This is the first release under the **Warcraft III 3.0 Windows 7 Compatibility Pack** name.

The important packaging change is that the old provider is no longer presented as the whole solution. Its original x64 release is preserved byte-for-byte as one component. The pack then adds the audited x86 Battle.net/Agent companion and the separately validated Warcraft III 3.0 process-local runtime launcher.

For existing users of the old provider: if the exact x64 provider is already installed and registered, `INSTALL.bat` recognizes it and does not overwrite it. If the exact x86 companion is already present, it is also reused. Unexpected provider files fail closed.

For fresh installations: use only the root `INSTALL.bat`, reboot, sign into Battle.net, then launch via `START_WARCRAFT_III.bat`.
