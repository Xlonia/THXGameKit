extends Node
## spin_hunt_probe —— 空转烧帧定位（作者分析器：3600帧/0.12s 全零负载）
##   复现作者路径：编辑器（主窗替换模式）→直接 _confirm_exit("title")
##   →切标题后全树扫描 仍活跃的 process/_physics_process 节点+每帧重画源
var _frames := 0
func _ready() -> void:
	await get_tree().process_frame
	## 由 wrapper 挂 root（本探针经 change_scene 验证——不可为 main_scene 子节点）
	var ed: Control = Control.new()
	ed.set_script(load(THXKit.kpath("res://addons/thx_gamekit/editor/danmaku_editor.gd")))
	get_tree().root.add_child.call_deferred(ed)
	await get_tree().process_frame
	await get_tree().process_frame
	if ed.events.is_empty():
		print("SPIN_FAIL 编辑器无事件")
		get_tree().quit(1)
		return
	ed.selected_idx = 0
	ed._confirm_exit("title")
	## 模拟点击保存并退出（语义层）
	await get_tree().process_frame
	await get_tree().process_frame
	for c in ed._exit_panel.find_children("*", "Button", true, false):
		if (c as Button).name == "ExitDrop":
			(c as Button).pressed.emit() ## 【作者路径】不保存退出
	await get_tree().process_frame
	await get_tree().process_frame
	## 切到标题后：扫 root 直属子节点（编辑器 _dialog_reparent 残留的
	## Window=root 直接子代——空转烧帧源）
	print("SPIN root 直属子代:")
	var leak := 0
	for c in get_tree().root.get_children():
		var cn := String(c.name)
		var cls := c.get_class()
		if cls == "THXKit" or cls == "Node" and cn.begins_with("SpinHunt"):
			continue ## autoload/本探针
		if cls in ["Window", "PopupPanel", "FileDialog", "AcceptDialog", "ConfirmationDialog"]:
			leak += 1
		print("  ", cn, " (", cls, ")")
	var cs := get_tree().current_scene
	print("SPIN current_scene=", cs.name if cs != null else "null")
	print("SPIN root 窗口类残留=", leak)
	print("SPIN_OK" if (leak == 0 and cs != null and cs.name == "TitleMenu") else "SPIN_FAIL")
	get_tree().quit()
