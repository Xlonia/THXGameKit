extends Node
## =============================================================
## THXKit —— 内核数据基底单例（project.godot autoload）
## 【0.0.9·内核化 20261111】自 th75 game_globals 的"弹幕处理数据基底"部分
## 移植（事件池/Mod 覆盖层/槽位解析/时间轴解析）——玩法部分（versus_*）
## 不在内核，由玩法插件自带。
## 职责：
##   1. 弹幕事件池：官方数据（data/danmaku_event*.csv）+ .thx mod 覆盖层
##   2. 时间轴注册表：官方（data/timelines/*.gd）+ mod + 编辑器工作集
##   3. 角色槽位解析（get_slot_events：main/sub/rest 按名解析事件）
## 【mod 加载运算流程】（对应策划文档《弹幕编辑器》.thx 结构）
##   ① _ready：载入官方分表 → official_events
##   ② 扫描 res://mods 与 user://mods 下 *.thx（zip 包）
##   ③ 逐包读 danmaku_event.csv → DanmakuEventData.parse_csv_text
##   ④ texture/ 下材质字节流 → DanmakuTex.load_from_bytes（运行时材质缓存）
##   ⑤ 事件以 event_name 为键进 mod_events（后加载覆盖先加载）
## 查询优先级：mod_events > official_events（mod 覆盖官方同名事件）
## .thx 同时是『导出为官方数据』的交换格式：编辑器可把 .thx 内容
## 直接写回 data/，供作者开发期作为官方数据使用。
## =============================================================

## 【CSV 拆分（作者批复 2026-10-03）】每种运行方式一份 csv；
## 旧的单文件 danmaku_event.csv 兼容读取（老 mod/官方旧包仍可用）。
## 【0.0.9·挂载点无关 20261111】数据路径从本脚本位置推导（submodule 可挂
## 任意目录）；宿主（游戏）可经 *_OVERRIDE 覆盖到自己的数据目录
var DATA_DIR := ""      ## .../data（官方表示例/材质/时间轴）
var SCENES_DIR := ""    ## .../scenes（试炼场/编辑器场景）
## 【宿主开关 20261113】判定盒像素编辑可用性——内核默认开（裸本体可编辑）；
## THX 系列宿主（特殊判定盒恒关）在 GameGlobals._ready 设 false（按钮禁用）
var allow_hitbox_edit := true
var PROJECTS_DIR := "user://thx_gamekit" ## 【appdata 默认】.thxp/.thx/.thxe 存放处（作者 20261111）

## 【0.0.9·③ 用户内容文件夹（作者 20261111）】材质/判定盒图/角色贴图/音乐/音效
## 可由用户指定特定文件夹（游戏工程可不配置=用内核默认）；顶栏标签页配置。
const CONTENT_DIRS_CFG := "user://thx_gamekit/content_dirs.json"
var content_dirs: Dictionary = {} ## {"danmaku_tex": [...], "hitbox_tex": [...], "chara_tex": [...], "audio": [...]}

func content_scan_dirs(kind: String) -> Array:
	## 该类内容的扫描目录列表（内核默认在前，用户追加在后——后扫者覆盖同名）
	var out: Array = []
	match kind:
		"danmaku_tex":
			out.append(DATA_DIR.path_join("textures/danmaku16pxs"))
		"chara_tex":
			out.append(DATA_DIR.path_join("textures/chars"))
		"audio":
			out.append(DATA_DIR.path_join("audio"))
	out.append_array(content_user_dirs(kind))
	return out

## 【用户目录单独提取 20261112】宿主/用户优先的扫描顺序需要拆层：
## 内核默认 → 宿主 DATA_BASE → 用户（后扫者覆盖同名=用户最优先）
func content_user_dirs(kind: String) -> Array:
	var out: Array = []
	for d in content_dirs.get(kind, []):
		var abs: String = d
		if not abs.begins_with("res://") and not abs.begins_with("user://"):
			abs = ProjectSettings.globalize_path(abs)
		if DirAccess.dir_exists_absolute(abs):
			out.append(abs)
	return out

