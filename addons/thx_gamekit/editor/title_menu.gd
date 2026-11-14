extends Control
## =============================================================
## title_menu —— THXGameKit 标题画面（0.0.9·③-A 游戏主体骨架·独立工程入口）
## 菜单（作者 20261112 指定六项）：编辑器/帮助文档/选项/测试/关于我们/退出
## 【待办（作者）】背景图+背景动画脚本后续上传——届时替换 _build_bg() 的占位
##   实现（当前=深色底+暗纹装饰；作者资产到位前先保证布局可用）
## 【试炼场往返修复 20261112】编辑器"试炼场预览"替换主窗后回不来——
##   本画面补全"返回游戏标题"路由（danmaku_editor._confirm_exit("title")
##   → 本场景 res://scenes/title_menu.tscn），标题↔编辑器↔试炼场 三点闭环
## =============================================================

const MENU_ITEMS := [
	{"id": "continue", "label": "继续（上次工程）"},
	{"id": "playthxe", "label": "打开 .thxe 就地游玩"},
	{"id": "editor", "label": "编辑器"},
	{"id": "docs", "label": "帮助文档"},
	{"id": "options", "label": "选项"},
	{"id": "test", "label": "测试"},
	{"id": "about", "label": "关于我们"},
	{"id": "quit", "label": "退出"},
]
## 内容文件夹四类（键=THXKit.content_dirs / content_scan_dirs 的 kind）
const CONTENT_KINDS := [
	["danmaku_tex", "弹幕材质"],
	["hitbox_tex", "判定盒图"],
	["chara_tex", "角色贴图"],
	["audio", "音乐/音效"],
]
const VERSION_TEXT := "THXGameKit 内核 v0.1.0（随 TH75 v0.0.9 开发）｜MIT License"

var _panel: PanelContainer = null ## 当前弹出面板（同类互斥）

func _ready() -> void:
	## 【卡死专案逐步诊断 20261114】每段耗时 print（作者 F5 控制台直接可见卡点）
	var _t0 := Time.get_ticks_msec()
	print("[标题] _ready 开始")
	## 【卡死取证哨兵 m57 恢复（m60 rebase 吞分支——与 editor 分支同型事故）】
	var diag := Node.new()
	diag.set_script(load("res://Tests/diag_sentinel.gd"))
	get_tree().root.add_child.call_deferred(diag)
	_build_bg()
	print("[标题] _build_bg 完成 +%dms" % (Time.get_ticks_msec() - _t0))
	## 标题
	var title := Label.new()
	title.text = "THXGameKit"
	title.add_theme_font_size_override("font_size", 44)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.position.y += 46
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "弹幕专题游戏制作内核 —— 弹幕运行时 / 事件 / 时间轴 / 编辑器"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	subtitle.position.y += 104
	add_child(subtitle)
	## 菜单按钮列（RPGVX 式：焦点在首项，方向键移动/Enter 确认——th75 同款）
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	for item in MENU_ITEMS:
		var btn := Button.new()
		btn.text = " %s " % item["label"]
		btn.add_theme_font_size_override("font_size", 22)
		btn.pressed.connect(_on_menu.bind(item["id"]))
		box.add_child(btn)
	if box.get_child_count() > 0:
		(box.get_child(0) as Button).grab_focus()
	print("[标题] UI 构建中… +%dms" % (Time.get_ticks_msec() - _t0))
	## 版本注记
	var foot := Label.new()
	foot.text = VERSION_TEXT + " ｜ github.com/Xlonia/THXGameKit"
	foot.add_theme_font_size_override("font_size", 12)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position.y -= 30
	add_child(foot)
	print("[标题] _ready 全部完成 +%dms" % (Time.get_ticks_msec() - _t0))

## —— 背景（占位：作者背景图+背景动画脚本上传后替换本函数）——
func _build_bg() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	## 暗纹装饰（【卡死专案 A/B 测试 20261114：临时禁用 TitleDeco——直跑帧率对照】
	## 作者资产到位后整类删除；实验结论回填后恢复或永久移除）
	# var deco := TitleDeco.new()
	# deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# add_child(deco)

## 【继续 20261114（作者裁定）】标题正中首项——读上次工程 thxp
## （最近文件记录 user://thx_gamekit/recent.txt；目标=开发者自己的游戏 thxp）
const RECENT_PATH := "user://thx_gamekit/recent.txt"

func _recent_read() -> String:
	if FileAccess.file_exists(RECENT_PATH):
		return FileAccess.get_file_as_string(RECENT_PATH).strip_edges()
	return ""

