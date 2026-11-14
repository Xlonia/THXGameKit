@tool
class_name ScenarioEditor
extends Control
## =============================================================
## 场景编辑器（0.0.9·③ 作者裁定 20261114）——四子标签：
##   ①场景树  场景=多个时间轴的集合（出生/资源/自机/数值系统节点图；
##           Boss/配置放时间轴关键帧）；列表+新建/保存/载入 .thxs+导出 .tscn
##   ②UI 画布  中央画布（网格+画布框）——控件拖放待下轮
##   ③逻辑链  节点图画布占位——触发器=时间轴/场景（设计探讨后深化）
##   ④内核引用  消弹/发射/判定+画布大小+参数启用禁用（写 _kit_field("scenario_cfg")）
## 【双形态单源】danmaku_editor 顶栏"场景"页签内嵌本类；
##   EditorPlugin 主屏页签（Dialogic 式，th75 宿主）也是本类——两处一个实现。
## =============================================================

const SUBTABS := ["场景树", "UI 画布", "逻辑链", "内核引用"]
## 【编辑器态数据宿主 20261114】THXKit autoload 只在运行时存在——编辑器主屏
## 用本地镜像（保存/载入走 Editor 界面时用 EditorSettings 路径亦可；当前=镜像变量）
var _kit_mirror := {
	"scenario_name": "", "scenario_cfg": {}, "allow_hitbox_edit": true,
}
func _kit() -> Variant:
	var k := Engine.get_main_loop()
	if k != null and (k as SceneTree).root.has_node("THXKit"):
		return (k as SceneTree).root.get_node("THXKit")
	return null

func _kit_field(prop: String) -> Variant:
	var k = _kit()
	if k != null:
		return k.get(prop)
	return _kit_mirror.get(prop)

func _kit_set(prop: String, v) -> void:
	var k = _kit()
	if k != null:
		k.set(prop, v)
	else:
		_kit_mirror[prop] = v

func _kit_call(method: String, args: Array) -> Variant:
	var k = _kit()
	if k != null and k.has_method(method):
		return k.callv(method, args)
	return null

var _subs: TabContainer
var _cfg_labels := {} ## 内核引用页：cfg 键→值 Label（保存后回读显示）

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.07, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_subs = TabContainer.new()
	_subs.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_subs)
	for t in SUBTABS:
		var page := _build_sub(t)
		page.name = t
		_subs.add_child(page)

func _build_sub(t: String) -> Control:
	match t:
		"场景树":
			return _build_tree_page()
		"UI 画布":
			return _build_canvas_page()
		"逻辑链":
			return _build_graph_page()
	return _build_kernel_page()

