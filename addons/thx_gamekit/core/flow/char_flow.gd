class_name CharFlowData
extends RefCounted
## =============================================================
## 【0.0.9·角色流程数据（scheme 新二 975 行）】角色流程可编程，收录在
## 本体侧 morerule.gd / 部署侧 progess.gd；非部署时在 tab 页面供修补。
## 【文件格式（morerule.gd / progess.gd，纯文本）】
##   ## THX CHARFLOW v1
##   ## @name: <流程名>
##   ## @owner: <角色名或*>
##   ## @trigger: <触发器名>[ | dist:<数字> | cond:<命题> | sel:<弹幕选择器> ]
##   ## F <op> | sel:<shape>,<参数对>… | ev:<事件名> | every:<tick数>
##     op=reflex/inverse（0.0.9 首批；inversep/inheritdamage/revolt 随后）
##     sel 参数对：r=120 / x0=-100,x1=100 / y0=…,y1=… / t_max=120 / max_n=64
##     side 由运行时按施放者敌对侧自动填（文档 sel 不含 side）
##     every=0 一次性；>0 = 每 N tick（0.1s/tick）重复执行该步
## 【m125 角色触发器（scheme 角色触发器节——作者 20261125 六答消歧义）】
##   trigger 词表：movetick/statictick/slowtick/fasttick（状态四宫格 tick——
##   正交双维度：移动性×慢快，同跑不互斥；慢机移动=slowtick+movetick 同跑）
##   /movestart/staticstart/slowstart/faststart（状态进入沿）/danmaku（发射时
##   ——[弹幕事件]=返回触发时释放的弹幕）/deathrattle(弹幕选择器)（死亡后
##   ——实体不参与渲染/跟踪/锁定/被弹，弹幕还在）/dmapproach(距离,弹幕选择器)
##   （每弹每次从外侧进入距离=一次上升沿——含友方物弹）/dmif(条件,弹幕选择器)
##   （被弹时满足角色条件——条件=命题，可引用 hp/damage 等）/smif(条件,弹幕
##   选择器)（每事件帧条件真即执行——**持续为真每帧执行**，与 threshold
##   setter 不同——作者答 4）。
## =============================================================

var flow_name := "untitled_flow"
var owner := "*" ## 角色名或 *（任意）
var trigger := "" ## 触发器名（空=无触发器=手动/符卡流程——0.0.9 原形态）
var t_dist := 0.0 ## dmapproach 距离数字
var t_cond := "" ## dmif/smif 条件命题
var t_sel := "" ## deathrattle/dmapproach/dmif/smif 的弹幕选择器参数
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
		elif cur != null and line.begins_with("## @trigger:"):
			## 【m125 角色触发器】trigger:名[ | dist:N | cond:命题 | sel:弹幕选择器]
			for seg in line.trim_prefix("## @trigger:").split("|"):
				var sg := seg.strip_edges()
				if sg.begins_with("dist:"):
					cur.t_dist = sg.trim_prefix("dist:").strip_edges().to_float()
				elif sg.begins_with("cond:"):
					cur.t_cond = sg.trim_prefix("cond:").strip_edges()
				elif sg.begins_with("sel:"):
					cur.t_sel = sg.trim_prefix("sel:").strip_edges()
				elif sg != "":
					cur.trigger = sg
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
	if trigger != "":
		## 【m125 角色触发器】参数段写回
		var tp := "## @trigger: " + trigger
		if t_dist > 0.0:
			tp += " | dist:%s" % str(t_dist)
		if t_cond != "":
			tp += " | cond:" + t_cond
		if t_sel != "":
			tp += " | sel:" + t_sel
		lines.append(tp)
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
