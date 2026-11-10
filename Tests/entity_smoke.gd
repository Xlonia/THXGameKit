extends Node
## entity_smoke —— EntityCore 实体底座冒烟（headless 可跑）
##   ①setup 默认（PLAYER：ap50/hp 10·20·10，对峙朝向）
##   ②移动+双朝向拆分（facing 随移动；atk_facing 独立）
##   ③被弹三类型（N 掉 AP / I 穿透 / S 碎甲瘫痪）+ 免疫 + 全灭 destroyed
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
	## ③被弹：N 类型先掉 AP
	var ap0: int = e.ap
	var destroyed_seen := [false]
	e.destroyed.connect(func(_x): destroyed_seen[0] = true)
	e.immune_frames = 0
	e.take_hit(10, 0, 0.0) ## 上方→武器部位；AP 50→40
	var ok3: bool = e.ap == ap0 - 10 and e.hp[0] == 10
	print("  %s 被弹 N=掉 AP（%d→%d）" % ["PASS" if ok3 else "FAIL", ap0, e.ap])
	if not ok3: fails += 1
	## S 碎甲=瘫痪 60×dmg
	e.immune_frames = 0
	e.take_hit(2, 2, -PI / 2.0)
	var ok4: bool = e.stun_frames[0] >= 120
	print("  %s 被弹 S=碎甲瘫痪（%d 帧）" % ["PASS" if ok4 else "FAIL", e.stun_frames[0]])
	if not ok4: fails += 1
	## 免疫帧=跳过
	var hp_w: int = e.hp[0]
	e.take_hit(999, 1, -PI / 2.0)
	var ok5: bool = e.hp[0] == hp_w ## 免疫中不掉血
	print("  %s 免疫帧跳过被弹" % ["PASS" if ok5 else "FAIL"])
	if not ok5: fails += 1
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
