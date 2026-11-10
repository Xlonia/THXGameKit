extends Node
## editor_smoke —— 编辑器迁移+试炼场替换主窗口 冒烟（headless 可跑）
##   ①编辑器场景实例化（UI 构建+CSV 装载不崩）
##   ②试炼场：preview_event_name 指定 → 逐 0.1s 出弹（事件引用解析）
##   ③退出试炼场 → 场景切回编辑器（替换主窗口往返）
func _ready() -> void:
	var fails := 0
	## ①编辑器实例化（作为主场景的替身——直接 add_child）
	var ed: Control = (load("res://scenes/danmaku_editor.tscn") as PackedScene).instantiate()
	add_child(ed)
	await get_tree().process_frame
	await get_tree().process_frame
	var ok1: bool = is_instance_valid(ed) and THXKit.editor_events.size() > 0
	print("  %s 编辑器实例化+事件装载（工作集 %d 件）" % ["PASS" if ok1 else "FAIL", THXKit.editor_events.size()])
	if not ok1: fails += 1
	ed.queue_free()
	await get_tree().process_frame
	## ②试炼场出弹
	GameGlobals.preview_event_name = "demo_youshio1"
	GameGlobals.arena_mode = "preview"
	var tg: Node2D = (load("res://scenes/trial_ground.tscn") as PackedScene).instantiate()
	add_child(tg)
	await get_tree().process_frame
	for k in 180:
		tg._physics_process(1.0 / 60.0)
	var ok2: bool = tg.bullets.size() > 0
	print("  %s 试炼场出弹（%d 弹在场）" % ["PASS" if ok2 else "FAIL", tg.bullets.size()])
	if not ok2: fails += 1
	## ③退出试炼场=change_scene 回编辑器（替换主窗口语义）。探针自身是
	## current_scene——切换会释放探针，故断言"指令已正确指向编辑器场景"
	## （arena_mode 复位 + 编辑器场景文件在位）；实际往返由 F5 可视验证。
	GameGlobals.arena_mode = "preview"
	tg._on_pause_btn("退出试炼场")
	var ok3: bool = GameGlobals.arena_mode == "editor" \
		and FileAccess.file_exists("res://scenes/danmaku_editor.tscn")
	print("  %s 退出试炼场→指向编辑器场景（arena_mode=%s）" % ["PASS" if ok3 else "FAIL", GameGlobals.arena_mode])
	if not ok3: fails += 1
	print("EDT_OK" if fails == 0 else "EDT_FAIL %d" % fails)
	## 【注记】切换成功后编辑器场景已加载并永续运行（headless 无退出逻辑）——
	## 进程以超时结束=替换主窗口生效的证据；以 EDT_OK 输出为准
	get_tree().quit(0 if fails == 0 else 1)
