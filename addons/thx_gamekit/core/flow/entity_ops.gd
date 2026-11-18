class_name EntityOps
extends RefCounted
## =============================================================
## 【m93 角色定位器（scheme 角色选择器规范化——作者 20261118）】
## 特殊选择器=单词直挂（closet/nearest=最近者、farthest=最远者、
## self=施法者、random=随机）；enemies=敌侧全部（消望插件特殊 enemies
## 同表——新定位器先注册此处，流程/节点图共用）。
## 参数选择器=iterate(命题)：iterate(hp>>5)=所有 hp>5 的角色
## （命题上下文=角色参数：x/y/d/hp/allhp/hpper/directc/ap/pp…）。
## 返回：实体数组（调用方再按需取样——单数取首/复数全用）。
## =============================================================

## 角色参数快照（命题上下文——与 scheme 角色参数对齐）
static func ent_ctx(e, caster) -> Dictionary:
	var d: float = e.position.distance_to(caster.position) if caster != null else 0.0
	var hpv: float = float(e.hp[0]) if "hp" in e and e.hp.size() > 0 else 0.0
	## allhp=三部位血量和（EntityCore 无独立 max 访问器——scheme allhp=当前
	## 全血量口径；hpper 分母同源=1.0 兜底）
	var allv: float = 0.0
	if "hp" in e:
		for part in e.hp:
			allv += float(part)
	return {"x": e.position.x, "y": e.position.y, "d": d,
		"hp": hpv, "allhp": allv,
		"hpper": (hpv / allv) if allv > 0.0 else 0.0,
		"ap": float(e.ap), "pp": float(e.pp),
		"self_x": e.position.x, "self_y": e.position.y}

## 定位器解析（spec=定位器字符串；caster=施法者；arena=战场/提供 entities
## 与 bullet_nearest_enemy_from 的对象）
static func resolve(spec: String, caster, arena) -> Array:
	var s := spec.strip_edges()
	if s == "":
		return []
	var out: Array = []
	## —— 特殊选择器（单词直挂）——
	match s.to_lower():
		"self":
			return [caster] if caster != null else []
		"closet", "closest", "nearest":
			if arena != null and caster != null and arena.has_method("bullet_nearest_enemy_from"):
				var t = arena.bullet_nearest_enemy_from(1 - caster.side, caster.position)
				return [t] if t != null else []
			return []
		"farthest":
			if arena != null and caster != null:
				var best = null
				var bd := -1.0
				for e in _side_ents(arena, 1 - caster.side):
					var d: float = e.position.distance_squared_to(caster.position)
					if d > bd:
						bd = d
						best = e
				return [best] if best != null else []
			return []
		"random":
			var pool := _side_ents(arena, 1 - caster.side)
			return [pool[randi() % pool.size()]] if pool.size() > 0 else []
		"enemy":
			if arena != null and caster != null and arena.has_method("bullet_nearest_enemy_from"):
				var t2 = arena.bullet_nearest_enemy_from(1 - caster.side, caster.position)
				return [t2] if t2 != null else []
			return []
		"enemies":
			return _side_ents(arena, 1 - caster.side)
		_:
			pass
	## —— 参数选择器 iterate(命题) ——
	if s.begins_with("iterate(") and s.ends_with(")"):
		var prop: String = s.substr(8, s.length() - 9).strip_edges()
		var ex := DanmakuExpr.new()
		if not ex.compile(prop, PackedStringArray(["x", "y", "d", "hp", "allhp", "hpper", "ap", "pp"])):
			return []
		for e3 in _side_ents(arena, 1 - caster.side):
			var ctx := ent_ctx(e3, caster)
			if ex.execute_dict(ctx, 0.0) > 0.5:
				out.append(e3)
		return out
	return []

## 敌侧全部存活角色（含消望插件特殊 enemies——PRIVATE 不含，角色操作
## 语义=角色级；弹幕级另用弹幕选择器）
## 【宿主类解耦】实体类型=宿主 BattleEntity（内核不可见）——Kind 枚举鸭子判定
static func _side_ents(arena, side: int) -> Array:
	var out: Array = []
	if arena == null or not ("entities" in arena):
		return out
	for e in arena.entities:
		if e == null or not is_instance_valid(e) or e.get("dead"):
			continue
		if int(e.get("side")) != side:
			continue
		## Kind.PRIVATE（=2，EntityCore 枚举序 PLAYER/MEMBER/PRIVATE/ENEMY）不参与角色操作
		if int(e.get("kind")) == 2:
			continue
		out.append(e)
	return out
