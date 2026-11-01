extends Node3D
## Synty POLYGON Military 武器导入演示（Unidot Importer → Godot 4.7）。
##
## 展示 4 把转换好的第一人称武器：
##   glock  <- SM_Wep_Pistol_01        (Glock 17 风格)
##   m4     <- SM_Wep_Preset_A_Rifle_01 (M4/AR-15 卡宾)
##   ak     <- SM_Wep_Preset_B_Rifle_01 (AK-47/AKM 木质)
##   mac10  <- SM_Wep_Preset_B_SMG_01   (紧凑型 SMG，PAC 里最接近 MAC-10 的)
##
## 输出 shots/weapon_import_*.png，并打印实测数据（tris / bbox / 枪口方向）
## Run: Godot --path "D:/Sim Life" "res://tests/weapon_import_demo.tscn"

const OUT := "res://shots/"
const IDS := ["glock", "m4", "ak", "mac10"]
const ROW_Y := 1.05
const GAP := 0.55

var cam: Camera3D
var label_root: Node3D
var weapons: Array[Node3D] = []
var row_x: Array[float] = []
var total_w := 0.0
var _fp_wall: MeshInstance3D = null
var _fp_dot: MeshInstance3D = null


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	_setup_env()
	await get_tree().process_frame
	_spawn_weapons()
	_setup_scale_bar()

	cam = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.02
	cam.far = 200.0
	add_child(cam)
	cam.current = true

	await get_tree().create_timer(0.25).timeout

	# --- 1) 3/4 视角整排
	_place_camera(Vector3(total_w * 0.5, ROW_Y + 1.35, total_w * 0.62 + 2.2),
		Vector3(total_w * 0.5, ROW_Y - 0.05, 0.0))
	await _shot("weapon_import_row.png")

	# --- 2) 正侧视角（枪口统一朝 -Z：屏幕左侧为 -Z 方向的那一侧需看齐）
	for i in range(weapons.size()):
		weapons[i].rotation_degrees = Vector3(0, 0, 0)
	_place_camera(Vector3(total_w * 0.5, ROW_Y + 0.05, 6.5), Vector3(total_w * 0.5, ROW_Y, 0.0))
	await _shot("weapon_import_side.png")

	# --- 3) 顶视（检查枪口方向 / 长度）
	_place_camera(Vector3(total_w * 0.5, 9.0, 0.02), Vector3(total_w * 0.5, 0, 0))
	await _shot("weapon_import_top.png")

	# 回到 3/4 方便后续局部图
	for i in range(weapons.size()):
		weapons[i].rotation_degrees = Vector3(0, 28.0, 0)

	# --- 4) 每把枪的近景 3/4
	for i in range(weapons.size()):
		var w := weapons[i]
		var size: Vector3 = _aabb_local(w).size
		var cx := w.position.x
		_place_camera(Vector3(cx + size.z * 0.55, ROW_Y + size.y * 0.9, size.z * 0.75 + 0.45),
			Vector3(cx, ROW_Y, 0))
		await _shot("weapon_import_closeup_%s.png" % IDS[i])

	# --- 5) 第一人称视图模型：枪挂在相机下，用 catalog 的 grip_offset
	for i in range(weapons.size()):
		await _fp_shot(IDS[i])
	_setup_fp_wall(false)

	print("PREVIEW_DONE")
	get_tree().quit()


func _setup_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.24, 0.36, 0.55)
	sm.sky_horizon_color = Color(0.62, 0.66, 0.70)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	add_child(sun)

	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	floor_mi.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.34, 0.36, 0.34)
	gm.roughness = 0.95
	floor_mi.material_override = gm
	add_child(floor_mi)

	label_root = Node3D.new()
	add_child(label_root)


func _spawn_weapons() -> void:
	var x := 0.0
	for id in IDS:
		if not WeaponAssets.has(id):
			push_error("UNKNOWN_WEAPON " + id)
			continue
		var w := WeaponAssets.instance_weapon(id)
		add_child(w)
		var aabb := _aabb_local(w)
		var size := aabb.size
		var muzzle := w.get_node_or_null("Muzzle") as Marker3D
		var muzzle_local := muzzle.position if muzzle != null else Vector3.ZERO
		print("WEAPON %s name=%s tris=%d bbox=(%.4f x %.4f x %.4f) muzzle_local=(%.3f, %.3f, %.3f) z_ok=%s" % [
			id, w.name, _count_tris(w), size.x, size.y, size.z,
			muzzle_local.x, muzzle_local.y, muzzle_local.z, str(muzzle_local.z < 0.0)])
		print("  catalog: grip_rotation=%s grip_offset=%s scale=%.2f" % [
			str(WeaponAssets.CATALOG[id]["grip_rotation"]),
			str(WeaponAssets.CATALOG[id]["grip_offset"]),
			float(WeaponAssets.CATALOG[id]["scale"])])
		var cat_bbox: Vector3 = WeaponAssets.CATALOG[id]["bbox"]
		if absf(cat_bbox.z - size.z) > 0.02:
			push_warning("CATALOG_BBOX_MISMATCH %s cat=%.3f actual=%.3f" % [id, cat_bbox.z, size.z])
		w.position = Vector3(x + size.z * 0.5, ROW_Y, 0.0)
		w.rotation_degrees = Vector3(0, 28.0, 0)
		weapons.append(w)
		row_x.append(w.position.x)
		var lbl := Label3D.new()
		lbl.text = "%s\n%s  %d tris" % [WeaponAssets.CATALOG[id]["name"], id, _count_tris(w)]
		lbl.font_size = 42
		lbl.pixel_size = 0.0045
		lbl.outline_size = 12
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_root.add_child(lbl)
		lbl.position = Vector3(w.position.x, ROW_Y + 0.52, 0.0)
		x += size.z + GAP
	total_w = maxf(x - GAP, 1.0)
	print("ROW total_w=%.2f" % total_w)


