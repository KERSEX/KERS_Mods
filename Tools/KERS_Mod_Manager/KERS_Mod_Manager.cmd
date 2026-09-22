@echo off
REM ==============================================================
REM  KERS Mod Manager - Starter
REM  Doppelklick genuegt. Der eigentliche Code liegt in manager.ps1.
REM ==============================================================
setlocal EnableExtensions
title KERS Mod Manager

where powershell.exe >nul 2>&1
if errorlevel 1 (
    echo [FEHLER] Windows PowerShell wurde nicht gefunden.
    pause
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0manager.ps1" %*
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
    echo.
    echo Beendet mit Code %RC%.
    pause
)
endlocal & exit /b %RC%
