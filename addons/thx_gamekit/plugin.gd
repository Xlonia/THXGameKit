@tool
extends EditorPlugin
## 【Dialogic 式主屏页签 20261114（作者：场景编辑参考 Dialogic 的页签形态）】
## Godot 编辑器顶部出现"THXGameKit"主屏 tab（与 2D/3D/脚本并列）——
## 内容=ScenarioEditor（四子标签：场景树/UI 画布/逻辑链/内核引用），
## 与自制编辑器顶栏"场景"页签同一实现（双形态单源）。
var _main_screen: Control = null

func _enter_tree() -> void:
	print("[THXGameKit] 数据基底就绪：弹幕事件/表达式/材质/时间轴/角色表/场景")

## 【主屏恢复 20261114（作者裁定：直接 @tool 化改造）】内核数据链已 @tool 头
## （kit.gd 环境门：编辑器只推路径基址不重装载）——全局类在编辑器可用，
## 主屏 tab 回归；场景编辑双形态单源（此处与游戏内"场景"页签同一 ScenarioEditor）
func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "THXGameKit"

func _make_visible(visible: bool) -> void:
	if _main_screen == null:
		_main_screen = Control.new()
		_main_screen.name = "THXGameKitScenario"
		## 【路径自推导 20261114】编辑器环境 autoload（THXKit）不保证存在——
		## 从 plugin.gd 自身位置推导（挂载点无关）：…/kit/addons/thx_gamekit/plugin.gd
		var self_dir: String = get_script().resource_path.get_base_dir()
		_main_screen.set_script(load(self_dir.path_join("editor/scenario_editor.gd")))
		get_editor_interface().get_editor_main_screen().add_child(_main_screen)
		_main_screen.hide()
	_main_screen.visible = visible

