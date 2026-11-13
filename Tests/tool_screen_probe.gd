@tool
extends SceneTree
## tool_screen_probe —— 编辑器内验证（--editor -s 运行）：主屏 tab+内核类型可用性
func _init() -> void:
	_run()

func _run() -> void:
	await process_frame
	await process_frame
	await process_frame
	## 主屏 tab：plugin 装载时 _make_visible(true) 创建的节点在 main_screen 容器
	## ——反射 main_screen_control（Godot 4.x EditorPlugin 主屏宿主）扫描全树
	var has_tab := false
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if String(n.name).contains("THXGameKit"):
			has_tab = true
			break
		stack.append_array(n.get_children())
	print("TOOL 主屏 tab 全树扫描=", has_tab)
	print("TOOL TimelineData=", TimelineData != null, " DanmakuEventData=", DanmakuEventData != null)
	print("TOOL 编辑器环境=", Engine.is_editor_hint())
	print("TOOL_DATA_BASE=", DanmakuTex.DATA_BASE)
	print("TOOL_OK" if has_tab else "TOOL_FAIL")
	quit(0 if has_tab else 1)
