Warcraft III - Windows 7 Battle.net compatibility provider v1.0
================================================================

IMPORTANT
---------
This is an independent compatibility project for Warcraft III on a specific Windows 7 SP1 x64
binary set. It is not affiliated with, supported by, or endorsed by Blizzard Entertainment or
Microsoft.

The tool is intended only for Warcraft III launched normally from the official Battle.net desktop
launcher and connected to Blizzard's official services.

It does NOT redirect Battle.net traffic, emulate authentication, fabricate tokens or credentials,
patch Warcraft III, replace Microsoft system DLLs, or force failed security operations to succeed.

Use at your own risk. Keep REMOVE.bat and the generated reports until you are satisfied that the
installation works correctly.

PROJECT ORIGIN AND SUPPORT LIMITS
---------------------------------
This compatibility tool was developed through a long iterative investigation performed with ChatGPT
by OpenAI, together with repeated tests on the affected Windows 7 machine.

The person publishing and testing this package is a novelist, not a software engineer, Windows
internals specialist, cryptography researcher, or security professional, and does not have formal
qualifications in those fields.

For that reason, the publisher can document what was tested and what worked on the validated machine,
but may not be able to answer technical questions, debug other Windows configurations, or provide
individual support.

The technical description below is intentionally included so that people with the appropriate
expertise can independently inspect, reproduce, or adapt the work.

VALIDATED v1.0 SYSTEM
---------------------
This public v1.0 was validated on Windows 7 SP1 x64 with the exact audited system-binary hashes below:

  schannel.dll          51dcfaa5fe70d231d609fc7c37a3262c30d613721420efd65f8c33578c371501
  ncrypt.dll            962f201ee3b08e3fc4a0849251958c573ebcb3b32f588ec624ebc443a2400be9
  bcrypt.dll            e101aa09220b126962ed5de00d7f15bcd645890f33afa1728fafd78d2e67ae90
  bcryptprimitives.dll  715977e616e206724f91660ef5bd0c4f2c6d66e3891f03c28a864419102ce5b6

The automatic installer checks these hashes before making any change.

If the precheck fails, do NOT bypass it. A different Windows build or binary set has not been
validated by this release.

WHAT THE TOOL FIXES
-------------------
In the validated Windows 7 environment, the current Warcraft III / Battle.net connection path reaches
Windows Schannel/ncrypt functionality that expects a version-3 SSL provider interface.

The older compatible provider path available on this Windows 7 system exposes a version-2 interface
containing slots 0 through 25. The current ncrypt path requires the version-3 extension and in
particular the real SslComputeSessionHash callback.

The compatibility provider keeps the existing provider behavior and exposes a relocated version-3
interface. Slots 0 through 25 are preserved. The real ncrypt callbacks SslComputeSessionHash and
SslGeneratePreMasterKey are resolved into slots 26 and 27.

Real nonzero error statuses are preserved. Resolver failure remains NTE_NOT_SUPPORTED.
No success result is fabricated.

The compatibility DLL does not contain the diagnostic trace/status-only instrumentation used during
development.

WINDOWS 8 / OTHER WINDOWS BUILDS
--------------------------------
Windows 8 is NOT supported or validated by this v1.0 release.

It is currently unknown whether the same compatibility mechanism is needed on Windows 8, whether it
would work unchanged, or whether a different interface/layout is involved.

INSTALL.bat deliberately rejects Windows 8 and any Windows 7 system whose audited binary hashes do not
match the validated set. Do not remove that protection simply to "try it".

For someone with the appropriate Windows-internals skills who wants to investigate another system,
the relevant approach is to reproduce the diagnosis on that exact system:

  - identify the Schannel/ncrypt call that returns NTE_NOT_SUPPORTED;
  - determine the provider-interface version and table layout expected by that build;
  - identify which real native callbacks are required;
  - preserve the existing provider entries and real error semantics;
  - construct a compatibility provider specifically for that system;
  - add fail-closed checks for the exact system binaries that were actually analyzed and tested.

The hashes and interface details in this package must not be assumed to apply to Windows 8 or to every
Windows 7 installation.

INSTALLATION PATHS
------------------
Warcraft III and Battle.net do NOT need to be installed on C: and no fixed game path is used.

The tool does not search for, patch, or modify Warcraft III or Battle.net files. The package can also
be extracted on another drive.

Windows system locations are resolved from the running Windows environment rather than from a fixed
"C:\Windows" path. The development/test machine itself used C:\Windows, so a Windows installation
located on another drive has not been separately validated.

