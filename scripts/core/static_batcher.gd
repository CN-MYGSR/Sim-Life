extends RefCounted
class_name StaticBatcher
## Batch immutable, opaque BoxMesh visuals. Collision bodies stay untouched.
## Call only after generation/pruning, never on interactive or animated geometry.

static func batch_boxes(root: Node3D) -> int:
	var groups := {}
	_collect(root, root, groups)
	var shared_box := BoxMesh.new()
	shared_box.size = Vector3.ONE
	var removed := 0
	for key in groups:
		var items: Array = groups[key]
		if items.size() < 2:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = shared_box
		mm.instance_count = items.size()
		var first: MeshInstance3D = items[0]
		var instance := MultiMeshInstance3D.new()
		instance.name = "StaticFurnitureBatch"
		instance.multimesh = mm
		instance.material_override = first.material_override
		instance.cast_shadow = first.cast_shadow
		root.add_child(instance)
		for i in range(items.size()):
			var mesh_instance: MeshInstance3D = items[i]
			var local := root.global_transform.affine_inverse() * mesh_instance.global_transform
			local.basis *= Basis.from_scale(mesh_instance.mesh.size)
			mm.set_instance_transform(i, local)
			mesh_instance.free()
			removed += 1
	return removed

static func _collect(node: Node, root: Node3D, groups: Dictionary) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh and child.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = child.material_override
			if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mat.albedo_texture != null or mat.next_pass != null:
				continue
			var key := "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
				mat.albedo_color.to_html(), mat.roughness, mat.metallic,
				mat.emission_enabled, mat.emission.to_html(), mat.emission_energy_multiplier,
				mat.shading_mode, mat.cull_mode, child.cast_shadow]
			if not groups.has(key):
				groups[key] = []
			groups[key].append(child)
		else:
			_collect(child, root, groups)
