extends Control
## 场景 UI 画布（骨架）：工程画布框+像素网格——控件拖放下轮
func _draw() -> void:
	var w := int(THXKit.scenario_cfg.get("canvas_w", 400))
	var h := int(THXKit.scenario_cfg.get("canvas_h", 400))
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.04, 0.05, 0.09))
	## 网格（40px 主格）
	var g := 40
	var x := 0
	while x <= w:
		draw_line(Vector2(x, 0), Vector2(x, h), Color(1, 1, 1, 0.06), 1.0)
		x += g
	var y := 0
	while y <= h:
		draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.06), 1.0)
		y += g
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.45, 0.5, 0.62, 0.9), false, 1.0)
