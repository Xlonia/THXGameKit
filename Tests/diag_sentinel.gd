extends Node
## diag_sentinel —— 卡死持续取证哨兵（作者令：多找原因）
##   挂 root 常驻：每帧记录 Performance 监控（fps/draw calls/objects/nodes/orphans）
##   +当前场景名+窗口状态——检测"空转段"（帧时间<1ms 连续 30 帧）自动落盘 csv
##   （下次复现自动捕获完整数据——重绘闭环 vs 空场景 vs Vulkan 可判）
var _frames := 0
var _rows: Array = []
var _spin_start := -1
var _spin_frames := 0
var _path := ""
func _ready() -> void:
	var t := Time.get_datetime_string_from_system().replace(":", "").replace("-", "")
	_path = "user://diag_sentinel_%s.csv" % t

func _notification(what: int) -> void:
	## 【退出落盘 20261114】进程 quit/场景切换时不丢数据
	if what == NOTIFICATION_EXIT_TREE and not _rows.is_empty():
		_flush("退出落盘（帧 %d）" % _frames)
func _process(_d: float) -> void:
	_frames += 1
	var ft: float = 1.0 / maxf(1.0, float(Engine.get_frames_per_second()))
	var fps := Engine.get_frames_per_second()
	var dc := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var objs := Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	var n := get_tree().get_node_count()
	var orph := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var cs := get_tree().current_scene
	var csname: String = cs.name if cs != null else "null"
	var sd := DisplayServer.window_get_mode()
	_rows.append([_frames, fps, "%.4f" % ft, dc, objs, n, orph, csname, sd])
	## 【检测条件修正 20261114（作者反馈哨兵未触发）】max_fps=60 后空转段 fps
	## 也被压到 60——fps>200 条件永远不触发。改判据=**渲染/树异常**：
	## ①有场景但零绘制（draw=0 持续 30 帧=渲染停摆）②树空壳（nodes<20）
	if (dc == 0 and csname != "null") or n < 20:
		if _spin_start < 0:
			_spin_start = _frames
		_spin_frames += 1
	else:
		if _spin_frames >= 30:
			_flush("异常段 %d 帧（起始帧 %d）" % [_spin_frames, _spin_start])
		_spin_start = -1
		_spin_frames = 0
	if _frames % 600 == 0:
		_flush("周期落盘（帧 %d）" % _frames)
func _flush(reason: String) -> void:
	var f := FileAccess.open(_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("frame,fps,frame_time_ms,draw_calls,objects,nodes,orphans,current_scene,window_mode\n")
	for r in _rows:
		f.store_string(",".join(r.map(func(x): return str(x))) + "\n")
	f.close()
	print("[diag_sentinel] %s → %s（%d 行）" % [reason, _path, _rows.size()])
