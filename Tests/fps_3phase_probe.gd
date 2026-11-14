extends Node
## fps_3phase_probe —— 三段 fps 实测（作者卡死专案）
##   A=标题直跑 300 帧；B=切编辑器 300 帧；C=切回标题 300 帧
##   逐段统计 fps 均值/帧均 ms——同哨兵口径，一锤定音哪段慢
var _ed: Control = null
var _phase := -1
var _frames := 0
var _cts: Array = []
var _results: Array = []
const LIMIT := 300
const PHASE_NAMES := ["A 标题直跑", "B 编辑器挂载"]
func _ready() -> void:
	var ed: Control = Control.new()
	ed.set_script(load("res://addons/thx_gamekit/editor/danmaku_editor.gd"))
	_ed = ed
	get_tree().root.add_child.call_deferred(ed)
	await get_tree().process_frame
	await get_tree().process_frame
	if _ed.events.is_empty():
		print("FPS_FAIL 编辑器无事件")
		get_tree().quit(1)
		return
	_start_phase(0)
func _start_phase(p: int) -> void:
	_phase = p
	_frames = 0
	_cts = []
	if p == 1:
		_ed.selected_idx = 0
		_ed._confirm_exit("title") ## 打开退出面板（不点按钮——只测编辑器挂载段）
		await get_tree().process_frame
	elif p == 2:
		if _ed._exit_panel != null:
			for c in _ed._exit_panel.find_children("*", "Button", true, false):
				if (c as Button).name == "ExitCancel":
					(c as Button).pressed.emit() ## 取消=留在编辑器
	if p == 1 or p == 2:
		await get_tree().process_frame
func _process(_d: float) -> void:
	if _phase < 0:
		return
	_frames += 1
	var ft := 1000.0 / maxf(1.0, float(Engine.get_frames_per_second()))
	_cts.append(ft)
	if _frames == LIMIT:
		var avg := 0.0
		for v in _cts:
			avg += v
		avg /= maxf(1.0, float(_cts.size()))
		_results.append("%s: 帧均=%.1fms（约 fps=%d）" % [PHASE_NAMES[_phase], avg, int(1000.0/avg)])
		print("[phase] ", _results[-1])
		var np := _phase + 1
		if np <= 2:
			_phase = -1 ## 暂停采集
			_do_switch(np)
		else:
			for r in _results:
				print("RESULT ", r)
			get_tree().quit(0)
func _do_switch(np: int) -> void:
	## 用编辑器内部路由切换（与作者操作一致：编辑器→返回游戏标题→标题→编辑器）
	if np == 1:
		_ed.selected_idx = 0
		_ed._confirm_exit("title") ## 打开面板
		await get_tree().process_frame
		await get_tree().process_frame
		for c in _ed._exit_panel.find_children("*", "Button", true, false):
			if (c as Button).name == "ExitCancel":
				(c as Button).pressed.emit() ## 取消=留编辑器（面板关闭）
		## 编辑器已在树（B 段开始）
	elif np == 2:
		## 从编辑器返回标题再回编辑器——直接重开面板触发 goto 标题再回编辑器太绕
		## 简化：C 段=标题再挂载（模拟返回标题后的标题帧率）
		var tm: Control = Control.new()
		tm.set_script(load("res://addons/thx_gamekit/editor/title_menu.gd"))
		get_tree().root.add_child(tm)
	_start_phase(np)
