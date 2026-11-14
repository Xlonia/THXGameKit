extends Node
## 【退出链探针 20261114】验证编辑器退出=get_tree().quit() 真正结束进程：
## 把编辑器实例挂到根 Window 下（=独立进程主场景位，_in_window_mode()=真）
## →1 秒后调 _after_exit("quit")→进程应在超时窗口内自行退出（退出码 0）。
## 旧实现（root Window.queue_free / goto_scene）在此探针下=进程不死（timeout=FAIL），
## 即作者"就算是新 Windows 窗口也退出后卡死"的自动化复现。
## 【跑法】godot --headless --path . res://Tests/exit_probe.tscn
##   预期：stdout 出现 EXIT_PROBE_BEGIN，进程 <30s 自退（exit 0）

func _ready() -> void:
	var ed: Control = (load("res://addons/thx_gamekit/editor/danmaku_editor.gd") as GDScript).new()
	get_tree().root.add_child.call_deferred(ed)
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(ed) or not ed.is_inside_tree():
		print("[exit_probe] FAIL：编辑器实例未就位")
		get_tree().quit(1)
		return
	print("[exit_probe] EXIT_PROBE_BEGIN（_after_exit('quit')）")
	ed._after_exit("quit")
	## 走到这里=quit 未生效（进程还活着）——5 秒后自杀并报 FAIL
	await get_tree().create_timer(5.0).timeout
	print("[exit_probe] FAIL：quit 后进程仍存活（退出链病根复现）")
	get_tree().quit(2)
