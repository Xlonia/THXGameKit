class_name EntityOps
extends RefCounted
## =============================================================
## 【m94 角色定位器 v2（作者 20261118 三决定）】
## ①选择器=函数调用式（C++/GDScript 类方法标点）：closest()/farthest()/
##   upst()/downst()/boss()/player()/self()/random()/enemies() 单词类=括号
##   直挂；iterate(命题)=特定实体类型满足命题的全部个体；
##   randomp(命题)=随机个体；geniterate(命题,类型)=跨类型通用查询
##   （scheme 通用选择器调用节——iterate 系=任何类通用容器查询语义，
##   对应 GDScript Array.filter/randomize 取样；C++ 无内建，此为内核实现）。
## ②角色定义变革（作者 20261118）：**角色=队伍成员 5 角色+各自杂兵**；
##   仅限自机与主要参与弹幕释放/剧情的叫**队伍成员**。
##   → enemies()/iterate 系默认含杂兵（PRIVATE=Kind.PRIVATE 也参与）。
## ③命题上下文变量：x/y/d/hp/allhp/hpper/ap/pp（directc 待办）
## =============================================================

## 角色参数快照（命题上下文）
static func ent_ctx(e, caster) -> Dictionary:
	var d: float = e.position.distance_to(caster.position) if caster != null else 0.0
	var hpv: float = float(e.hp[0]) if "hp" in e and e.hp.size() > 0 else 0.0
	var allv: float = 0.0
	if "hp" in e:
		for part in e.hp:
			allv += float(part)
	return {"x": e.position.x, "y": e.position.y, "d": d,
		"hp": hpv, "allhp": allv,
		"hpper": (hpv / allv) if allv > 0.0 else 0.0,
		"ap": float(e.ap), "pp": float(e.pp),
		"self_x": e.position.x, "self_y": e.position.y}

## 定位器解析（spec=定位器表达式；caster=施法者；arena=战场）
## 返回实体数组（调用方取样：单数取首/复数全用）
static func resolve(spec: String, caster, arena) -> Array:
	var s := spec.strip_edges()
	if s == "":
		return []
	## —— 括号函数式（先于单词判定；空括号=单词类放行——m120 修：player()
	## 等空括号单词选择器曾误入带参分支落 _:=[] 全断）——
	var lp := s.find("(")
	if lp >= 0 and s.ends_with(")") and s.substr(lp + 1, s.length() - lp - 2).strip_edges() != "":
		var fname: String = s.substr(0, lp).strip_edges().to_lower()
		var inner: String = s.substr(lp + 1, s.length() - lp - 2).strip_edges()
		match fname:
			"iterate":
				## 【m95 语义修正（作者 20261118：iterate=仅限已确定特定返回类型
				## 的环境做相应实体类型返回——不能泛型；带类型=geniterate）】
				## 符卡流程上下文=敌侧（角色=成员+杂兵）
				return _filter_prop(_enemy_ents(arena, caster), inner, caster)
			"randomp":
				var pool := _filter_prop(_all_ents(arena, caster), inner, caster)
				return [pool[randi() % pool.size()]] if pool.size() > 0 else []
			"geniterate":
				## geniterate(命题,实体类型)——类型=player/member/private/enemy
				## （全部种类中筛满足命题者，再按类型取样）
				var argsegs := _split_top(inner)
				if argsegs.size() < 2:
					return []
				var pool2 := _filter_prop(_all_ents(arena, caster), argsegs[0].strip_edges(), caster)
				var tname: String = argsegs[1].strip_edges().to_lower()
				var out2: Array = []
				for e2 in pool2:
					if _kind_name(e2) == tname:
						out2.append(e2)
				return out2
			"getallenemy":
				## scheme 章节选择器：遍历章节所有敌机（复数——含杂兵，角色=成员+杂兵）
				return _enemy_ents(arena, caster)
			"getenemy":
				## scheme 章节选择器：获取章节特定敌机（条件式——同 iterate 语义）
				return _filter_prop(_enemy_ents(arena, caster), inner, caster)
			_:
				return []
	## —— 单词/单词() 类（可带空括号）——
	var word: String = s.to_lower().trim_suffix("()").strip_edges()
	match word:
		"self":
			return [caster] if caster != null else []
		"player":
			## 【m120 修】自机=side==0 首个存活实体（原查不存在的 is_player 属性
			## 恒空→选择器无目标）；直扫实体池不受"选取其他"排除影响——
			## 玩家自机=显式绝对选择器（damage(player()) 作用于自身合法）
			if arena == null or not ("entities" in arena):
				return []
			for e4 in arena.entities:
				if e4 == null or not is_instance_valid(e4) or e4.get("dead"):
					continue
				if int(e4.get("side")) == 0:
					return [e4]
			return []
		"closest", "closet", "nearest":
			var t = _nearest(arena, caster, _all_ents(arena, caster), true)
			return [t] if t != null else []
		"farthest":
			var t3 = _nearest(arena, caster, _all_ents(arena, caster), false)
			return [t3] if t3 != null else []
		"upst":
			var t4 = _extreme(arena, caster, true)
			return [t4] if t4 != null else []
		"downst":
			var t5 = _extreme(arena, caster, false)
			return [t5] if t5 != null else []
		"boss":
			## 【m95 boss()=Enemy.csv is_boss 列（作者裁定：boss 属 enemy 类）】
			for e5 in _all_ents(arena, caster):
				if int(e5.get("db", {}).get("is_boss", 0) if "db" in e5 else 0) == 1:
					return [e5]
			return []
		"random":
			var pool3 := _all_ents(arena, caster)
			pool3.shuffle()
			return [pool3[0]] if pool3.size() > 0 else []
		"enemy":
			var t6 = _nearest(arena, caster, _enemy_ents(arena, caster), true)
			return [t6] if t6 != null else []
		"enemies":
			return _enemy_ents(arena, caster) ## 【m94 角色定义】含杂兵（角色=成员+杂兵）
		"getallenemy":
			return _enemy_ents(arena, caster) ## scheme 章节选择器（单词/空括号形）
		"getenemy":
			return _enemy_ents(arena, caster) ## 无条件形=全部章节敌机（条件形走带参分支）
	return []

