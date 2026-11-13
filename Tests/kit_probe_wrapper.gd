extends Node
## kit 探针 wrapper：脚本直实例化内核探针；挂 root（探针做 change_scene
## 验证时自身不被连坐——监视器存活到 quit）
@export var probe_script: GDScript
func _ready() -> void:
	var n := Node.new()
	n.set_script(probe_script)
	get_tree().root.add_child.call_deferred(n)
