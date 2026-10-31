extends RefCounted
class_name KitLib
## Quaternius Downtown City MegaKit 模块库（CC0）
## 负责：实例化 .gltf 模块、批量 MultiMesh 渲染、生成简单碰撞盒 / 装饰盒子。
## 约定：模块以「米」为单位，墙模块高 3m、宽 2m，地板模块 4x4 / 2x2。

const DIR := "res://assets/kit/models/"

static var _scenes: Dictionary = {}
static var _meshes: Dictionary = {}


static func scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		_scenes[name] = load(DIR + name + ".gltf")
	return _scenes[name]


static func inst(name: String) -> Node3D:
	var ps: PackedScene = scene(name)
	if ps == null:
		push_warning("KitLib: missing module " + name)
		return Node3D.new()
	return ps.instantiate() as Node3D


static func place(parent: Node3D, name: String, pos: Vector3, rot_y := 0.0) -> Node3D:
	var n := inst(name)
	n.position = pos
	n.rotation.y = rot_y
	parent.add_child(n)
	return n


## 取模块的网格资源（用于 MultiMesh 合批）。为了性能，把导入材质简化为
## 只采样 BaseColor 贴图、固定粗糙度的材质，去掉法线/ORM 采样。
static func mesh_of(name: String) -> Mesh:
	if _meshes.has(name):
		return _meshes[name]
	var n := inst(name)
	var m := _find_mesh(n)
	var simple := _simplify(m)
	_meshes[name] = simple
	n.free()
	return simple


static func _simplify(m: Mesh) -> Mesh:
	if m == null or m.get_surface_count() == 0:
		return m
	var out := ArrayMesh.new()
	for i in range(m.get_surface_count()):
		var arr := m.surface_get_arrays(i)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat := m.surface_get_material(i)
		var sm := StandardMaterial3D.new()
		sm.roughness = 0.88
		sm.metallic = 0.0
		sm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		if mat is BaseMaterial3D:
			var bm := mat as BaseMaterial3D
			sm.albedo_color = bm.albedo_color
			sm.albedo_texture = bm.albedo_texture
			sm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		out.surface_set_material(out.get_surface_count() - 1, sm)
	return out


static func unit_box_mesh() -> BoxMesh:
	if not _meshes.has("__unit_box"):
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		_meshes["__unit_box"] = b
	return _meshes["__unit_box"]


## 把一组「尺寸不同的盒子」合批成一个 MultiMesh（用缩放变换表达尺寸）
static func box_multimesh(parent: Node3D, xforms: Array, color: Color) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = unit_box_mesh()
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	mmi.material_override = m
	parent.add_child(mmi)
	return mmi


static func _find_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			return mi.mesh
	for c in n.get_children():
		var r := _find_mesh(c)
		if r != null:
			return r
	return null


## 同一模块的多个实例合成一个 MultiMesh（大幅减少 draw call）
static func multimesh(parent: Node3D, name: String, xforms: Array) -> void:
	var mesh := mesh_of(name)
	if mesh == null or xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	parent.add_child(mmi)


static func solid(parent: Node3D, pos: Vector3, size: Vector3, rot_y := 0.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.position = pos
	sb.rotation.y = rot_y
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	parent.add_child(sb)
	return sb


## 斜面碰撞（楼梯）
static func solid_slope(parent: Node3D, pos: Vector3, size: Vector3, rot_x: float) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.position = pos
	sb.rotation.x = rot_x
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	parent.add_child(sb)
	return sb


## 一个 2m 宽的墙模块 + 碰撞盒（厚度默认 0.3m）
static func wall(parent: Node3D, name: String, pos: Vector3, rot_y := 0.0,
		collide := true, dims := Vector3(2.0, 3.0, 0.3)) -> Node3D:
	var n := place(parent, name, pos, rot_y)
	if collide:
		solid(parent, pos + Vector3(0, dims.y * 0.5, 0), dims, rot_y)
	return n


## 轴对齐盒子（装饰 / 家具 / 简化墙体），可选碰撞
static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color,
		collide := false, rough := 0.85, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	if collide:
		solid(parent, pos, size, rot_y)
	return mi


# ── 模块尺寸（碰撞用）────────────────────────────────────────
const DIMS := {
	"Brick_Plain_3": Vector3(2.0, 3.0, 0.28),
	"Brick_Plain_3_noWear": Vector3(2.0, 3.0, 0.28),
	"Brick_Plain_4": Vector3(2.0, 4.0, 0.28),
	"Brick_Window_Trim_Single": Vector3(2.0, 3.0, 0.3),
	"Brick_Window_Trim": Vector3(2.0, 3.0, 0.3),
	"Brick_Window_Square_Single": Vector3(2.0, 3.0, 0.3),
	"Brick_Inset_Window": Vector3(4.0, 3.0, 0.4),
	"Brick_Inset_Window_Curved": Vector3(4.0, 3.0, 0.4),
	"Brick_Inset_Window_Curved_Small": Vector3(4.0, 3.0, 0.4),
	"Brick_Window_CurvedDouble": Vector3(4.0, 3.0, 0.32),
	"Brick_RedWhite_DoubleWindow": Vector3(4.0, 3.0, 0.32),
	"Brick_Inset": Vector3(4.0, 3.0, 0.28),
	"Brick_InteriorWall_3": Vector3(2.0, 3.0, 0.25),
	"Brick_InteriorWall_4": Vector3(2.0, 4.0, 0.25),
	"Metal_Plain_3": Vector3(2.0, 3.0, 0.28),
	"Metal_FirstFloor_Wall": Vector3(2.0, 3.0, 0.32),
	"Metal_FirstFloor_Window": Vector3(2.0, 3.0, 0.34),
	"Metal_FullWindow": Vector3(2.0, 3.0, 0.3),
	"Metal_Window": Vector3(4.0, 3.0, 0.3),
	"Metal_Window_Half": Vector3(2.0, 3.0, 0.3),
	"Trim_Plain_3": Vector3(2.0, 3.0, 0.28),
	"Trim_FirstFloor_Wall": Vector3(2.0, 3.0, 0.32),
	"Trim_FirstFloor_Window_001": Vector3(2.0, 3.0, 0.3),
	"Trim_Window": Vector3(2.0, 3.0, 0.3),
	"DoorFrame_Trim": Vector3(2.0, 3.0, 0.28),
	"DoorFrame_Wooden": Vector3(2.3, 3.0, 0.5),
	"DoorFrame_Metal_Single": Vector3(2.0, 3.0, 0.28),
}
