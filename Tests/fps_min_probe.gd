extends Node
## fps_min_probe —— 最小 fps 探针（空场景+autoload——定位 fps=5 源）
var _frames := 0
var _sum := 0.0
var _n := 0
var _t0 := 0
var _ph: Control = null
var _ed: Control = null ## 面板交互宿主（挂哨兵后为编辑器实例）
func _ready() -> void:
	_t0 = Time.get_ticks_msec()
	_ph = Control.new()
	_ph.set_script(load("res://addons/thx_gamekit/editor/danmaku_editor.gd"))
	get_tree().root.add_child.call_deferred(_ph)
var _phase := 0
var _phase_t := 0
func _process(_d: float) -> void:
	_frames += 1
	var now := Time.get_ticks_msec()
	if now - _phase_t >= 4000:
		var el := (now - _phase_t) / 1000.0
		if _frames > 30:
			print("[phase %d] 4 秒 %d 帧 = fps %.1f" % [_phase, _frames, _frames / el])
		_phase_t = now
		_frames = 0
		_phase += 1
		if _phase == 1 and _ph != null:
			## B 段：打开退出面板（面板=编辑器 UI 变化）
			_ph._confirm_exit("title")
		elif _phase == 2 and _ed != null and _ed._exit_panel != null:
			## C 段：面板关闭
			for c in _ph._exit_panel.find_children("*", "Button", true, false):
				if (c as Button).name == "ExitCancel":
					(c as Button).pressed.emit()
		elif _phase >= 3:
			print("[min] 三段完成——数据见上")
			get_tree().quit(0)
