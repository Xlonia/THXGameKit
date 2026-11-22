class_name ChapterFlow
extends Node
## =============================================================
## 【m120 章节流程内核化（作者 20261122 确认："章节流程到内核——本来就是
## THXGameKit 的"；scheme 新二 1394"chapter.gd 是章节流程"）】
## 自 th75 宿主 battle_arena 迁入（m116 地基→m117 触发器/条目→m118 全量）：
## 顺序块流转（skip/goto/select/fix/slug/trigged/loop）+ 触发器全类
## （starter/finner 章界+stage/settle/next 关卡级+globe 并集）+
## 角色条目（章节局部帧）+ 运动关键帧（二次贝塞尔）+ 音乐方案
## （continue/hard/soft/sfx/loop:A[,B]）。宿主只留薄消费（信号接线）。
## 宿主职责（信号）：脚本操作执行（toast/playclips/letenemy…）/入场片段/
## 角色实体位/背景画面换装/midboss·clear 语境（实体死亡在宿主）。
## 自有帧时基：tick() 每拍自增 frames（宿主在物理拍调用一次）。
## =============================================================

signal op_requested(op: String, arg: String, where: String)  ## 脚本操作（宿主执行）
signal entrance(mem: Dictionary)                              ## 章节入场（宿主播片段）
signal char_entered(ent_name: String, pos: Vector2)
signal char_exited(ent_name: String)
signal char_driven(ent_name: String, pos: Vector2)            ## 运动关键帧逐拍编排位
signal background_changed(path: String)                       ## 背景画面（""=恢复默认）
signal chapter_started(mem: Dictionary)
signal chapter_ended(mem: Dictionary)
signal flow_finished()                                        ## the_fin 完结

var rows: Array = []            ## ordered 全表
var scan_idx := -1              ## 上一顺序块末位（advance 从 idx+1 扫描）
var done := false               ## 完结门（the_fin 后不再重入）
var run: Array = []             ## 当前并行成员（行副本+运行态 _start/_until/_loops）
var skip_plans: Array = []      ## 全部 skip 单元（{id,cond}）
var trig_memo: Dictionary = {}  ## 触发器单元格文本 → 解析（并集扫描缓存）
var fb_seen: Dictionary = {}    ## feedback 事件 → 上一拍累计
var chars_state: Dictionary = {} ## 章节id+名 → {entered:bool}
var frames := 0                 ## 自有帧时基（tick 自增）
var music_search := ""          ## 宿主附加音乐搜索目录（如 th75/addons/thxgamekit/music/）

## —— 音乐（内核自有：AudioStreamPlayer 为引擎级，不涉宿主渲染）——
var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
var _sfx_player: AudioStreamPlayer = null
var _music_track := ""
var _music_loop_range := PackedFloat32Array() ## [a,b]（b<0=到结束——仅 slug）
var _xfade_in: AudioStreamPlayer = null
var _xfade_out: AudioStreamPlayer = null
var _sfx_pending := {}

func _chapters_data_default_csv() -> String:
	return "res://addons/thx_gamekit/data/chapters.csv"

func start_from_csv(path: String) -> void:
	ChapterData.clear()
	ChapterData.load_csv(path)
	start_rows(ChapterData.ordered())

func start_rows(ordered_rows: Array) -> void:
	rows = ordered_rows
	run = []
	done = false
	scan_idx = -1
	chars_state.clear()
	fb_seen.clear()
	trig_memo.clear()
	skip_plans = []
	for r in rows:
		for sk in ChapterData.parse_skip_cell(str(r.get("skip", ""))):
			skip_plans.append(sk)
	_music_nodes()
	if rows.is_empty():
		return
	globe_level("stage") ## 关卡起始触发器（scheme stage）
	advance()

