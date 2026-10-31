extends Node3D
## 临时测试场景：InteriorFurnish 室内家具布置
## - 搭若干简单房间（地板 / 四面砖墙 / 天花板 / 灯 / 相机）
## - 对每种 kind 调用 InteriorFurnish.furnish()
## - 自动检查：数量 / 边界 / 高度 / 中央通道 / 互相穿插 / 无灯光无脚本
## - 截图到 shots/furnish_demo_N.png
## 运行：Godot --path "D:/Sim Life" "res://tests/furnish_demo.tscn"

const OUT := "D:/Sim Life/shots/"
const BRICK := Color(0.42, 0.30, 0.26)

var cam: Camera3D
var rng := RandomNumberGenerator.new()
var shot_n := 0
var fail := 0


func _ready() -> void:
	_setup_env()
	rng.seed = 20261101
	cam = Camera3D.new()
	cam.fov = 76.0
	cam.far = 400.0
	add_child(cam)

	# 必需的 4+1 张截图
	await _run("police", 14.0, 10.0, 0.0, Vector3(-34, 0, -14), true)
	await _run("diner", 16.0, 10.0, 0.0, Vector3(0, 0, -14), true)
	await _run("deco_office", 12.0, 10.0, 3.0, Vector3(34, 0, -14), true)
	await _run("hospital", 20.0, 12.0, 0.0, Vector3(0, 0, 18), true)
	await _run("police", 12.0, 9.0, 3.0, Vector3(34, 0, 18), true)  # 上层自动映射
	await _run("bank", 20.0, 14.0, 0.0, Vector3(-34, 0, 18), true)

	# 其余 kind 只做自动检查，不出图
	await _run("fire", 26.0, 18.0, 0.0, Vector3(0, 0, 52), false)
	await _run("mart", 20.0, 14.0, 0.0, Vector3(34, 0, 52), false)
	await _run("garage", 26.0, 18.0, 0.0, Vector3(-34, 0, 52), false)
	await _run("gang", 26.0, 18.0, 0.0, Vector3(68, 0, 52), false)
	await _run("shopfront", 20.0, 14.0, 0.0, Vector3(0, 0, 90), false)
	await _run("deco_apartment", 16.0, 14.0, 3.0, Vector3(34, 0, 90), false)
	await _run("deco_warehouse", 28.0, 20.0, 3.0, Vector3(-34, 0, 90), false)
	await _run("hospital", 24.0, 16.0, 3.0, Vector3(68, 0, 90), false)  # 上层病房
	await _run("diner", 22.0, 16.0, 3.0, Vector3(0, 0, 128), false)  # 上层储物
	await _run("deco_office", 26.0, 22.0, 3.0, Vector3(34, 0, 128), false)

	print("FURNISH_DEMO_DONE shots=", shot_n, " fail=", fail)
	get_tree().quit()


func _run(kind: String, w: float, d: float, fy: float, off: Vector3, shoot: bool) -> void:
	var room := _make_room(off, w, d, fy)
	var area := Rect2(-w * 0.5 + 0.2, -d * 0.5 + 0.2, w - 0.4, d - 0.4)
	var before := room.get_child_count()
	var nodes_before := _count_desc(room)
	var t0 := Time.get_ticks_msec()
	InteriorFurnish.furnish(room, kind, fy, area, rng)
	var ms := Time.get_ticks_msec() - t0
	var pieces := room.get_child_count() - before
	var added := _count_desc(room) - nodes_before
	var rep := _validate(room, before, area, fy)
	var tag := "OK"
	if int(rep["bad"]) > 0:
		tag = "BAD"
		fail += 1
	print("FURNISH kind=%s fy=%.1f size=%.0fx%.0f pieces=%d nodes=%d ms=%d meshes=%d max_h=%.2f out=%d lane=%d overlap=%d lights=%d scripts=%d -> %s"
		% [kind, fy, w, d, pieces, added, ms, int(rep["meshes"]), float(rep["max_h"]),
		int(rep["out"]), int(rep["lane"]), int(rep["overlap"]), int(rep["lights"]),
		int(rep["scripts"]), tag])
	if not shoot:
		room.free()
		return
	# 相机：站在中间靠门处，朝房间深处看
	var cam_local := Vector3(-1.2, fy + 1.72, d * 0.5 - 1.1)
	var look_local := Vector3(0.6, fy + 0.95, -d * 0.5 + 1.0)
	cam.position = room.position + cam_local
	cam.look_at(room.position + look_local)
	cam.current = true
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	shot_n += 1
	var path := OUT + "furnish_demo_%d.png" % shot_n
	img.save_png(path)
	print("SHOT ", path, " (", kind, " ", pieces, " pieces)")