func set_content_dir(kind: String, user_dir: String) -> void:
	## 用户指定文件夹（空串=清除）；持久化 user://thx_gamekit/content_dirs.json
	var arr: Array = content_dirs.get(kind, [])
	arr.erase(user_dir)
	if user_dir != "":
		arr.append(user_dir)
	if arr.is_empty():
		content_dirs.erase(kind)
	else:
		content_dirs[kind] = arr
	var f := FileAccess.open(CONTENT_DIRS_CFG, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(content_dirs))
		f.close()

func load_content_dirs() -> void:
	if not FileAccess.file_exists(CONTENT_DIRS_CFG):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTENT_DIRS_CFG))
	if data is Dictionary:
		content_dirs = data

func _resolve_paths() -> void:
	if _kernel_root == "":
		var core_dir: String = get_script().resource_path.get_base_dir()
		_kernel_root = core_dir.path_join("..").simplify_path()
	DATA_DIR = _kernel_root.path_join("data").simplify_path()
	SCENES_DIR = _kernel_root.path_join("scenes").simplify_path()
	## 推送静态基准（chara_db/danmaku_tex/chara_tex 为全静态类）
	CharaDB.DATA_BASE = DATA_DIR
	DanmakuTex.DATA_BASE = DATA_DIR.path_join("textures/danmaku16pxs").simplify_path() ## 根目录本身
	CharaTex.DATA_BASE = DATA_DIR.path_join("textures/chars").simplify_path()
const MOD_DIRS: Array[String] = ["res://mods", "user://mods"]

## —— 弹幕事件池 ——
var official_events: Dictionary = {} ## event_name -> DanmakuEventData
var mod_events: Dictionary = {}      ## event_name -> DanmakuEventData（覆盖层）
var loaded_mods: Array[String] = []  ## 已加载 .thx 文件名（UI 展示用）
## —— 时间轴注册表 ——
var editor_events: Array = []        ## 编辑器工作集（弹幕事件；编辑器必备件共享）
var editor_timelines: Array = []     ## 编辑器工作集（时间轴）
var official_timelines: Dictionary = {} ## 官方时间轴注册表（名→TimelineData）
var mod_timelines: Dictionary = {}   ## mod 时间轴注册表（名→TimelineData）

func _ready() -> void:
	_resolve_paths()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROJECTS_DIR))
	_load_official()
	_load_official_timelines()

## 官方时间轴装载：data/timelines/*.gd（TimelineData.parse_gd 文本格式）
func _load_official_timelines() -> void:
	var dir := DirAccess.open(DATA_DIR.path_join("timelines"))
	if dir == null:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".gd"):
			var tl := TimelineData.parse_gd(FileAccess.get_file_as_string(DATA_DIR.path_join("timelines").path_join(f)))
			if not official_timelines.has(tl.tl_name):
				official_timelines[tl.tl_name] = tl
		f = dir.get_next()
	dir.list_dir_end()

func _load_official() -> void:
	var loaded := false
	var csvs := _official_csvs()
	for path in csvs.values():
		if not FileAccess.file_exists(path):
			continue
		loaded = true
		for ev in DanmakuEventData.parse_csv_text(FileAccess.get_file_as_string(path)):
			var cerrs: Array[String] = ev.compile()
			if not cerrs.is_empty():
				push_warning("[事件表] %s 编译失败：%s" % [ev.event_name, cerrs[0]]) ## 静默失败是 Youshio1 事故根因
			## 【20261020】同名先到先得（regular→physical→…表序）——不同分表
			## 存在同名事件时后表不再覆盖（曾致 demo_aimed 被物理表同名行顶掉）
			if not official_events.has(ev.event_name):
				official_events[ev.event_name] = ev
	if loaded:
		return
	if not FileAccess.file_exists(DATA_DIR.path_join("danmaku_event.csv")):
		return
	var text := FileAccess.get_file_as_string(DATA_DIR.path_join("danmaku_event.csv"))
	for ev in DanmakuEventData.parse_csv_text(text):
		ev.compile()
		official_events[ev.event_name] = ev

