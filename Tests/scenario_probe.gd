extends Node
## scenario_probe —— 场景三件套探针（headless 可跑）
##   ①.thxs 保存→载入往返（场景名/cfg 回读）
##   ②generate_tscn 文件生成+内容含画布尺寸
##   ③ScenarioEditor 四子标签构建
##   ④内核引用页 cfg 写回（画布宽 SpinBox→scenario_cfg）
func _ready() -> void:
	var fails := 0
	## ①.thxs 往返
	THXKit.editor_events = []
	THXKit.scenario_name = "probe_scn"
	THXKit.scenario_cfg["canvas_w"] = 480
	var ok_save: bool = THXKit.save_scenario("user://probe_scn.thxs")
	var ok_load: bool = THXKit.load_scenario("user://probe_scn.thxs")
	var ok1: bool = ok_save and ok_load and THXKit.scenario_name == "probe_scn" and int(THXKit.scenario_cfg.get("canvas_w")) == 480
	print("  %s .thxs 往返（save=%s load=%s 名=%s 画布宽=%s）" % ["PASS" if ok1 else "FAIL", ok_save, ok_load, THXKit.scenario_name, THXKit.scenario_cfg.get("canvas_w")])
	if not ok1: fails += 1
	## ②tscn 导出
	## 造一条时间轴（触发器节点随时间轴生成）
	var tl := TimelineData.new()
	tl.tl_name = "probe_tl"
	THXKit.editor_timelines.append(tl)
	var ok_t: bool = THXKit.generate_tscn("user://probe_scn.tscn")
	var tscn_text := FileAccess.get_file_as_string("user://probe_scn.tscn") if FileAccess.file_exists("user://probe_scn.tscn") else ""
	var ok2: bool = ok_t and tscn_text.contains("480") and tscn_text.contains("Timer")
	print("  %s tscn 导出（文件=%s 含画布=%s 含触发器=%s）" % ["PASS" if ok2 else "FAIL", ok_t, tscn_text.contains("480"), tscn_text.contains("Timer")])
	if not ok2: fails += 1
	## ③ScenarioEditor 四子标签
	var se := Control.new()
	se.set_script(load(THXKit.kpath("res://addons/thx_gamekit/editor/scenario_editor.gd")))
	add_child(se)
	await get_tree().process_frame
	var tabs: TabContainer = se._subs
	var names: Array = []
	for c in tabs.get_children():
		names.append(String(c.name))
	var ok3: bool = names == ["场景树", "UI 画布", "逻辑链", "内核引用"]
	print("  %s 四子标签（%s）" % ["PASS" if ok3 else "FAIL", str(names)])
	if not ok3: fails += 1
	## ④cfg 写回（内核引用页 SpinBox）
	tabs.current_tab = 3
	await get_tree().process_frame
	var sb: SpinBox = se._cfg_labels.get("canvas_w")
	var ok4: bool = sb != null
	if sb != null:
		sb.value = 512
	var ok4b: bool = int(THXKit.scenario_cfg.get("canvas_w")) == 512
	var ok_all4: bool = ok4 and ok4b
	print("  %s cfg 写回（SpinBox=%s cfg=%s）" % ["PASS" if ok_all4 else "FAIL", ok4, THXKit.scenario_cfg.get("canvas_w")])
	if not ok_all4: fails += 1
	se.queue_free()
	DirAccess.remove_absolute("user://probe_scn.thxs")
	DirAccess.remove_absolute("user://probe_scn.tscn")
	print("SCN_OK" if fails == 0 else "SCN_FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
