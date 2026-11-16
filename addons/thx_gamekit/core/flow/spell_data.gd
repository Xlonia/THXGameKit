class_name SpellData
extends RefCounted
## =============================================================
## 【0.0.9·符卡数据（scheme 概述：spell.csv=所有符卡的文件，包含它
## 每个触发器的挂载流程）】四列：符卡本地化键名 + 三核心触发器
## （spellstart=释放时刻 / spellfin=符卡结束 / spelltick=每事件帧）。
## 每格=挂载的流程步骤（JSON 数组，元素 {op, arg, params}——伪节点图编辑）。
## 弹幕表演走片段（playclips/loopclips 流程），不在本文件。
## =============================================================

var spell_name := "untitled_spell" ## 本地化键名
var steps_start: Array = []
var steps_fin: Array = []
var steps_tick: Array = []

static func _cell_json(steps: Array) -> String:
	if steps.is_empty():
		return ""
	return JSON.stringify(steps)

static func _parse_cell(cell: String) -> Array:
	var c := cell.strip_edges()
	if c == "":
		return []
	var v: Variant = JSON.parse_string(c)
	return v if v is Array else []

## spell.csv 解析：header=spell_name,spellstart,spellfin,spelltick（UTF-8，
## 单元格 JSON 以双引号包裹——CSV 引号转义按 RFC4180 双写）
static func parse_csv(text: String) -> Array:
	var out: Array = []
	var lines := text.split("\n", false)
	var header_seen := false
	for raw in lines:
		var line := raw.strip_edges()
		if line == "" or line.begins_with("spell_name,"):
			header_seen = true
			continue
		## 简易四列拆分（JSON 内无裸逗号——JSON.stringify 输出含逗号但被
		## 双引号包裹；此处按引号感知拆分）
		var cells := _split_csv_line(line)
		if cells.size() < 4:
			continue
		var sp := SpellData.new()
		sp.spell_name = cells[0]
		sp.steps_start = _parse_cell(cells[1])
		sp.steps_fin = _parse_cell(cells[2])
		sp.steps_tick = _parse_cell(cells[3])
		out.append(sp)
	return out

static func _split_csv_line(line: String) -> PackedStringArray:
	var cells := PackedStringArray()
	var cur := ""
	var in_q := false
	var i := 0
	while i < line.length():
		var ch := line[i]
		if in_q:
			if ch == "\"":
				if i + 1 < line.length() and line[i + 1] == "\"":
					cur += "\""
					i += 1
				else:
					in_q = false
			else:
				cur += ch
		else:
			if ch == "\"":
				in_q = true
			elif ch == ",":
				cells.append(cur)
				cur = ""
			else:
				cur += ch
		i += 1
	cells.append(cur)
	return cells

static func save_csv(spells: Array) -> String:
	var lines: Array[String] = ["spell_name,spellstart,spellfin,spelltick"]
	for sp in spells:
		var row := PackedStringArray()
		for c in [sp.spell_name, _cell_json(sp.steps_start), _cell_json(sp.steps_fin), _cell_json(sp.steps_tick)]:
			row.append(_csv_cell(str(c)))
		lines.append(",".join(row))
	return "\n".join(lines) + "\n"

static func _csv_cell(v: String) -> String:
	if v.contains(",") or v.contains("\"") or v.contains("\n"):
		return "\"" + v.replace("\"", "\"\"") + "\""
	return v
