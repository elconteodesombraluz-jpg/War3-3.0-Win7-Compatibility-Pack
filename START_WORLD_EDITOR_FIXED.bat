@echo off
setlocal EnableExtensions
title Warcraft III 3.0.1.24371 World Editor - Win7 Fix v1.2
if not exist "%~dp0War3_3.0.1_WorldEditor_Win7_Fix_v1.2\START_WORLD_EDITOR_FIXED.bat" (
  echo ERROR: World Editor helper is missing from the complete pack.
  pause
  exit /b 3
)
call "%~dp0War3_3.0.1_WorldEditor_Win7_Fix_v1.2\START_WORLD_EDITOR_FIXED.bat"
exit /b %ERRORLEVEL%
