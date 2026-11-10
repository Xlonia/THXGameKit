extends Node2D
## =============================================================
## 试炼场（0.0.9·内核化 20261111）——内核自带的弹幕沙盒（窗口 A 雏形）：
## 编辑器"试炼场预览"=**替换主窗口**为本场景（0.0.7-legacy/0.0.8 行为；
## 编辑器工作集经 THXKit.editor_events 保留），Esc 面板=解除暂停/退出试炼场。
## 本场景只含内核件：EntityCore 发射者 + 弹幕运行时 + MultiMesh 渲染；
## 无玩法假设（无 P 点/态势/热力图——那些由玩法插件自带）。
## =============================================================

const FIELD := 400
var bullets: Array = []
var emitter: EntityCore = null
var frames := 0
var paused := false
var pause_panel: PanelContainer = null
var _by_tex: Dictionary = {}
var _mm_cache: Dictionary = {}
var _mm_last_cnt: Dictionary = {}
var _gctx := {"field_t": 0.0, "field_phase": 1}

func _ready() -> void:
	## 发射者=EntityCore（内核底座）；位置=场心
	emitter = EntityCore.new()
	emitter.setup({"Name": "emitter", "Cruise": 6, "Normal": 3, "Determine": 3}, 0, EntityCore.Kind.MEMBER, true)
	emitter.position = Vector2(200, 200)
	add_child(emitter)
	## 事件来源：编辑器预览指定名 → 编辑器工作集/官方池
	var ev: DanmakuEventData = null
	var pn := GameGlobals.preview_event_name
	if pn != "":
		ev = THXKit.get_event(pn)
	if ev == null and THXKit.editor_events.size() > 0:
		ev = THXKit.editor_events[0]
	if ev == null:
		for k in THXKit.official_events:
			ev = THXKit.official_events[k]
			break
	if ev != null:
		ev.compile()
		set_meta("preview_ev", ev)
		_spawn_volley(ev)
		print("[试炼场] 预览事件：%s（每 0.1s 一轮）" % ev.event_name)
	## 暂停面板（解除暂停/退出试炼场——作者 20261110 规格）
	pause_panel = PanelContainer.new()
	pause_panel.visible = false
	var box := VBoxContainer.new()
	pause_panel.add_child(box)
	var title := Label.new()
	title.text = "试炼场暂停"
	box.add_child(title)
	for txt in ["解除暂停", "退出试炼场"]:
		var btn := Button.new()
		btn.text = txt
		btn.pressed.connect(_on_pause_btn.bind(txt))
		box.add_child(btn)
	add_child(pause_panel)
	pause_panel.position = Vector2(160, 140)

func _spawn_volley(ev: DanmakuEventData) -> void:
	## 每 0.1s 一轮：从发射者位置释放一次事件（含旋转/重复子代自动展开）
	var b := Bullet.new()
	b.setup(ev, emitter.position, 0, emitter, self, 0)
	bullets.append(b)

