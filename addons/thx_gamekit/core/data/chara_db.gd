class_name CharaDB
extends RefCounted
## =============================================================
## 角色数据库（第①期：新增 poi 表达式列 + privates.csv + Enemy.csv）
## Characters.csv 列（作者已提供 poi 数据）：
##   ... Weapon_Muti, main_y, sub_x, sub_y,
##   main_poi_x, main_poi_y, sub_poi_x, sub_poi_y, Char_*, NameZH/JP/EN
## poi 列为表达式字符串（变量 wpcs/to_c），建议仅加减乘除
## Enemy.csv：敌方角色（无 ID/Team 列——不需接受队伍指挥，批复说明）
## privates.csv：杂兵（Name,Normal,Determine,Defend,NameZH/JP/EN）
## =============================================================

## 【0.0.9·挂载点无关】路径=DATA_BASE（THXKit 推送）+ 宿主覆盖（THX75
## 指向 gameAssetBase 自己的数据）——静态变量而非 const（可被宿主重定向）
static var DATA_BASE := "res://addons/thx_gamekit/data"
static var CSV_OVERRIDE := ""
static var ENEMY_OVERRIDE := ""
static var PRIVATES_OVERRIDE := ""

static func csv_path() -> String:
	return CSV_OVERRIDE if CSV_OVERRIDE != "" else DATA_BASE.path_join("characters.csv")
static func enemy_path() -> String:
	return ENEMY_OVERRIDE if ENEMY_OVERRIDE != "" else DATA_BASE.path_join("enemy.csv")
static func privates_path() -> String:
	return PRIVATES_OVERRIDE if PRIVATES_OVERRIDE != "" else DATA_BASE.path_join("privates.csv")

const INT_COLS := ["Cruise", "Normal", "Determine", "Defend", "Mag", "Phy", "ID", "Team", "Main_Cd", "Sub_Cd"]
const FLOAT_COLS := ["Weapon_Muti", "Char_Raid", "Char_Allfire", "Char_Blitz", "Char_Cover", "Char_Elast", "Char_Delay", "Char_Feint",
	"main_para_rat", "main_seci_rat", "sub_para_rat"] ## 火力占比三列（作者 2026-10-03 提供）
const EXPR_COLS := ["main_y", "sub_x", "sub_y", "main_poi_x", "main_poi_y", "sub_poi_x", "sub_poi_y"] ## 可表达式（建议±*/）
const POI_VARS: PackedStringArray = ["wpcs", "to_c"]

static func load_all() -> Array[Dictionary]:
	return _load_csv(csv_path(), true)

static func load_enemies() -> Array[Dictionary]:
	return _load_csv(enemy_path(), false)

static var _priv_cache: Array[Dictionary] = [] ## 【0.0.9·审计C2 20261108】privates.csv 重复读盘缓存（建队 10 次+每增援）
static func load_privates() -> Array[Dictionary]:
	if _priv_cache.is_empty():
		_priv_cache = _load_csv(privates_path(), false)
	return _priv_cache

