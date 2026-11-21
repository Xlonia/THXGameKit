class_name FieldRules
## =============================================================
## 【场地规则（scheme 弹幕编辑器新二"场地规则"节，作者 20261121 更新版）】
## 诸如东方正作的收点、THX75 的支援框——特定的区域内操作可被应用或者覆写。
##
## 规则结构（scheme 原文）：
##   规则头   =本地化键名(tag)+ID
##   处理对象 =chara / danmaku（默认都不处理——"这些太浪费性能"，填了才解析）
##   规则范围 =x0,y0,x1,y1（缺省一对=条带判定：只考虑 x 或 y 属于特定值）
##   场地操作 =挂载在范围上的关卡/角色/章节操作（有弹幕或对象须在处理对象声明）
##   规则关系 =mutual 互斥（覆盖另一规则——如 THX75 的 support_out 覆盖
##             total_support：支援框内外两套规则）/ require 需要（另一规则
##             存在时才执行）
##   范围类型 =main 主范围（默认框线区域）/ sattle 特许范围（框内完全不应用
##             主规则的区域）/ smooth 圆滑范围（子框线到所属框线之间强度过渡，
##             使界线不生硬）
##
## 本类=静态注册表+纯框运算域判定（无逐帧实体轮询——使用方按需查询，
## 性能口径=作者"全局一个内核操作覆盖支援框外逻辑"）。
## 解除条件：进入范围即应用、超出自动解除（使用方按拍查询即天然获得该语义）。
## =============================================================

static var _rules: Array = []        ## 规则表（注册序）
static var _by_id: Dictionary = {}   ## id → 规则
static var _auto := 0                ## 无 ID 时自动编号

## 注册一条场地规则。字段（全部可选除 tag 外）：
##   id(String) 唯一键（缺省=tag_自动号）/ tag(String) 本地化键名
##   chara/danmaku(bool) 处理对象（默认 false——性能默认不处理）
##   box(Vector4 或 Array[x0,y0,x1,y1]) 主范围；缺省对=条带（如 [25,null,375,null]）
##   sattle(Array[x0,y0,x1,y1]) 特许范围——框内不应用本规则（缺省=无）
##   ops(Array[String]) 场地操作（章节/角色/关卡操作文本，使用方解析执行）
##   mutual(Array[String]) 互斥：本规则在活跃区间内覆盖这些 id
##   require(Array[String]) 需要：这些 id 至少一个活跃时本规则才可能活跃
## 返回实际 id。
static func register(rule: Dictionary) -> String:
	var id := String(rule.get("id", ""))
	if id == "" or _by_id.has(id):
		_auto += 1
		id = "%s_%d" % [String(rule.get("tag", "rule")), _auto]
		while _by_id.has(id):
			_auto += 1
			id = "%s_%d" % [String(rule.get("tag", "rule")), _auto]
	var box: Array = rule.get("box", [null, null, null, null])
	var r := {
		"id": id, "tag": String(rule.get("tag", id)),
		"chara": bool(rule.get("chara", false)),
		"danmaku": bool(rule.get("danmaku", false)),
		"x0": box[0] if box.size() > 0 else null,
		"y0": box[1] if box.size() > 1 else null,
		"x1": box[2] if box.size() > 2 else null,
		"y1": box[3] if box.size() > 3 else null,
		"sattle": rule.get("sattle", null),  ## Array[x0,y0,x1,y1] 或 null
		"ops": rule.get("ops", []),
		"mutual": rule.get("mutual", []),
		"require": rule.get("require", []),
		"smooth": rule.get("smooth", null),  ## smooth 子框（过渡带=子框边→主框边）
	}
	_rules.append(r)
	_by_id[id] = r
	return id

static func unregister(id: String) -> void:
	if not _by_id.has(id):
		return
	_rules.erase(_by_id[id])
	_by_id.erase(id)

static func clear() -> void:
	_rules.clear()
	_by_id.clear()
	_auto = 0

static func get_rule(id: String) -> Dictionary:
	return _by_id.get(id, {})

## 主范围判定（缺省对=条带：null 边=该轴不设限）
static func in_main(rule: Dictionary, pos: Vector2) -> bool:
	var x0 = rule.get("x0")
	var y0 = rule.get("y0")
	var x1 = rule.get("x1")
	var y1 = rule.get("y1")
	if x0 != null and pos.x < float(x0):
		return false
	if x1 != null and pos.x > float(x1):
		return false
	if y0 != null and pos.y < float(y0):
		return false
	if y1 != null and pos.y > float(y1):
		return false
	return true

## 特许范围（sattle）：框内=完全不应用本规则
static func in_sattle(rule: Dictionary, pos: Vector2) -> bool:
	var st = rule.get("sattle")
	if st == null:
		return false
	return _in_box_arr(pos, st)

static func _in_box_arr(pos: Vector2, b: Array) -> bool:
	if b.size() < 4:
		return false
	if b[0] != null and pos.x < float(b[0]):
		return false
	if b[2] != null and pos.x > float(b[2]):
		return false
	if b[1] != null and pos.y < float(b[1]):
		return false
	if b[3] != null and pos.y > float(b[3]):
		return false
	return true