## 每物理拍调用一次（自增时基+成员处理）
func tick() -> void:
	if rows.is_empty() or done:
		return
	frames += 1
	_music_tick()
	_video_note() ## 占位：内核不持有视频（宿主 background_changed 自理）
	for mem in run.duplicate():
		var lp := str(mem.get("loop", "flow"))
		var slug := lp == "slug"
		var frozen := slug and int(mem.get("_until_frame", -1)) >= 0 and frames >= int(mem["_until_frame"])
		if not frozen:
			triggers_tick(mem)
			chars_tick(mem)
		if slug:
			continue ## 迟滞：事件帧冻结后不自动流转，等待 trigged()
		if int(mem.get("_until_frame", -1)) >= 0 and frames >= int(mem["_until_frame"]):
			if lp == "loop":
				mem["_loops"] = int(mem.get("_loops", 0)) + 1
				begin(mem) ## 循环章节：从头再来（scheme）
				mem["_until_frame"] = flow_until(mem)
			else:
				end(mem) ## finner（+next 转场触发器+goto 跳转）
	if run.is_empty():
		advance()

func trigged() -> void:
	## trigged 转场：外部唤起——跳过剩余部分运行下一个（scheme 触发(trigged)/
	## 循环章节后必须使用触发转场）。boss 击破等外部事件后续批接线。
	for mem in run.duplicate():
		end(mem)
	if run.is_empty():
		advance()

## 关底语境：当前成员块=总剪辑最后一块（或成员 goto=the_fin——直达终局）
func is_final() -> bool:
	for mem in run:
		if str(mem.get("goto", "")).contains("the_fin"):
			return true
	if run.is_empty():
		return false
	var order0 := ChapterData.order_of(run[0])
	for r in rows:
		if ChapterData.order_of(r) > order0:
			return false
	return true

## =============================================================
## 顺序块流转
## =============================================================
func advance() -> void:
	while true:
		if scan_idx + 1 >= rows.size():
			run = []
			done = true ## 完结门：tick 不再重入（settle 只发一次）
			background_changed.emit("")
			globe_level("settle") ## 关卡结算触发器（scheme settle）
			print("[章节] 总剪辑完结（the_fin）")
			flow_finished.emit()
			return
		scan_idx += 1
		var order0 := ChapterData.order_of(rows[scan_idx])
		var block: Array = [rows[scan_idx]]
		var j := scan_idx + 1
		while j < rows.size() and ChapterData.order_of(rows[j]) == order0:
			block.append(rows[j])
			j += 1
		scan_idx = j - 1 ## 块消费完毕的扫描位置（goto 改写后同样从下一块起）
		var live: Array = []
		for r in block:
			if not skip_hit(str(r.get("id", ""))):
				live.append(r)
		if live.is_empty():
			print("[章节] skip：顺序 %s 整块跳过" % str(order0))
			continue
		var members: Array = []
		var any_fix := false
		for r2 in live:
			if str(r2.get("fix", "")).strip_edges() != "":
				any_fix = true
		if any_fix:
			members = live ## 并列混合：同序章节一同进行（scheme fix）
		elif live.size() > 1:
			for r3 in live:
				var sc := str(r3.get("select", "")).strip_edges()
				if sc == "" or cond(sc, {}):
					members = [r3]
					break
			if members.is_empty():
				print("[章节] select 均不满足——跳过顺序 %s 全部章节" % str(order0))
				continue
		else:
			members = [live[0]]
		run = []
		for m0 in members:
			var mem: Dictionary = (m0 as Dictionary).duplicate()
			mem["_start_frame"] = frames
			mem["_loops"] = 0
			mem["_until_frame"] = flow_until(mem)
			run.append(mem)
		for mem2 in run:
			begin(mem2)
		chapter_music(run[0], false) ## 并列组音乐取首位成员
		background_changed.emit(str(run[0].get("background", "")))
		return

func skip_hit(id: String) -> bool:
	for sk in skip_plans:
		if str(sk.get("id", "")) == id:
			if str(sk.get("cond", "")) == "" or cond(str(sk["cond"]), {}):
				return true
	return false