static func _load_csv(path: String, full: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[CharaDB] 表格无法读取：%s" % path)
		return out
	var header: PackedStringArray = []
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() == 0:
			continue
		var first: String = row[0].strip_edges()
		if first.is_empty() or first.begins_with("#"):
			continue
		if header.is_empty():
			header = row
			continue
		var d := {}
		for i in header.size():
			if i >= row.size() or header[i].is_empty():
				continue
			d[header[i]] = row[i] if i < row.size() else ""
		if full:
			_cast(d)
		out.append(d)
	file.close()
	return out

static func _cast(d: Dictionary) -> Dictionary:
	for k in INT_COLS:
		d[k] = int(String(d.get(k, "0")).to_float())
	for k in FLOAT_COLS:
		d[k] = String(d.get(k, "0")).to_float()
	## poi 列保持字符串（表达式），缺失补 "0"
	for k in EXPR_COLS:
		var raw := String(d.get(k, "0")).strip_edges()
		d[k] = raw if not raw.is_empty() else "0"
	return d

## 列默认值表（作者批复 2026-10-03：事故丢失/不可用的数据拟默认值）
## 数值列→合理零值；性格默认 0.2（无偏好）；poi/修改值→"0"；名称→占位
const COL_DEFAULTS := {
	"Cruise": "3", "Normal": "2", "Determine": "3", "Defend": "1",
	"Mag": "0", "Phy": "0", "ID": "0", "Team": "0",
	"Main_Cd": "4", "Sub_Cd": "2", "Weapon_Muti": "1",
	"main_y": "0", "sub_x": "0", "sub_y": "0",
	"main_poi_x": "0", "main_poi_y": "0", "sub_poi_x": "0", "sub_poi_y": "0",
	"Char_Raid": "0.2", "Char_Allfire": "0.2", "Char_Blitz": "0.2", "Char_Cover": "0.2",
	"Char_Elast": "0.2", "Char_Delay": "0.2", "Char_Feint": "0.2",
	"main_para_rat": "0.3", "main_seci_rat": "0.3", "sub_para_rat": "0.3",
	"NameZH": "未命名", "NameJP": "未命名", "NameEN": "Unnamed",
}

## 取列值：缺失/无效（数值列填了非数字、非法负值）→ 拟默认值
static func _cell_or_default(row: Dictionary, key: String) -> String:
	var raw := str(row.get(key, "")).strip_edges()
	var dflt: String = COL_DEFAULTS.get(key, "")
	if raw.is_empty():
		return dflt
	if key in INT_COLS or key in FLOAT_COLS:
		if not raw.is_valid_float():
			return dflt ## 不可用的值 → 默认
		if raw.to_float() < 0.0:
			return dflt ## 非法负值（全部数值列均非负语义，ID/Team=0 合法）→ 默认
	return raw

## 【20261003】写回单个角色行（编辑器角色页）：仅替换该行，其余原样保留；
## 字段值经 CSV 转义（poi 表达式可含逗号）。成功返回 true。
static func save_row(chara_name: String, row: Dictionary) -> bool:
	var f := FileAccess.open(csv_path(), FileAccess.READ)
	if f == null:
		push_error("[CharaDB] 无法读取：%s（若为导出版运行：请检查导出预设 include 是否包含 *.csv）" % csv_path())
		return false
	var header_line := ""
	var header: PackedStringArray = []
	var body: Array[String] = []
	while not f.eof_reached():
		var line := f.get_line()
		if header.is_empty() and line.strip_edges().replace("﻿", "").begins_with("Name"):
			header_line = line ## 表头原样写回（含 BOM/原始格式）
			header = line.split(",")
			continue
		body.append(line)
	f.close()
	if header.is_empty():
		return false
	## 【自愈 20261020】角色弹幕列表列缺失时补入表头（写侧迁移——
	## 防旧表无列时绑定数据被丢弃；新建表头含列的文件原样）
	var need := ["main_evs", "sub_evs", "rest_evs", "skill_evs", "spell_evs"]
	var hdr_keys := []
	for h in header:
		hdr_keys.append(String(h).strip_edges().replace("﻿", ""))
	for nk in need:
		if not hdr_keys.has(nk):
			header.append(nk)
			header_line = header_line + "," + nk
	var new_cells := PackedStringArray()
	for h in header:
		## 注意 BOM：表头首列可能是 "﻿Name"，查字典前必须剥掉
		var key := String(h).strip_edges().replace("﻿", "")
		if key.is_empty():
			new_cells.append("")
		else:
			## 【20261003】缺失/无效的值拟默认值（含 Name 首列兜底）
			var v := _cell_or_default(row, key)
			if key == "Name" and v.is_empty():
				v = chara_name
			new_cells.append(_csv_cell(v))
	var target := -1
	for i in body.size():
		var line := body[i]
		if line.strip_edges().is_empty():
			continue
		if line.split(",")[0].strip_edges().replace("﻿", "") == chara_name:
			target = i
			break
	if target < 0:
		return false
	body[target] = ",".join(new_cells)
	while not body.is_empty() and body[body.size() - 1].strip_edges().is_empty():
		body.pop_back() ## get_line 的 eof 特性会多出一个尾随空行，写回前剥掉
	var w := FileAccess.open(csv_path(), FileAccess.WRITE)
	if w == null:
		return false
	w.store_line(header_line) ## 【修复 20261003】表头必须写回（旧版丢失 → 全表变称号）
	for line in body:
		w.store_line(line)
	w.close()
	return true

## 【0.0.9·内核化 20261111】新建角色：逐列取 COL_DEFAULTS（Name=键名），
## 追加到表尾。必填列由 COL_DEFAULTS 兜底（与 _load_csv 同源）。
## 【1111c 修订】实现统一到 _append_row（与 .thxp/.thxe 装载共用）。
static func new_character(chara_name: String) -> bool:
	if not get_by_name(chara_name).is_empty():
		return false ## 已存在
	return _append_row(csv_path(), {"Name": chara_name, "NameZH": chara_name,
		"NameJP": chara_name, "NameEN": chara_name})

## 【0.0.9·内核化 20261111】新建杂兵（privates.csv；三语名=键名，其余默认）
## 【1111c 修订】同上统一 _append_row。
static func new_private(private_name: String) -> bool:
	if not get_private_by_name(private_name).is_empty():
		return false
	return _append_row(privates_path(), {"Name": private_name, "NameZH": private_name,
		"NameJP": private_name, "NameEN": private_name})

## 【0.0.9·内核化 20261111】行追加（.thxp/.thxe 装载与新建共用）：
## 逐列 _cell_or_default 兜底（存在→由调用方 upsert，本函数只追加）
static func _append_row(path: String, row: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var header_line := ""
	var body: Array[String] = []
	while not f.eof_reached():
		var line := f.get_line()
		if header_line == "" and line.strip_edges().replace("\ufeff", "").begins_with("Name"):
			header_line = line
			continue
		if line.strip_edges() != "":
			body.append(line)
	f.close()
	if header_line == "":
		return false
	var header: PackedStringArray = header_line.split(",")
	var new_cells := PackedStringArray()
	for h in header:
		var key := String(h).strip_edges().replace("\ufeff", "")
		new_cells.append(_csv_cell(_cell_or_default(row, key)))
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	if f2 == null:
		return false
	f2.store_string(header_line + "\n")
	for line in body:
		f2.store_string(line + "\n")
	f2.store_string(",".join(new_cells) + "\n")
	f2.close()
	return true

## 【0.0.9·内核化 20261111】.thxp/.thxe 装载：角色/杂兵表逐行 upsert
## （存在→整行覆盖走 save_row/save_private_row；新增→_append_row；键名=首列 Name）
static func import_csv_text(text: String, kind: String) -> int:
	var imported := 0
	var lines := text.split("\n")
	var header := PackedStringArray()
	for line in lines:
		var l := line.strip_edges()
		if l == "":
			continue
		if header.is_empty() and l.replace("\ufeff", "").begins_with("Name"):
			header = l.replace("\ufeff", "").split(",")
			continue
		if header.is_empty():
			continue
		var cells := l.split(",")
		var row := {}
		for i in header.size():
			var key := String(header[i]).strip_edges().replace("\ufeff", "")
			if key != "" and i < cells.size():
				row[key] = cells[i]
		var nm := String(row.get("Name", ""))
		if nm == "":
			continue
		if kind == "chara":
			if not get_by_name(nm).is_empty():
				if save_row(nm, row):
					imported += 1
			elif _append_row(csv_path(), row):
				imported += 1
		else:
			if not get_private_by_name(nm).is_empty():
				if save_private_row(nm, row):
					imported += 1
			elif _append_row(privates_path(), row):
				imported += 1
	return imported

static func _csv_cell(v) -> String:
	var s := str(v)
	if s.contains(",") or s.contains("\""):
		return "\"" + s.replace("\"", "\"\"") + "\""
	return s

static func get_by_name(chara_name: String) -> Dictionary:
	for d in load_all():
		if d["Name"] == chara_name:
			return d
	return {}

## 【杂兵编辑+弹幕分配 20261020】私兵行保存（编辑器杂兵页用；表头自愈含 shoot_evs）
const PRIVATES_REQUIRED := ["ShootCd", "shoot_evs"]
static func save_private_row(private_name: String, row: Dictionary) -> bool:
	var f := FileAccess.open(privates_path(), FileAccess.READ)
	if f == null:
		push_error("[CharaDB] 无法读取：%s" % privates_path())
		return false
	var header_line := ""
	var header: PackedStringArray = []
	var body: Array[String] = []
	while not f.eof_reached():
		var line := f.get_line()
		if header.is_empty() and line.strip_edges().replace("﻿", "").begins_with("Name"):
			header_line = line
			header = line.split(",")
			continue
		body.append(line)
	f.close()
	if header.is_empty():
		return false
	## 表头自愈：缺列自动补（ShootCd/shoot_evs）
	var hdr_keys := []
	for h in header:
		hdr_keys.append(String(h).strip_edges().replace("﻿", ""))
	for nk in PRIVATES_REQUIRED:
		if not hdr_keys.has(nk):
			header.append(nk)
			header_line = header_line + "," + nk
	var new_cells := PackedStringArray()
	for h in header:
		var key := String(h).strip_edges().replace("﻿", "")
		if key.is_empty():
			new_cells.append("")
		else:
			var v := _cell_or_default(row, key)
			if key == "Name" and v.is_empty():
				v = private_name
			new_cells.append(_csv_cell(v))
	var target := -1
	for i in body.size():
		var cells := body[i].split(",")
		if cells.size() > 0 and cells[0].strip_edges() == private_name:
			target = i
			break
	var line2 := ",".join(new_cells)
	if target >= 0:
		body[target] = line2
	else:
		body.append(line2)
	var w := FileAccess.open(privates_path(), FileAccess.WRITE)
	if w == null:
		push_error("[CharaDB] 无法写入：%s" % privates_path())
		return false
	w.store_string(header_line + "
")
	for b in body:
		if b.strip_edges() != "":
			w.store_string(b + "
")
	w.close()
	return true

static func get_private_by_name(n: String) -> Dictionary:
	for d in load_privates():
		if d["Name"] == n:
			return d
	return {}

static func get_enemy_by_name(n: String) -> Dictionary:
	for d in load_enemies():
		if d["Name"] == n:
			return d
	return {}

## poi 表达式编译工具（FireControl 复用；错误返回 null）
static func compile_poi(row: Dictionary, col: String) -> DanmakuExpr:
	var raw := String(row.get(col, "0")).strip_edges()
	if raw.is_empty():
		raw = "0"
	var e := DanmakuExpr.new()
	if not e.compile(raw, POI_VARS):
		return null
	return e
