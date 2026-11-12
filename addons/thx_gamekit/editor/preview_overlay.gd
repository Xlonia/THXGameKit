class_name PreviewOverlay
extends Control
## 展示画布（弹幕编辑器通用参数页·专属行列内）
##   布局（作者 20261112 规格）：外框=本画布；材质/判定盒/中心都画在中央
##   **框内 1/2 尺寸区域**（128 画布→材质 64px，NEAREST 不糊）；
##   红=判定盒判定区（白像素）；橙点+橙圈=旋转-运动中心
## 【交互 20261112】
##   · 旋转-运动中心：鼠标按住橙点拖动——**恒 snap 0.5 像素网格**
##     （作者裁定：不论如何运动中心只能是 0.5 的整数倍），拖动中 emit spin_changed
##   · 判定盒编辑（edit_mode=true 且 edit_img 有效）：左键按住=绘制白像素
##     （=判定），右键按住=擦去（黑=无判定）；松开 emit hitbox_edited
## 【信号契约】编辑器接 spin_changed(sx, sy) 写回事件定值列；
##   hitbox_edited(image) 存 editor_textures+绑定 hitbox_name

var base_tex: Texture2D = null
var hitbox_img: Image = null
var spin_center := Vector2.ZERO
var show_hitbox := true
var show_spin := true
## 判定盒编辑模式（编辑器"编辑判定盒"开关）：
var edit_mode := false
var edit_img: Image = null       ## 可写位图（编辑器构造/传入；尺寸=材质）
var _drag_spin := false          ## 中心拖动中
var _paint_btn := 0              ## 绘制中的鼠标键（0=无）

signal spin_changed(sx: float, sy: float)
signal hitbox_edited(img: Image)

## 中央显示盒（1/2 画布宽的正方形，居中）与像素换算比例
func _box_rect() -> Rect2:
	var side := minf(size.x, size.y) * 0.5
	return Rect2(Vector2((size.x - side) * 0.5, (size.y - side) * 0.5), Vector2(side, side))

func _px_scale() -> float:
	var bs := base_tex.get_size() if base_tex != null else Vector2(16, 16)
	return _box_rect().size.x / maxf(maxf(bs.x, bs.y), 1.0) ## 材质最长边铺满显示盒（保比居中）

func _tex_to_screen(tp: Vector2) -> Vector2:
	var box := _box_rect()
	var bs := base_tex.get_size() if base_tex != null else Vector2(16, 16)
	var k := _px_scale()
	var drawn := bs * k
	return box.get_center() - drawn * 0.5 + tp * k

func _screen_to_tex(sp: Vector2) -> Vector2:
	var box := _box_rect()
	var bs := base_tex.get_size() if base_tex != null else Vector2(16, 16)
	var k := _px_scale()
	var drawn := bs * k
	return (sp - (box.get_center() - drawn * 0.5)) / k

func _draw() -> void:
	var sz := size
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.07, 0.08, 0.12))
	## 外框（展示区边界——材质不再布满整框）
	var box := _box_rect()
	draw_rect(box, Color(0.45, 0.5, 0.62, 0.9), false, 1.0)
	var bs := base_tex.get_size() if base_tex != null else Vector2(16, 16)
	var k := _px_scale()
	var drawn := bs * k
	var origin := box.get_center() - drawn * 0.5
	## 材质（居中于框内）
	if base_tex != null:
		draw_texture_rect(base_tex, Rect2(origin, drawn), false, Color(1, 1, 1, 0.9))
	## 判定盒覆盖（编辑中用 edit_img 实时反馈；否则用 hitbox_img 只读图）
	var show_img: Image = edit_img if edit_mode and edit_img != null else hitbox_img
	if show_hitbox and show_img != null:
		var isz := Vector2(show_img.get_width(), show_img.get_height())
		var hk_origin := box.get_center() - isz * k * 0.5
		var htex := ImageTexture.create_from_image(show_img)
		draw_texture_rect(htex, Rect2(hk_origin, isz * k), false, Color(1.0, 0.3, 0.3, 0.55))
	## 旋转-运动中心（材质像素系→显示系；默认 0,0=材质几何中心）
	if show_spin:
		var center_px := bs * 0.5 + spin_center
		var cp := _tex_to_screen(center_px)
		draw_line(Vector2(cp.x - 9, cp.y), Vector2(cp.x + 9, cp.y), Color(1.0, 0.7, 0.1), 1.4)
		draw_line(Vector2(cp.x, cp.y - 9), Vector2(cp.x, cp.y + 9), Color(1.0, 0.7, 0.1), 1.4)
		draw_arc(cp, 6.0, 0, TAU, 16, Color(1.0, 0.7, 0.1), 1.2)
		draw_string(ThemeDB.fallback_font, cp + Vector2(11, -6), "spin", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.7, 0.1))

func _gui_input(event: InputEvent) -> void:
	if base_tex == null:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			var tp := _screen_to_tex(mb.position)
			var bs := base_tex.get_size()
			var center_px := bs * 0.5 + spin_center
			## 中心点命中（±12 显示像素）→ 中心拖动（优先于绘制）
			if show_spin and _tex_to_screen(center_px).distance_to(mb.position) <= 12.0:
				_drag_spin = true
				accept_event()
				return
			## 判定盒绘制（编辑模式下左=画右=擦）
			if edit_mode and edit_img != null:
				_paint_btn = mb.button_index
				_paint_at(tp)
				accept_event()
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).button_mask != 0:
		var mm := event as InputEventMouseMotion
		var tp := _screen_to_tex(mm.position)
		if _drag_spin:
			## 中心=鼠标-材质几何中心；**恒 0.5 整数倍**（作者裁定）
			var bs := base_tex.get_size()
			var v := tp - bs * 0.5
			spin_center = Vector2(roundf(v.x * 2.0) * 0.5, roundf(v.y * 2.0) * 0.5)
			spin_changed.emit(spin_center.x, spin_center.y)
			queue_redraw()
			accept_event()
		elif _paint_btn != 0 and edit_mode and edit_img != null:
			_paint_at(tp)
			accept_event()
	elif event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		var mb2 := event as InputEventMouseButton
		if _drag_spin:
			_drag_spin = false
			accept_event()
		elif _paint_btn != 0:
			_paint_btn = 0
			if edit_img != null:
				hitbox_edited.emit(edit_img) ## 松开=提交（编辑器落盘）
			accept_event()

## 绘制/擦除一个像素（材质系取整；越界忽略）
func _paint_at(tp: Vector2) -> void:
	var p := Vector2i(int(floor(tp.x)), int(floor(tp.y)))
	if p.x < 0 or p.y < 0 or p.x >= edit_img.get_width() or p.y >= edit_img.get_height():
		return
	var on: bool = _paint_btn == MOUSE_BUTTON_LEFT ## 左=白(判定) 右=黑(擦去)
	edit_img.set_pixelv(p, Color(1, 1, 1, 1) if on else Color(0, 0, 0, 1))
	queue_redraw()
