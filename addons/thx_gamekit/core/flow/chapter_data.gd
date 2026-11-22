class_name ChapterData
## =============================================================
## 【章节数据（0.2.0·内核 0.1.0 第一批——scheme 弹幕编辑器新二"关卡设置/
## 总剪辑/章节"节，作者 20261122 版）】
## 章节(chapter)=每个关卡的组成单元（绀珠传式计分/回档/音乐重复参与单元）；
## 总剪辑=整个关卡的时间轴，可分多个章节；弹幕片段(clip)=角色的弹幕组成单元。
##
## 本批=**稳态地基**（作者："在确切的短期目标内把稳重且基础的做好"）：
##   章节主表（CSV：顺序/转场/循环/跳转/音乐方案/入场片段序列/触发器文本）
##   ——角色出场条目/运动关键帧/动画剪辑/背景画面=数据字段占位（后续批消费）。
## 转场：continue（直接拼接无公共触发器）/ next（触发公共剪辑触发器）。
## 循环：flow 流动（时间到运行下一个）/ trigged 触发（外部唤起跳剩余）/
##       slug 迟滞（事件帧停但不出局）/ loop 循环（从头再来——后须触发转场）。
## 章节：goto 跳转 / skip 跳过 / select 抉择 / fix 并列混合（定位器=章节名，
##       起始=the_start，结束=the_fin）。
## 触发器（globe_/l_ 前缀）：starter/finner/ticker/threshold/feedback+
##       反馈事件（bullseye/hit/privatehit/spell/playerspell/leftless/miss/
##       danmaku/shoot/michihit/clear——注册才启用）。
## =============================================================

const NAMES_ORDER_FIELD := "order"

static var _chapters: Array = []      ## 注册序（主表行：字符串字典）
static var _by_id: Dictionary = {}

static func clear() -> void:
	_chapters.clear()
	_by_id.clear()

## 注册/覆盖一条章节（id 相同=覆盖）
static func register(row: Dictionary) -> String:
	var id := String(row.get("id", "")).strip_edges()
	if id == "":
		id = "chapter_%d" % (_chapters.size() + 1)
	if _by_id.has(id):
		for i in _chapters.size():
			if String(_chapters[i].get("id", "")) == id:
				_chapters[i] = row
				_by_id[id] = row
				return id
	_chapters.append(row)
	_by_id[id] = row
	return id

static func get_chapter(id: String) -> Dictionary:
	return _by_id.get(id, {})

static func all() -> Array:
	return _chapters

static func count() -> int:
	return _chapters.size()

## 按 order 字段排序的章节序列（总剪辑流转顺序；order 缺省=注册序）
static func ordered() -> Array:
	var out: Array = []
	for r in _chapters:
		out.append(r)
	out.sort_custom(func(a, b):
		var oa := int(float(a.get("order", "0")) if str(a.get("order", "")) != "" else 0)
		var ob := int(float(b.get("order", "0")) if str(b.get("order", "")) != "" else 0)
		return oa < ob)
	return out

## =============================================================
## CSV 存取（chapters.csv——编辑器章节页/宿主装载共用）
## 列：id,name,order,transition,loop,goto,skip,select,fix,
##     music_plan,music_track,music_start,
##     entrance_clips,local_triggers,globe_triggers,enemypcs,boss_data
## entrance_clips=分号片段名序列（入场编排——消费方按序 playclips）
## local/globe_triggers=分号分隔"类型:脚本文本"条目（脚本执行随章节系统后续批）
## =============================================================
const CSV_PATH_DEFAULT := "res://addons/thx_gamekit/data/chapters.csv"
const COLUMNS := ["id", "name", "order", "transition", "loop", "goto", "skip", "select", "fix",
	"music_plan", "music_track", "music_start", "entrance_clips", "chars", "local_triggers",
	"globe_triggers", "enemypcs", "boss_data"]

