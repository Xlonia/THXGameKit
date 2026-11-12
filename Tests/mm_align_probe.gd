extends Node
## mm_align_probe —— 弹幕贴图错位侦查（headless 可跑）：渲染数学层断言
##   ①零偏心：draw_transform.origin==pos（MM 中心=弹心）
##   ②偏心 (3.5,2.0)：origin==pos-旋转后偏移
func _ready() -> void:
	var fails := 0
	var ev := DanmakuEventData.new()
	ev.event_name = "probe_align"
	ev.texture = ""
	ev.compile()
	var b := RefCounted.new()
	b.set_script(load(THXKit.kpath("res://addons/thx_gamekit/core/danmaku/bullet_runtime.gd")))
	b.setup(ev, Vector2(200, 200), 0, null, self, 0)
	var ok1: bool = b.draw_transform().origin == Vector2(200, 200)
	print("  %s 零偏心 MM 中心=弹心（origin=%s）" % ["PASS" if ok1 else "FAIL", str(b.draw_transform().origin)])
	if not ok1: fails += 1
	## ②偏心：程序化赋值 spin（eval_num_global 读值成员）→重 setup
	var ev2 := DanmakuEventData.new()
	ev2.event_name = "probe_align2"
	ev2.texture = ""
	ev2.spin_x = 3.5
	ev2.spin_y = 2.0
	ev2.compile()
	b.setup(ev2, Vector2(200, 200), 0, null, self, 0)
	var expect: Vector2 = Vector2(200, 200) - Vector2(3.5, 2.0).rotated(b.draw_rotation())
	var ok2: bool = b.draw_transform().origin.distance_to(expect) < 0.001
	print("  %s 偏心中心=弹心-旋转后偏移（origin=%s expect=%s）" % ["PASS" if ok2 else "FAIL", str(b.draw_transform().origin), str(expect)])
	if not ok2: fails += 1
	print("MM_OK" if fails == 0 else "MM_FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
