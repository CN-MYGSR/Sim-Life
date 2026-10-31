extends Node3D
## Temp inspection: dump imported Lo Polly animals GLB scene structure, bounds, materials, animation data.

const GLB := "res://assets/animals/Lo Polly animals FREE.glb"


func _ready() -> void:
	print("=== GLB: ", GLB)
	var ps: PackedScene = load(GLB)
	if ps == null:
		print("LOAD_FAILED")
		get_tree().quit()
		return
	var inst: Node3D = ps.instantiate()
	add_child(inst)
	_dump_tree(inst, 0)
	print("=== SKELETON/ANIM FINDS")
	print("  AnimationPlayer count: ", _count_type(inst, "AnimationPlayer"))
	print("  Skeleton3D count: ", _count_type(inst, "Skeleton3D"))
	var ap := _find_ap(inst)
	print("  first AP: ", ap)
	if ap:
		print("  anims=", ap.get_animation_list())
	print("=== ROOT-LEVEL ANIM NODES (owner check)")
	for c in inst.get_children():
		print("  child=", c.name, " class=", c.get_class(), " owner=", c.owner.name if c.owner else "<null>")
	get_tree().quit()


func _dump_tree(n: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	var extra := ""
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		var mesh := mi.mesh
		var aabb := mi.get_aabb()
		var g := mi.global_transform * aabb
		var mats: Array = []
		for s in range(mesh.get_surface_count()):
			var m: Material = mesh.surface_get_material(s)
			mats.append(m.resource_name if m else "<null>")
		extra = " mesh=%s aabb=%s global_size=%s surf=%d mats=%s" % [
			mesh.resource_name, aabb, g.size, mesh.get_surface_count(), mats]
	elif n is Node3D:
		var n3: Node3D = n
		extra = " pos=%s rot=%s scale=%s" % [n3.position, n3.rotation_degrees, n3.scale]
	print(pad, n.name, " [", n.get_class(), "]", extra)
	for c in n.get_children():
		_dump_tree(c, depth + 1)


func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r:
			return r
	return null


func _count_type(n: Node, cls: String) -> int:
	var k := 1 if n.is_class(cls) else 0
	for c in n.get_children():
		k += _count_type(c, cls)
	return k