func flow_until(mem: Dictionary) -> int:
	## flow=入场片段播完估算（30s 下限）；trigged=外部唤起（无时限）；
	## slug=事件帧冻结点（until 后不再处理触发器/条目，等待 trigged）
	if str(mem.get("loop", "flow")) == "trigged":
		return -1
	var total_ticks := 0
	for cn2 in String(mem.get("entrance_clips", "")).split(";", false):
		var cdx2: ClipData = THXKit.resolve_clip(cn2.strip_edges())
		if cdx2 != null:
			var mx := cdx2.length_ticks
			for k in cdx2.ticks.keys():
				mx = maxi(mx, int(k) + 1)
			total_ticks += maxi(1, mx)
	return frames + maxi(30 * 60, total_ticks * 6 + 60)

func begin(mem: Dictionary) -> void:
	print("[章节] 进入 %s（%s） starter 触发%s" % [str(mem.get("id")), str(mem.get("name")),
		"" if int(mem.get("_loops", 0)) == 0 else "（第 %d 次循环重进）" % int(mem["_loops"])])
	chapter_started.emit(mem)
	fire(mem, "starter")
	for key in chars_state.keys():
		if str(key).begins_with(str(mem.get("id", "")) + "|"):
			chars_state.erase(key) ## 循环重进：条目状态清（从头再来——scheme）
	entrance.emit(mem) ## 入场片段（宿主播——锚=演出方领队）

func end(mem: Dictionary) -> void:
	fire(mem, "finner")
	if str(mem.get("transition", "")) == "next":
		globe_level("next") ## 剪辑触发器（Next）——进入 next 转场时（scheme）
	## goto：章末条件跳转（目标=章节 id 或 the_fin；条件不满足=正常流转）
	var g := ChapterData.parse_goto_cell(str(mem.get("goto", "")))
	if str(g.get("target", "")) != "":
		if str(g.get("cond", "")) == "" or cond(str(g["cond"]), mem):
			var tgt := str(g["target"])
			if tgt == "the_fin":
				scan_idx = rows.size() - 1
				print("[章节] goto the_fin——直接跳转至结束")
			else:
				var found := false
				for i in rows.size():
					if str(rows[i].get("id", "")) == tgt:
						scan_idx = i - 1
						found = true
						break
				if found:
					print("[章节] goto → %s" % tgt)
				else:
					print("[章节] goto 目标未找到：%s（正常流转）" % tgt)
	chapter_ended.emit(mem)
	run.erase(mem)

func fire(mem: Dictionary, ty: String) -> void:
	## starter/finner：全局触发器（globe 前缀=scheme"所有章节"）+ 本章节 local
	for r in rows:
		for tr in trig_parsed(str(r.get("globe_triggers", ""))):
			if str(tr["type"]) == ty:
				op_requested.emit(str(tr["script"]), "", ty + ":globe")
	for tr2 in trig_parsed(str(mem.get("local_triggers", ""))):
		if str(tr2["type"]) == ty:
			op_requested.emit(str(tr2["script"]), "", ty + ":local")

func globe_level(ty: String) -> void:
	## 关卡级触发器：stage（总剪辑起始）/settle（完结）/next（next 转场时）
	for r in rows:
		for tr in trig_parsed(str(r.get("globe_triggers", ""))):
			if str(tr["type"]) == ty:
				op_requested.emit(str(tr["script"]), "", ty)

## =============================================================
## 触发器逐拍（ticker/threshold/feedback——globe 并集+local）
## =============================================================
func trig_parsed(cell: String) -> Array:
	if not trig_memo.has(cell):
		trig_memo[cell] = ChapterData.parse_triggers(cell)
	return trig_memo[cell]

