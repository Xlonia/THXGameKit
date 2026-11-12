extends Node
## round80_probe —— 80轮探针（headless 可跑）
##   ①直通退出：确认面板已撤（_confirm_exit=静默保存+after_exit，无交互）
##   ②展示画布交互数学：盒 1/2 尺寸/坐标往返/0.5 snap/判定盒绘制白黑
##   ③ThxFormationPresets 改名生效（内核类+编辑器调用点）
##   ④设置页两开关（特殊判定盒/中心覆盖）
func _ready() -> void:
	var fails := 0
	## ①直通退出
	GameGlobals.editor_events = []
	## 编辑器=脚本直实例化（tscn ext_resource 内核绝对路径在宿主失效=历史坑）
	var ed: Control = Control.new()
	ed.set_script(load(THXKit.kpath("res://addons/thx_gamekit/editor/danmaku_editor.gd")))
	add_child(ed)
	await get_tree().process_frame
	await get_tree().process_frame
	ed.selected_idx = 0 if ed.events.size() > 0 else -1
	ed._confirm_exit("close") ## close+非窗口=保存链全走且不切场景
	await get_tree().process_frame
	var ok1: bool = ed._exit_panel == null and ed._project_path != "" and ed._project_path.ends_with(".thxp")
	print("  %s 直通退出（面板已撤=%s 静默保存=%s）" % ["PASS" if ok1 else "FAIL", ed._exit_panel == null, ed._project_path])
	if not ok1: fails += 1
	## ②展示画布交互数学
	var ov := Control.new()
	ov.set_script(load(THXKit.kpath("res://addons/thx_gamekit/editor/preview_overlay.gd")))
	add_child(ov)
	ov.size = Vector2(128, 128)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	ov.base_tex = ImageTexture.create_from_image(img)
	var box: Rect2 = ov._box_rect()
	var ok2a: bool = absf(box.size.x - 64.0) < 0.01 and absf(box.position.x - 32.0) < 0.01 ## 框=画布1/2 居中
	var sp: Vector2 = ov._tex_to_screen(Vector2(8, 8))
	var back: Vector2 = ov._screen_to_tex(sp)
	var ok2b: bool = back.distance_to(Vector2(8, 8)) < 0.01 ## 坐标往返
	## 0.5 snap：模拟拖动语义（roundf(v*2)*0.5）
	var v := Vector2(1.234, -0.777)
	var snapped := Vector2(roundf(v.x * 2.0) * 0.5, roundf(v.y * 2.0) * 0.5)
	var ok2c: bool = snapped == Vector2(1.0, -1.0) ## 1.234→1.0；-0.777→-1.0（round 半值取远离 0）
	## 判定盒绘制：左=白 右=黑
	ov.edit_mode = true
	ov.edit_img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	ov.edit_img.fill(Color.BLACK)
	ov._paint_btn = MOUSE_BUTTON_LEFT
	ov._paint_at(Vector2(3, 4))
	ov._paint_btn = MOUSE_BUTTON_RIGHT
	ov._paint_at(Vector2(3, 4))
	var ok2d: bool = ov.edit_img.get_pixel(3, 4).r < 0.5 ## 右键擦=黑
	var edited := [false]
	ov.hitbox_edited.connect(func(_im): edited[0] = true)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = false
	mb.position = Vector2(0, 0)
	ov._gui_input(mb) ## 松开→emit
	var ok2: bool = ok2a and ok2b and ok2c and ok2d and edited[0]
	print("  %s 展示画布交互（框=%s 往返=%s snap=%s 绘擦=%s 提交=%s）" % ["PASS" if ok2 else "FAIL", ok2a, ok2b, ok2c, ok2d, edited[0]])
	if not ok2: fails += 1
	ov.queue_free()
	## ③ThxFormationPresets
	var fp := load(THXKit.kpath("res://addons/thx_gamekit/core/data/formation_presets.gd"))
	var ok3: bool = fp != null and fp.get_global_name() == "ThxFormationPresets" and fp.PRESETS.has("扇形防护")
	print("  %s ThxFormationPresets（类=%s 公式=%d 预设）" % ["PASS" if ok3 else "FAIL", fp.get_global_name() if fp != null else "?", fp.PRESETS.size() if fp != null else 0])
	if not ok3: fails += 1
	## ④设置页两开关
	ed._show_top_page("settings")
	var has_shb := false
	for c in ed._top_pages["settings"].find_children("*", "Button", true, false):
		if (c as Button).text.begins_with("特殊判定盒"):
			has_shb = true
	var ok4: bool = has_shb
	print("  %s 设置页两开关（特殊判定盒按钮=%s）" % ["PASS" if ok4 else "FAIL", has_shb])
	if not ok4: fails += 1
	ed._show_top_page("editor")
	print("R80_OK" if fails == 0 else "R80_FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
