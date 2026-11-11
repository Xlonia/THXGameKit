extends Node
## title_round_probe —— 标题画面/NIS残余/预览专属行列 探针（headless 可跑）
##   ①标题场景实例化（六菜单项构建不崩）
##   ②编辑器通用参数页不再提供 dmg_mode 选取（N/I/S 残余清除）
##   ③dmg_mode 数据列 CSV 往返无损（编辑器不显示≠列丢失）
##   ④预览覆盖画布开关变量存在（show_hitbox/show_spin——上轮缺失会崩）
##   ⑤试炼场常驻退出按钮存在（点击回编辑器）
func _ready() -> void:
	var fails := 0
	## ①标题实例化
	var tm: Control = (load("res://addons/thx_gamekit/editor/title_menu.gd") as GDScript).new()
	add_child(tm)
	await get_tree().process_frame
	var ok1: bool = is_instance_valid(tm)
	print("  %s 标题场景实例化（六菜单+背景占位）" % ["PASS" if ok1 else "FAIL"])
	if not ok1: fails += 1
	tm.queue_free()
	await get_tree().process_frame
	## ②编辑器通用参数页无 dmg_mode 选取控件（N/I/S 不可再选）
	GameGlobals.editor_events = []
	var ed: Control = (load("res://scenes/danmaku_editor.tscn") as PackedScene).instantiate()
	add_child(ed)
	await get_tree().process_frame
	await get_tree().process_frame
	var has_pick: bool = ed._widgets.has("dmg_mode")
	var has_dmg: bool = ed._widgets.has("dmg")
	var ok2: bool = (not has_pick) and has_dmg
	print("  %s 通用参数页 N/I/S 选取已移除（dmg_mode控件=%s dmg控件=%s）" % ["PASS" if ok2 else "FAIL", has_pick, has_dmg])
	if not ok2: fails += 1
	## ③dmg_mode 列往返：构造 I 模式事件 → to_csv_row → parse 还原
	var ev := DanmakuEventData.new()
	ev.event_name = "probe_nis"
	ev.dmg_mode = DanmakuEventData.MODE_IMPALE
	var csv_text: String = ",".join(DanmakuEventData.CSV_HEADER) + "\n" + ev.to_csv_row() + "\n"
	var ev2: DanmakuEventData = DanmakuEventData.parse_csv_text(csv_text)[0]
	var ok3: bool = ev2.dmg_mode == DanmakuEventData.MODE_IMPALE
	print("  %s dmg_mode 数据列往返无损（写入 I → 读回 %s）" % ["PASS" if ok3 else "FAIL", ev2.dmg_mode])
	if not ok3: fails += 1
	## ④覆盖画布开关变量
	var ov := Control.new()
	ov.set_script(load("res://addons/thx_gamekit/editor/preview_overlay.gd"))
	var ok4: bool = "show_hitbox" in ov and "show_spin" in ov
	print("  %s 覆盖画布开关变量（show_hitbox/show_spin）" % ["PASS" if ok4 else "FAIL"])
	if not ok4: fails += 1
	ov.queue_free()
	ed.queue_free()
	await get_tree().process_frame
	## ⑤试炼场常驻退出按钮
	GameGlobals.preview_event_name = "demo_youshio1"
	var tg := (load("res://scenes/trial_ground.tscn") as PackedScene).instantiate()
	add_child(tg)
	await get_tree().process_frame
	var found_exit := false
	for c in tg.get_children():
		if c is Button and (c as Button).text.contains("退出试炼场"):
			found_exit = true
	var ok5: bool = found_exit
	print("  %s 试炼场常驻退出按钮" % ["PASS" if ok5 else "FAIL"])
	if not ok5: fails += 1
	tg.queue_free()
	await get_tree().process_frame
	print("ROUND_OK" if fails == 0 else "ROUND_FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