## 【根治 20261020】编辑器工作集 → 官方五分表 静默同步（合并式：工作集优先
## 同名覆盖，不清除分表既有事件——防数据损失）
func _official_csvs() -> Dictionary:
	return {
		DanmakuEventData.TAG_REGULAR: DATA_DIR.path_join("danmaku_event_regular.csv"),
		DanmakuEventData.TAG_PHYSICAL: DATA_DIR.path_join("danmaku_event_physical.csv"),
		DanmakuEventData.TAG_FUNCTED: DATA_DIR.path_join("danmaku_event_functed.csv"),
		DanmakuEventData.TAG_LASER: DATA_DIR.path_join("danmaku_event_laser.csv"),
		DanmakuEventData.TAG_NODES: DATA_DIR.path_join("danmaku_event_nodes.csv"),
	}

func sync_official_events(events: Array, exclude_names: PackedStringArray = PackedStringArray()) -> void:
	var existing: Array[DanmakuEventData] = []
	for path in _official_csvs().values():
		if FileAccess.file_exists(path):
			existing.append_array(DanmakuEventData.parse_csv_text(FileAccess.get_file_as_string(path)))
	var merged := {}
	for ev: DanmakuEventData in existing:
		if not exclude_names.has(ev.event_name):
			merged[ev.event_name] = ev
	for ev: DanmakuEventData in events:
		if exclude_names.has(ev.event_name):
			continue
		var cur: DanmakuEventData = merged.get(ev.event_name)
		if cur == null or cur.tag == ev.tag:
			merged[ev.event_name] = ev
	var by_tag := {}
	for ev: DanmakuEventData in merged.values():
		if not by_tag.has(ev.tag):
			by_tag[ev.tag] = []
		by_tag[ev.tag].append(ev)
	var csvs2 := _official_csvs()
	for tag: String in csvs2:
		var f := FileAccess.open(String(csvs2[tag]), FileAccess.WRITE)
		if f == null:
			continue
		var lines: Array[String] = [",".join(DanmakuEventData.CSV_HEADER)]
		for ev: DanmakuEventData in by_tag.get(tag, []):
			lines.append(ev.to_csv_row())
		f.store_string("\n".join(lines) + "\n")
		f.close()

## 【20261020】时间轴落盘（官方库存 data/timelines/）
func save_timeline_gd(tl: TimelineData) -> void:
	DirAccess.make_dir_recursive_absolute(DATA_DIR.path_join("timelines"))
	var f := FileAccess.open(DATA_DIR.path_join("timelines").path_join(tl.tl_name + ".gd"), FileAccess.WRITE)
	if f == null:
		push_warning("[THXKit] 时间轴写入失败: " + tl.tl_name)
		return
	f.store_string(tl.to_gd())
	f.close()
	for i in editor_timelines.size():
		if editor_timelines[i] is TimelineData and editor_timelines[i].tl_name == tl.tl_name:
			editor_timelines[i] = tl
			break

## 扫描 mod 目录下全部 .thx（.thx.disabled 后缀=禁用，改名恢复；下次启动生效）
func scan_mod_files() -> Array[String]:
	var out: Array[String] = []
	for dir_path in MOD_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var f := dir.get_next()
		while f != "":
			if f.ends_with(".thx.disabled"):
				loaded_mods.append(f + "（禁用）") ## 展示用；不加载
			elif f.ends_with(".thx"):
				out.append(dir_path.path_join(f))
			f = dir.get_next()
		dir.list_dir_end()
	return out

## 加载一个 .thx → 返回成功载入的事件名列表
func load_thx(path: String) -> Array[String]:
	var names: Array[String] = []
	var zr := ZIPReader.new()
	if zr.open(path) != OK:
		push_warning("[THXKit] 无法打开 .thx：%s" % path)
		return names
	## ① danmaku_event.csv → 事件池
	if zr.get_files().has("danmaku_event.csv"):
		var text := zr.read_file("danmaku_event.csv").get_string_from_utf8()
		for ev in DanmakuEventData.parse_csv_text(text):
			ev.compile()
			mod_events[ev.event_name] = ev
			names.append(ev.event_name)
	## ② texture/ 材质 → 运行时材质缓存
	for f in zr.get_files():
		if f.begins_with("texture/"):
			var tex_name := f.get_file().get_basename()
			DanmakuTex.load_from_bytes(tex_name, zr.read_file(f))
	zr.close()
	return names

