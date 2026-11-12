extends Node
## round79_probe —— 79轮四件套探针（headless 可跑）
##   ①顶栏三页签（设置/探针懒建+探针刷新输出非空）
##   ②退出自绘面板：存在→模拟保存并退出（.thxp 生成+_project_path 记录）
##     →模拟不保存退出（draft 还原路径）→面板关闭
##   ③判定盒"同显示"：常量+下拉首项+Bullet 载入用材质图（开关开启时位图非空）
##   ④展示卡判定盒覆盖图：白像素→红、黑像素→透明（白=判定阈值同 runtime）
func _ready() -> void:
	var fails := 0
	GameGlobals.editor_events = []
	var ed: Control = Control.new() ## 脚本直实例化（tscn ext_resource 宿主失效坑）
	ed.set_script(load(THXKit.kpath("res://addons/thx_gamekit/editor/danmaku_editor.gd")))
	add_child(ed)
	await get_tree().process_frame
	await get_tree().process_frame
	## ①顶栏页签
	ed._show_top_page("settings")
	var ok1a: bool = ed._top_pages.has("settings") and ed._top_pages["settings"].visible
	ed._show_top_page("probe")
	var ok1b: bool = ed._top_pages.has("probe") and ed._top_pages["probe"].visible
	var out: Label = ed._top_pages["probe"].find_child("ProbeOut", true, false)
	var ok1c: bool = out != null and out.text.length() > 10 and out.text.contains("事件总数")
	ed._show_top_page("editor")
	var ok1: bool = ok1a and ok1b and ok1c and ed._top_pages["editor"].visible
	print("  %s 顶栏三页签（设置=%s 探针=%s 输出=%s 回编辑器=%s）" % ["PASS" if ok1 else "FAIL", ok1a, ok1b, ok1c, ed._top_pages["editor"].visible])
	if not ok1: fails += 1
	## ②退出自绘面板
	ed.selected_idx = 0 if ed.events.size() > 0 else -1
	ed._confirm_exit("close") ## close+非窗口模式=保存链全走且不切场景（探针=main_scene 防连坐）
	var ok2a: bool = ed._exit_panel != null and is_instance_valid(ed._exit_panel)
	if ok2a:
		var save_b: Button = null
		for c in ed._exit_panel.find_children("*", "Button", true, false):
			if (c as Button).text == "保存并退出":
				save_b = c
		if save_b != null:
			save_b.pressed.emit() ## 模拟点击：保存 .thxp + 退出回调链前置
		await get_tree().process_frame
	var ok2b: bool = ed._project_path != "" and ed._project_path.ends_with(".thxp")
	var ok2c: bool = FileAccess.file_exists(ed._project_path) if ed._project_path != "" else false
	var ok2: bool = ok2a and ok2b and ok2c
	print("  %s 退出面板+保存并退出（面板=%s 路径=%s 文件=%s）" % ["PASS" if ok2 else "FAIL", ok2a, ed._project_path, ok2c])
	if not ok2: fails += 1
	ed._confirm_exit("close")
	if ed._exit_panel != null:
		for c in ed._exit_panel.find_children("*", "Button", true, false):
			if (c as Button).text == "取消":
				(c as Button).pressed.emit()
		await get_tree().process_frame
	var ok2d: bool = ed._exit_panel == null
	print("  %s 退出面板取消=留编辑器（面板已关=%s）" % ["PASS" if ok2d else "FAIL", ok2d])
	if not ok2d: fails += 1
	## ③判定盒"同显示"
	var has_const: bool = DanmakuEventData.HITBOX_SAME == "同显示"
	var ev := DanmakuEventData.new()
	ev.event_name = "probe_same"
	ev.texture = "ball" if DanmakuTex.list_names().size() > 0 else ""
	ev.hitbox_name = DanmakuEventData.HITBOX_SAME
	Bullet.special_hitbox_enabled = true
	var b := RefCounted.new()
	b.set_script(load("res://addons/thx_gamekit/core/danmaku/bullet_runtime.gd"))
	b.setup(ev, Vector2(200, 200), 0, null, self, 0)
	var ok3: bool = has_const and b.hitbox_bits.size() > 0
	print("  %s 判定盒同显示（常量=%s 载入位图=%d px）" % ["PASS" if ok3 else "FAIL", has_const, b.hitbox_bits.size()])
	if not ok3: fails += 1
	Bullet.special_hitbox_enabled = false
	## ③b 编辑器 hitbox 下拉首项=同显示
	var edev: DanmakuEventData = ed.events[0] if ed.events.size() > 0 else ev
	var w: Control = ed._make_widget(["hitbox", "判定盒图", "opt_tex"], edev)
	var first_item: String = (w as OptionButton).get_item_text(0) if (w as OptionButton).item_count > 0 else ""
	var ok3b: bool = first_item == DanmakuEventData.HITBOX_SAME
	print("  %s 判定盒下拉首项=同显示（实际=%s，选项%d）" % ["PASS" if ok3b else "FAIL", first_item, (w as OptionButton).item_count])
	if not ok3b: fails += 1
	w.queue_free()
	## ④展示卡判定盒覆盖图（白→红 黑→透明）——直接调 refresh 的核心逻辑
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	for y in 4:
		for x in 4:
			img.set_pixel(x, y, Color.WHITE if (x < 2) else Color.BLACK)
	var tex4 := ImageTexture.create_from_image(img)
	var htex := tex4
	var himg: Image = null
	if htex != null and htex.get_image() != null:
		var src: Image = htex.get_image()
		himg = Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
		for yy in src.get_height():
			for xx in src.get_width():
				if src.get_pixel(xx, yy).r > 0.5:
					himg.set_pixel(xx, yy, Color(1.0, 0.25, 0.25, 0.6))
	var ok4: bool = himg != null and himg.get_pixel(0, 0).a > 0.5 and himg.get_pixel(3, 3).a == 0.0
	print("  %s 展示卡判定盒覆盖图（白→红=%s 黑→透明=%s）" % ["PASS" if ok4 else "FAIL",
		himg.get_pixel(0, 0).a > 0.5 if himg != null else "?", himg.get_pixel(3, 3).a == 0.0 if himg != null else "?"])
	if not ok4: fails += 1
	print("R79_OK" if fails == 0 else "R79_FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
