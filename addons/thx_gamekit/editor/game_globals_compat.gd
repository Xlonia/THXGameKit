extends Node
## =============================================================
## GameGlobals —— 编辑器兼容层（0.0.9·内核化 20261111）
## 【定位】保"弹幕编辑器代码零改动"的宿主接口：数据级委托给 THXKit
## （事件池/时间轴/官方表同步），本层只持有编辑器自己的工作状态
## （editor_textures/preview_event_name/arena_mode）与场景路由。
## 【命名保留原因】编辑器 2100 行按 GameGlobals.* 书写——改名=大规模
## 无意义 diff；内核化以"宿主接口"名义保留此名（README 已注记）。
## =============================================================

var OFFICIAL_EVENT_CSVS: Dictionary:
	get: return THXKit.official_csvs()

var editor_events: Array:
	get: return THXKit.editor_events
	set(v): THXKit.editor_events = v ## 编辑器 _set_events 工作集赋值（同一实例约定）
var editor_timelines: Array:
	get: return THXKit.editor_timelines
	set(v): THXKit.editor_timelines = v
var official_events: Dictionary:
	get: return THXKit.official_events
var mod_events: Dictionary:
	get: return THXKit.mod_events

## —— 编辑器工作状态（编辑器层自有）——
var editor_textures: Dictionary = {} ## 自定义导入材质（名→字节流/贴图）
var preview_event_name := ""         ## 试炼场预览的事件名
var arena_mode := "editor"           ## editor / preview

## 【0.0.9·③ 特殊判定盒（作者 20261111）】THX 系列恒 false；原作复刻插件可开
func _ready() -> void:
	pass ## 特殊判定盒默认 false（Bullet.special_hitbox_enabled 内核默认值——THX 系列无需显式关）

func sync_official_events(events: Array, exclude_names: PackedStringArray = PackedStringArray()) -> void:
	THXKit.sync_official_events(events, exclude_names)

func save_timeline_gd(tl: TimelineData) -> void:
	THXKit.save_timeline_gd(tl)

func reload_official() -> void:
	THXKit.reload_official()

func goto_scene(res_path: String) -> void:
	## 【手动切场景撤销 20261114（作者：换思路多找原因）】回 change_scene_to_file——
	## m54 手动版在作者机 nodes=1（新场景未挂载）vs 我探针挂载成功——差异待查
	print("[goto_scene] 切换到 %s 开始" % res_path)
	var t0 := Time.get_ticks_msec()
	get_tree().change_scene_to_file(res_path)
	print("[goto_scene] change_scene_to_file 返回 +%dms" % (Time.get_ticks_msec() - t0))