## ——①场景树——
func _build_tree_page() -> Control:
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	sc.add_child(box)
	var tip := Label.new()
	tip.text = "【场景 = 多个时间轴的集合】出生/资源/自机/数值系统在节点图编排；Boss 与配置放进时间轴用关键帧调整。数据格式 .thxs（zip：scenario.json+引用时间轴）。"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(560, 0)
	box.add_child(tip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var nm := LineEdit.new()
	nm.placeholder_text = "场景名"
	nm.text = _kit_field("scenario_name")
	nm.custom_minimum_size = Vector2(180, 0)
	row.add_child(nm)
	var save_b := Button.new()
	save_b.text = "保存场景(.thxs)"
	save_b.pressed.connect(func():
		_kit_set("scenario_name", nm.text.strip_edges())
		DirAccess.make_dir_recursive_absolute(_kit_field("SCENARIO_DIR"))
		var p: String = _kit_field("SCENARIO_DIR").path_join((_kit_field("scenario_name") if _kit_field("scenario_name") != "" else "untitled") + ".thxs")
		print("[场景] %s → %s" % ["已保存" if _kit_call("save_scenario", [p]) else "保存失败", p]))
	row.add_child(save_b)
	var load_dlg := FileDialog.new()
	load_dlg.access = FileDialog.ACCESS_FILESYSTEM
	load_dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_dlg.filters = PackedStringArray(["*.thxs ; THX场景包"])
	load_dlg.size = Vector2i(720, 480)
	row.add_child(load_dlg)
	var load_b := Button.new()
	load_b.text = "载入场景"
	load_b.pressed.connect(func(): load_dlg.popup_centered())
	row.add_child(load_b)
	load_dlg.file_selected.connect(func(fp: String):
		var ok: bool = _kit_call("load_scenario", [fp])
		nm.text = _kit_field("scenario_name")
		print("[场景] %s → %s" % ["已载入" if ok else "载入失败", fp]))
	var tscn_b := Button.new()
	tscn_b.text = "导出 Godot 场景(.tscn)"
	tscn_b.pressed.connect(func():
		DirAccess.make_dir_recursive_absolute(_kit_field("SCENARIO_DIR"))
		var p: String = _kit_field("SCENARIO_DIR").path_join((_kit_field("scenario_name") if _kit_field("scenario_name") != "" else "untitled") + ".tscn")
		var ok: bool = _kit_call("generate_tscn", [p])
		print("[场景] tscn 导出%s → %s" % ["成功" if ok else "失败", p]))
	row.add_child(tscn_b)
	var l := Label.new()
	l.text = "本场景引用的时间轴（时间轴页编辑；关键帧=Boss/配置载体）："
	box.add_child(l)
	var tls := ItemList.new()
	tls.custom_minimum_size = Vector2(0, 160)
	for tl in _kit_field("editor_timelines"): ## 弱类型（编辑器扫描期类型注册未完成）
		tls.add_item(tl.tl_name)
	box.add_child(tls)
	return sc

## ——②UI 画布——
func _build_canvas_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var tip := Label.new()
	tip.text = "【UI 画布】把 UI 当场景做（所见即所得存 .thxs）。当前=画布骨架（网格+工程画布框）；控件拖放/属性面板下轮。"
	tip.add_theme_font_size_override("font_size", 12)
	box.add_child(tip)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(center)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(int(_kit_field("scenario_cfg").get("canvas_w", 400)), int(_kit_field("scenario_cfg").get("canvas_h", 400)))
	canvas.set_script(load(_kit_call("kpath", ["res://addons/thx_gamekit/editor/scenario_canvas.gd"])))
	center.add_child(canvas)
	return box

## ——③逻辑链——
func _build_graph_page() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var tip := Label.new()
	tip.text = "【逻辑链（节点图）】节点=事件/条件/动作三类连线编排；**时间轴与场景可作为触发器**（作者裁定 20261114）。当前=画布骨架；节点/连线/求值下轮（设计探讨中）。"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(560, 0)
	box.add_child(tip)
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(center)
	var canvas := Control.new()
	canvas.custom_minimum_size = Vector2(600, 320)
	canvas.set_script(load(_kit_call("kpath", ["res://addons/thx_gamekit/editor/graph_canvas.gd"])))
	center.add_child(canvas)
	return box

## ——④内核引用——
func _build_kernel_page() -> Control:
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	sc.add_child(box)
	var tip := Label.new()
	tip.text = "【内核引用与参数】画布大小、消弹/发射/判定、特殊判定盒等启用禁用——写入 THXKit.scenario_cfg（随 .thxs 保存）。"
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size = Vector2(560, 0)
	box.add_child(tip)
	for spec in [
		["canvas_w", "画布宽", "int"], ["canvas_h", "画布高", "int"],
		["special_hitbox", "特殊判定盒（黑白位图判定）", "check"],
		["hitbox_edit", "判定盒像素编辑可用", "check"],
		["bullet_clear", "消弹域", "check"],
		["nonhuman_res_ban", "非人类玩家资源获取禁止（AI 不获取任何资源）", "check"],
	]:
		box.add_child(_cfg_row(spec[0], spec[1], spec[2]))
	var note := Label.new()
	note.text = "（发射/判定参数化与消弹域范围绘制=下轮；当前项已进 scenario_cfg 并随场景保存）"
	note.add_theme_font_size_override("font_size", 12)
	box.add_child(note)
	## ——【.thxp 双格式管理（作者裁定 20261114）】——
	box.add_child(HSeparator.new())
	var l3 := Label.new()
	l3.text = "【.thxp 双格式】打包=zip 全资源（含 thxs）｜引用=JSON 清单→本地文件（projectdata/<文件名>/，游戏根目录）"
	l3.add_theme_font_size_override("font_size", 16)
	box.add_child(l3)
	var fmt_l := Label.new()
	fmt_l.name = "ThxpFmt"
	fmt_l.add_theme_font_size_override("font_size", 12)
	box.add_child(fmt_l)
	var pick := FileDialog.new()
	pick.access = FileDialog.ACCESS_FILESYSTEM
	pick.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	pick.filters = PackedStringArray(["*.thxp ; THX工程"])
	pick.size = Vector2i(720, 480)
	box.add_child(pick)
	var cur := [""]
	var show_fmt := func():
		if cur[0] == "":
			fmt_l.text = "（未选 .thxp——点下方任一按钮选取）"
		else:
			fmt_l.text = "%s　格式=%s" % [cur[0], _kit_call("thxp_format", [cur[0]])]
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	box.add_child(row2)
	var b1 := Button.new()
	b1.text = "转为引用格式"
	b1.tooltip_text = "打包 thxp 的资源解压到 projectdata/<文件名>/，thxp 覆写为 JSON 清单（原打包版备份 .packed.bak）"
	b1.pressed.connect(func():
		if cur[0] != "" and _kit_call("thxp_to_reference", [cur[0]]):
			print("[thxp] 已转引用格式：%s" % cur[0])
			show_fmt.call())
	row2.add_child(b1)
	var b2 := Button.new()
	b2.text = "打包资源引用"
	b2.tooltip_text = "把所有引用的文件夹内容复制进来压缩进该文件（JSON 清单备份 .reference.bak）"
	b2.pressed.connect(func():
		if cur[0] != "" and _kit_call("thxp_to_packed", [cur[0]]):
			print("[thxp] 已转打包格式：%s" % cur[0])
			show_fmt.call())
	row2.add_child(b2)
	var b3 := Button.new()
	b3.text = "复制外引资源"
	b3.tooltip_text = "所有引用的文件夹内容复制迁移到 projectdata/<文件名>/"
	b3.pressed.connect(func():
		if cur[0] != "" and _kit_call("thxp_copy_external", [cur[0]]):
			print("[thxp] 外引资源已复制到 projectdata")
			show_fmt.call())
	row2.add_child(b3)
	pick.file_selected.connect(func(fp: String):
		cur[0] = fp
		show_fmt.call())
	for b in [b1, b2, b3]:
		b.pressed.connect(func(): pass) ## pick 由各按钮前次路径记忆
		b.focus_mode = Control.FOCUS_NONE
	var pick_b := Button.new()
	pick_b.text = "选取 .thxp"
	pick_b.pressed.connect(func(): pick.popup_centered())
	row2.add_child(pick_b)
	show_fmt.call()
	return sc

func _cfg_row(key: String, label: String, kind: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(200, 0)
	row.add_child(l)
	if kind == "int":
		var sb := SpinBox.new()
		sb.min_value = 100
		sb.max_value = 4096
		sb.value = int(_kit_field("scenario_cfg").get(key, 400))
		sb.value_changed.connect(func(v: float):
			_kit_field("scenario_cfg")[key] = int(v))
		row.add_child(sb)
		_cfg_labels[key] = sb
	else:
		var cb := CheckBox.new()
		cb.button_pressed = bool(_kit_field("scenario_cfg").get(key, false))
		cb.disabled = (key == "hitbox_edit" and not _kit_field("allow_hitbox_edit")) ## 宿主旗标只读
		cb.toggled.connect(func(on: bool):
			_kit_field("scenario_cfg")[key] = on
			if key == "special_hitbox":
				## 【工程级开关】Bullet=全局类（@tool 化后编辑器也可用）——
				## 静态属性直接赋值
				Bullet.special_hitbox_enabled = on
			print("[场景] cfg %s=%s" % [key, str(on)]))
		row.add_child(cb)
		_cfg_labels[key] = cb
	return row
