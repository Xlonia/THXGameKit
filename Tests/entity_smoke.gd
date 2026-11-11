extends Node
## entity_smoke —— EntityCore 实体底座冒烟（headless 可跑）
##   ①setup 默认（PLAYER：ap50/hp 10·20·10，对峙朝向）
##   ②移动+双朝向拆分（facing 随移动；atk_facing 独立）
##   ③被弹契约（N/I/S 迁移后 20261112）：
##     · 底座=虚方法桩：不改任何状态、返回 false（结算权=自走棋插件）
##     · 插件视角镜像：子类覆盖 take_hit 最小 N/S 结算——验证底座状态字段
##       （ap setter 剥甲信号/stun 数组/免疫门）可被插件正常驱动
##   ④杂兵跟随 + 2px 场地钳制
func _ready() -> void:
	var fails := 0
	var e := EntityCore.new()
	e.setup(CharaDB.get_by_name("Youshio"), 0, EntityCore.Kind.PLAYER, true)
	add_child(e)
	var ok1: bool = e.ap == 50 and e.hp[0] == 10 and e.hp[1] == 20 and not e.dead
	print("  %s setup 默认（ap=%d hp=%s）" % ["PASS" if ok1 else "FAIL", e.ap, str(e.hp)])
	if not ok1: fails += 1
	## ②朝向拆分
	e.atk_facing = Vector2.UP
	e.move(Vector2.RIGHT, 1.0)
	var ok2: bool = e.facing == Vector2.RIGHT and e.frame_forward() == Vector2.UP
	print("  %s 朝向拆分（facing=RIGHT / atk_facing=UP）" % ["PASS" if ok2 else "FAIL"])
	if not ok2: fails += 1
	## ③a 底座桩契约：take_hit 不改状态、返回 false（N/I/S=插件内容）
	var ap0: int = e.ap
	var stub_hit: bool = e.take_hit(10, 0, 0.0)
	var ok3: bool = (not stub_hit) and e.ap == ap0 and e.stun_frames[0] == 0 and e.hp[0] == 10
	print("  %s 底座 take_hit=虚方法桩（返回%s ap=%d 不变）" % ["PASS" if ok3 else "FAIL", stub_hit, e.ap])
	if not ok3: fails += 1
	## ③b 插件视角镜像：子类覆盖 take_hit（BattleEntity 迁移语义的极简版）
	var pe := PluginHitEnt.new()
	pe.setup(CharaDB.get_by_name("Youshio"), 0, EntityCore.Kind.PLAYER, true)
	add_child(pe)
	var shatter_seen := [false]
	pe.barrier_shattered.connect(func(_x): shatter_seen[0] = true)
	var pn_ok: bool = pe.take_hit(10, 0, 0.0) and pe.ap == 40 ## N=掉 AP
	pe.immune_frames = 0 ## 每次被弹独立（免受上一次免疫帧门）
	var ps_ok: bool = pe.take_hit(2, 2, -PI / 2.0) and pe.stun_frames[0] >= 120 ## S=瘫痪×60
	pe.ap = 0 ## 剥甲（ap setter 检测→信号）
	var pb_ok: bool = pe.barrier_broken and shatter_seen[0]
	pe.immune_frames = 30
	var pi_ok: bool = not pe.take_hit(1, 0, 0.0) ## 免疫门（插件自实现）
	var ok4: bool = pn_ok and ps_ok and pb_ok and pi_ok
	print("  %s 插件覆盖契约（N掉AP=%s S瘫痪=%s 剥甲信号=%s 免疫门=%s）" % [
		"PASS" if ok4 else "FAIL", pn_ok, ps_ok, pb_ok, pi_ok])
	if not ok4: fails += 1
	## ④杂兵 2px 钳制
	var p := EntityCore.new()
	p.setup({"Name": "priv", "Normal": 2}, 0, EntityCore.Kind.PRIVATE)
	p.setup_private({}, 0, e, 1, false)
	p.local_pos = Vector2(-500.0, 0.0)
	p.sync_private_pos()
	var ok6: bool = p.position.x >= 2.0 and p.position.x <= 398.0
	print("  %s 杂兵 2px 场地钳制（pos=%s）" % ["PASS" if ok6 else "FAIL", str(p.position)])
	if not ok6: fails += 1
	print("ENT_OK" if fails == 0 else "ENT_FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)

## 【插件视角镜像】最小 N/S 结算（BattleEntity.take_hit 迁移语义）——
## 非内核部件，仅验证底座状态字段（ap/stun/immune）可被插件子类驱动
class PluginHitEnt:
	extends EntityCore
	func take_hit(dmg: int, dmg_type: int, _hit_angle: float) -> bool:
		if dead or immune_frames > 0:
			return false
		if dmg_type == 2: ## S=碎甲：瘫痪秒×60 帧
			stun_frames[0] += dmg * 60
		else: ## N/I 极简化：掉 AP
			ap -= dmg
		immune_frames = 30
		return true