func _setup_scale_bar() -> void:
	# 1 米参照条 + 1.7 m 人形，用来检查武器真实尺寸
	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 0.02, 0.06)
	bar.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.72, 0.20)
	bar.material_override = m
	bar.position = Vector3(total_w * 0.5, 0.02, 1.05)
	add_child(bar)
	var lbl := Label3D.new()
	lbl.text = "1 m"
	lbl.font_size = 44
	lbl.pixel_size = 0.0045
	lbl.outline_size = 10
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_root.add_child(lbl)
	lbl.position = Vector3(total_w * 0.5, 0.22, 1.05)

	var human := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.24
	cm.height = 1.7
	human.mesh = cm
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color(0.72, 0.30, 0.30)
	human.material_override = hm
	human.position = Vector3(0.0, 0.85, 1.35)
	add_child(human)


func _fp_shot(id: String) -> void:
	# 墙面 + 准星，模拟第一人称开火视角
	_setup_fp_wall(true)
	var w := WeaponAssets.instance_weapon(id)
	var hand := Node3D.new()
	hand.name = "WeaponHand"
	cam.add_child(hand)
	var off: Vector3 = WeaponAssets.CATALOG[id]["grip_offset"]
	hand.transform = Transform3D(Basis.IDENTITY, off)
	hand.add_child(w)
	w.position = Vector3.ZERO
	cam.fov = 75.0
	_place_camera(Vector3(0, 1.62, 0), Vector3(0, 1.55, -6))
	await _shot("weapon_import_fp_%s.png" % id)
	var muzzle := WeaponAssets.muzzle_global(w, id)
	print("FP %s hand_offset=%s muzzle_world=%s" % [id, str(off), str(muzzle)])
	hand.queue_free()
	_setup_fp_wall(false)
	await get_tree().process_frame


func _setup_fp_wall(active: bool) -> void:
	if _fp_wall == null:
		_fp_wall = MeshInstance3D.new()
		_fp_wall.name = "FPWall"
		var bm := BoxMesh.new()
		bm.size = Vector3(8, 4, 0.1)
		_fp_wall.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.30, 0.32, 0.33)
		m.roughness = 0.9
		_fp_wall.material_override = m
		_fp_wall.position = Vector3(0, 2.0, -6.0)
		add_child(_fp_wall)
		_fp_dot = MeshInstance3D.new()
		_fp_dot.name = "FPDot"
		var sm := BoxMesh.new()
		sm.size = Vector3(0.06, 0.06, 0.06)
		_fp_dot.mesh = sm
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.9, 0.2, 0.15)
		dm.emission_enabled = true
		dm.emission = Color(0.9, 0.2, 0.15)
		_fp_dot.material_override = dm
		_fp_dot.position = Vector3(0, 1.55, -6.05)
		add_child(_fp_dot)
	_fp_wall.visible = active
	_fp_dot.visible = active


func _count_tris(n: Node) -> int:
	var tris := 0
	if n is MeshInstance3D and n.mesh != null:
		for s in range(n.mesh.get_surface_count()):
			var arr: Array = n.mesh.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX] if arr.size() > Mesh.ARRAY_INDEX else null
			if idx != null and (idx as PackedInt32Array).size() > 0:
				tris += (idx as PackedInt32Array).size() / 3
			elif arr.size() > Mesh.ARRAY_VERTEX and arr[Mesh.ARRAY_VERTEX] != null:
				tris += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	for c in n.get_children():
		tris += _count_tris(c)
	return tris


func _aabb_local(n: Node3D) -> AABB:
	var aabb := AABB()
	var first := true
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D and cur.mesh != null:
			var mi: MeshInstance3D = cur
			# transform relative to n
			var rel := _relative_transform(n, mi)
			var ga: AABB = rel * mi.get_aabb()
			if first:
				aabb = ga
				first = false
			else:
				aabb = aabb.merge(ga)
		for c in cur.get_children():
			stack.append(c)
	return aabb


func _relative_transform(root: Node3D, node: Node3D) -> Transform3D:
	return root.global_transform.affine_inverse() * node.global_transform


func _place_camera(pos: Vector3, target: Vector3) -> void:
	cam.position = pos
	cam.look_at(target)


func _shot(file: String) -> void:
	await get_tree().create_timer(0.18).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := OUT + file
	var err := img.save_png(path)
	print("SHOT_SAVED ", path, " ", img.get_size(), " err=", err)
