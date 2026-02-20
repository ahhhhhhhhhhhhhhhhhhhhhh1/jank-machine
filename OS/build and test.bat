@echo off

py build.py

if %errorlevel% NEQ 0 (
pause
exit /b 1
)

qemu-system-x86_64 -fda full.bin

if %errorlevel% NEQ 0 (
pause
exit /b 1
)