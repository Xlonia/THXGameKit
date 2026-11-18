class_name FlowSignature
extends RefCounted
## =============================================================
## 【m94 流程=函数（作者 20261118：形参自动读取→输入框自动生成）】
## 每 op 声明形参表（名称/类型/默认/提示）——编辑器据此为流程步骤
## 自动生成对应输入框（原生 op 与开发者新增 op 同一机制=自动适配）；
## 存储格式不变（{op,arg,params}——arg=params 第 0 形参的历史承载，
## 读取时按形参表拆分）。
## 类型标注沿 C++/GDScript 类方法习惯：
##   entity=角色（选择器表达式）  danmaku_sel=弹幕选择器表达式
##   event=弹幕事件名            clip=片段名
##   int/float/string=标量
## =============================================================

## 形参声明：op -> [{name, type, hint, dflt}]
const SIGNATURES := {
	"svgresign": [
		{"name": "序号", "type": "int", "hint": "空=默认圆形", "dflt": "0"},
	],
	"clean": [
		{"name": "范围", "type": "string", "hint": "inspellrange=注册图形范围；留空=同左", "dflt": "inspellrange"},
	],
	"reflex": [
		{"name": "弹幕选择", "type": "danmaku_sel", "hint": "留空=全场敌对弹；sel:shape=circle,r=120=圆内", "dflt": ""},
	],
	"inverse": [
		{"name": "事件", "type": "event", "hint": "替换目标事件名", "dflt": ""},
		{"name": "弹幕选择", "type": "danmaku_sel", "hint": "留空=全场敌对弹", "dflt": ""},
	],
	"inversep": [
		{"name": "事件", "type": "event", "hint": "重生事件名", "dflt": ""},
		{"name": "弹幕选择", "type": "danmaku_sel", "hint": "留空=全场敌对弹", "dflt": ""},
	],
	"revolt": [
		{"name": "目标", "type": "entity", "hint": "角色定位器：closest()/enemies()/randomp(命题)/iterate(命题,类型)；留空=敌侧随机", "dflt": ""},
	],
	"inheritdamage": [
		{"name": "事件", "type": "event", "hint": "伤害来源事件名", "dflt": ""},
		{"name": "弹幕选择", "type": "danmaku_sel", "hint": "留空=全场敌对弹", "dflt": ""},
	],
	"playclips": [
		{"name": "片段", "type": "clip", "hint": "片段名", "dflt": ""},
	],
	"loopclips": [
		{"name": "片段", "type": "clip", "hint": "片段名（循环至符卡结束）", "dflt": ""},
	],
	"danmaku": [
		{"name": "事件", "type": "event", "hint": "释放的弹幕事件名", "dflt": ""},
		{"name": "目标", "type": "entity", "hint": "角色定位器；留空=敌侧随机", "dflt": ""},
	],
}

## 形参表读取（未知 op=单 string 形参兜底——开发者新 op 自动适配的保底形态）
static func params_of(op: String) -> Array:
	return SIGNATURES.get(op, [{"name": "参数", "type": "string", "hint": "", "dflt": ""}])

## {op,arg,params} → 形参值数组（按形参表拆分：第 0 形参=arg 承载，其余=params 逗号段）
static func split_args(st: Dictionary) -> Array:
	var sig: Array = params_of(String(st.get("op", "")))
	var arg: String = String(st.get("arg", ""))
	var rest: String = String(st.get("params", ""))
	var out: Array = []
	for i in sig.size():
		if i == 0:
			out.append(arg)
		else:
			## 逗号拆段（引号内逗号不拆——命题可能含引号字符串）
			var segs := _split_quote(rest)
			out.append(segs[i - 1] if i - 1 < segs.size() else "")
	return out

## 形参值数组 → {op,arg,params}（写回）
static func join_args(op: String, vals: Array) -> Dictionary:
	var sig: Array = params_of(op)
	var arg: String = String(vals[0]) if vals.size() > 0 else ""
	var rest_segs: PackedStringArray = PackedStringArray()
	for i in range(1, sig.size()):
		rest_segs.append(String(vals[i]) if i < vals.size() else "")
	return {"op": op, "arg": arg, "params": ",".join(rest_segs)}

## 引号感知逗号拆分（RFC4180 简法）
static func _split_quote(s: String) -> Array:
	var out: Array = []
	var cur := ""
	var in_q := false
	for ch in s:
		if ch == "\"":
			in_q = not in_q
			cur += ch
		elif ch == "," and not in_q:
			out.append(cur)
			cur = ""
		else:
			cur += ch
	out.append(cur)
	return out
