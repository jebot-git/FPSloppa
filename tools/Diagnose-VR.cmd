@echo off
setlocal
if not exist "%~dp0FPSloppa.exe" (
  echo Place this file beside FPSloppa.exe in the extracted Windows build.
  pause
  exit /b 2
)
set "probe_log=%TEMP%\FPSloppa-VR-startup.log"
echo Logging to "%probe_log%"
echo Leave SteamVR and the headset running before starting this test.
"%~dp0FPSloppa.exe" --xr-mode on --verbose %* > "%probe_log%" 2>&1
set "probe_exit=%ERRORLEVEL%"
echo.>> "%probe_log%"
echo Process exit code: %probe_exit%>> "%probe_log%"
type "%probe_log%"
echo.
echo Log saved to "%probe_log%"
pause
exit /b %probe_exit%
