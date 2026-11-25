extends Node
func _ready() -> void:
	await get_tree().process_frame
	var txt := FileAccess.get_file_as_string("res://addons/thx_gamekit/data/danmaku_event_regular.csv")
	var evs := DanmakuEventData.parse_csv_text(txt)
	print("[dbg] csv_len=", txt.length(), " CRLF=", txt.contains("\r\n"), " parsed=", evs.size())
	if evs.size() > 0:
		var e0: DanmakuEventData = evs[0]
		var cerrs: Array = e0.compile()
		print("[dbg] first=", e0.event_name, " compile_errs=", cerrs.size())
	get_tree().quit(0)
