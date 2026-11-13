extends Node
## window_exit_probe —— 退出链真窗口实测（替换主窗模式=m39 现行路线）
##   编辑器实例化为 current_scene 姊妹→_confirm_exit("title")→点击"保存并退出"
##   →change_scene 切标题→轮询判定+逐阶段时间戳（作者：卡死依旧复发——定位卡点）
##   探针挂 root（不在 current_scene 内=change_scene 不连坐）
var _ed: Control = null
var _frames := 0
var _t0 := 0
var _phase := "boot"
func _ready() -> void:
	await get_tree().process_frame
	_ed = Control.new()
	_ed.set_script(load(THXKit.kpath("res://addons/thx_gamekit/editor/danmaku_editor.gd")))
	get_tree().root.add_child.call_deferred(_ed)
	await get_tree().process_frame
	await get_tree().process_frame
	if _ed.events.is_empty():
		print("WINDOW_FAIL 编辑器无事件")
		get_tree().quit(1)
		return
	_ed.selected_idx = 0
	var t_click := Time.get_ticks_msec()
	_ed._confirm_exit("title")
	await get_tree().process_frame
	await get_tree().process_frame
	if _ed._exit_panel == null:
		print("WINDOW_FAIL 面板未出现")
		get_tree().quit(1)
		return
	var save_btn: Button = null
	for c in _ed._exit_panel.find_children("*", "Button", true, false):
		if (c as Button).name == "ExitSave":
			save_btn = c
	if save_btn == null:
		print("WINDOW_FAIL 保存按钮未找到")
		get_tree().quit(1)
		return
	print("[probe] T+%dms 面板就绪" % (Time.get_ticks_msec() - t_click))
	## 【拟真鼠标 20261114（作者批准）】warp 真光标到按钮屏幕坐标+屏幕系
	## parse_input_event（OS 鼠标位置+全局管线——最接近真人点击）
	var btn_screen: Vector2 = save_btn.get_global_rect().get_center()
	var screen_pt: Vector2 = Vector2(get_window().position) + btn_screen ## Vector2i+Vector2 需显式转换
	Input.warp_mouse(screen_pt)
	await get_tree().process_frame
	print("[probe] 光标已 warp @屏幕%s（按钮局部%s）" % [str(screen_pt), str(btn_screen)])
	var mm := InputEventMouseMotion.new()
	mm.position = btn_screen
	mm.global_position = btn_screen
	Input.parse_input_event(mm)
	await get_tree().process_frame
	var mb := InputEventMouseButton.new()
	mb.position = btn_screen
	mb.global_position = btn_screen
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	Input.parse_input_event(mb)
	await get_tree().process_frame
	var mb2 := InputEventMouseButton.new()
	mb2.position = btn_screen
	mb2.global_position = btn_screen
	mb2.button_index = MOUSE_BUTTON_LEFT
	mb2.pressed = false
	Input.parse_input_event(mb2)
	_phase = "wait"
	_t0 = Time.get_ticks_msec()
	_phase = "wait"
	_t0 = Time.get_ticks_msec()
func _process(_d: float) -> void:
	if _phase != "wait":
		return
	_frames += 1
	var cs := get_tree().current_scene
	if cs != null and cs.name == "TitleMenu":
		print("WINDOW_EXIT_OK 回标题（%d 帧/%d ms 内）" % [_frames, Time.get_ticks_msec() - _t0])
		set_process(false)
		get_tree().quit(0)
	elif _frames == 30:
		print("[probe] T+%dms 0.5s 未切——场景=%s 面板存活=%s（保存链耗时监测中）" % [
			Time.get_ticks_msec() - _t0, cs.name if cs != null else "null", str(_ed._exit_panel)])
	elif _frames > 600: ## 10 秒
		print("WINDOW_FAIL 10 秒未回标题（场景=%s 面板=%s）——卡死复现" % [
			cs.name if cs != null else "null", str(_ed._exit_panel)])
		set_process(false)
		get_tree().quit(1)
