extends Window
## =============================================================
## 【m79 内窗口调试（作者 20261117）】独立进程编辑器的报错/消息继承窗口。
## 原理：编辑器进程以 --log-file 落盘控制台与报错（Godot 原生参数），
## 本窗口 0.5s 轮询读增量并滚动显示——独立窗口进程自此可观测。
## 用法：log_path 赋值（绝对路径）后 add_child 即可。
## =============================================================

var log_path := ""
var _pos := 0
var _rtl: RichTextLabel

func _ready() -> void:
	title = "内窗口调试（编辑器控制台继承）"
	size = Vector2i(760, 420)
	_rtl = RichTextLabel.new()
	_rtl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rtl.scroll_following = true
	_rtl.add_theme_font_size_override("normal_font_size", 12)
	add_child(_rtl)
	var t := Timer.new()
	t.wait_time = 0.5
	t.autostart = true
	t.timeout.connect(_tail)
	add_child(t)

func _tail() -> void:
	if log_path == "" or not FileAccess.file_exists(log_path):
		return
	var f := FileAccess.open(log_path, FileAccess.READ)
	if f == null:
		return
	var flen := f.get_length()
	if flen < _pos:
		_pos = 0 ## 日志轮转/截断=从头重读
	if flen == _pos:
		f.close()
		return
	f.seek(_pos)
	var chunk := f.get_as_text()
	_pos = f.get_length()
	f.close()
	if chunk != "":
		_rtl.append_text(chunk)
		_rtl.scroll_to_line(_rtl.get_line_count() - 1)