## 条件求值（goto/skip/select 与 threshold 共用语境；>> → > 转义同 threshold）
func cond(expr: String, mem: Dictionary) -> bool:
	var ex := DanmakuExpr.new()
	var names := PackedStringArray(["time_frames", "chaptertime", "chapterloop", "graze", "hit",
		"miss", "spell", "danmaku", "shoot", "privatehit", "midboss", "dochuhit", "clear"])
	if not ex.compile(expr.replace(">>", ">").replace("<<", "<"), names):
		return false
	var start_f := frames
	var loops := 0.0
	if not mem.is_empty():
		start_f = int(mem.get("_start_frame", frames))
		loops = float(mem.get("_loops", 0))
	var vals := {
		"time_frames": float(frames),
		"chaptertime": float(frames - start_f),
		"chapterloop": loops,
		"graze": float(BehaviorScore.read("graze")),
		"hit": float(BehaviorScore.read("hit")),
		"miss": float(BehaviorScore.read("miss")),
		"spell": float(BehaviorScore.read("spell")),
		"danmaku": float(BehaviorScore.read("danmaku")),
		"shoot": float(BehaviorScore.read("shoot")),
		"privatehit": float(BehaviorScore.read("privatehit")),
		"midboss": float(BehaviorScore.read("midboss")),
		"dochuhit": float(BehaviorScore.read("dochuhit")),
		"clear": float(BehaviorScore.read("clear")),
	}
	return ex.execute_dict(vals, 0.0) > 0.5

func triggers_tick(mem: Dictionary) -> void:
	var cells: Array = []
	for r in rows:
		cells.append(str(r.get("globe_triggers", "")))
	cells.append(str(mem.get("local_triggers", "")))
	for tcell in cells:
		for tr in trig_parsed(tcell):
			match str(tr["type"]):
				"ticker":
					op_requested.emit(str(tr["script"]), "", "ticker")
				"threshold":
					if cond(str(tr["cond"]), mem):
						op_requested.emit(str(tr["script"]), "", "threshold")
				"feedback":
					var ev := str(tr["cond"])
					var cur: int = BehaviorScore.display_score(ev)
					var seen: int = int(fb_seen.get(ev, cur))
					if cur > seen:
						op_requested.emit(str(tr["script"]), "", "feedback:" + ev)
					fb_seen[ev] = cur

## =============================================================
## 角色条目（章节局部帧）+ 运动关键帧
## =============================================================
func chars_tick(mem: Dictionary) -> void:
	var ch_id := str(mem.get("id", ""))
	var lt := frames - int(mem.get("_start_frame", frames))
	for ce in ChapterData.parse_char_entries(str(mem.get("chars", ""))):
		var key: String = ch_id + "|" + str(ce["name"])
		var st: Dictionary = chars_state.get(key, {"entered": false})
		if not bool(st["entered"]) and lt >= int(ce["enter"]):
			char_entered.emit(str(ce["name"]), ce["pos"])
			st["entered"] = true
			chars_state[key] = st
		elif bool(st["entered"]) and int(ce["exit"]) >= 0 and lt >= int(ce["exit"]):
			char_exited.emit(str(ce["name"]))
			st["entered"] = false
			chars_state[key] = st
	moves_tick(mem, lt, ch_id)

## 运动关键帧：moves="名@tick:x,y[|cx,cy];…"——段内二次贝塞尔（弯曲点=进入
## 该关键帧一段的弯曲点，缺省=直线）；首段前=出场位，末段后=末关键帧。
func moves_tick(mem: Dictionary, lt: int, ch_id: String) -> void:
	var kfs: Dictionary = {}
	for mv in ChapterData.parse_moves(str(mem.get("moves", ""))):
		if not kfs.has(mv["name"]):
			kfs[mv["name"]] = []
		(kfs[mv["name"]] as Array).append(mv)
	if kfs.is_empty():
		return
	var enter_pos := {}
	for ce2 in ChapterData.parse_char_entries(str(mem.get("chars", ""))):
		enter_pos[str(ce2["name"])] = ce2["pos"]
	for nm in kfs:
		var st2: Dictionary = chars_state.get(ch_id + "|" + str(nm), {"entered": false})
		if not bool(st2["entered"]):
			continue ## 未出场不编排
		var list: Array = kfs[nm]
		list.sort_custom(func(a, b): return int(a["tick"]) < int(b["tick"]))
		var p0: Vector2 = enter_pos.get(nm, Vector2.ZERO)
		var t0 := 0
		var target := p0
		for kf in list:
			var kt := int(kf["tick"])
			if lt < kt:
				var denom := kt - t0
				var u := 0.0 if denom <= 0 else clampf(float(lt - t0) / float(denom), 0.0, 1.0)
				var p1: Vector2 = kf["pos"]
				var ctrl: Vector2 = p0.lerp(p1, 0.5) if not bool(kf.get("has_ctrl", false)) else (kf["ctrl"] as Vector2)
				var q0 := p0.lerp(ctrl, u)
				var q1 := ctrl.lerp(p1, u)
				target = q0.lerp(q1, u) ## 二次贝塞尔（de Casteljau）
				break
			p0 = kf["pos"]
			t0 = kt
			target = p0
		char_driven.emit(str(nm), target)

