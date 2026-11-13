extends Node
## thxp_probe —— .thxp 双格式探针（headless 可跑）
##   ①格式识别（packed/reference/未知）
##   ②to_reference：解压 projectdata+JSON 清单+packed.bak
##   ③to_packed：收集回打包+reference.bak+内容一致性
##   ④copy_external：外引复制
func _ready() -> void:
	var fails := 0
	var name := "probe_dual"
	var path := "user://%s.thxp" % name
	## 造打包版（CSV 载荷）
	var zw := ZIPPacker.new()
	zw.open(path)
	zw.start_file("danmaku_event.csv")
	zw.write_file("Name\nprobe_row\n".to_utf8_buffer())
	zw.close_file()
	zw.close()
	var ok1: bool = THXKit.thxp_format(path) == "packed"
	print("  %s 格式识别 packed（=%s）" % ["PASS" if ok1 else "FAIL", THXKit.thxp_format(path)])
	if not ok1: fails += 1
	## ②转引用
	var ok2: bool = THXKit.thxp_to_reference(path)
	var base := THXKit.projectdata_dir(name)
	var extracted: bool = FileAccess.file_exists(base.path_join("danmaku_event.csv"))
	var json_head := FileAccess.get_file_as_string(path).substr(0, 1) == "{"
	var bak: bool = FileAccess.file_exists(path + ".packed.bak")
	var ok_all2: bool = ok2 and extracted and json_head and bak
	print("  %s 转引用（解压=%s 清单=%s 备份=%s）" % ["PASS" if ok_all2 else "FAIL", extracted, json_head, bak])
	if not ok_all2: fails += 1
	## ③回打包
	var ok3: bool = THXKit.thxp_to_packed(path)
	var head2 := FileAccess.get_file_as_string(path).substr(0, 2)
	var bak2: bool = FileAccess.file_exists(path + ".reference.bak")
	var zr := ZIPReader.new()
	var content_ok := false
	if zr.open(path) == OK:
		if zr.file_exists("danmaku_event.csv"):
			content_ok = zr.read_file("danmaku_event.csv").get_string_from_utf8().contains("probe_row")
		zr.close()
	var ok_all3: bool = ok3 and head2 == "PK" and bak2 and content_ok
	print("  %s 回打包（PK=%s 备份=%s 内容=%s）" % ["PASS" if ok_all3 else "FAIL", head2 == "PK", bak2, content_ok])
	if not ok_all3: fails += 1
	## ④外引复制（从打包版再解压一份）
	var ok4: bool = THXKit.thxp_copy_external(path) and FileAccess.file_exists(base.path_join("danmaku_event.csv"))
	print("  %s 外引复制" % ["PASS" if ok4 else "FAIL"])
	if not ok4: fails += 1
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".packed.bak")
	DirAccess.remove_absolute(path + ".reference.bak")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(base))
	print("THXP_OK" if fails == 0 else "THXP_FAIL %d" % fails)
	get_tree().quit(0 if fails == 0 else 1)
