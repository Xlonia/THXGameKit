class_name BehaviorScore
## =============================================================
## 【行为检测（0.2.0·内核 0.1.0——scheme 弹幕编辑器新二"关卡流程/行为检测"节）】
## 关卡活跃时检测行为本身，结算规则部分返回累计次数并重置。
## 内核设置标签 #behavior_score_noreset_chapter=跳过章节结算对行为检测累计重置；
## #behavior_score_noreset_display_chapter=生成忽略重置的副本（原名_display，
## 用于关卡显示的行为累计数，比如擦弹）。
## 章节操作 behaviorReset 可在不结算的前提下重置所有行为累计计数。
## 反馈触发器事件（注册才启用）：bullseye/hit/privatehit/spell/playerspell/
## leftless/miss/danmaku/shoot/michihit/clear。
## =============================================================

const EVENTS := ["bullseye", "hit", "privatehit", "spell", "playerspell", "leftless",
	"miss", "danmaku", "shoot", "michihit", "clear", "graze"]

static var _scores: Dictionary = {}        ## 行为名 → 累计（章节内）
static var _display: Dictionary = {}       ## 行为名 → 显示副本累计（_display 口径）
static var _noreset_tags: Dictionary = {}  ## 行为名 → true（#behavior_score_noreset_chapter）

static func clear() -> void:
	_scores.clear()
	_display.clear()

## 计数 +1（宿主挂点调用：graze/hit/…）
static func add(event: String, n: int = 1) -> void:
	_scores[event] = int(_scores.get(event, 0)) + n
	_display[event] = int(_display.get(event, 0)) + n

## 章节结算读取：返回累计并重置（noreset 标签行为除外）
static func settle(event: String) -> int:
	var v := int(_scores.get(event, 0))
	if not bool(_noreset_tags.get(event, false)):
		_scores[event] = 0
	return v

## 显示副本读取（_display 口径——不重置）
static func display_score(event: String) -> int:
	return int(_display.get(event, 0))

## 章节操作 behaviorReset：不结算前提下重置全部行为累计
static func behavior_reset() -> void:
	_scores.clear()

## 标签：跳过章节结算重置（#behavior_score_noreset_chapter）
static func set_noreset(event: String, enabled: bool) -> void:
	_noreset_tags[event] = enabled

## 阈值触发器查询：某行为累计是否到达阈值（上下沿由消费方管理）
static func reached(event: String, threshold: int) -> bool:
	return int(_scores.get(event, 0)) >= threshold

## 【m117 threshold 条件读取】不重置的累计读数（阈值表达式变量）
static func read(event: String) -> int:
	return int(_scores.get(event, 0))