func _on_pause_btn(txt: String) -> void:
	match txt:
		"解除暂停":
			pause_panel.visible = false
		"退出试炼场":
			## 【替换主窗口】回编辑器场景（工作集经 THXKit.editor_events 保留）
			GameGlobals.arena_mode = "editor"
			GameGlobals.goto_scene("res://scenes/danmaku_editor.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not event.echo:
		paused = not paused
		pause_panel.visible = paused
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_physical_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_physical_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_physical_key_pressed(KEY_DOWN): dir.y += 1
	if dir != Vector2.ZERO and emitter != null and not paused:
		emitter.move(dir, 1.0)

func _physics_process(delta: float) -> void:
	if paused:
		queue_redraw()
		return
	frames += 1
	_gctx["field_t"] = float(frames)
	if frames % 6 == 0 and has_meta("preview_ev"):
		_spawn_volley(get_meta("preview_ev"))
	var i := bullets.size() - 1
	while i >= 0:
		var b: Bullet = bullets[i]
		b.sync_shared(_gctx)
		if not b.update(1.0):
			bullets.remove_at(i)
		i -= 1
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2(-4, -4), Vector2(FIELD + 8, FIELD + 8)), Color(0.05, 0.07, 0.12, 1.0))
	draw_rect(Rect2(Vector2.ZERO, Vector2(FIELD, FIELD)), Color(0.55, 0.65, 0.85, 0.6), false, 1.0)
	draw_circle(emitter.position, 4.0, Color(1.0, 0.9, 0.4))
	## —— 弹幕 MultiMesh（按材质分组）——
	_by_tex.clear()
	for b in bullets:
		var bl: Bullet = b
		if bl.hidden_now or bl.ev.tag == DanmakuEventData.TAG_LASER:
			continue
		if not _by_tex.has(bl.tex):
			_by_tex[bl.tex] = []
		_by_tex[bl.tex].append(bl)
	for tex in _by_tex:
		var list: Array = _by_tex[tex]
		var mm := _get_mm(tex)
		var cnt: int = list.size()
		if cnt > mm.instance_count:
			mm.instance_count = cnt
		for i in cnt:
			var bl: Bullet = list[i]
			var xf := Transform2D(bl.draw_rotation(), bl.pos)
			xf = xf.scaled_local(Vector2(bl.size_mul, bl.size_mul))
			mm.set_instance_transform_2d(i, xf)
			var rc: Array = bl.render_color_alpha()
			mm.set_instance_color(i, Color(rc[0].r, rc[0].g, rc[0].b, rc[1]))
		if cnt < _mm_last_cnt.get(tex, 0):
			for i in range(cnt, _mm_last_cnt[tex]):
				mm.set_instance_transform_2d(i, Transform2D(0, Vector2(-9999, -9999)))
		_mm_last_cnt[tex] = cnt
		draw_multimesh(mm, tex)
	## —— 激光：线段绘制（laser_samples）——
	for b2 in bullets:
		var bl2: Bullet = b2
		if bl2.hidden_now or bl2.ev.tag != DanmakuEventData.TAG_LASER:
			continue
		if bl2.laser_samples.size() >= 2:
			draw_polyline(bl2.laser_samples, Color(1, 0.4, 0.4, 0.8), bl2.laser_width())

func _get_mm(tex: Texture2D) -> MultiMesh:
	if not _mm_cache.has(tex):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.instance_count = 0
		mm.mesh = _quad_mesh(tex)
		_mm_cache[tex] = mm
	return _mm_cache[tex]

func _quad_mesh(tex: Texture2D) -> Mesh:
	var sz: Vector2 = tex.get_size() if tex != null else Vector2(16, 16)
	var h := sz * 0.5
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([
		Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## —— Bullet 世界接口（试炼场桩：目标=鼠标假想敌；引爆链=同名事件再生）——
func bullet_nearest_enemy_pos(_side: int, from: Vector2) -> Vector2:
	return get_global_mouse_position().clamp(Vector2.ZERO, Vector2(400, 400)) if is_inside_tree() else from
func bullet_nearest_enemy_from(_side: int, from: Vector2) -> EntityCore:
	return null
func bullet_hit_query(_cx: float, _cy: float, _r: float, _side: int, _skip) -> Dictionary:
	return {}
func bullet_collapse_counts() -> Dictionary:
	return {"friendly_privates_collapse": 0.0, "enemy_privates_collapse": 0.0,
		"friendly_chara_collapes": 0.0, "enemy_chara_collapes": 0.0,
		"field_privates_collapse": 0.0, "field_chara_collapes": 0.0}
func spawn_event_by_name(event_name: String, at: Vector2, side: int, depth: int) -> void:
	if depth > Bullet.MAX_DEPTH:
		return
	var ev := THXKit.get_event(event_name)
	if ev == null or emitter == null:
		return
	var b := Bullet.new()
	b.setup(ev, at, side, emitter, self, depth)
	bullets.append(b)
