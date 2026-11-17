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
var length_ticks := 1 ## 片段长度（tick；上限 256——作者 20261118：更长交给章节剪辑）
var ticks := {}       ## int tick -> Array[String 事件名]（升序求值）
## 【m87 资源管理（scheme #资源管理/冷知识）】分组标签（legacy=THX75 原有片段
## 打包组；空=未分组）。完整"多 csv 文件+目录树"资源分组=资源管理大功能
## （后续版本），本字段先行占位——列表按此分组显示、CSV 第 4 列持久化
var group := ""

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

## —— 编辑器助手（与 TimelineData add_event/set_events 同构）——
func events_at(tick: int) -> Array:
	return ticks.get(tick, [])

func add_event(tick: int, ev_name: String) -> void:
	var arr: Array = ticks.get(tick, [])
	if not arr.has(ev_name):
		arr.append(ev_name)
	ticks[tick] = arr

func set_events(tick: int, names: Array) -> void:
	if names.is_empty():
		ticks.erase(tick)
	else:
		ticks[tick] = names

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

## danmaku_clip.csv 解析（header=clip_name,length,ticks[,group]——3 列旧文件兼容）
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
		cd.length_ticks = clampi(int(cells[1].to_float()), 1, 256) ## 【m87】上限 256
		cd.ticks = _parse_cell(cells[2])
		if cells.size() >= 4:
			cd.group = cells[3].strip_edges()
		out.append(cd)
	return out

func to_csv_row() -> String:
	## 四列：名/长度/ticks(JSON)/分组——JSON 格含逗号需引号包裹（RFC4180 双写）
	var j := _cell_json(ticks)
	return "%s,%d,\"%s\",%s" % [clip_name, length_ticks, j.replace("\"", "\"\""), group]

## danmaku_clip.csv 全文（表头+逐行）——编辑器包保存/导出官方数据用
static func save_csv(clips: Array) -> String:
	var lines: Array[String] = ["clip_name,length,ticks,group"]
	for c in clips:
		lines.append((c as ClipData).to_csv_row())
	return "\n".join(lines) + "\n"
