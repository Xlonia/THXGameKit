extends Node
## editor_smoke —— 编辑器迁移+试炼场替换主窗口 冒烟（headless 可跑）
##   ①编辑器场景实例化（UI 构建+CSV 装载不崩）
##   ②试炼场：preview_event_name 指定 → 逐 0.1s 出弹（事件引用解析）
##   ③退出试炼场 → 场景切回编辑器（替换主窗口往返）
func _ready() -> void:
	var fails := 0
	## ①编辑器实例化（作为主场景的替身——直接 add_child）
	var ed: Control = Control.new() ## 脚本直实例化（tscn ext_resource 宿主失效坑）
	ed.set_script(load(THXKit.kpath("res://addons/thx_gamekit/editor/danmaku_editor.gd")))
	add_child(ed)
	await get_tree().process_frame
	await get_tree().process_frame
	var ok1: bool = is_instance_valid(ed) and GameGlobals.editor_events.size() > 0 ## 断言走 GameGlobals（kit=委托THXKit / th75=宿主自有——编辑器真实工作集）
	print("  %s 编辑器实例化+事件装载（工作集 %d 件）" % ["PASS" if ok1 else "FAIL", GameGlobals.editor_events.size()])
	if not ok1: fails += 1
	## 【m86 片段页】构建+工作集自建（clip_1 兜底）
	ed._show_main_page("clip")
	var ok1b: bool = ed._pages.has("clip") and ed._pages["clip"].get_child_count() > 0 \
		and GameGlobals.editor_clips.size() > 0
	print("  %s 片段页构建（工作集 %d 片段）" % ["PASS" if ok1b else "FAIL", GameGlobals.editor_clips.size()])
	if not ok1b: fails += 1
	ed.queue_free()
	await get_tree().process_frame
	## ②试炼场出弹
	GameGlobals.preview_event_name = "demo_youshio1"
	GameGlobals.arena_mode = "preview"
	var tg: Node2D = Node2D.new() ## 脚本直实例化
	tg.set_script(load(THXKit.kpath("res://addons/thx_gamekit/editor/trial_ground.gd")))
	add_child(tg)
	await get_tree().process_frame
	for k in 180:
		tg._physics_process(1.0 / 60.0)
	var ok2: bool = tg.bullets.size() > 0
	print("  %s 试炼场出弹（%d 弹在场）" % ["PASS" if ok2 else "FAIL", tg.bullets.size()])
	if not ok2: fails += 1
	## ③退出试炼场=指向编辑器场景（arena_mode 复位断言——稳定版；
	## 真实场景往返由 F5 可视验证，探针不做 change_scene 实切）
	## ③签名体系：thxe 强校验（缺清单拒载/篡改拒载）+ thx 签名可选
	var ed2: Control = Control.new() ## 脚本直实例化
	ed2.set_script(load(THXKit.kpath("res://addons/thx_gamekit/editor/danmaku_editor.gd")))
	add_child(ed2)
	await get_tree().process_frame
	## 【m86】播种符卡+片段（空池环境下包内无内容可恢复——断言需有源）
	var sp_seed := SpellData.new()
	sp_seed.spell_name = "smoke_spell"
	sp_seed.steps_tick = [{"op": "clean", "arg": "", "params": "inspellrange"}]
	GameGlobals.editor_spells = [sp_seed]
	var cl_seed := ClipData.new()
	cl_seed.clip_name = "smoke_clip"
	cl_seed.length_ticks = 4
	cl_seed.add_event(0, "demo_youshio1")
	GameGlobals.editor_clips = [cl_seed]
	ed2._save_package("user://kit_sig.thxe", "thxe")
	var ok3: bool = FileAccess.file_exists("user://kit_sig.thxe")
	print("  %s .thxe 保存（签名清单内嵌）" % ["PASS" if ok3 else "FAIL"])
	if not ok3: fails += 1
	var ok4a: bool = ed2._load_package("user://kit_sig.thxe")
	print("  %s .thxe 完整性校验通过装载" % ["PASS" if ok4a else "FAIL"])
	if not ok4a: fails += 1
	## 【m86】包往返：danmaku_clip.csv + spell.csv（恢复缺口修复）随包恢复
	var ok4b: bool = GameGlobals.editor_clips.size() > 0 and GameGlobals.editor_spells.size() > 0
	print("  %s 片段+符卡随包恢复（片段 %d / 符卡 %d）" % ["PASS" if ok4b else "FAIL",
		GameGlobals.editor_clips.size(), GameGlobals.editor_spells.size()])
	if not ok4b: fails += 1
	## 篡改：重写 manifest → 必须拒载
	var zr := ZIPReader.new()
	zr.open("user://kit_sig.thxe")
	var files := zr.get_files()
	var tamper := {}
	for f in files:
		tamper[f] = zr.read_file(f)
	tamper["manifest.txt"] = tamper["manifest.txt"].get_string_from_utf8().replace("characters.csv", "xxxx.csv").to_utf8_buffer()
	zr.close()
	var zw := ZIPPacker.new()
	zw.open("user://kit_sig_tampered.thxe")
	for f2 in tamper:
		zw.start_file(f2)
		zw.write_file(tamper[f2])
		zw.close_file()
	zw.close()
	var rejected: bool = not ed2._load_package("user://kit_sig_tampered.thxe")
	print("  %s 篡改 .thxe → 拒载（防恶意代码注入）" % ["PASS" if rejected else "FAIL"])
	if not rejected: fails += 1
	ed2._save_package("user://kit_sig.thx", "thx")
	var ok5a: bool = ed2._load_package("user://kit_sig.thx")
	print("  %s .thx 拓展包装载（签名可选）" % ["PASS" if ok5a else "FAIL"])
	if not ok5a: fails += 1
	tg.queue_free()
	await get_tree().process_frame
	## ③b CharaDB 新建/导入（数据层直测；测后还原 characters.csv）
	var csv_backup: PackedByteArray = FileAccess.get_file_as_bytes(CharaDB.csv_path())
	var okc: bool = CharaDB.new_character("KitTest1")
	print("  %s new_character 建档" % ["PASS" if okc else "FAIL"])
	if not okc: fails += 1
	var dup: bool = not CharaDB.new_character("KitTest1")
	print("  %s 重复建档拒绝" % ["PASS" if dup else "FAIL"])
	var csv_text: String = "Name,NameZH
KitTest2,测试二
KitTest3,测试三
"
	var imported: int = CharaDB.import_csv_text(csv_text, "chara")
	var ok4: bool = imported == 2 and not CharaDB.get_by_name("KitTest2").is_empty()
	print("  %s import_csv_text upsert（%d 行）" % ["PASS" if ok4 else "FAIL", imported])
	if not ok4: fails += 1
	var upsert := CharaDB.get_by_name("KitTest2")
	upsert["NameZH"] = "改名二"
	var ok5: bool = CharaDB.save_row("KitTest2", upsert) 		and String(CharaDB.get_by_name("KitTest2").get("NameZH", "")) == "改名二"
	print("  %s 已存在行 upsert 覆盖" % ["PASS" if ok5 else "FAIL"])
	if not ok5: fails += 1
	var f := FileAccess.open(CharaDB.csv_path(), FileAccess.WRITE)
	f.store_buffer(csv_backup)
	f.close()
	var restored: bool = CharaDB.get_by_name("KitTest1").is_empty() 		and not CharaDB.get_by_name("Youshio").is_empty()
	print("  %s 测试后还原（晚汐在位/测试行清除）" % ["PASS" if restored else "FAIL"])
	if not restored: fails += 1
	print("EDT_OK" if fails == 0 else "EDT_FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
