extends Node
## =============================================================
## GameGlobals —— 编辑器兼容层（0.0.9·内核化 20261111）
## 【定位】保"弹幕编辑器代码零改动"的宿主接口：数据级委托给 THXKit
## （事件池/时间轴/官方表同步），本层只持有编辑器自己的工作状态
## （editor_textures/preview_event_name/arena_mode）与场景路由。
## 【命名保留原因】编辑器 2100 行按 GameGlobals.* 书写——改名=大规模
## 无意义 diff；内核化以"宿主接口"名义保留此名（README 已注记）。
## =============================================================

const OFFICIAL_EVENT_CSV := "res://addons/thx_gamekit/data/danmaku_event.csv"
const OFFICIAL_EVENT_CSVS: Dictionary = {
	DanmakuEventData.TAG_REGULAR: "res://addons/thx_gamekit/data/danmaku_event_regular.csv",
	DanmakuEventData.TAG_PHYSICAL: "res://addons/thx_gamekit/data/danmaku_event_physical.csv",
	DanmakuEventData.TAG_FUNCTED: "res://addons/thx_gamekit/data/danmaku_event_functed.csv",
	DanmakuEventData.TAG_LASER: "res://addons/thx_gamekit/data/danmaku_event_laser.csv",
	DanmakuEventData.TAG_NODES: "res://addons/thx_gamekit/data/danmaku_event_nodes.csv",
}

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

func sync_official_events(events: Array, exclude_names: PackedStringArray = PackedStringArray()) -> void:
	THXKit.sync_official_events(events, exclude_names)

func save_timeline_gd(tl: TimelineData) -> void:
	THXKit.save_timeline_gd(tl)

func reload_official() -> void:
	THXKit.reload_official()

func goto_scene(res_path: String) -> void:
	get_tree().change_scene_to_file(res_path)
