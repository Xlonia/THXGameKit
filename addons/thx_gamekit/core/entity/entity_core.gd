class_name EntityCore
extends Node2D
## =============================================================
## 实体底座（0.0.9·内核化第二步 20261111）——自 th75 BattleEntity 抽取的
## **玩法无关**子集：三部位 HP/AP/瘫痪、判定圆、慢快机移动、双朝向
## （攻击 atk_facing / 运动 facing）、局部帧、杂兵跟随、被弹结算。
## 【分层约定】玩法插件（如自走棋）在自己的实体子类里追加：结界半径
## （Defend 列）、P 点经济、态势卡/AI/心情/热力感知、消弹域等。
## 本类不含任何玩法假设（不知道 P 点/态势卡/热力图为何物）。
## 【默认值说明】setup 的按 kind 初始 HP/AP 为 THX75 平衡值=内核默认；
## 玩法插件可在 setup 后覆盖。
## =============================================================

const PART_WEAPON := 0
const PART_BODY := 1
const PART_MOVE := 2

enum Kind { PLAYER, MEMBER, PRIVATE, ENEMY } ## 自机/队伍成员/杂兵/敌角色

var db: Dictionary = {}
var side := 0
var kind := Kind.MEMBER
var is_player := false
var ap := 0:
	set(v):
		ap = v
		if ap <= 0 and not barrier_broken:
			barrier_broken = true   ## 剥甲：本场无法恢复（getset 检测）
			barrier_shattered.emit(self)
var hp := [0, 0, 0]:
	set(v):
		hp = v
		_on_hp_changed()           ## 部位归零→重伤检测（getset，无遍历）
var immune_frames := 0
var stun_frames := [0, 0, 0]
var dead := false
var barrier_broken := false
var is_elite_private := false    ## 较强杂兵 tag
var impale_cap: float = INF      ## 穿透伤害上限钩子（道具/玩法插件覆盖）
var touch_state: Dictionary = {}

## 巡航/快机（poi 的 to_c 与移动用）
var cruise_active := false
## 【运动朝向】=移动方向（静止保持）；不驱动贴图/排布旋转（躲弹抽搐根除）
var facing := Vector2.RIGHT:
	set(v):
		if v != Vector2.ZERO:
			facing = v.normalized()

## 【攻击朝向】=贴图/杂兵排布/火力排布面对的方向（指向瞄准目标——由
## 玩法/操控侧逐帧回写；内核不假设"目标"为何物）
var atk_facing := Vector2.RIGHT

## 局部帧基向量：forward=攻击朝向（局部+y），right=顺时针 90°（局部+x）
func frame_forward() -> Vector2:
	return atk_facing
func frame_right() -> Vector2:
	return atk_facing.rotated(PI / 2.0)
func frame_back() -> Vector2:
	return -atk_facing
## 局部(x=右侧,y=前方) → 世界
func frame_to_world(lx: float, ly: float) -> Vector2:
	return frame_right() * lx + frame_forward() * ly
## 世界 → 局部(x=右侧,y=前方)
func world_to_frame(w: Vector2) -> Vector2:
	var r := frame_right()
	var f := frame_forward()
	return Vector2(w.dot(r), w.dot(f))

## —— 杂兵（相对角色跟随；杂兵/触发器产生=内核概念，排布公式属玩法）——
var owner_ent: EntityCore = null
var local_pos := Vector2.ZERO    ## 相对角色坐标
var privates_id := 1             ## 目标 ID（开局/增援时空位分配）
var formation_t := 0.0           ## 排布三角波 t（封闭数据）

signal damaged(entity: EntityCore)
signal destroyed(entity: EntityCore)
signal barrier_shattered(entity: EntityCore) ## 剥甲事件（经济/演出由插件接）

func setup(chara_db_row: Dictionary, entity_side: int, entity_kind: int, player_flag: bool = false) -> void:
	db = chara_db_row
	side = entity_side
	kind = entity_kind
	is_player = player_flag
	facing = Vector2.RIGHT if entity_side == 0 else Vector2.LEFT ## 默认对峙
	match kind:
		Kind.PLAYER:
			ap = 50
			hp = [10, 20, 10]
		Kind.MEMBER, Kind.ENEMY:
			ap = 25
			hp = [3, 5, 3]
		Kind.PRIVATE:
			ap = 5
			hp = [1, 1, 1]
			if is_elite_private:
				ap = 10
				hp = [2, 2, 2]
	## 【玩法插件覆盖点】上述默认=THX75 平衡值；插件按自己的数据表覆盖
	## （例：自走棋插件从自身数据行读取结界/部位值）
	dead = false
	immune_frames = 0
	stun_frames = [0, 0, 0]
	barrier_broken = false
	touch_state.clear()

func setup_private(chara_db_row: Dictionary, entity_side: int, owner: EntityCore, pid: int, elite: bool) -> void:
	is_elite_private = elite
	privates_id = pid
	setup(chara_db_row, entity_side, Kind.PRIVATE)
	owner_ent = owner
	local_pos = Vector2.ZERO

