@echo off
rem THXGameKit 编辑器独立进程启动（与标题画面进程完全独立）
rem 用法：双击本文件直接打开弹幕编辑器（无需经过标题画面）
cd /d "%~dp0"
start "" "Godot_v4.7.2-stable_win64.exe" --path . "res://scenes/danmaku_editor.tscn"
