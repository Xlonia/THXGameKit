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
const OFFICIAL_EVENT_CSV := "res://addons/thx_gamekit/data/danmaku_event.csv"
const OFFICIAL_EVENT_CSVS: Dictionary = {
	DanmakuEventData.TAG_REGULAR: "res://addons/thx_gamekit/data/danmaku_event_regular.csv",
	DanmakuEventData.TAG_PHYSICAL: "res://addons/thx_gamekit/data/danmaku_event_physical.csv",
	DanmakuEventData.TAG_FUNCTED: "res://addons/thx_gamekit/data/danmaku_event_functed.csv",
	DanmakuEventData.TAG_LASER: "res://addons/thx_gamekit/data/danmaku_event_laser.csv",
	DanmakuEventData.TAG_NODES: "res://addons/thx_gamekit/data/danmaku_event_nodes.csv",
}
const TIMELINES_DIR := "res://addons/thx_gamekit/data/timelines"
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
	_load_official()

func _load_official() -> void:
	var loaded := false
	for path in OFFICIAL_EVENT_CSVS.values():
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
	if not FileAccess.file_exists(OFFICIAL_EVENT_CSV):
		return
	var text := FileAccess.get_file_as_string(OFFICIAL_EVENT_CSV)
	for ev in DanmakuEventData.parse_csv_text(text):
		ev.compile()
		official_events[ev.event_name] = ev

## 【根治 20261020】编辑器工作集 → 官方五分表 静默同步（合并式：工作集优先
## 同名覆盖，不清除分表既有事件——防数据损失）
func sync_official_events(events: Array, exclude_names: PackedStringArray = PackedStringArray()) -> void:
	var existing: Array[DanmakuEventData] = []
	for path in OFFICIAL_EVENT_CSVS.values():
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
	for tag: String in OFFICIAL_EVENT_CSVS:
		var f := FileAccess.open(String(OFFICIAL_EVENT_CSVS[tag]), FileAccess.WRITE)
		if f == null:
			continue
		var lines: Array[String] = [",".join(DanmakuEventData.CSV_HEADER)]
		for ev: DanmakuEventData in by_tag.get(tag, []):
			lines.append(ev.to_csv_row())
		f.store_string("\n".join(lines) + "\n")
		f.close()

## 【20261020】时间轴落盘（官方库存 data/timelines/）
func save_timeline_gd(tl: TimelineData) -> void:
	DirAccess.make_dir_recursive_absolute(TIMELINES_DIR)
	var f := FileAccess.open(TIMELINES_DIR + "/" + tl.tl_name + ".gd", FileAccess.WRITE)
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
