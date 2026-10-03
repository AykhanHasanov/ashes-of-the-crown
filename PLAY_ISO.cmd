@echo off
rem Ashes of the Crown - isometric build (iso-main branch).
rem Opens the iso scene directly. Options go after the script name, e.g.:
rem   PLAY_ISO.cmd --quality=high      PLAY_ISO.cmd --quality=low
cd /d "%~dp0"
start "" "C:\Users\User\Documents\games\_tools\godot\Godot_v4.7.2-stable_win64.exe" --path . res://iso/scenes/iso_game.tscn -- %*
