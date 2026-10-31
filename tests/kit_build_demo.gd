extends Node3D
## 临时测试：用 MegaKit 在城市网格上生成全部建筑，截图 + 测帧率

var cam: Camera3D
var built: Array = []


func _ready() -> void:
	_setup_env()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261101
	for p in Data.PLACES:
		var kind := str(p["kind"])
		if kind == "park" or kind == "parking":
			continue
		_make(p, Data.cell_center(p["cell"]), rng)
	cam = Camera3D.new()
	add_child(cam)
	cam.fov = 72.0
	cam.far = 500.0
	var pc := Data.cell_center(Vector2i(0, 0))
	var dc := Data.cell_center(Vector2i(3, 0))
	var ac := Data.cell_center(Vector2i(0, 3))
	await _shot("D:/Sim Life/shots/kit_city_police.png", pc + Vector3(0, 4.5, 34.0), pc + Vector3(0, 4.0, 0))
	await _shot("D:/Sim Life/shots/kit_city_police_in.png", pc + Vector3(1.5, 1.7, 10.0), pc + Vector3(-6.0, 1.4, -6.0))
	await _shot("D:/Sim Life/shots/kit_city_stairs.png", pc + Vector3(3.0, 1.7, 1.0), pc + Vector3(-12.0, 2.2, -8.0))
	await _shot("D:/Sim Life/shots/kit_city_diner.png", dc + Vector3(0, 4.2, 30.0), dc + Vector3(0, 3.0, 0))
	await _shot("D:/Sim Life/shots/kit_city_hospital.png", Data.cell_center(Vector2i(2, 0)) + Vector3(0, 8.0, 40.0), Data.cell_center(Vector2i(2, 0)) + Vector3(0, 7.0, 0))
	await _shot("D:/Sim Life/shots/kit_city_deco.png", ac + Vector3(0, 8.0, 38.0), ac + Vector3(0, 7.0, 0))
	# 帧率测量
	await get_tree().create_timer(2.0).timeout
	var f0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_msec()
	await get_tree().create_timer(2.0).timeout
	var f1 := Engine.get_frames_drawn()
	var dt := (Time.get_ticks_msec() - t0) / 1000.0
	print("CITY_SHOTS_DONE buildings=", built.size(), " fps=", round((f1 - f0) / dt))
	get_tree().quit()


func _make(p: Dictionary, pos: Vector3, rng: RandomNumberGenerator) -> void:
	var b := KitBuilding.new()
	b.setup(p, self, rng)
	b.position = pos
	add_child(b)
	b.build_to(b)
	built.append(b)


func _shot(path: String, pos: Vector3, look: Vector3) -> void:
	cam.position = pos
	cam.look_at(look)
	cam.current = true
	await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path)


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
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.35
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.26, 0.30, 0.24)
	gm.roughness = 0.95
	ground.material_override = gm
	add_child(ground)
	# 街区人行道块
	for i in range(Data.GRID):
		for j in range(Data.GRID):
			var c := Data.cell_center(Vector2i(i, j))
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(Data.BLOCK, 0.03, Data.BLOCK)
			b.mesh = bm
			b.position = Vector3(c.x, -0.015, c.z)
			var sm2 := StandardMaterial3D.new()
			sm2.albedo_color = Color(0.40, 0.41, 0.42)
			sm2.roughness = 0.95
			b.material_override = sm2
			add_child(b)
