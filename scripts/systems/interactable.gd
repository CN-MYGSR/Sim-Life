extends StaticBody3D
class_name Interactable
## 通用可交互物：射线打中后显示 prompt，按 E 触发 action

@export var prompt: String = "交互"
var action: Callable = Callable()
var enabled: bool = true
var highlight: MeshInstance3D = null


func interact(_player: Node3D) -> void:
	if not enabled:
		return
	if action.is_valid():
		action.call()


func set_prompt(p: String) -> void:
	prompt = p


static func create(parent: Node3D, pos: Vector3, size: Vector3, text: String, cb: Callable) -> Interactable:
	var it := Interactable.new()
	it.collision_layer = 1 << 4      # layer 5: interact
	it.collision_mask = 0
	it.position = pos
	it.prompt = text
	it.action = cb
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	it.add_child(cs)
	parent.add_child(it)
	return it
