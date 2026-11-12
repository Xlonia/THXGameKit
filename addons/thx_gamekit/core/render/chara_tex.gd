class_name CharaTex
extends RefCounted
## =============================================================
## 角色贴图装载（0.0.9·20261109）：res://addons/thx_gamekit/data/textures/chars/<名>.PNG
## 【作者要求（本轮三项留档之一）】
##   ①本版=精灵图集 PNG 支持+默认循环播放：
##     横条带（宽=短边整数倍）或竖条带按短边切帧；方形图=单帧。
##     播放≈8 帧/秒循环（实体相位错开）。完整动画帧表（各行各动作）
##     待作者图集完成后验证——"用户在此处要求精灵图集+循环播放，
##     其在后续版本有跟进时作为参考"（0.0.9）。
##   ②【后续版本参考（作者 20261109 要求）】弹幕编辑器的角色设置中
##     设置贴图并支持预览——本版先做目录约定装载，编辑器 UI 随后跟进。
## =============================================================
static var _cache: Dictionary = {}    ## key -> Dictionary(tex/frames/fw/fh/horiz) 或 {}=无
static var _dir_scanned := false
static var DATA_BASE := "" ## 【内核化】由 THXKit 推送（宿主可覆盖）
static var _stem_map: Dictionary = {} ## 小写文件名主干 -> 路径

static func _scan_dir() -> void:
	if _dir_scanned:
		return
	_dir_scanned = true
	## 【0.0.9·挂载点无关+用户文件夹】扫描分层 20261112：内核默认 →
	## 宿主 DATA_BASE → 用户目录（后扫者覆盖同名=用户最优先）。
	## 旧版宿主在前、content_scan_dirs（含内核默认）在后=内核自带文件
	## 覆盖宿主（晚汐贴图被内核同名占位图抢注→submodule 内 PNG 宿主
	## 导入库加载失败→反而缺图）
	var dirs: Array = []
	var main_loop := Engine.get_main_loop()
	var kit_node: Node = null
	if main_loop != null and main_loop.root.has_node("THXKit"):
		kit_node = main_loop.root.get_node("THXKit")
	if kit_node != null:
		dirs.append((kit_node as Node).DATA_DIR.path_join("textures/chars")) ## 内核默认
	if DATA_BASE != "":
		dirs.append(DATA_BASE) ## 宿主（游戏本体数据覆盖内核）
	if kit_node != null:
		dirs.append_array((kit_node as Node).content_user_dirs("chara_tex")) ## 用户最优先
	for scan_dir in dirs:
		var dir := DirAccess.open(scan_dir)
		if dir == null:
			continue
		for f in dir.get_files():
			if f.to_lower().ends_with(".png") and not f.ends_with(".import"):
				_stem_map[f.get_basename().to_lower()] = scan_dir.path_join(f)

## 【编辑器导入/清除路径】角色贴图目录本身
static func chars_dir() -> String:
	return DATA_BASE if DATA_BASE != "" else "res://addons/thx_gamekit/data/textures/chars"

## 名字→文件主干：全名 → 去尾部 A/B → 中文名
static func _resolve(name_key: String, name_zh: String) -> String:
	if _stem_map.is_empty():
		_scan_dir()
	if _stem_map.is_empty():
		return ""
	var cands := [name_key.to_lower()]
	if name_key.length() > 3 and (name_key.ends_with("A") or name_key.ends_with("B")):
		cands.append(name_key.substr(0, name_key.length() - 1).to_lower())
	cands.append(name_zh.to_lower())
	for c in cands:
		if _stem_map.has(c):
			return _stem_map[c]
	return ""

## 取角色贴图（含图集切帧信息；无文件返回空 Dictionary）
static func get_chara(name_key: String, name_zh: String = "") -> Dictionary:
	var key := name_key + "|" + name_zh
	if _cache.has(key):
		return _cache[key]
	var out := {}
	var path := _resolve(name_key, name_zh)
	if path != "":
		var tex: Texture2D = load(path)
		if tex != null:
			var w := tex.get_width()
			var h := tex.get_height()
			var frames := 1
			var fw := w
			var fh := h
			var horiz := true
			if w > h and w % h == 0:      ## 横条带：帧=短边正方形
				frames = w / h
				fw = h
			elif h > w and h % w == 0:    ## 竖条带
				frames = h / w
				fh = w
				horiz = false
			out = {"tex": tex, "frames": frames, "fw": fw, "fh": fh, "horiz": horiz}
	_cache[key] = out
	return out

## 帧区域（frame_i：0..frames-1）
## 【编辑器贴图设定用】变更（导入/清除）后失效该角色缓存（下帧重读文件）
static func invalidate(name_key: String, name_zh: String = "") -> void:
	_cache.erase(name_key + "|" + name_zh)
	_cache.erase(name_key + "|" + name_key) ## name_zh 兜底同键

## 【标题画面-选项 20261112】内容文件夹变更后整体重扫（下次 get_chara 触发）
static func invalidate_all() -> void:
	_dir_scanned = false
	_stem_map.clear()
	_cache.clear()

static func frame_region(c: Dictionary, frame_i: int) -> Rect2:
	var n: int = c["frames"]
	var fi := wrapi(frame_i, 0, n)
	if c["horiz"]:
		return Rect2(fi * c["fw"], 0, c["fw"], c["fh"])
	return Rect2(0, fi * c["fw"], c["fw"], c["fh"])