## =============================================================
## 音乐方案（scheme 背景音乐节——内核自有播放器）
## =============================================================
func _music_nodes() -> void:
	if _music_a != null:
		return
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	_sfx_player = AudioStreamPlayer.new()
	add_child(_music_a)
	add_child(_music_b)
	add_child(_sfx_player)

func music_resolve(track: String) -> AudioStream:
	var t := track.strip_edges()
	if t == "":
		return null
	var dirs := ["res://addons/thx_gamekit/data/music/"]
	if music_search != "":
		dirs.append(music_search)
	var cands := [t]
	for d in dirs:
		cands.append(d + t)
		for ext in [".ogg", ".wav", ".OGG", ".WAV"]:
			cands.append(d + t + ext)
	for p in cands:
		if ResourceLoader.exists(p):
			return load(p)
		if FileAccess.file_exists(p) and (p.to_lower().ends_with(".wav") or p.to_lower().ends_with(".ogg")):
			var s: AudioStream = AudioStreamWAV.load_from_file(p) if p.to_lower().ends_with(".wav") else AudioStreamOggVorbis.load_from_file(p)
			if s != null:
				return s
	return null

func music_play(track: String, start_s: float) -> void:
	var st := music_resolve(track)
	if st == null:
		if track != "":
			op_requested.emit("toast", "【章节音乐】轨未找到：%s（.ogg/.wav——data/music/ 或宿主 music 目录，按名或全路径）" % track, "music")
		return
	_music_loop_range = PackedFloat32Array()
	_music_a.stream = st
	_music_a.volume_db = 0.0
	_music_a.play(start_s)
	_music_track = track

func chapter_music(mem: Dictionary, _reentry := false) -> void:
	var plan := str(mem.get("music_plan", "")).strip_edges()
	var pl := plan.to_lower()
	var track := str(mem.get("music_track", "")).strip_edges()
	var start_s := float(str(mem.get("music_start", ""))) if str(mem.get("music_start", "")) != "" else 0.0
	if pl == "" or pl == "continue":
		## 不重复：同轨继续上一章播放进度（scheme）；换轨=从起始点起
		if track != "" and _music_track != track:
			music_play(track, start_s)
		return
	if pl.begins_with("loop"):
		music_play(track, start_s)
		var args := pl.substr(4).strip_edges().lstrip(":")
		var pts := args.split(",")
		if pts.size() >= 1 and pts[0].strip_edges().is_valid_float():
			var a := float(pts[0])
			var b := -1.0
			if pts.size() >= 2 and pts[1].strip_edges().is_valid_float():
				b = float(pts[1])
			if b < 0.0:
				if str(mem.get("loop", "")) != "slug":
					op_requested.emit("toast", "【章节音乐】内循环缺终点仅支持迟滞（slug）章节", "music")
				else:
					_music_loop_range = PackedFloat32Array([a, b])
			else:
				_music_loop_range = PackedFloat32Array([a, b])
		return
	if pl == "hard":
		music_play(track, start_s) ## 硬起始：直接从起始点开始
		return
	if pl == "soft":
		## 软起始：等功率转场（旧轨 cos 衰减/新轨 sin 起升，2 秒——scheme"前后若干秒"）
		var st2 := music_resolve(track)
		if st2 == null:
			if track != "":
				op_requested.emit("toast", "【章节音乐】轨未找到：%s（.ogg/.wav）" % track, "music")
			return
		var np := _music_b
		np.stream = st2
		np.volume_db = linear_to_db(0.0001)
		np.play(start_s)
		_music_track = track
		_music_loop_range = PackedFloat32Array()
		_xfade_in = np
		_xfade_out = _music_a
		var tw := create_tween()
		tw.tween_method(_xfade_step, 0.0, 1.0, 2.0)
		tw.tween_callback(_xfade_done)
		return
	if pl.begins_with("sfx"):
		sfx_fade_and_play(track, start_s, plan)
		return
	op_requested.emit("toast", "【章节音乐】未知方案：%s（continue/hard/soft/sfx/loop:A[,B]）" % plan, "music")

