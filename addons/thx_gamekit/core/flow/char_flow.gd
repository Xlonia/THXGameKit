class_name CharFlowData
extends RefCounted
## =============================================================
## 【0.0.9·角色流程数据（scheme 新二 975 行）】角色流程可编程，收录在
## 本体侧 morerule.gd / 部署侧 progess.gd；非部署时在 tab 页面供修补。
## 【文件格式（morerule.gd / progess.gd，纯文本）】
##   ## THX CHARFLOW v1
##   ## @name: <流程名>
##   ## @owner: <角色名或*>
##   ## F <op> | sel:<shape>,<参数对>… | ev:<事件名> | every:<tick数>
##     op=reflex/inverse（0.0.9 首批；inversep/inheritdamage/revolt 随后）
##     sel 参数对：r=120 / x0=-100,x1=100 / y0=…,y1=… / t_max=120 / max_n=64
##     side 由运行时按施放者敌对侧自动填（文档 sel 不含 side）
##     every=0 一次性；>0 = 每 N tick（0.1s/tick）重复执行该步
## =============================================================

var flow_name := "untitled_flow"
var owner := "*" ## 角色名或 *（任意）
var steps: Array = [] ## [{op, sel:Dictionary, ev:String, every:int}]

static func parse_gd(text: String) -> Array:
	## 多流程共存：返回 Array[CharFlowData]（## @name 分段）
	var flows: Array = []
	var cur: CharFlowData = null
	for raw in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.begins_with("## @name:"):
			cur = CharFlowData.new()
			cur.flow_name = line.trim_prefix("## @name:").strip_edges()
			flows.append(cur)
		elif cur != null and line.begins_with("## @owner:"):
			cur.owner = line.trim_prefix("## @owner:").strip_edges()
		elif cur != null and line.begins_with("## F "):
			var step := parse_step(line.trim_prefix("## F "))
			if not step.is_empty():
				cur.steps.append(step)
	return flows

static func parse_step(body: String) -> Dictionary:
	var parts := body.split("|")
	if parts.is_empty():
		return {}
	var step := {"op": parts[0].strip_edges(), "sel": {}, "ev": "", "every": 0}
	for pi in range(1, parts.size()):
		var seg: String = parts[pi].strip_edges()
		if seg.begins_with("sel:"):
			for kv in seg.trim_prefix("sel:").split(","):
				var pp := kv.split("=")
				if pp.size() == 2:
					var key: String = pp[0].strip_edges()
					var v: float = pp[1].to_float()
					match key:
						"shape", "x0", "x1", "y0", "y1", "r", "t_max", "max_n":
							step["sel"][key] = v if key != "shape" else pp[1].strip_edges()
		elif seg.begins_with("ev:"):
			step["ev"] = seg.trim_prefix("ev:").strip_edges()
		elif seg.begins_with("every:"):
			step["every"] = int(seg.trim_prefix("every:").to_float())
	return step

func to_gd() -> String:
	var lines: Array[String] = []
	lines.append("## THX CHARFLOW v1")
	lines.append("## @name: %s" % flow_name)
	lines.append("## @owner: %s" % owner)
	for st in steps:
		var sel_parts: PackedStringArray = PackedStringArray()
		for k in st["sel"]:
			sel_parts.append("%s=%s" % [k, str(st["sel"][k])])
		var l := "## F %s | sel:%s" % [st["op"], ",".join(sel_parts)]
		if str(st["ev"]) != "":
			l += " | ev:%s" % st["ev"]
		if int(st["every"]) > 0:
			l += " | every:%d" % int(st["every"])
		lines.append(l)
	return "\n".join(lines) + "\n"
