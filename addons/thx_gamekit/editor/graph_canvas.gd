extends Control
## 逻辑链节点图画布（骨架）：节点/连线/求值下轮——当前画示例占位节点
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.07, 0.08, 0.12))
	## 示例三节点：时间轴触发 → 条件 → 动作（作者裁定：触发器=时间轴/场景）
	var nodes := [
		[Vector2(40, 120), Color(0.55, 0.75, 1.0), "触发：时间轴"],
		[Vector2(240, 120), Color(1.0, 0.8, 0.45), "条件：…"],
		[Vector2(440, 120), Color(0.55, 1.0, 0.7), "动作：…"],
	]
	for i in nodes.size() - 1:
		var a: Vector2 = nodes[i][0] + Vector2(150, 22)
		var b: Vector2 = nodes[i + 1][0]
		draw_line(a, b, Color(1, 1, 1, 0.35), 2.0)
	for n in nodes:
		var r := Rect2(n[0], Vector2(150, 44))
		draw_rect(r, Color(0.1, 0.12, 0.18))
		draw_rect(r, n[1], false, 1.4)
		draw_string(ThemeDB.fallback_font, n[0] + Vector2(12, 28), str(n[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.85))