func _xfade_step(p: float) -> void:
	if _xfade_in != null:
		_xfade_in.volume_db = linear_to_db(maxf(sin(p * PI / 2.0), 0.0001))
	if _xfade_out != null:
		_xfade_out.volume_db = linear_to_db(maxf(cos(p * PI / 2.0), 0.0001))

func _xfade_done() -> void:
	if _xfade_out != null:
		_xfade_out.stop()
		_xfade_out.volume_db = 0.0
	if _xfade_in != null:
		_xfade_in.volume_db = 0.0
		var old_a := _music_a
		_music_a = _xfade_in
		_music_b = old_a
	_xfade_in = null
	_xfade_out = null

func sfx_fade_and_play(track: String, start_s: float, plan: String) -> void:
	## 音效起始（scheme）：旧轨 fade 秒内渐弱→静音→[音效]→delay 秒后从起始点播放
	var fade := 2.0
	var delay := 1.0
	var sfxp := ""
	var argstr := plan.substr(3).strip_edges().lstrip(":")
	for seg in argstr.split(";"):
		var s := seg.strip_edges()
		if s == "":
			continue
		var ci := s.find(":")
		if ci > 0:
			var k := s.substr(0, ci).to_lower()
			var v := s.substr(ci + 1).strip_edges()
			if k == "fade" and v.is_valid_float():
				fade = float(v)
			elif k == "delay" and v.is_valid_float():
				delay = float(v)
			elif k == "sfx":
				sfxp = v
		else:
			sfxp = s
	_sfx_pending = {"track": track, "start": start_s, "sfx": sfxp}
	var tw := create_tween()
	tw.tween_method(_sfx_fade_step, 0.0, 1.0, maxf(fade, 0.1))
	tw.tween_callback(_sfx_silence)
	tw.tween_interval(maxf(delay, 0.1))
	tw.tween_callback(_sfx_then_play)

func _sfx_fade_step(p: float) -> void:
	if _music_a != null and _music_a.playing:
		_music_a.volume_db = linear_to_db(maxf(cos(p * PI / 2.0), 0.0001))

func _sfx_silence() -> void:
	if _music_a != null:
		_music_a.stop()
		_music_a.volume_db = 0.0
	var sfxp := str(_sfx_pending.get("sfx", ""))
	if sfxp != "" and _sfx_player != null:
		var st := music_resolve(sfxp)
		if st != null:
			_sfx_player.stream = st
			_sfx_player.play()

func _sfx_then_play() -> void:
	if _sfx_player != null:
		_sfx_player.stop()
	music_play(str(_sfx_pending.get("track", "")), float(_sfx_pending.get("start", 0.0)))

func _music_tick() -> void:
	## 内循环区间守门：播到 B 回 A（B<0=到结束仅 slug 语义，无 B 界）
	if _music_loop_range.size() == 2 and _music_a != null and _music_a.playing:
		var b := _music_loop_range[1]
		if b >= 0.0 and _music_a.get_playback_position() >= b:
			_music_a.seek(_music_loop_range[0])

func _video_note() -> void:
	pass ## 视频背景归宿主渲染（background_changed 信号）——内核无视频面
