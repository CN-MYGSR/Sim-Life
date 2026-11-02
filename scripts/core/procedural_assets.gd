extends RefCounted
class_name ProceduralAssets
## Original low-poly replacements, distributed under the repository's Unlicense.
## Optional Quaternius imports still take priority when installed.

static var _materials: Dictionary = {}

static func material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.88
		_materials[key] = mat
	return _materials[key]

static func module_mesh(module_name: String) -> Mesh:
	var color := Color(0.52, 0.34, 0.27)
	if module_name.begins_with("Metal"):
		color = Color(0.40, 0.46, 0.50)
	elif module_name.begins_with("Trim") or module_name.contains("Column"):
		color = Color(0.70, 0.67, 0.59)
	var parts: Array = []
	if module_name.begins_with("DoorFrame"):
		parts = [
			[Vector3(-0.9, 1.5, 0), Vector3(0.2, 3, 0.32), color],
			[Vector3(0.9, 1.5, 0), Vector3(0.2, 3, 0.32), color],
			[Vector3(0, 2.85, 0), Vector3(1.6, 0.3, 0.32), color]]
	elif module_name == "Door_1":
		parts = [[Vector3(0.45, 1.3, 0), Vector3(0.9, 2.6, 0.08), Color(0.25, 0.20, 0.16)]]
	elif module_name.contains("Column"):
		parts = [[Vector3(0, 1.5, 0), Vector3(0.45, 3, 0.45), color]]
	elif module_name.begins_with("Prop_"):
		parts = [[Vector3(0, 0.4, 0), Vector3(1, 0.8, 0.7), Color(0.48, 0.50, 0.52)]]
	elif module_name.contains("Cornice"):
		parts = [[Vector3(0, 0.15, 0), Vector3(2, 0.3, 0.5), color.lightened(0.15)]]
	elif module_name.contains("Window"):
		parts = [
			[Vector3(-0.85, 1.5, 0), Vector3(0.3, 3, 0.3), color],
			[Vector3(0.85, 1.5, 0), Vector3(0.3, 3, 0.3), color],
			[Vector3(0, 0.4, 0), Vector3(1.4, 0.8, 0.3), color],
			[Vector3(0, 2.7, 0), Vector3(1.4, 0.6, 0.3), color],
			[Vector3(0, 1.6, -0.03), Vector3(1.4, 1.6, 0.1), Color(0.12, 0.23, 0.30)],
			[Vector3(0, 1.6, 0.06), Vector3(0.06, 1.6, 0.12), color.lightened(0.25)]]
	else:
		parts = [[Vector3(0, 1.5, 0), Vector3(2, 3, 0.3), color]]
	# One surface per color, still instanced through the existing MultiMesh path.
	var groups := {}
	for part in parts:
		var key: String = part[2].to_html()
		if not groups.has(key):
			groups[key] = []
		groups[key].append(part)
	var result := ArrayMesh.new()
	for key in groups:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part in groups[key]:
			var box := BoxMesh.new()
			box.size = part[1]
			surface.append_from(box, 0, Transform3D(Basis.IDENTITY, part[0]))
		surface.set_material(material(Color.html(key)))
		surface.commit(result)
	return result

static func person() -> Node3D:
	var root := Node3D.new()
	root.name = "ProceduralPerson"
	var shirt := Color(0.25, 0.40, 0.56)
	var skin := Color(0.78, 0.58, 0.43)
	var pants := Color(0.17, 0.21, 0.28)
	_add_part(root, "Torso", Vector3(0, 1.12, 0), Vector3(0.48, 0.58, 0.25), shirt)
	_add_part(root, "Head", Vector3(0, 1.57, 0), Vector3(0.28, 0.32, 0.28), skin)
	for side in [-1, 1]:
		var arm := _limb(root, "Arm%d" % side, Vector3(side * 0.32, 1.36, 0))
		_add_part(arm, "Sleeve", Vector3(0, -0.25, 0), Vector3(0.15, 0.5, 0.17), shirt)
		var leg := _limb(root, "Leg%d" % side, Vector3(side * 0.14, 0.84, 0))
		_add_part(leg, "Trouser", Vector3(0, -0.4, 0), Vector3(0.19, 0.8, 0.23), pants)
	var player := AnimationPlayer.new()
	root.add_child(player)
	var library := AnimationLibrary.new()
	for state in ["Idle", "Walk", "Run", "Death"]:
		var animation := Animation.new()
		animation.length = 0.7 if state == "Run" else 1.0
		animation.loop_mode = Animation.LOOP_NONE if state == "Death" else Animation.LOOP_LINEAR
		for side in [-1, 1]:
			for limb in ["Arm", "Leg"]:
				var track := animation.add_track(Animation.TYPE_VALUE)
				animation.track_set_path(track, NodePath("%s%d:rotation:x" % [limb, side]))
				var amplitude := 0.0 if state in ["Idle", "Death"] else 0.55
				var sign_value: int = side * (-1 if limb == "Arm" else 1)
				for i in range(5):
					animation.track_insert_key(track, animation.length * i / 4.0, sin(i * PI * 0.5) * amplitude * sign_value)
		if state == "Death":
			var track := animation.add_track(Animation.TYPE_VALUE)
			animation.track_set_path(track, NodePath(".:rotation:x"))
			animation.track_insert_key(track, 0, 0.0)
			animation.track_insert_key(track, 1, -PI * 0.5)
		library.add_animation(state, animation)
	player.add_animation_library("", library)
	return root

static func _limb(root: Node3D, part_name: String, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = part_name
	pivot.position = pos
	root.add_child(pivot)
	return pivot

static func _add_part(root: Node3D, part_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material(color)
	instance.position = pos
	root.add_child(instance)
