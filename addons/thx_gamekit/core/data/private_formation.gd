class_name PrivateFormation
extends RefCounted
## =============================================================
## 杂兵排布——**内核作者编辑面**（0.0.9·内核化 20261111）：
##   预设公式库 + 玩家覆盖层持久化 + 表达式变量表（弹幕编辑器排布页所需）。
## 【分层】运行时 stepping（step()/setup()，引用实体类型）属玩法插件——
##   内核只承载公式数据与覆盖层 IO（本文件即 th75 同名类的静态半部）。
## =============================================================

const PRESETS := {
	"扇形防护": {
		"termin_point_x": "(custom_a*privates_id-custom_a)*(-1)^privates_id+0.5*custom_a",
		"termin_point_y": "15+custom_b-3*custom_a*privates_id",
		"termin_range": "0.7*custom_a",
		"dict_zh": {"custom_a": "散布规模", "custom_b": "前后距离"},
	},
	"线列防护": {
		"termin_point_x": "(custom_a*privates_id-custom_a)*(-1)^privates_id+0.5*custom_a",
		"termin_point_y": "15+custom_b",
		"termin_range": "0.7*custom_a",
		"dict_zh": {"custom_a": "散布规模", "custom_b": "前后距离"},
	},
	"蝶翼防护": {
		"termin_point_x": "(privates_id-3)^0*custom_a*(-1)^privates_id",
		"termin_point_y": "(privates_id-3)^0*custom_a*(-1)^(privates_id-1)+custom_b*(abs(privates_id-3)-1)*(abs(privates_id-3)-2)",
		"termin_range": "0.7*custom_a",
		"dict_zh": {"custom_a": "散布规模"},
	},
	"潮汐防护": {
		"termin_point_x": "sin(getField(t)*0.1*custom_b)*custom_a",
		"termin_point_y": "cos(getField(t)*0.1*custom_b)*custom_a",
		"termin_range": "0.7*custom_a",
		"tpp": "10*tau",
		"dict_zh": {"custom_a": "散布规模", "custom_b": "环绕速度"},
	},
}

## 表达式变量表（排布域）：privates_id/custom_*/t/field_t + getField(t) 别名
const FORMATION_VARS: PackedStringArray = [
	"privates_id", "custom_a", "custom_b", "custom_c",
	"t", "field_t", "getField_t",
]

const OVERRIDE_PATH := "user://formation_override.cfg"

## 【批复 20261024】玩家可改公式（编辑器排布页）——覆盖层持久化
static func load_override() -> Dictionary:
	var f := FileAccess.open(OVERRIDE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d: Variant = f.get_var()
	f.close()
	return d if d is Dictionary else {}

static func save_override(d: Dictionary) -> void:
	var f := FileAccess.open(OVERRIDE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_var(d)
	f.close()
