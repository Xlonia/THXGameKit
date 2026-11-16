@tool
class_name TimelineData
extends RefCounted

## =============================================================
## 时间轴（作者批复 2026-10-02）：
##   不为弹幕安排"时间轴的帧"，而是在时间轴的每个弹幕事件帧（0.1秒一个tick）
##   安排一个或多个弹幕事件；保存为 .gd 后缀文件，
##   结构与弹幕事件行（danmaku_event.csv 行）不完全相同。
## 【文件格式（danmaku/<名>.gd，纯文本可读）】
##   ## THX075 TIMELINE v1
##   ## @name: <时间轴名>
##   ## @owner: <角色名或*>
##   ## @slot:  skill | spell
##   ## T <tick序号> => <事件名>,<事件名>,…
## 运行时（能力/符卡释放）在②期接线；剧情可覆盖为多条时间轴（数组）。
## =============================================================

var tl_name := "demotimeline1"
var slot := "spell"          ## skill=能力 / spell=符卡
## 【m74 角色触发器（作者 20261116）】符卡启动/每事件帧 绑定角色流程
## （名称对应 morerule.gd 原生预设 / progess.gd 已有保存逻辑；空=不绑定）
var flow_start := ""
var flow_every := ""
## 【m75 伪节点图（作者 20261117）】符卡触发器挂载的流程步骤列表
## （每步 {op:键名, arg:名称/图形, params:参数文本框}——编辑器伪节点图
## 增删/排序/复制；执行顺序=数组序）。svgresign/clean 为符卡专用 op。
var steps_start: Array = []
var steps_tick: Array = []
var length_ticks := 60       ## 总帧数（每帧0.1秒；Flash 式帧条的长度）
var ticks := {}              ## int(tick, 每0.1秒) -> PackedStringArray 事件名

func set_events(tick: int, names: PackedStringArray) -> void:
	if names.is_empty():
		ticks.erase(tick)
	else:
		ticks[tick] = names

func add_event(tick: int, ev_name: String) -> void:
	var arr: PackedStringArray = ticks.get(tick, PackedStringArray())
	if not arr.has(ev_name):
		arr.append(ev_name)
	ticks[tick] = arr

func remove_tick(tick: int) -> void:
	ticks.erase(tick)

## —— 序列化（.gd 文本）——
func to_gd() -> String:
	var lines: Array[String] = []
	lines.append("## THX075 TIMELINE v1")
	lines.append("## @name: %s" % tl_name)
	lines.append("## @slot: %s" % slot)
	lines.append("## @len: %d" % length_ticks)
	if flow_start != "":
		lines.append("## @flow_start: %s" % flow_start)
	if flow_every != "":
		lines.append("## @flow_every: %s" % flow_every)
	if steps_start.size() > 0:
		lines.append("## @steps_start: %s" % JSON.stringify(steps_start))
	if steps_tick.size() > 0:
		lines.append("## @steps_tick: %s" % JSON.stringify(steps_tick))
	lines.append("## 每个 tick = 0.1秒；格式：## T <tick> => 事件名,事件名,…")
	var keys := ticks.keys()
	keys.sort()
	for k in keys:
		lines.append("## T %d => %s" % [k, ",".join(ticks[k])])
	lines.append("## 本文件由弹幕编辑器自动生成；运行时解析见 TimelineData。")
	return "\n".join(lines) + "\n"

static func parse_gd(text: String):
	var tl = TimelineData.new()
	for line in text.split("\n", false):
		var l := line.strip_edges()
		if l.begins_with("## @name:"):
			tl.tl_name = l.trim_prefix("## @name:").strip_edges()
		elif l.begins_with("## @owner:"):
			pass ## 【20261020】owner 废除——旧文件该行忽略（时间轴归属走角色列）
		elif l.begins_with("## @slot:"):
			tl.slot = l.trim_prefix("## @slot:").strip_edges()
		elif l.begins_with("## @flow_start:"):
			tl.flow_start = l.trim_prefix("## @flow_start:").strip_edges()
		elif l.begins_with("## @flow_every:"):
			tl.flow_every = l.trim_prefix("## @flow_every:").strip_edges()
		elif l.begins_with("## @steps_start:"):
			var ss: Variant = JSON.parse_string(l.trim_prefix("## @steps_start:"))
			if ss is Array:
				tl.steps_start = ss
		elif l.begins_with("## @steps_tick:"):
			var st: Variant = JSON.parse_string(l.trim_prefix("## @steps_tick:"))
			if st is Array:
				tl.steps_tick = st
		elif l.begins_with("## @len:"):
			tl.length_ticks = maxi(10, int(l.trim_prefix("## @len:").strip_edges()))
		elif l.begins_with("## T "):
			var body := l.trim_prefix("## T ")
			var sep := body.find("=>")
			if sep >= 0:
				var tick := int(body.substr(0, sep).strip_edges())
				var names := PackedStringArray()
				for n in body.substr(sep + 2).split(",", false):
					var nn := n.strip_edges()
					if not nn.is_empty():
						names.append(nn)
				tl.ticks[tick] = names
	if tl.tl_name.is_empty():
		tl.tl_name = "imported_timeline"
	return tl

static func is_timeline_gd(text: String) -> bool:
	return text.contains("## THX075 TIMELINE")
