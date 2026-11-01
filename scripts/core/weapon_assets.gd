class_name WeaponAssets
extends RefCounted
## 武器资产目录（Synty POLYGON Military → Unidot Importer → Godot 4.7）
##
## 数据来源：`shots/weapon_catalog.md`，全部数值由转换脚本在导入后实测得到。
## 生成的 `.tscn` 已经"规整化"，可以直接当第一人称视图模型使用：
##   * 场景根节点 = 握把/扳机处的枢轴（手的位置），几何体已相对该枢轴摆好；
##   * 枪口朝 **-Z**（Godot 相机前方），上方为 +Y，与相机坐标一致；
##   * 长度单位为米（Synty Unity 工程按 1 unit = 1 m 导出，Unidot 未缩放）；
##   * 网格与材质已内嵌在 .tscn 里（自包含），贴图在 `assets/weapons/textures/`
##     （512×512，未超过 1024 上限）。
##
## 用法（挂到相机/手臂节点下）：
##   var gun := WeaponAssets.scene("m4").instantiate()
##   camera.add_child(gun)
##   gun.transform = Transform3D(Basis.IDENTITY, WeaponAssets.CATALOG["m4"].grip_offset)
##   # 枪口世界坐标：gun.global_transform * WeaponAssets.CATALOG["m4"].muzzle_offset
##
## 说明：
##   * `grip_rotation` 是"原始 Synty FBX → 枪口朝 -Z"所需的旋转（绕 Y 180°）。
##     交付的 .tscn 已经把该旋转烘焙进几何体，因此运行时**不需要**再次应用；
##     如果你的代码直接把原始 FBX 当模型加载，则需要应用它。
##   * `grip_offset` 是"枪柄根节点相对相机（手）的推荐位置"，单位为米，
##     相机空间：+X 右、+Y 上、-Z 前。
##   * `muzzle_offset` 是枪口在**场景根节点（握把枢轴）局部坐标**下的位置，
##     即 `gun.global_transform * muzzle_offset` 得到枪口世界坐标（用于枪焰/射线起点）。
##   * `scale` = 1.0（模型本身已是米制真实尺寸，不要再缩放）。

const WEAPON_IDS := ["glock", "m4", "ak", "mac10"]

const CATALOG := {
	"glock": {
		"name": "Glock 17",
		"source_model": "SM_Wep_Pistol_01",
		"model_path": "res://assets/weapons/glock.tscn",
		"scale": 1.0,
		"grip_rotation": Vector3(0.0, 180.0, 0.0),
		"grip_offset": Vector3(0.17, -0.17, -0.36),
		"muzzle_offset": Vector3(0.0, 0.0439, -0.1553),
		"tris": 1038,
		"bbox": Vector3(0.0432, 0.1869, 0.2792),
		"material": "res://assets/weapons/materials/PolygonMilitary_Weapon_Mat_01.material",
		"texture": "res://assets/weapons/textures/PolygonMilitary_Weapons_01.png",
	},
	"m4": {
		"name": "M4 卡宾枪",
		"source_model": "SM_Wep_Preset_A_Rifle_01",
		"model_path": "res://assets/weapons/m4.tscn",
		"scale": 1.0,
		"grip_rotation": Vector3(0.0, 180.0, 0.0),
		"grip_offset": Vector3(0.14, -0.16, -0.30),
		"muzzle_offset": Vector3(0.0, 0.0725, -0.6548),
		"tris": 3966,
		"bbox": Vector3(0.0944, 0.3292, 1.0305),
		"material": "res://assets/weapons/materials/PolygonMilitary_Weapon_Mat_01.material",
		"texture": "res://assets/weapons/textures/PolygonMilitary_Weapons_01.png",
	},
	"ak": {
		"name": "AK-47",
		"source_model": "SM_Wep_Preset_B_Rifle_01",
		"model_path": "res://assets/weapons/ak.tscn",
		"scale": 1.0,
		"grip_rotation": Vector3(0.0, 180.0, 0.0),
		"grip_offset": Vector3(0.14, -0.16, -0.30),
		"muzzle_offset": Vector3(0.0, 0.0691, -0.7023),
		"tris": 3846,
		"bbox": Vector3(0.0899, 0.4565, 1.1502),
		"material": "res://assets/weapons/materials/PolygonMilitary_Weapon_Mat_01.material",
		"texture": "res://assets/weapons/textures/PolygonMilitary_Weapons_01.png",
	},
	"mac10": {
		"name": "MAC-10",
		"source_model": "SM_Wep_Preset_B_SMG_01",
		"model_path": "res://assets/weapons/mac10.tscn",
		"scale": 1.0,
		"grip_rotation": Vector3(0.0, 180.0, 0.0),
		"grip_offset": Vector3(0.16, -0.16, -0.32),
		"muzzle_offset": Vector3(0.0, 0.0713, -0.4205),
		"tris": 2596,
		"bbox": Vector3(0.0899, 0.3982, 0.5497),
		"material": "res://assets/weapons/materials/PolygonMilitary_Weapon_Mat_01.material",
		"texture": "res://assets/weapons/textures/PolygonMilitary_Weapons_01.png",
	},
}

# 供演示/测试读取的 fallback 盒子模型（资产缺失时使用）。
static var _fallback_cache: PackedScene = null


static func has(id: String) -> bool:
	return CATALOG.has(id)


## 返回武器场景（PackedScene）。资产缺失或 id 未收录时返回一个占位盒子模型。
static func scene(id: String) -> PackedScene:
	if CATALOG.has(id):
		var path: String = CATALOG[id]["model_path"]
		if ResourceLoader.exists(path):
			var ps := load(path) as PackedScene
			if ps != null:
				return ps
		push_warning("WeaponAssets: 资产缺失 %s (%s)，使用占位盒子模型" % [id, path])
	return _fallback_scene(id)


## 生成一个可用的武器实例（自动应用 catalog 里的 scale；旋转/枢轴已烘焙进场景）。
static func instance_weapon(id: String) -> Node3D:
	var node := scene(id).instantiate() as Node3D
	if node == null:
		# 理论上不会发生（fallback 是 Node3D），保险起见再包一层。
		var wrapper := Node3D.new()
		wrapper.name = id
		return wrapper
	node.name = id
	if CATALOG.has(id):
		var s: float = CATALOG[id]["scale"]
		if not is_equal_approx(s, 1.0):
			node.scale = Vector3.ONE * s
	return node


## 枪口世界坐标（第一人称射线/枪焰起点）。
static func muzzle_global(weapon: Node3D, id: String) -> Vector3:
	if not CATALOG.has(id):
		return weapon.global_position + weapon.global_basis * Vector3(0, 0, -0.4)
	return weapon.global_transform * (CATALOG[id]["muzzle_offset"] as Vector3)


static func _fallback_scene(id: String) -> PackedScene:
	if _fallback_cache != null:
		return _fallback_cache
	var root := Node3D.new()
	root.name = "Fallback_" + id
	var mi := MeshInstance3D.new()
	mi.name = "Placeholder"
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.12, 0.35)
	mi.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.27, 0.30)
	mat.roughness = 0.6
	mat.metallic = 0.4
	mi.material_override = mat
	root.add_child(mi)
	mi.owner = root
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, 0, -0.175)
	root.add_child(muzzle)
	muzzle.owner = root
	var ps := PackedScene.new()
	ps.pack(root)
	_fallback_cache = ps
	root.free()
	return ps
