extends Node
## ext_smoke —— C++ 扩展在内核工程内的装载验证（headless 可跑）
func _ready() -> void:
	var fails := 0
	for cls in ["Th75BulletHot", "Th75MotionHot", "Th75BulletHashCpp", "Th75BulletSetup"]:
		var ok := ClassDB.class_exists(cls)
		print("  %s %s 装载" % ["PASS" if ok else "FAIL", cls])
		if not ok: fails += 1
	## BulletHot 实测：表达式求值（C++ 路径生效）
	if ClassDB.class_exists("Th75BulletHot"):
		var hot: Object = ClassDB.instantiate("Th75BulletHot") as Object
		var err: String = str(hot.compile("sin(t)*60+2", ["t"]))
		var v: float = float(hot.eval([3.0], 0.0))
		var ok: bool = err == "" and absf(v - (sin(3.0) * 60.0 + 2.0)) < 0.001
		print("  %s BulletHot 求值（sin(t)*60+2 @ t=3 → %.3f）" % ["PASS" if ok else "FAIL", v])
		if not ok: fails += 1
	## DanmakuExpr 自动走 C++（类存在即启用）
	var e := DanmakuExpr.new()
	e.compile("60+2", [])
	var ok2: bool = float(e.execute([], 0.0)) == 62.0
	print("  %s DanmakuExpr 常量求值（%s）" % ["PASS" if ok2 else "FAIL", str(e.execute([], 0.0))])
	if not ok2: fails += 1
	print("EXT_OK" if fails == 0 else "EXT_FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
