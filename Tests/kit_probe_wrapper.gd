extends Node
## kit 探针 wrapper（双布局）：probe_script 未设时按工程布局探测
## （GameKit 仓=res://Tests/<名>.gd；th75 宿主=submodule Tests/ 路径）
@export var probe_script: GDScript
@export_file("*.gd") var probe_path := ""
func _ready() -> void:
	var scr: GDScript = probe_script
	if scr == null and probe_path != "":
		scr = load(probe_path)
	if scr == null:
		push_error("[wrapper] probe_script/probe_path 均未提供")
		get_tree().quit(1)
		return
	var n := Node.new()
	n.set_script(scr)
	get_tree().root.add_child.call_deferred(n)
