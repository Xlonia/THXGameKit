class_name BulletOps
extends RefCounted
## =============================================================
## 【0.0.9·角色流程弹幕操作（scheme 新二 975-997 行，20261116 作者消歧义：
## 角色层流程批量作用于弹幕——非逐弹钩子）】内核侧纯函数操作集：
##   select  弹幕选择器（区域沿筛：xi/yi/di/t_copy 相对角色；平方距预筛）
##   reflex  反射（捕获当前运动学→冻结为反向——**留在 frozen 类=C++ MotionHot
##           兼容**，不破混合双遍式禁令；表达式弹=沿当前速度直线反射）
##   inverse 实体替换（载荷交换：tex/判定/伤害换新 ev；轨迹保持旧表——
##           "弹幕实体替换为特定弹幕实体"，命中时 hit_damage 读 ev 自动生效）
## 【安全边界】只写池化重置清单内既有字段（frozen_ok 已在清单 m1105d）——
##   零新增池毒面；宿主侧数组由调用方传入（内核不持有弹幕数组）
## =============================================================

## 弹幕选择器（相对锚点=角色位置；side 过滤 + 区域沿筛 + 数量上限）
## sel: {shape:"circle"|"band_x"|"band_y", r/x0/x1/y0/y1, t_max, side, max_n}
##   circle=di≤r｜band_x=xi∈[x0,x1]｜band_y=yi∈[y0,y1]｜t_max=t_copy 上限
## 【性能纪律】平方距比较免 sqrt；命中即收（上升沿语义=进入区域即被选中）
static func select(bullets: Array, anchor: Vector2, sel: Dictionary) -> Array:
	var out: Array = []
	var max_n: int = int(sel.get("max_n", 64))
	var side_f: int = int(sel.get("side", -2)) ## -2=不过滤
	var t_max: float = float(sel.get("t_max", 0.0))
	var shape: String = str(sel.get("shape", "circle"))
	var r2: float = float(sel.get("r", 120.0))
	r2 *= r2
	for b in bullets:
		if out.size() >= max_n:
			break
		var bl: Bullet = b
		if not bl.alive or bl.hidden_now:
			continue
		if side_f != -2 and bl.source_side != side_f:
			continue
		var dx: float = bl.pos.x - anchor.x
		var dy: float = bl.pos.y - anchor.y
		match shape:
			"circle":
				if dx * dx + dy * dy > r2:
					continue
			"band_x":
				if dx < float(sel.get("x0", -100.0)) or dx > float(sel.get("x1", 100.0)):
					continue
			"band_y":
				if dy < float(sel.get("y0", -100.0)) or dy > float(sel.get("y1", 100.0)):
					continue
			_:
				continue
		if t_max > 0.0 and bl.t > t_max: ## t_copy=表达式别名；成员=t（本副本存续）
			continue
		out.append(bl)
	return out

## 反射：frozen_speed=当前速度，frozen_dir=当前方向取反，frozen_ok=true
## （查表/表达式弹沿捕获瞬间速度直线反射；frozen 类=C++ 批量运动学兼容）
static func reflex(list: Array) -> int:
	var n := 0
	for b in list:
		var bl: Bullet = b
		if not bl.alive:
			continue
		var sp: float = bl.cur_speed()
		var d: Vector2 = bl.cur_dir()
		if sp <= 0.0 or d.length_squared() < 0.0001:
			continue
		bl.frozen_speed = sp
		bl.frozen_dir = -d.normalized()
		bl.frozen_ok = true
		bl._w_frozen_dir = Vector2.ZERO ## 旧静态冻结方向清（防逐帧回写旧向）
		n += 1
	return n

## 伤害继承（scheme inheritdamage）：选中弹覆盖为指定事件的出生伤害
## （hit_damage 优先读 damage_override；池化重置已入清单）
static func inherit_damage(list: Array, ref_ev: DanmakuEventData) -> int:
	if ref_ev == null:
		return 0
	var dmg := int(ref_ev.eval_spawn_params({}).get("dmg", 0))
	var n := 0
	for b in list:
		var bl: Bullet = b
		if not bl.alive:
			continue
		bl.damage_override = dmg
		n += 1
	return n

## 实体替换：ev 换新（表现/判定/伤害随之）——轨迹保持（表已烘焙为旧路）
static func inverse(list: Array, new_ev: DanmakuEventData) -> int:
	if new_ev == null:
		return 0
	var n := 0
	for b in list:
		var bl: Bullet = b
		if not bl.alive:
			continue
		bl.ev = new_ev
		bl.tex = DanmakuTex.resolve(new_ev.texture)
		bl.tex_half = DanmakuTex.half_size(bl.tex)
		bl.draw_radius = bl.tex_half * new_ev.danmaku_size_muti
		bl.spin_offset = Vector2(new_ev.eval_num_global("spin_x", 0.0), new_ev.eval_num_global("spin_y", 0.0))
		bl.base_hue_now = new_ev.base_hue()
		bl.hue_val = fposmod(bl.base_hue_now + new_ev.hue / 256.0, 1.0)
		bl.sat_val = maxf(0.0, new_ev.saturation)
		bl.alpha_now = new_ev.alpha_const if new_ev.alpha_is_const else bl.alpha_now
		bl._special_hitbox_load() ## 判定盒随新 ev 重载（HITBOX_SAME/命名图）
		n += 1
	return n