static func load_csv(path: String = CSV_PATH_DEFAULT) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var header: PackedStringArray = []
	var n := 0
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() == 0:
			continue
		var first := row[0].strip_edges()
		if first.is_empty() or first.begins_with("#"):
			continue
		if header.is_empty():
			header = row
			continue
		var d := {}
		for i in header.size():
			d[header[i]] = row[i] if i < row.size() else ""
		register(d)
		n += 1
	f.close()
	return n

static func save_csv(path: String = CSV_PATH_DEFAULT) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "写盘失败：%d" % FileAccess.get_open_error()
	f.store_line(",".join(COLUMNS))
	for r in _chapters:
		var line: Array = []
		for col in COLUMNS:
			var cs := str(r.get(col, ""))
			line.append(('"%s"' % cs.replace('"', '""')) if (cs.contains(",") or cs.contains('"')) else cs)
		f.store_line(",".join(line))
	f.close()
	return ""

static func csv_rows(path: String = CSV_PATH_DEFAULT) -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	var out: Array = []
	if f == null:
		return out
	var header: PackedStringArray = []
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() == 0:
			continue
		var first := row[0].strip_edges()
		if first.is_empty() or first.begins_with("#"):
			continue
		if header.is_empty():
			header = row
			continue
		var d := {}
		for i in header.size():
			d[header[i]] = row[i] if i < row.size() else ""
		out.append(d)
	f.close()
	return out

static func save_csv_rows(rows: Array, path: String = CSV_PATH_DEFAULT) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "写盘失败：%d" % FileAccess.get_open_error()
	f.store_line(",".join(COLUMNS))
	for rd in rows:
		var line: Array = []
		for col in COLUMNS:
			var cs := str(rd.get(col, ""))
			line.append(('"%s"' % cs.replace('"', '""')) if (cs.contains(",") or cs.contains('"')) else cs)
		f.store_line(",".join(line))
	f.close()
	return ""

## =============================================================
## 【触发器/角色条目解析（m117——宿主章节运行时消费）】
## 触发器单元格="类型:文本"分号多条：
##   starter/finner/ticker/feedback:事件=脚本 / threshold:条件=脚本
##   （threshold/feedback 两段式=scheme"上段触发条件/下段执行代码"）
## 角色条目单元格="名:进tick:出tick:x,y:运动"分号多条（运动=占位字段）
## =============================================================
static func parse_triggers(cell: String) -> Array:
	var out: Array = []
	for seg in cell.split(";", false):
		var t := seg.strip_edges()
		if t == "":
			continue
		var ci := t.find(":")
		if ci < 0:
			out.append({"type": "ticker", "text": t}) ## 无类型=逐帧文本兜底
			continue
		var ty := t.substr(0, ci).strip_edges().to_lower()
		var rest := t.substr(ci + 1).strip_edges()
		if ty == "threshold" or ty == "feedback":
			## 两段式：条件=脚本（feedback=事件=脚本）
			var si := rest.find("=")
			if si < 0:
				out.append({"type": ty, "cond": rest, "script": ""})
			else:
				out.append({"type": ty, "cond": rest.substr(0, si).strip_edges(),
					"script": rest.substr(si + 1).strip_edges()})
		else:
			out.append({"type": ty, "script": rest})
	return out

static func parse_char_entries(cell: String) -> Array:
	var out: Array = []
	for seg in cell.split(";", false):
		var t := seg.strip_edges()
		if t == "":
			continue
		var parts := t.split(":")
		if parts.size() < 3:
			continue
		var pos := Vector2(200, 200)
		if parts.size() >= 4:
			var xy := parts[3].split(",")
			if xy.size() == 2:
				pos = Vector2(float(xy[0]), float(xy[1]))
		out.append({"name": parts[0].strip_edges(), "enter": int(parts[1]) if parts.size() > 1 else 0,
			"exit": int(parts[2]) if parts.size() > 2 else -1, "pos": pos,
			"move": parts[4].strip_edges() if parts.size() > 4 else "stay"})
	return out