## —— 只读属性 ——
func judge_radius() -> float:
	return float(db.get("Determine", 3)) ## 判定半径=狭义本体必填列
## 【结界半径=玩法插件追加】（自走棋：judge+Defend 列）——内核不含 Defend 假设
func normal_speed() -> float:
	return float(db.get("Normal", 2)) ## 慢机速度=狭义本体必填列
func cruise_speed() -> float:
	return float(db.get("Cruise", 3)) ## 快机速度=狭义本体必填列
func chara_name() -> String:
	return String(db.get("Name", "?"))

## 部位可用（HP>0 且未瘫痪）
func part_ok(part: int) -> bool:
	return hp[part] > 0 and stun_frames[part] <= 0
func weapon_ok() -> bool: return part_ok(PART_WEAPON)
func wing_ok() -> bool:    return part_ok(PART_BODY)
func move_ok() -> bool:    return part_ok(PART_MOVE)

## 移动（角色：慢机/快机；机动折损→20%；杂兵：世界坐标由跟随+位移合成）
## dist_scale：时间尺度缩放（道具/演出整体放慢用）
## speed_k：慢机速度比例（0~1；基础规避 BC 合力换算的比例速度——
## "标量×慢机速度/256，大于慢机速度则返回慢机速度"）；快机不受此比例
func move(dir: Vector2, dist_scale: float = 1.0, speed_k: float = 1.0) -> void:
	if dead or dir == Vector2.ZERO:
		return
	facing = dir ## 运动朝向=移动方向（不驱动贴图旋转）
	var spd := cruise_speed() if cruise_active and move_ok() else normal_speed() * clampf(speed_k, 0.0, 1.0)
	if not move_ok():
		spd = normal_speed() * 0.2 * clampf(speed_k, 0.0, 1.0) ## 机动折损：慢机20%
	spd *= dist_scale
	if kind == Kind.PRIVATE:
		## 杂兵位置=角色位置+相对位移（角色动它们跟着动）
		local_pos += dir.normalized() * spd
		sync_private_pos()
		return
	position += dir.normalized() * spd
	position = position.clamp(Vector2.ZERO, Vector2(400, 400))

## 杂兵世界坐标同步（owner 移动即跟随；local_pos=平面世界相对坐标）
## 【强制拉回】钳入场内并回写 local_pos（防边界处反复对抗抖动；
## 场外漂移=所属角色被击败后无人管理的卡死根源）
func sync_private_pos() -> void:
	if owner_ent != null:
		position = (owner_ent.position + local_pos).clamp(Vector2(2, 2), Vector2(398, 398))
		local_pos = position - owner_ent.position

func tick() -> void:
	if immune_frames > 0:
		immune_frames -= 1
	for i in 3:
		if stun_frames[i] > 0:
			stun_frames[i] -= 1

## =============================================================
## 被弹结算（部位三类型：一般 N / 穿透 I / 碎甲 S）
## 免疫帧内完全跳过；全部位归零= destroyed 信号
## =============================================================
func take_hit(dmg: int, dmg_type: int, hit_angle: float) -> bool:
	if dead or immune_frames > 0:
		return false
	if dmg <= 0 and dmg_type != 2:
		return false
	var part := _part_from_angle(hit_angle)
	match dmg_type:
		0: ## 一般(N)
			if ap > 0:
				ap = maxi(0, ap - dmg)
			else:
				hp[part] = maxi(0, hp[part] - dmg)
				_apply_serious(part)
		1: ## 穿透(I)：AP 削减反比；AP=0 → dmg÷0=浮点最大值（一发重伤）
			var direct: float
			if ap > 0:
				direct = maxf(1.0, float(dmg) * float(ap) / 100.0)
				direct = minf(direct, impale_cap)
			else:
				direct = minf(3.4e38, impale_cap)
			hp[part] = maxi(0, hp[part] - int(minf(direct, 1e9)))
			_apply_serious(part)
		2: ## 碎甲(S)：瘫痪秒=dmg
			stun_frames[part] = maxi(stun_frames[part], dmg * 60)
	immune_frames = 30
	damaged.emit(self)
	if hp[0] <= 0 and hp[1] <= 0 and hp[2] <= 0:
		dead = true
		destroyed.emit(self)
	return true

## 重伤副作用（getset 检测）：部位归零 → 对应能力失效由 part_ok 即时反映
func _on_hp_changed() -> void:
	for i in 3:
		if hp[i] <= 0:
			_apply_serious(i)

func _apply_serious(part: int) -> void:
	## 钩子：玩法插件可覆盖（"重伤叠加""修理"等——文档：重伤会叠加）
	pass

## 部位判定（上120°武器 / 下120°机动 / 左右60°僚机）
func _part_from_angle(angle: float) -> int:
	if absf(angle_difference(angle, -PI / 2.0)) <= deg_to_rad(60.0):
		return PART_WEAPON
	if absf(angle_difference(angle, PI / 2.0)) <= deg_to_rad(60.0):
		return PART_MOVE
	return PART_BODY
