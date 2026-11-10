extends Node
## kit_smoke —— THXGameKit 数据基底冒烟（headless 可跑）
##   ①晚汐角色行读取（chara_db 路径重定向生效）
##   ②官方事件装载（demo_youshio1 编译+入库）
##   ③槽位解析（get_slot_events main=Youshio2 缺失→空；sub=demo_youshio1→1）
##   ④.thx 往返（事件打包→mod 加载覆盖）
func _ready() -> void:
	var fails := 0
	## ①
	var row := CharaDB.get_by_name("Youshio")
	var ok1: bool = not row.is_empty() and String(row.get("NameZH", "")) == "晚汐"
	print("  %s 角色行读取（NameZH=%s）" % ["PASS" if ok1 else "FAIL", row.get("NameZH", "?")])
	if not ok1: fails += 1
	## ②
	var ev := THXKit.get_event("demo_youshio1")
	var ok2: bool = ev != null and ev.event_name == "demo_youshio1"
	print("  %s 官方事件装载（demo_youshio1=%s）" % ["PASS" if ok2 else "FAIL", "有" if ev != null else "无"])
	if not ok2: fails += 1
	## ③
	var main_evs := THXKit.get_slot_events("Youshio", "main")
	var sub_evs := THXKit.get_slot_events("Youshio", "sub")
	print("  INFO main 解析=%d（Youshio2 官方表缺失=预期空） sub 解析=%d" % [main_evs.size(), sub_evs.size()])
	var ok3: bool = sub_evs.size() == 1 and sub_evs[0].event_name == "demo_youshio1"
	print("  %s sub 槽位解析" % ["PASS" if ok3 else "FAIL"])
	if not ok3: fails += 1
	## ④ .thx 往返：临时打包一条事件 → mod 加载
	var src_ev := THXKit.get_event("demo_youshio1")
	var zw := ZIPPacker.new()
	var tmp_path := "user://kit_smoke.thx"
	if zw.open(tmp_path) == OK:
		var csv_text: String = ",".join(DanmakuEventData.CSV_HEADER) + "\n" + src_ev.to_csv_row() + "\n"
		zw.start_file("danmaku_event.csv")
		zw.write_file(csv_text.to_utf8_buffer())
		zw.close_file()
		zw.close()
	var n_before: int = THXKit.mod_events.size()
	var names := THXKit.load_thx(tmp_path)
	var ok4: bool = names.has("demo_youshio1") and THXKit.mod_events.size() > n_before
	print("  %s .thx 往返（mod 覆盖层+%d）" % ["PASS" if ok4 else "FAIL", THXKit.mod_events.size() - n_before])
	if not ok4: fails += 1
	DirAccess.remove_absolute("user://kit_smoke.thx")
	print("KIT_OK" if fails == 0 else "KIT_FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
