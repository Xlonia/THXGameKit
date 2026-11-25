@tool
extends EditorPlugin
## =============================================================
## 【消望插件 plugin.gd（m125 插件化第一批——作者批复 20261125）】
## 最小实现：无编辑器侵入逻辑。职责=
##   ① 编辑器插件列表可独立启停（plugin.cfg 入口）
##   ② 玩法运行时全部在 versus/ + ui/（宿主场景挂脚本消费）
## 【autoload 约定】GameGlobals 由项目 project.godot 显式配置指向
## 本插件 game_globals.gd（真全局——编辑器兼容层 game_globals_compat
## 已退役：字段面四函数 sync_official/save_timeline/reload/goto 全兼容）
## 【后续批】.thx manifest 内容域注册 API（作者批复③=独立新一批）
## =============================================================


func _enter_tree() -> void:
	print("[keshinozo] 消望插件启用（versus 自走棋玩法层）")
	## 【m126 内容域注册（作者批复③）】arrange=杂兵排布字典（自走棋对战语义）
	var kit := get_node_or_null("/root/THXKit") ## autoload 双环境恒在
	if kit != null and kit.has_method("register_content_plugin"):
		kit.register_content_plugin("keshinozo", ["arrange"])


func _exit_tree() -> void:
	pass