func _count_desc(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count_desc(ch)
	return c


func _validate(room: Node3D, from_idx: int, area: Rect2, fy: float) -> Dictionary:
	var res := {"meshes": 0, "max_h": 0.0, "out": 0, "overlap": 0, "lights": 0,
		"scripts": 0, "lane": 0, "bad": 0}
	var boxes: Array[AABB] = []
	var ccx := area.position.x + area.size.x * 0.5
	var lane := Rect2(ccx - 0.9, area.position.y + area.size.y * 0.35, 1.8, area.size.y * 0.65)
	for i in range(from_idx, room.get_child_count()):
		var st := {"aabb": AABB(), "first": true, "meshes": 0, "lights": 0, "scripts": 0}
		_walk(room.get_child(i), st)
		res["meshes"] += int(st["meshes"])
		res["lights"] += int(st["lights"])
		res["scripts"] += int(st["scripts"])
		if bool(st["first"]):
			continue
		var ab: AABB = st["aabb"]
		ab.position -= room.global_position
		boxes.append(ab)
		var top := ab.end.y - fy
		if top > float(res["max_h"]):
			res["max_h"] = top
		var e := 0.12
		if ab.position.x < area.position.x - e or ab.position.z < area.position.y - e \
				or ab.end.x > area.end.x + e or ab.end.z > area.end.y + e \
				or ab.position.y < fy - 0.06 or top > 2.26:
			res["out"] += 1
			print("  OUT_OF_AREA piece=", room.get_child(i).name, " aabb=", ab)
		var flat := Rect2(ab.position.x, ab.position.z, ab.size.x, ab.size.z)
		if flat.intersects(lane):
			res["lane"] += 1
			print("  LANE piece=", room.get_child(i).name)
	for i in range(boxes.size()):
		for j in range(i + 1, boxes.size()):
			# 地毯 / 展台这类贴地装饰允许压在家具下面
			if boxes[i].size.y < 0.15 or boxes[j].size.y < 0.15:
				continue
			if boxes[i].intersects(boxes[j]):
				var inter := boxes[i].intersection(boxes[j])
				if inter.get_volume() > 0.05:
					res["overlap"] += 1
					print("  OVERLAP ", i, " ", j, " vol=", inter.get_volume())
	res["bad"] = int(res["out"]) + int(res["overlap"]) + int(res["lights"]) \
		+ int(res["scripts"]) + int(res["lane"])
	return res


func _walk(n: Node, st: Dictionary) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			var ab: AABB = mi.global_transform * mi.get_aabb()
			if bool(st["first"]):
				st["aabb"] = ab
				st["first"] = false
			else:
				var cur: AABB = st["aabb"]
				st["aabb"] = cur.merge(ab)
			st["meshes"] += 1
	elif n is OmniLight3D or n is SpotLight3D or n is DirectionalLight3D:
		st["lights"] += 1
	if n.get_script() != null:
		st["scripts"] += 1
	for c in n.get_children():
		_walk(c, st)


func _make_room(off: Vector3, w: float, d: float, fy: float) -> Node3D:
	var room := Node3D.new()
	room.position = off
	add_child(room)
	var t := 0.3
	var h := 3.1
	# 地板（顶面 = fy）
	_box(room, Vector3(0, fy - 0.1, 0), Vector3(w, 0.2, d), Color(0.52, 0.50, 0.46), true)
	# 天花板
	_box(room, Vector3(0, fy + 3.18, 0), Vector3(w + 0.5, 0.3, d + 0.5), Color(0.60, 0.58, 0.54))
	# 后墙 / 左右墙
	_box(room, Vector3(0, fy + h * 0.5, -d * 0.5 - t * 0.5), Vector3(w + t * 2.0, h, t), BRICK, true)
	_box(room, Vector3(-w * 0.5 - t * 0.5, fy + h * 0.5, 0), Vector3(t, h, d + t * 2.0), BRICK, true)
	_box(room, Vector3(w * 0.5 + t * 0.5, fy + h * 0.5, 0), Vector3(t, h, d + t * 2.0), BRICK, true)
	# 前墙：留门洞
	var door := minf(2.4, w - 2.0)
	var seg := (w - door) * 0.5
	if seg > 0.1:
		_box(room, Vector3(-(door * 0.5 + seg * 0.5), fy + h * 0.5, d * 0.5 + t * 0.5), Vector3(seg, h, t), BRICK, true)
		_box(room, Vector3(door * 0.5 + seg * 0.5, fy + h * 0.5, d * 0.5 + t * 0.5), Vector3(seg, h, t), BRICK, true)
	_box(room, Vector3(0, fy + h - 0.3, d * 0.5 + t * 0.5), Vector3(door, 0.6, t), BRICK, true)
	# 测试用室内灯（真实建筑里由 Lead 统一布置）
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, fy + 2.55, 0)
	lamp.light_color = Color(1.0, 0.90, 0.75)
	lamp.light_energy = 3.0
	lamp.omni_range = 18.0
	lamp.omni_attenuation = 0.8
	lamp.shadow_enabled = false
	room.add_child(lamp)
	var lamp2 := OmniLight3D.new()
	lamp2.position = Vector3(0, fy + 2.45, d * 0.28)
	lamp2.light_color = Color(1.0, 0.92, 0.80)
	lamp2.light_energy = 1.6
	lamp2.omni_range = 12.0
	lamp2.shadow_enabled = false
	room.add_child(lamp2)
	return room


func _box(parent: Node3D, pos: Vector3, size: Vector3, col: Color, collide := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.9
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		sb.position = pos
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		parent.add_child(sb)
	return mi


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
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.3
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(800, 800)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.24, 0.28, 0.22)
	gm.roughness = 0.95
	ground.material_override = gm
	ground.position = Vector3(0, -0.02, 0)
	add_child(ground)