## =============================================================
## 【0.0.9·③ 内核路径解析（挂载点无关）】
##   内核内部 load("res://addons/thx_gamekit/xxx") 在宿主挂载（submodule
##   位于 addons/thxgamekit/kit/）时失效——kpath 把内核相对路径重写为
##   实际挂载位置。所有内核内部 load() 一律走本函数。
## =============================================================
var _kernel_root := ""
func kpath(rel: String) -> String:
	if _kernel_root == "":
		var core_dir: String = get_script().resource_path.get_base_dir()
		_kernel_root = core_dir.path_join("..").simplify_path()
	var tail := rel.trim_prefix("res://addons/thx_gamekit/")
	if tail == rel:
		return rel ## 非内核前缀路径原样返回
	return _kernel_root.path_join(tail)

## 【挂载点无关】官方表路径（兼容层/宿主读取用）
func official_csvs() -> Dictionary:
	return _official_csvs()

## 事件查询（mod 覆盖官方）
func get_event(event_name: String) -> DanmakuEventData:
	if mod_events.has(event_name):
		return mod_events[event_name]
	return official_events.get(event_name)

## 取某角色某火力槽的全部事件
## 优先级：编辑器事件（仅试炼场模式，实时改参可见）> mod > 官方；同名去重
func get_slot_events(owner_name: String, slot: String, row: Dictionary = {}) -> Array[DanmakuEventData]:
	var out: Array[DanmakuEventData] = []
	if row.is_empty():
		row = CharaDB.get_by_name(owner_name)
	if row.is_empty():
		return out
	var col: String = {"main": "main_evs", "sub": "sub_evs", "rest": "rest_evs"}.get(slot, "")
	if col == "":
		return out
	for nm in String(row.get(col, "")).split(";", false):
		var ev_name: String = nm.strip_edges()
		if ev_name == "":
			continue
		var ev := resolve_event_by_name(ev_name)
		if ev != null:
			out.append(ev)
	return out

## 按事件名解析（编辑器工作集 → Mod → 官方）
func resolve_event_by_name(ev_name: String) -> DanmakuEventData:
	for ev: DanmakuEventData in editor_events:
		if ev.event_name == ev_name:
			return ev
	if mod_events.has(ev_name):
		return mod_events[ev_name]
	if official_events.has(ev_name):
		return official_events[ev_name]
	return null

## 能力/符卡时间轴事件（timeline_frame≥0，按帧排序）
func get_timeline_events(chara_name: String, slot: String, row: Dictionary = {}) -> Array[DanmakuEventData]:
	var out: Array[DanmakuEventData] = []
	var col: String = {"skill": "skill_evs", "spell": "spell_evs"}.get(slot, "")
	if row.is_empty():
		row = CharaDB.get_by_name(chara_name)
	if row.is_empty():
		return out
	for tl_name in String(row.get(col, "")).split(";", false):
		var tl := resolve_timeline(tl_name.strip_edges())
		if tl == null:
			continue
		for tick in tl.ticks:
			for ev_name in tl.ticks[tick]:
				var ev := resolve_event_by_name(ev_name.strip_edges())
				if ev != null:
					out.append(ev)
	return out

## 按时间轴名解析（工作集 → Mod → 官方）
func resolve_timeline(tl_name: String) -> TimelineData:
	for tl: TimelineData in editor_timelines:
		if tl.tl_name == tl_name:
			return tl
	if mod_timelines.has(tl_name):
		return mod_timelines[tl_name]
	if official_timelines.has(tl_name):
		return official_timelines[tl_name]
	return null

## 事件池整体变更后清缓存（兼容空操作——调用方不改动）
func invalidate_caches() -> void:
	pass

## 重载官方事件表（编辑器『导出为官方数据』后调用，即时生效）
func reload_official() -> void:
	official_events.clear()
	_load_official()
	invalidate_caches()

## =============================================================
## 【场景（.thxs）0.0.9·③ 作者裁定 20261114】
##   场景=多个时间轴的集合（出生/资源/自机/数值系统节点图；Boss/配置
##   放时间轴关键帧）；逻辑链触发自时间轴；导出可生成 .tscn。
##   scenario_cfg=画布大小/内核参数（特殊判定盒启用等）——场景级配置
##   单源；.thxs=zip（scenario.json+引用时间轴）。
## =============================================================
var scenario_name := ""
var scenario_cfg := {
	"canvas_w": 400, "canvas_h": 400,
	"special_hitbox": false, "hitbox_edit": true,
	"bullet_clear": true, ## 消弹域默认开
}
const SCENARIO_DIR := "user://thx_gamekit/scenarios"