## smooth 强度：smooth 子框内=1.0；子框边→主框边沿径向线性衰减到 0.0；
## 无 smooth 定义时：主范围内恒 1.0（非主范围 0.0）。
## 用于把场地操作强度过渡的用法（scheme：如越往上伤害越高的判定）。
## 近似口径：两框视作同心（径向距离比例）——条带主框（缺省边）恒 1.0。
static func smooth_strength(rule: Dictionary, pos: Vector2) -> float:
	if not in_main(rule, pos) or in_sattle(rule, pos):
		return 0.0
	var sm = rule.get("smooth")
	if sm == null or not (sm is Array) or (sm as Array).size() < 4:
		return 1.0
	if _in_box_arr(pos, sm):
		return 1.0
	var mc := _box_center([rule.get("x0"), rule.get("y0"), rule.get("x1"), rule.get("y1")])
	var r_s := _box_half_diag(sm)
	var r_m := _box_half_diag([rule.get("x0"), rule.get("y0"), rule.get("x1"), rule.get("y1")])
	if r_m <= r_s + 0.0001:
		return 1.0
	var d := pos.distance_to(mc)
	return clampf(1.0 - (d - r_s) / (r_m - r_s), 0.0, 1.0)

static func _box_half_diag(b: Array) -> float:
	var x0: float = float(b[0]) if b.size() > 0 and b[0] != null else -1e9
	var x1: float = float(b[2]) if b.size() > 2 and b[2] != null else 1e9
	var y0: float = float(b[1]) if b.size() > 1 and b[1] != null else -1e9
	var y1: float = float(b[3]) if b.size() > 3 and b[3] != null else 1e9
	if x1 > 1e8 or x0 < -1e8 or y1 > 1e8 or y0 < -1e8:
		return 1e9 ## 条带（缺省边）=无衰减
	return Vector2(x1 - x0, y1 - y0).length() * 0.5

static func _box_center(b: Array) -> Vector2:
	var x0: float = float(b[0]) if b.size() > 0 and b[0] != null else -1e9
	var x1: float = float(b[2]) if b.size() > 2 and b[2] != null else 1e9
	var y0: float = float(b[1]) if b.size() > 1 and b[1] != null else -1e9
	var y1: float = float(b[3]) if b.size() > 3 and b[3] != null else 1e9
	return Vector2((x0 + x1) * 0.5, (y0 + y1) * 0.5)

## 该点在该规则的主范围内（未过关系过滤）
static func _raw_hit(rule: Dictionary, pos: Vector2) -> bool:
	return in_main(rule, pos) and not in_sattle(rule, pos)

## 查询：pos 处活跃的规则（处理对象匹配 + require 满足 + 未被 mutual 覆盖）。
## mutual 语义（scheme）：support_out 覆盖 total_support——覆盖者命中时被覆盖者
## 在该点视为不活跃（即使其主范围包含该点）。
static func active_for(pos: Vector2, target: String = "chara") -> Array:
	var out: Array = []
	var hit: Array = []
	for r in _rules:
		var key := "chara" if target == "chara" else "danmaku"
		if not bool(r[key]):
			continue
		if not _raw_hit(r, pos):
			continue
		hit.append(r)
	for r in hit:
		var ok := true
		for rq in r["require"]:
			var rq_active := false
			for h in hit:
				if h["id"] == rq:
					rq_active = true
					break
			if not rq_active:
				ok = false
				break
		if not ok:
			continue
		for h in hit:
			if (h["mutual"] as Array).has(r["id"]):
				ok = false
				break
		if ok:
			out.append(r)
	return out

## 快捷判定：某 id 的规则在 pos 是否活跃（含 mutual/require/处理对象过滤）
static func is_active(id: String, pos: Vector2, target: String = "chara") -> bool:
	for r in active_for(pos, target):
		if r["id"] == id:
			return true
	return false

## =============================================================
## 【itemget 磁吸（scheme 1246：itemget(角色选择器，范围，解除条件)）】
## 为角色设定磁吸效果——半径范围内的道具自动吸附。内核只挂状态（meta），
## 道具实体系统由各游戏宿主实现（THX75=_update_drops 读取本状态）。
## 解除条件=until_frame（时间帧；0/缺省=挂到清除）。
## =============================================================
static func itemget(ent: Node, radius: float, until_frame: int = 0) -> void:
	if ent == null:
		return
	ent.set_meta("itemget_radius", radius)
	ent.set_meta("itemget_until", until_frame)

static func itemget_clear(ent: Node) -> void:
	if ent != null:
		ent.remove_meta("itemget_radius")
		ent.remove_meta("itemget_until")

## 当前生效的磁吸半径（0=无；解除条件按使用方的帧计数判断——传入 now）
static func itemget_radius(ent: Node, now: int = 0) -> float:
	if ent == null or not ent.has_meta("itemget_radius"):
		return 0.0
	var until := int(ent.get_meta("itemget_until", 0))
	if until > 0 and now > until:
		return 0.0
	return maxf(float(ent.get_meta("itemget_radius", 0.0)), 0.0)
