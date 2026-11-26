@echo off
rem THXGameKit 编辑器独立进程启动（与标题画面进程完全独立）
rem 【m128】project.godot 已永久改名 standalone——防止 th75 编辑器把本目录
rem 当嵌套项目跳过扫描（全局类缓存被刷根因——作者编辑器打开 th75 即坏）。
rem 本 bat 临时恢复 project.godot → 启动编辑器（/wait 阻塞）→ 关闭后自动删回。
cd /d "%~dp0"
copy /y project.godot.standalone project.godot >nul
start /wait "" "Godot_v4.7.2-stable_win64.exe" --path . "res://scenes/danmaku_editor.tscn"
del project.godot
