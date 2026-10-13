@echo off
setlocal
if not defined GODOT_BIN set "GODOT_BIN=godot"
"%GODOT_BIN%" --path "%~dp0" --xr-mode off -- --launcher %*