## —— 内部：实体池（角色=成员+杂兵；不含已死）——
static func _all_ents(arena, caster) -> Array:
	var out: Array = []
	if arena == null or not ("entities" in arena):
		return out
	for e in arena.entities:
		if e == null or not is_instance_valid(e) or e.get("dead"):
			continue
		if caster != null and e == caster:
			continue ## 定位器语义=选取"其他"角色（self() 显式取己）
		out.append(e)
	return out

static func _enemy_ents(arena, caster) -> Array:
	var out: Array = []
	if caster == null:
		return out
	for e in _all_ents(arena, caster):
		if int(e.get("side")) != int(caster.get("side")):
			out.append(e)
	return out

static func _nearest(arena, caster, pool: Array, closest: bool):
	if caster == null or pool.is_empty():
		return null
	var best = null
	var bd := -1.0
	for e in pool:
		var d: float = e.position.distance_squared_to(caster.position)
		if best == null or (closest and d < bd) or (not closest and d > bd):
			bd = d
			best = e
	return best

static func _extreme(arena, caster, top: bool):
	var best = null
	var bv := INF
	for e in _all_ents(arena, caster):
		var y: float = float(e.get("position").y)
		if top and y < bv:
			bv = y
			best = e
		elif not top and y > bv:
			bv = y
			best = e
	return best

## 命题过滤（DanmakuExpr 同一引擎——iterate 系通用容器查询）
static func _filter_prop(pool: Array, prop: String, caster) -> Array:
	## 【m95】作者伪脚本约定：>>=大于、<<=小于（文档管线转义习惯——GDScript
	## Expression 中它们是移位符，定位器命题里恒为比较语义）
	var p := prop.strip_edges().replace(">>", ">").replace("<<", "<")
	if p == "":
		return pool
	var ex := DanmakuExpr.new()
	if not ex.compile(p, PackedStringArray(["x", "y", "d", "hp", "allhp", "hpper", "ap", "pp"])):
		return []
	var out: Array = []
	for e6 in pool:
		if ex.execute_dict(ent_ctx(e6, caster), 0.0) > 0.5:
			out.append(e6)
	return out

static func _kind_name(e) -> String:
	match int(e.get("kind")):
		0:
			return "player"
		1:
			return "member"
		2:
			return "private"
		3:
			return "enemy"
	return ""

## 括号深度感知逗号拆分（嵌套 iterate(…,…) 用）
static func _split_top(s: String) -> Array:
	var out: Array = []
	var cur := ""
	var depth := 0
	var in_q := false
	for ch in s:
		if ch == "\"":
			in_q = not in_q
			cur += ch
		elif in_q:
			cur += ch
		elif ch == "(":
			depth += 1
			cur += ch
		elif ch == ")":
			depth -= 1
			cur += ch
		elif ch == "," and depth == 0:
			out.append(cur)
			cur = ""
		else:
			cur += ch
	out.append(cur)
	return out
