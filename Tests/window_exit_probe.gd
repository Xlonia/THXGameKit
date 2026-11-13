extends Node
## window_exit_probe —— 真窗口退出交互自动化（非 headless 跑；定位"卡死=交互层"）
## 流程：编辑器实例化→打开退出面板→等 ready→Input.parse_input_event 注入
## 真实鼠标移动+左键点击"保存并退出"→5 秒内轮询场景是否切到标题→报结果。
## 【注入的是 OS 窗口客户区坐标的真实 InputEvent——与 headless 模拟点击不同】
var _frames := 0
var _phase := "boot"
var _ed: Control = null
var _probe_win: Window = null
var _t0 := 0
func _ready() -> void:
	## 【窗口模式 20261114（作者方向）】编辑器真放 OS Window 里——退出=关窗
	## （零场景切换）；点击"保存并退出"后断言窗口释放
	_ed = Control.new()
	_ed.set_script(load(THXKit.kpath("res://addons/thx_gamekit/editor/danmaku_editor.gd")))
	var w := Window.new()
	w.title = "probe editor"
	w.size = Vector2i(1280, 800)
	w.add_child(_ed)
	add_child(w)
	w.popup_centered()
	_probe_win = w
	await get_tree().process_frame
	await get_tree().process_frame
	if _ed.events.is_empty():
		print("WINDOW_PROBE_SKIP 编辑器无事件")
		get_tree().quit(1)
		return
	_ed.selected_idx = 0
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
	## 真实点击注入（按钮中心=窗口客户区坐标）
	## 【稳定性 20261113】未聚焦窗口的注入点击会被 GUI 忽略——先聚焦+多帧
	var win := get_window()
	win.grab_focus()
	await get_tree().process_frame
	await get_tree().process_frame
	var center: Vector2 = save_btn.get_global_rect().get_center()
	print("[probe] 窗口聚焦=%s 注入点击 @%s（按钮=%s 全局=%s）" % [win.has_focus(), str(center), save_btn.text, str(save_btn.get_global_rect())])
	var mm := InputEventMouseMotion.new()
	mm.position = center
	mm.global_position = center
	Input.parse_input_event(mm)
	await get_tree().process_frame
	var mb := InputEventMouseButton.new()
	mb.position = center
	mb.global_position = center
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	Input.parse_input_event(mb)
	await get_tree().process_frame
	var mb2 := InputEventMouseButton.new()
	mb2.position = center
	mb2.global_position = center
	mb2.button_index = MOUSE_BUTTON_LEFT
	mb2.pressed = false
	Input.parse_input_event(mb2)
	_phase = "wait_scene"
	_t0 = Time.get_ticks_msec()

func _process(_d: float) -> void:
	if _phase != "wait_scene":
		return
	_frames += 1
	## 窗口模式判定：探针窗口被释放（编辑器关窗退出=作者方向的零场景切换路径）
	if _probe_win == null or not is_instance_valid(_probe_win):
		print("WINDOW_EXIT_OK 窗口已关（编辑器窗口模式退出=%d 帧/%d ms 内）" % [_frames, Time.get_ticks_msec() - _t0])
		set_process(false)
		get_tree().quit(0)
	elif _frames > 300: ## 5 秒 @60fps
		print("WINDOW_FAIL 5 秒未关窗（面板=%s 窗口=%s）" % [
			str(_ed._exit_panel), str(_probe_win)])
		set_process(false)
		get_tree().quit(1)
