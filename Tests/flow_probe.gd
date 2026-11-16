extends Node
## flow_probe —— 角色流程首批操作探针（m74 20261116）
## A 选择器（circle/band_x/t_max/side/数量上限）
## B reflex（frozen 类反向——C++ 兼容语义）
## C inverse（载荷交换：ev/tex/判定随新事件；轨迹保持）
## D CharFlowData parse/to_gd 往返
## 【跑法】godot --headless --path . res://Tests/flow_probe.tscn → FLOW_OK / FLOW_FAIL n

var _fails := 0
func _fail(m: String) -> void:
	_fails += 1
	print("FLOW_FAIL: ", m)

func _mk_bullet(ev: DanmakuEventData, at: Vector2, side: int) -> Bullet:
	var src := EntityCore.new()
	src.setup({"Name": "probe_src", "Cruise": 6, "Normal": 3, "Determine": 3}, side, EntityCore.Kind.MEMBER, true)
	var b := Bullet.new()
	ev.compile()
	b.setup(ev, at, side, src, self, 0)
	return b

func _ready() -> void:
	await get_tree().process_frame
	## 取两个不同官方事件
	var evs: Array = []
	for k in THXKit.official_events:
		evs.append(THXKit.official_events[k])
		if evs.size() >= 2:
			break
	if evs.size() < 2:
		_fail("官方事件不足 2 个（探针前提；official_events.size()=%d）" % THXKit.official_events.size())
		_finish()
		return
	var ev1: DanmakuEventData = evs[0]
	var ev2: DanmakuEventData = evs[1]
	if ev1.event_name == ev2.event_name:
		_fail("两个事件同名（选择前提失效）")
	## ——A 选择器——
	var anchor := Vector2(200, 200)
	var b1 := _mk_bullet(ev1, Vector2(220, 200), 1)
	var b2 := _mk_bullet(ev1, Vector2(350, 350), 1)
	var b3 := _mk_bullet(ev1, Vector2(180, 210), 1)
	var arr: Array = [b1, b2, b3]
	var picked: Array = BulletOps.select(arr, anchor, {"shape": "circle", "r": 80, "side": 1})
	if picked.size() != 2 or not picked.has(b1) or not picked.has(b3) or picked.has(b2):
		_fail("circle r80 应选 b1/b3（得 %d）" % picked.size())
	var bx: Array = BulletOps.select(arr, anchor, {"shape": "band_x", "x0": -100, "x1": 100, "side": 1})
	if bx.size() != 2:
		_fail("band_x ±100 应选 b1/b3（得 %d）" % bx.size())
	b1.t = 200.0
	var tm: Array = BulletOps.select(arr, anchor, {"shape": "circle", "r": 80, "side": 1, "t_max": 100})
	if tm.size() != 1 or not tm.has(b3):
		_fail("t_max=100 应只余 b3（得 %d）" % tm.size())
	var mx: Array = BulletOps.select(arr, anchor, {"shape": "circle", "r": 80, "side": 1, "max_n": 1})
	if mx.size() != 1:
		_fail("max_n=1 应只选 1（得 %d）" % mx.size())
	var sf: Array = BulletOps.select(arr, anchor, {"shape": "circle", "r": 80, "side": 0})
	if sf.size() != 0:
		_fail("side=0 过滤应全排除（得 %d）" % sf.size())
	## ——B reflex——
	## 表达式弹 velocity 恒零（运动走 w 路径）——手动赋予初速度模拟飞行态
	b3.velocity = Vector2(3, 0)
	b2.velocity = Vector2(-2, 2)
	var d0: Vector2 = b3.cur_dir()
	var sp0: float = b3.cur_speed()
	var nref: int = BulletOps.reflex([b3, b2])
	if nref != 2:
		_fail("reflex 应作用于 2（得 %d）" % nref)
	if not b3.frozen_ok:
		_fail("reflex 后未入 frozen 类")
	if b3.frozen_dir.distance_to(-d0.normalized()) > 0.01:
		_fail("frozen_dir 未取反")
	if absf(b3.frozen_speed - sp0) > 0.01:
		_fail("frozen_speed 未保速")
	if b1.frozen_ok:
		_fail("未选中的 b1 被误改（frozen_ok=true）")
	## ——C inverse——
	var tex_expect: Texture2D = DanmakuTex.resolve(ev2.texture)
	var ninv: int = BulletOps.inverse([b1], ev2)
	if ninv != 1:
		_fail("inverse 应作用于 1（得 %d）" % ninv)
	if b1.ev != ev2:
		_fail("ev 未替换")
	if b1.tex != tex_expect:
		_fail("tex 未随新事件重解析")
	if b1.pos != Vector2(220, 200):
		_fail("inverse 不应移动弹（轨迹保持语义）")
	## ——E inheritdamage——
	var dmg_expect: int = int(ev2.eval_spawn_params({}).get("dmg", 0))
	var ninh: int = BulletOps.inherit_damage([b1], ev2)
	if ninh != 1:
		_fail("inherit_damage 应作用于 1（得 %d）" % ninh)
	elif b1.damage_override != dmg_expect or b1.hit_damage() != dmg_expect:
		_fail("伤害覆盖未生效（override=%d 期望=%d）" % [b1.damage_override, dmg_expect])
	## ——D parse/to_gd 往返——
	var text := "## THX CHARFLOW v1\n## @name: probe_flow\n## @owner: *\n## F reflex | sel:shape=circle,r=120,t_max=60,max_n=64\n## F inverse | sel:shape=band_x,x0=-100,x1=100 | ev:demo_aimed | every:36\n"
	var flows: Array = CharFlowData.parse_gd(text)
	if flows.size() != 1:
		_fail("应解析 1 个流程（得 %d）" % flows.size())
	else:
		var f: CharFlowData = flows[0]
		if f.flow_name != "probe_flow" or f.steps.size() != 2:
			_fail("流程名/步数不符")
		elif String(f.steps[1]["ev"]) != "demo_aimed" or int(f.steps[1]["every"]) != 36:
			_fail("第二步 ev/every 解析不符")
		else:
			var re: Array = CharFlowData.parse_gd(f.to_gd())
			if re.size() != 1 or re[0].steps.size() != 2 or String(re[0].steps[0]["op"]) != "reflex":
				_fail("to_gd 往返失真")
	_finish()

func _finish() -> void:
	if _fails == 0:
		print("FLOW_OK（A 选择器 5 断言+B reflex+C inverse+D 往返）")
		get_tree().quit(0)
	else:
		print("FLOW_FAIL %d" % _fails)
		get_tree().quit(1)
