@tool
extends EditorPlugin
## 【Dialogic 式主屏页签 20261114（作者：场景编辑参考 Dialogic 的页签形态）】
## Godot 编辑器顶部出现"THXGameKit"主屏 tab（与 2D/3D/脚本并列）——
## 内容=ScenarioEditor（四子标签：场景树/UI 画布/逻辑链/内核引用），
## 与自制编辑器顶栏"场景"页签同一实现（双形态单源）。
var _main_screen: Control = null

func _enter_tree() -> void:
	print("[THXGameKit] 数据基底就绪：弹幕事件/表达式/材质/时间轴/角色表/场景")

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "THXGameKit"

func _make_visible(visible: bool) -> void:
	if _main_screen == null:
		_main_screen = Control.new()
		_main_screen.name = "THXGameKitScenario"
		var scr_path := "res://addons/thx_gamekit/editor/scenario_editor.gd"
		## 挂载点无关：submodule 情形 kit.gd 在宿主 autoload 推导实际路径
		var kit := get_tree().root.get_node_or_null("THXKit")
		if kit != null and kit.has_method("kpath"):
			scr_path = kit.kpath(scr_path)
		_main_screen.set_script(load(scr_path))
		get_editor_interface().get_editor_main_screen().add_child(_main_screen)
		_main_screen.hide()
	_main_screen.visible = visible

