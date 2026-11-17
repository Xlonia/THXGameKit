class_name ClipData
extends RefCounted
## =============================================================
## 【m85 弹幕片段（作者裁定 20261117，scheme 新二 710/142）】
## 片段=可安放数个弹幕事件的时间轴（0.1s/tick）。火力点配置从"弹幕本身"
## 改为"单个仅含单个弹幕的片段"——迁移期全部为单事件 tick0 片段；
## 片段长度来自火力点延迟（角色 CSV 的 Cd 类=消望插件数据）作**最低长度**。
## 以后角色弹幕修改流程：弹幕配置给片段 → 将片段配置给角色。
## 存储：danmaku_clip.csv 三列（clip_name,length,ticks——ticks 格为 JSON
## {"0":["demo_aimed"]}，RFC4180 引号双写转义，与 spell.csv 同法）。
## =============================================================

var clip_name := "untitled_clip"
var length_ticks := 1 ## 片段长度（tick；>=角色 Cd 最低长度）
var ticks := {}       ## int tick -> Array[String 事件名]（升序求值）

## 按 tick 升序展开为 [{tick:int, name:String}]
## （length_ticks=**最低长度**——只约束火力点节拍对齐，不截断事件）
func flat_entries() -> Array:
	var out: Array = []
	var ks: Array = ticks.keys()
	ks.sort()
	for k in ks:
		for nm in ticks[k]:
			out.append({"tick": int(k), "name": String(nm)})
	return out

static func _cell_json(ticks: Dictionary) -> String:
	var out := {}
	for k in ticks:
		out[str(int(k))] = ticks[k]
	return JSON.stringify(out)

static func _parse_cell(cell: String) -> Dictionary:
	var c := cell.strip_edges()
	if c == "":
		return {}
	var v: Variant = JSON.parse_string(c)
	if v is Dictionary:
		var out := {}
		for k in v:
			out[int(k)] = v[k]
		return out
	return {}

## danmaku_clip.csv 解析（header=clip_name,length,ticks）
static func parse_csv(text: String) -> Array:
	var out: Array = []
	for raw in text.split("\n", false):
		var line: String = raw.strip_edges().trim_suffix("\r")
		if line == "" or line.begins_with("clip_name,"):
			continue
		var cells := DanmakuEventData.split_csv_line(line)
		if cells.size() < 3:
			continue
		var cd := ClipData.new()
		cd.clip_name = cells[0]
		cd.length_ticks = maxi(1, int(cells[1].to_float()))
		cd.ticks = _parse_cell(cells[2])
		out.append(cd)
	return out

func to_csv_row() -> String:
	## 三列：名/长度/ticks(JSON)——只有 JSON 格含逗号需引号包裹（RFC4180 双写）
	var j := _cell_json(ticks)
	return "%s,%d,\"%s\"" % [clip_name, length_ticks, j.replace("\"", "\"\"")]
