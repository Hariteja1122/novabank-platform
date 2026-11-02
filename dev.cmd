@echo off
rem Double-click friendly launcher for Windows: starts the full NovaBank stack.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0dev.ps1" %*
if "%1"=="" pause
