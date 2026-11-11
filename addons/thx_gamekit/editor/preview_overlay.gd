class_name PreviewOverlay
extends Control
## 材质/判定盒/旋转中心 覆盖显示画布（弹幕编辑器通用参数页·专属行列内）
##   底=材质灰显；红=判定盒图半透明叠加；橙点+橙圈=旋转-运动中心
## 【开关变量 20261112】编辑器"判定盒显示/旋转中心显示"两按钮写入——
##   上一轮按钮赋值时本类缺这两个变量（赋值即无效属性报错）

var base_tex: Texture2D = null
var hitbox_img: Image = null
var spin_center := Vector2.ZERO
var show_hitbox := true
var show_spin := true

func _draw() -> void:
	var sz := size
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.07, 0.08, 0.12))
	if base_tex != null:
		draw_texture_rect(base_tex, Rect2(Vector2.ZERO, sz), false, Color(1, 1, 1, 0.85))
	## 判定盒图半透明红叠加（开关=编辑器画布旁按钮）
	if show_hitbox and hitbox_img != null:
		var htex := ImageTexture.create_from_image(hitbox_img)
		draw_texture_rect(htex, Rect2(Vector2.ZERO, sz), false, Color(1, 0.35, 0.35, 0.45))
	## 旋转-运动中心（材质像素系→显示系线性换算；默认 0,0=几何中心）
	if show_spin:
		var bs := base_tex.get_size() if base_tex != null else Vector2(16, 16)
		var scale_f := sz.x / maxf(bs.x, 1.0)
		var center_px := bs * 0.5 + spin_center
		var cp := center_px * scale_f
		draw_line(Vector2(cp.x - 8, cp.y), Vector2(cp.x + 8, cp.y), Color(1.0, 0.7, 0.1), 1.2)
		draw_line(Vector2(cp.x, cp.y - 8), Vector2(cp.x, cp.y + 8), Color(1.0, 0.7, 0.1), 1.2)
		draw_arc(cp, 5.0, 0, TAU, 16, Color(1.0, 0.7, 0.1), 1.0)
		draw_string(ThemeDB.fallback_font, cp + Vector2(10, -6), "spin", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1.0, 0.7, 0.1))