func _recent_write(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(RECENT_PATH.get_base_dir())
	var f := FileAccess.open(RECENT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(path)
		f.close()

func _on_continue() -> void:
	var last := _recent_read()
	if last == "" or not FileAccess.file_exists(last):
		_open_panel_msg("继续", "没有上次工程记录（先在编辑器里打开/保存一个 .thxp）")
		return
	THXKit.load_thx(last)
	_recent_write(last)
	_open_editor_os_window()

func _open_panel_msg(title: String, msg: String) -> void:
	var p := _open_panel(title)
	var l := Label.new()
	l.text = msg
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(400, 0)
	p.add_child(l)

## 【独立进程编辑器 20261114（作者终裁：THX75 编辑器模式）】
## 编辑器=完全独立的 Godot 进程（OS.create_process 启动），标题画面进程
## **完全不受影响**——退出编辑器=关闭那个进程的窗口（零交集零空转）
## 与 THX75 的"启动弹幕编辑器.bat"同一模式

func _launch_editor_process() -> void:
	var godot_exe := OS.get_executable_path()
	var project_dir := ProjectSettings.globalize_path("res://")
	var args := PackedStringArray(["--path", project_dir, "res://scenes/danmaku_editor.tscn"])
	var pid := OS.create_process(godot_exe, args)
	if pid > 0:
		print("[编辑器] 独立进程已启动 pid=%d" % pid)
	else:
		push_error("[编辑器] 独立进程启动失败")

func _on_menu(id: String) -> void:
	_close_panel()
	match id:
		"continue":
			_on_continue()
		"playthxe":
			_open_thxe_dialog()
		"editor":
			_launch_editor_process() ## 【m47 rebase 事故恢复】editor 分支被冲突吞掉=点编辑器丝毫无反应
		"docs":
			_open_docs()
		"options":
			_open_options()
		"test":
			_open_test()
		"about":
			_open_about()
		"quit":
			get_tree().quit()

## —— 通用弹出面板（居中 PanelContainer + 标题 + 关闭）——
func _open_panel(ptitle: String) -> VBoxContainer:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(620, 380)
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_left", 18)
	wrap.add_theme_constant_override("margin_right", 18)
	wrap.add_theme_constant_override("margin_top", 12)
	wrap.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(wrap)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	wrap.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	var hl := Label.new()
	hl.text = ptitle
	hl.add_theme_font_size_override("font_size", 20)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hl)
	var close := Button.new()
	close.text = "✕"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_close_panel)
	head.add_child(close)
	add_child(_panel)
	return box

func _close_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null

## —— 帮助文档：docs/ 清单（点击系统默认程序打开）——
func _open_docs() -> void:
	var box := _open_panel("帮助文档")
	var dir := DirAccess.open("res://docs")
	if dir == null:
		var l := Label.new()
		l.text = "docs/ 目录不存在（源码仓库内提供：github.com/Xlonia/THXGameKit）"
		box.add_child(l)
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	var n := 0
	while f != "":
		if not dir.current_is_dir() and (f.ends_with(".md") or f.ends_with(".txt")):
			var path := "res://docs/".path_join(f)
			var b := Button.new()
			b.text = f
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(func():
				OS.shell_open(ProjectSettings.globalize_path(path)))
			box.add_child(b)
			n += 1
		f = dir.get_next()
	dir.list_dir_end()
	if n == 0:
		var l2 := Label.new()
		l2.text = "docs/ 下暂无文档文件"
		box.add_child(l2)

## —— 选项：内容文件夹配置（③-B 归入）——
func _open_options() -> void:
	var box := _open_panel("选项 —— 内容文件夹（用户指定目录，改动即时生效）")
	var tip := Label.new()
	tip.text = "扫描顺序：内核默认目录在前、此处追加在后（后扫者覆盖同名）。留空=只用默认。"
	tip.add_theme_font_size_override("font_size", 12)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tip)
	for kind in CONTENT_KINDS:
		box.add_child(_content_row(kind[0], kind[1]))
	var note := Label.new()
	note.text = "特殊判定盒/旋转中心覆盖显示开关在编辑器菜单栏「设置」内（编辑器局部状态）。"
	note.add_theme_font_size_override("font_size", 12)
	box.add_child(note)

