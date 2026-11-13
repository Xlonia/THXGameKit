extends Node
## render_hunt_probe —— 切标题后渲染活性实测（作者：空转段物理 tick 空推+画面不动）
##   编辑器→保存并退出→回标题→统计标题画面 60 帧内 _draw 实际调用数
##   _draw 调用=0 → 渲染停摆实锤（与节点残留无关——上一轮方向修正）
var _ed: Control = null
var _frames := 0
var _draws := 0
func _ready() -> void:
	var ed: Control = Control.new()
	ed.set_script(load(THXKit.kpath("res://addons/thx_gamekit/editor/danmaku_editor.gd")))
	get_tree().root.add_child.call_deferred(ed)
	await get_tree().process_frame
	await get_tree().process_frame
	if ed.events.is_empty():
		print("RENDER_FAIL 编辑器无事件")
		get_tree().quit(1)
		return
	ed.selected_idx = 0
	ed._confirm_exit("title")
	await get_tree().process_frame
	await get_tree().process_frame
	for c in ed._exit_panel.find_children("*", "Button", true, false):
		if (c as Button).name == "ExitSave":
			(c as Button).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	## 挂一个哨兵 Control 到标题画面内——统计自身 _draw 触发
	var cs := get_tree().current_scene
	print("RENDER current_scene=", cs.name if cs != null else "null")
	var sentinel := DrawSentinel.new()
	sentinel.host = self
	cs.add_child(sentinel)
func _process(_d: float) -> void:
	_frames += 1
	if _frames == 60:
		print("RENDER 60 帧内标题画面 _draw 调用=%d（>0=渲染活/0=停摆实锤）" % _draws)
		print("RENDER_OK" if _draws > 0 else "RENDER_FAIL 渲染停摆")
		get_tree().quit(0 if _draws > 0 else 1)

class DrawSentinel:
	extends Control
	var host: Node = null
	var _n := 0
	func _draw() -> void:
		_n += 1
		host._draws = _n
