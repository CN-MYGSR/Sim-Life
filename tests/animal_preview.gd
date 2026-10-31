extends Node3D
## Lo Polly animals FREE GLB - visual + data preview.
## The pack contains 7 static low-poly animals, ONE shared texture atlas, and
## ZERO skeletons / ZERO animations (verified at import: no AnimationPlayer,
## no Skeleton3D, glTF has no "skins"/"animations" keys).
## This scene renders: full row, side row, human scale reference, close-ups,
## a procedural "bob" demo (the only motion possible without a rig), and a top view.
## Run: Godot --path "D:/Sim Life" "res://tests/animal_preview.tscn"

const GLB := "res://assets/animals/Lo Polly animals FREE.glb"
const OUT := "res://shots/"
const ROW_GAP := 0.85
const HUMAN_H := 1.7

var cam: Camera3D
var label_root: Node3D
var animals: Array[MeshInstance3D] = []
var row_end := 0.0
var motion_bars: Array[MeshInstance3D] = []


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1600, 900))
	_setup_env()
	_load_animals()
	_layout_row()
	var human := _add_human_reference()

	cam = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.05
	cam.far = 200.0
	add_child(cam)
	cam.current = true

	await get_tree().create_timer(0.25).timeout

	# --- 1) full row, 3/4 front view
	var mid := row_end * 0.5
	_place_camera(Vector3(mid, 2.7, 14.0), Vector3(mid, 0.9, 0))
	await _shot("animal_preview_row.png")

	# --- 2) all 7 + human 1.7 m reference in one frame
	_place_camera(Vector3((mid + human.position.x) * 0.5, 2.6, 15.5),
		Vector3((mid + human.position.x) * 0.5, 1.0, 0))
	await _shot("animal_preview_with_human.png")

	# --- 2b) closer side-on row (silhouette / leg / texture detail check)
	_place_camera(Vector3(mid, 1.5, 8.0), Vector3(mid, 0.85, 0))
	await _shot("animal_preview_row_side.png")

	# --- 3) scale check: human next to Bull + Crocodile + Donkey
	var bull := _animal_by_prefix("Bull")
	var donkey := _animal_by_prefix("Donkey")
	var cx := (donkey.position.x + human.position.x) * 0.5
	_place_camera(Vector3(cx, 2.15, 8.6), Vector3(cx, 0.9, 0))
	await _shot("animal_preview_scale.png")

	# --- 4) close-up on the large animals (Donkey, Crocodile, Bull)
	var croc := _animal_by_prefix("Crocodile")
	var big_x := (donkey.position.x + bull.position.x) * 0.5
	_place_camera(Vector3(big_x, 1.5, 6.0), Vector3(big_x, 0.8, 0))
	await _shot("animal_preview_big_closeup.png")

	# --- 5) close-up on the small animals (Swan, Rooster, "Leopard", Falcon)
	var swan := _animal_by_prefix("Swan")
	var falcon := _animal_by_prefix("Falcon")
	var small_x := (swan.position.x + falcon.position.x) * 0.5
	_place_camera(Vector3(small_x, 0.95, 4.4), Vector3(small_x, 0.5, 0))
	await _shot("animal_preview_small_closeup.png")

	# --- 6) motion demo: with no rig the ONLY thing possible is moving the whole
	# rigid body. Bull is rendered at 3 timestamps of a fake "walk" (root translate
	# + bob + pitch). Legs stay frozen -> feet visibly slide. This is evidence, not
	# a real animation. Ground bars make the sliding visible.
	var base_pos := bull.position
	var base_rot := bull.rotation_degrees
	var cam_x := bull.position.x
	_add_ground_bars(cam_x - 0.9, 6, 0.45)
	_place_camera(Vector3(cam_x - 0.2, 1.3, 5.6), Vector3(cam_x + 0.4, 0.75, 0))
	for i in range(3):
		var t := float(i) * 0.5
		bull.position = base_pos + Vector3(0.6 * t, 0.05 * absf(sin(t * PI * 2.0)), 0.0)
		bull.rotation_degrees = Vector3(0.0, 90.0, 3.0 * sin(t * PI * 2.0))
		var cap := Label3D.new()
		cap.text = "FAKE WALK  t=%.1fs\nno rig: legs frozen" % t
		cap.font_size = 40
		cap.pixel_size = 0.004
		cap.outline_size = 10
		cap.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_root.add_child(cap)
		cap.position = Vector3(cam_x + 1.4, 1.9, 1.0)
		await _shot("animal_preview_motion_t%d.png" % i)
		cap.queue_free()
	bull.position = base_pos
	bull.rotation_degrees = base_rot

	# --- 7) top view of Crocodile + Bull + human for footprint / orientation check
	for bar in motion_bars:
		bar.queue_free()
	var top_x := (croc.position.x + human.position.x) * 0.5
	_place_camera(Vector3(top_x, 8.6, 0.02), Vector3(top_x, 0.0, 0.0))
	await _shot("animal_preview_top.png")

	print("PREVIEW_DONE")
	get_tree().quit()