## 保存场景包（.thxs）：scenario.json（名称/配置/时间轴引用/节点图占位）
## + timelines/（引用的时间轴 CSV 描述）
func save_scenario(path: String) -> bool:
	var zw := ZIPPacker.new()
	if zw.open(path) != OK:
		push_warning("[THXKit] 场景包打开失败：%s" % path)
		return false
	var tl_refs := []
	var tl_payload := {}
	for tl: TimelineData in editor_timelines:
		tl_refs.append(tl.tl_name)
		## 时间轴载荷=JSON（ticks→事件名数组；to_gd 是 .gd 描述体不适宜包内数据）
		var tj := {"name": tl.tl_name, "ticks": {}}
		for tick in tl.ticks:
			tj["ticks"][str(tick)] = Array(tl.ticks[tick])
		tl_payload["timelines/%s.json" % tl.tl_name] = JSON.stringify(tj, "	")
	var meta := {
		"format": "thxs", "version": 1,
		"name": scenario_name, "cfg": scenario_cfg,
		"timelines": tl_refs,
		"graph": {}, ## 逻辑链节点图（占位——设计探讨后接入）
	}
	zw.start_file("scenario.json")
	zw.write_file(JSON.stringify(meta, "\t").to_utf8_buffer())
	zw.close_file()
	for k in tl_payload:
		zw.start_file(k)
		zw.write_file(str(tl_payload[k]).to_utf8_buffer())
		zw.close_file()
	zw.close()
	return true

## 载入场景包（.thxs）：meta 回读（场景名/配置）+时间轴进工作集
func load_scenario(path: String) -> bool:
	var zr := ZIPReader.new()
	if zr.open(path) != OK:
		push_warning("[THXKit] 场景包打开失败：%s" % path)
		return false
	if not zr.file_exists("scenario.json"):
		zr.close()
		return false
	var meta: Variant = JSON.parse_string(zr.read_file("scenario.json").get_string_from_utf8())
	zr.close()
	if typeof(meta) != TYPE_DICTIONARY or str(meta.get("format")) != "thxs":
		return false
	scenario_name = str(meta.get("name", ""))
	var cfg: Variant = meta.get("cfg", {})
	if typeof(cfg) == TYPE_DICTIONARY:
		for k in cfg:
			scenario_cfg[k] = cfg[k]
	return true

## 场景导出为 Godot 场景（裁定③：生成 .tscn）——骨架版：
## 根 Node2D + 画布底 + 引用时间轴每条一个 Timer 触发器占位 + 出生点 Marker
func generate_tscn(path: String) -> bool:
	var w := int(scenario_cfg.get("canvas_w", 400))
	var h := int(scenario_cfg.get("canvas_h", 400))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	var sb := "[gd_scene format=3]\n\n"
	sb += "[sub_resource type=\"RectangleShape2D\" id=\"canvas\"]\n"
	sb += "size = Vector2(%d, %d)\n\n" % [w, h]
	sb += "[node name=\"%s\" type=\"Node2D\"]\n" % (scenario_name if scenario_name != "" else "THXScenario")
	sb += "[node name=\"Canvas\" type=\"ColorRect\" parent=\".\"]\n"
	sb += "offset_right = %d.0\noffset_bottom = %d.0\ncolor = Color(0.05, 0.06, 0.1, 1)\n" % [w, h]
	var i := 0
	for tl: TimelineData in editor_timelines:
		sb += "[node name=\"TL_%s\" type=\"Timer\" parent=\".\"]\nwait_time = 0.1\nautostart = true\n" % tl.tl_name
		sb += "[node name=\"TL_out_%d\" type=\"Marker2D\" parent=\".\"]\nposition = Vector2(%d, %d)\n" % [i, w / 2 + i * 12, 40]
		i += 1
	f.store_string(sb)
	f.close()
	return true
