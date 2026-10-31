extends Node3D
## 临时测试场景：MegaKit 模块画廊 + 拼接测试

const K := "res://assets/kit/models/"


func _ready() -> void:
	_setup_env()
	_gallery()
	_test_house()

	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 5.0, 20.0)
	cam.look_at(Vector3(0, 2.0, 0))
	cam.fov = 60.0
	cam.current = true

	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("D:/Sim Life/shots/kit_gallery.png")
	print("SHOT_SAVED")
	get_tree().quit()


func _setup_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.28, 0.46, 0.74)
	sm.sky_horizon_color = Color(0.76, 0.82, 0.88)
	sm.ground_bottom_color = Color(0.13, 0.15, 0.17)
	sm.ground_horizon_color = Color(0.52, 0.57, 0.62)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.3
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	# 地面
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.26, 0.30, 0.24)
	gm.roughness = 0.95
	ground.material_override = gm
	ground.position.y = -0.01
	add_child(ground)


func _inst(name: String) -> Node3D:
	var ps: PackedScene = load(K + name + ".gltf")
	if ps == null:
		print("MISSING ", name)
		return Node3D.new()
	return ps.instantiate() as Node3D


func _gallery() -> void:
	var items := [
		"Brick_Plain_1", "Brick_Plain_3", "Brick_Window_Trim_Single", "Brick_Window_Square_Single",
		"Brick_Inset_Window", "Brick_Inset_Window_Curved", "Brick_RedWhite_DoubleWindow", "Metal_Plain_3",
		"Metal_FirstFloor_Wall", "Metal_FirstFloor_Window", "Metal_Window", "Metal_FullWindow",
		"Metal_Window_Half", "Trim_Plain_3",
		"DoorFrame_Trim", "DoorFrame_Wooden", "DoorFrame_Metal_Single", "Door_1", "Door_2", "Door_3",
		"Brick_InteriorWall_3", "Brick_InteriorWall_4", "Cornice_Trim_Center", "Roof_4x4",
		"Floor_4x4", "Stairs_Entrance_Concrete", "Stairs_Rails_Metal_Straight_2", "Prop_Planter_Single",
	]
	var per_row := 14
	for i in range(items.size()):
		var row := i / per_row
		var col := i % per_row
		var m := _inst(items[i])
		m.position = Vector3(-19.5 + col * 3.0, 0.0, -2.0 - row * 3.0)
		add_child(m)
		var l := Label3D.new()
		l.text = items[i]
		l.font_size = 20
		l.pixel_size = 0.004
		l.modulate = Color(1, 1, 1)
		l.outline_size = 6
		l.position = Vector3(-19.5 + col * 3.0, 3.4, -2.0 - row * 3.0)
		add_child(l)


func _test_house() -> void:
	# 8m x 8m 两层小楼：四周墙体 + 楼板 + 门 + 窗
	var root := Node3D.new()
	root.position = Vector3(0, 0, 6)
	add_child(root)
	# 一层四周：每边 4 个 2m 模块
	# 前墙 (+z)：门洞 2m + 3 个窗/墙
	var front := ["Brick_Plain_3", "Brick_Window_Trim_Single", "Brick_Plain_3", "Brick_Plain_3"]
	for i in range(4):
		var m := _inst(front[i])
		m.position = Vector3(-3 + i * 2, 0, 4)
		root.add_child(m)
	# 后墙
	for i in range(4):
		var m2 := _inst("Brick_Plain_3")
		m2.position = Vector3(-3 + i * 2, 0, -4)
		m2.rotation.y = PI
		root.add_child(m2)
	# 左右墙
	for i in range(4):
		var ml := _inst("Brick_Plain_3")
		ml.position = Vector3(-4, 0, -3 + i * 2)
		ml.rotation.y = PI * 0.5
		root.add_child(ml)
		var mr := _inst("Brick_Plain_3")
		mr.position = Vector3(4, 0, -3 + i * 2)
		mr.rotation.y = -PI * 0.5
		root.add_child(mr)
	# 一层楼板
	for gx in range(2):
		for gz in range(2):
			var f := _inst("Floor_4x4")
			f.position = Vector3(-2 + gx * 4, 0.0, -2 + gz * 4)
			root.add_child(f)
	# 二层楼板
	for gx in range(2):
		for gz in range(2):
			var f2 := _inst("Floor_4x4")
			f2.position = Vector3(-2 + gx * 4, 3.0, -2 + gz * 4)
			root.add_child(f2)
	# 二层墙体
	for i in range(4):
		var m3 := _inst("Brick_Window_Trim_Single")
		m3.position = Vector3(-3 + i * 2, 3, 4)
		root.add_child(m3)
	# 门
	var df := _inst("DoorFrame_Trim")
	df.position = Vector3(-3.0, 0, 4.0)
	root.add_child(df)
	var d := _inst("Door_1")
	d.position = Vector3(-3.0, 0, 4.0)
	root.add_child(d)
	# 内墙
	var iw := _inst("Brick_InteriorWall_3")
	iw.position = Vector3(0.5, 0, 0)
	root.add_child(iw)
	var iw2 := _inst("Brick_InteriorWall_3")
	iw2.position = Vector3(2.5, 0, 0)
	root.add_child(iw2)
	# 屋顶
	for gx in range(2):
		for gz in range(2):
			var r := _inst("Roof_4x4")
			r.position = Vector3(-2 + gx * 4, 6.0, -2 + gz * 4)
			root.add_child(r)