func _setup_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.30, 0.48, 0.76)
	sm.sky_horizon_color = Color(0.78, 0.84, 0.90)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.52, 0.56, 0.47)
	gm.roughness = 0.95
	ground.material_override = gm
	add_child(ground)

	label_root = Node3D.new()
	add_child(label_root)


func _load_animals() -> void:
	var ps: PackedScene = load(GLB)
	if ps == null:
		push_error("GLB_LOAD_FAILED")
		get_tree().quit()
		return
	var holder: Node3D = ps.instantiate()
	add_child(holder)
	print("=== GLB ROOT: ", holder.name, " class=", holder.get_class())
	var i := 0
	for child in holder.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child
			mi.reparent(self)
			mi.rotation_degrees = Vector3(0.0, 90.0, 0.0)
			animals.append(mi)
			_dump_animal(i, mi)
			i += 1
	holder.queue_free()
	print("=== ANIMAL COUNT: ", animals.size())


func _dump_animal(idx: int, mi: MeshInstance3D) -> void:
	var aabb := mi.get_aabb()
	var size := Vector3(aabb.size.z, aabb.size.y, aabb.size.x)  # 90 deg Y rotation
	var tris := 0
	for s in range(mi.mesh.get_surface_count()):
		tris += mi.mesh.get_faces().size() / 3
	print("ANIMAL ", idx, " name=", mi.name, " size_m=(%.3f x %.3f x %.3f)" % [size.x, size.y, size.z],
		" feet_y=%.4f" % aabb.position.y, " mesh=", mi.mesh.resource_name,
		" surfaces=", mi.mesh.get_surface_count(), " vertex_faces_sum=", tris)
	var m: Material = mi.mesh.surface_get_material(0)
	if m is StandardMaterial3D:
		print("   material=", m.resource_name, " tex=", "yes" if m.albedo_texture else "no",
			" roughness=%.2f" % m.roughness, " metallic=%.2f" % m.metallic,
			" cull_back=", not m.cull_mode)


func _layout_row() -> void:
	var x := 0.0
	for mi in animals:
		var aabb := mi.get_aabb()
		var size := Vector3(aabb.size.z, aabb.size.y, aabb.size.x)  # after 90 deg Y
		mi.position = Vector3(x + size.x * 0.5, -aabb.position.y, 0.0)
		var lbl := Label3D.new()
		lbl.text = "%s\n%.2f m" % [_short_name(mi.name), size.y]
		lbl.font_size = 44
		lbl.pixel_size = 0.0045
		lbl.outline_size = 10
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label_root.add_child(lbl)
		lbl.position = Vector3(mi.position.x, size.y + 0.42, 0.0)
		x += size.x + ROW_GAP
	row_end = maxf(x - ROW_GAP, 1.0)


func _add_human_reference() -> MeshInstance3D:
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.24
	cm.height = HUMAN_H
	body.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.30, 0.30)
	body.material_override = mat
	body.position = Vector3(row_end + 1.3, HUMAN_H * 0.5, 0.0)
	add_child(body)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.13
	sm.height = 0.26
	head.mesh = sm
	head.material_override = mat
	head.position = Vector3(row_end + 1.3, HUMAN_H + 0.1, 0.0)
	add_child(head)
	var lbl := Label3D.new()
	lbl.text = "HUMAN\n1.70 m"
	lbl.font_size = 44
	lbl.pixel_size = 0.0045
	lbl.outline_size = 10
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_root.add_child(lbl)
	lbl.position = Vector3(row_end + 1.3, HUMAN_H + 0.75, 0.0)
	return body


func _add_ground_bars(start_x: float, count: int, step: float) -> void:
	for i in range(count):
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.02, 3.0)
		bar.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.18, 0.20, 0.16)
		bar.material_override = m
		bar.position = Vector3(start_x + i * step, 0.01, 0.0)
		add_child(bar)
		motion_bars.append(bar)


func _animal_by_prefix(prefix: String) -> MeshInstance3D:
	for mi in animals:
		if mi.name.begins_with(prefix):
			return mi
	return animals[0]


func _short_name(n: String) -> String:
	var s := n.replace("_", ".").replace(".001", "").replace(".002", "")
	if s == "Leopard":
		return "Leopard* (goat!)"
	return s


func _place_camera(pos: Vector3, target: Vector3) -> void:
	cam.position = pos
	cam.look_at(target)


func _shot(file: String) -> void:
	await get_tree().create_timer(0.18).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := OUT + file
	img.save_png(path)
	print("SHOT_SAVED ", path, " ", img.get_size())