AVG / ANTIVIRUS NOTE
--------------------
On the Windows 7 machine used during development, AVG interfered with the installation process by
blocking the involved compatibility files. Once the verified package had been allowed to install,
no further AVG-related problem was observed during normal Warcraft III / Battle.net use.

Antivirus behavior can vary by product version and configuration. Before allowing or restoring any
blocked file, verify the SHA-256 hashes in SHA256SUMS.txt.

If AVG or another antivirus quarantines or removes a package file, do not continue with an incomplete
package. Restore/allow only the verified release files whose hashes match SHA256SUMS.txt, then run
INSTALL.bat again. Prefer a specific allow-list/exclusion for the verified release files rather than
broadly weakening system protection.

AUTOMATIC INSTALLATION - RECOMMENDED
------------------------------------
1. Close Warcraft III and the Battle.net desktop application.
2. Extract the complete package to a normal folder.
3. Right-click INSTALL.bat and choose Run as administrator.
4. INSTALL.bat checks Windows 7 x64, the four system hashes above, and the package DLL hash.
5. If the precheck fails, stop. Nothing should be installed.
6. If installation succeeds, INSTALL.bat verifies the installed System32 DLL hash.
7. Keep INSTALL_REPORT.txt.
8. Reboot Windows once.
9. Start the official Battle.net desktop launcher normally.
10. Launch Warcraft III from the official launcher and use Battle.net normally.

MANUAL INSTALLATION - ADVANCED USERS
------------------------------------
The automatic method is recommended because it performs the compatibility checks.

For an advanced manual installation:
1. Close Warcraft III and Battle.net.
2. Verify the four system hashes above.
3. Verify:
     War3Win7BattleNetCompat.dll
     SHA256 = d2dc7f30344f2f4482196301835fdc45231619fc4df3d74bf49bf809b5fcbc90
4. Only if every hash matches exactly, run War3Win7BattleNetCompatInstall.exe as Administrator.
5. Verify after installation that:
     %SystemRoot%\System32\War3Win7BattleNetCompat.dll
   has SHA256:
     d2dc7f30344f2f4482196301835fdc45231619fc4df3d74bf49bf809b5fcbc90
6. Reboot Windows once.
7. Launch Warcraft III only through the official Battle.net launcher.

Do not use the manual method to bypass an automatic precheck failure.

REMOVAL
-------
1. Close Warcraft III and the Battle.net desktop application.
2. Right-click REMOVE.bat and choose Run as administrator.
3. Keep REMOVE_REPORT.txt if an error is reported.
4. Reboot Windows once after removal.

IF SOMETHING GOES WRONG
-----------------------
Do not repeatedly reinstall over an unknown partial state.

Keep and share, when possible:
  INSTALL_REPORT.txt
  REMOVE_REPORT.txt

If INSTALL.bat reports a precheck failure, do not bypass it.
If the installer reports a post-install hash failure, use REMOVE.bat before further testing.
If removal cannot immediately delete the unique System32 DLL because it is still in use, reboot and
run REMOVE.bat again.

FILES
-----
  War3Win7BattleNetCompat.dll          Compatibility-provider DLL.
  War3Win7BattleNetCompatInstall.exe   Provider-registration installer.
  INSTALL.bat                          Recommended checked installation.
  REMOVE.bat                           Reversible provider removal.
  README.txt                           This documentation.
  SHA256SUMS.txt                       Release file hashes.

PROVIDER IDENTITY
-----------------
Provider name : War3 Win7 Battle.net Compat v1.0
System32 DLL  : War3Win7BattleNetCompat.dll
DLL SHA256    : d2dc7f30344f2f4482196301835fdc45231619fc4df3d74bf49bf809b5fcbc90

VALIDATION STATUS
-----------------
The clean provider, checked installation, reboot sequence, official Battle.net launch, Warcraft III
Battle.net connection, multiplayer access, game operation and map download were successfully tested
on the exact Windows 7 x64 binary set listed above.

No claim is made for untested Windows builds or antivirus configurations.

LEGAL / INDEPENDENCE
--------------------
This package contains only the independent compatibility provider and installation/removal tools.

No Blizzard game executable, Battle.net executable, Microsoft system DLL, authentication material,
token, account credential, or server-side component is distributed.

Warcraft, Warcraft III, Battle.net and Blizzard Entertainment are trademarks or properties of their
respective owners. Windows and Microsoft are trademarks or properties of Microsoft Corporation.

This project is independent and is not affiliated with or endorsed by Blizzard Entertainment,
Microsoft, AVG, or OpenAI.