func _content_row(kind: String, label: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(90, 0)
	row.add_child(l)
	var cur := Label.new()
	cur.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cur.clip_text = true
	var dirs: Array = THXKit.content_dirs.get(kind, [])
	cur.text = str(dirs[0]) if not dirs.is_empty() else "（未指定）"
	row.add_child(cur)
	var pick := Button.new()
	pick.text = "选取文件夹"
	pick.focus_mode = Control.FOCUS_NONE
	var dlg := FileDialog.new()
	dlg.use_native_dialog = true
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dlg.title = "选择 %s 目录" % label
	dlg.size = Vector2i(720, 480)
	row.add_child(dlg)
	pick.pressed.connect(func(): dlg.popup_centered())
	dlg.dir_selected.connect(func(fp: String):
		THXKit.set_content_dir(kind, fp)
		DanmakuTex.invalidate_scan()
		CharaTex.invalidate_all()
		cur.text = fp
		print("[标题-选项] %s → %s" % [kind, fp]))
	row.add_child(pick)
	## 【资源管理器浏览 20261114（作者：分组资源加浏览导入）】打开当前目录（未设=内核默认）
	var browse := Button.new()
	browse.text = "浏览"
	browse.tooltip_text = "用系统资源管理器打开该类资源的当前目录（可直接拖文件进/出）"
	browse.pressed.connect(func():
		var bdirs: Array = THXKit.content_scan_dirs(kind)
		var open_dir: String = bdirs[bdirs.size() - 1] if not bdirs.is_empty() else "res://"
		OS.shell_open(ProjectSettings.globalize_path(open_dir)))
	row.add_child(browse)
	var clr := Button.new()
	clr.text = "清除"
	clr.focus_mode = Control.FOCUS_NONE
	clr.pressed.connect(func():
		THXKit.set_content_dir(kind, "")
		DanmakuTex.invalidate_scan()
		CharaTex.invalidate_all()
		cur.text = "（未指定）")
	row.add_child(clr)
	return row

## —— 测试：smoke 场景启动器（自跑自退，结果打在控制台/退出码）——
func _open_test() -> void:
	var box := _open_panel("测试 —— 冒烟场景（运行后自动退出，结果见控制台输出）")
	var entries := [["试炼场（不自动退出）", "res://scenes/trial_ground.tscn"]]
	var dir := DirAccess.open("res://Tests")
	if dir != null:
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.ends_with(".tscn"):
				entries.append([f, "res://Tests/".path_join(f)])
			f = dir.get_next()
		dir.list_dir_end()
	for e in entries:
		var b := Button.new()
		b.text = e[0]
		b.pressed.connect(_run_test_scene.bind(e[1]))
		box.add_child(b)

func _run_test_scene(path: String) -> void:
	GameGlobals.goto_scene(path)

## —— 关于我们 ——
func _open_about() -> void:
	var box := _open_panel("关于我们")
	for line in [
		"THXGameKit —— 弹幕专题游戏制作内核（次级引擎）",
		"弹幕运行时 / 事件数据基底 / 时间轴 / 角色表 / 弹幕编辑器 / 试炼场",
		"",
		"作者：Xlonia",
		"仓库：github.com/Xlonia/THXGameKit",
		"许可：MIT License（详见仓库 LICENSE）",
		"",
		VERSION_TEXT,
	]:
		var l := Label.new()
		l.text = line
		box.add_child(l)

## 【thxe 直玩 20261114（作者批准 ModBox 式生态）】选 thxe→装载（签名强校验）
## →试炼场式直接玩（事件/时间轴全部就位）
func _open_thxe_dialog() -> void:
	var dlg := FileDialog.new()
	dlg.use_native_dialog = true
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.filters = PackedStringArray(["*.thxe ; THX发布包（签名强校验）"])
	dlg.size = Vector2i(720, 480)
	add_child(dlg)
	dlg.file_selected.connect(func(fp: String):
		var names: Array = THXKit.load_thx(fp)
		if names.is_empty():
			_open_panel_msg("打开失败", "thxe 装载失败（签名校验不通过或包损坏）")
			return
		_recent_write(fp)
		GameGlobals.goto_scene("res://scenes/trial_ground.tscn"))
	dlg.popup_centered()

## —— 背景暗纹装饰（作者资产到位后整类删除）——
class TitleDeco:
	extends Control
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
	func _draw() -> void:
		var c := size * 0.5
		for i in 6:
			var r := 130.0 + 42.0 * i + sin(_t * 0.8 + float(i)) * 10.0
			draw_arc(c, r, 0.0, TAU, 64, Color(0.35, 0.45, 0.75, 0.10 + 0.02 * i), 1.0)
