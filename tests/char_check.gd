extends Node3D
## 临时测试：角色 glTF（含内置动画）与 FBX 动画的骨骼/动画兼容性检查

const CHARS := ["Casual_Male", "Casual_Female", "Worker_Male", "Soldier_Male"]
const FBXS := ["Walking", "Running", "Boxing"]

var cam: Camera3D


func _ready() -> void:
	_setup_env()
	var i := 0
	for n in CHARS:
		var ps: PackedScene = load("res://assets/chars/%s.gltf" % n)
		if ps == null:
			print("MISSING ", n)
			continue
		var inst: Node3D = ps.instantiate()
		inst.position = Vector3(-6.0 + i * 4.0, 0, 0)
		add_child(inst)
		_dump("CHAR " + n, inst)
		var ap := _find_ap(inst)
		if ap:
			print("  AP anims=", ap.get_animation_list())
			if ap.has_animation("Walk"):
				ap.play("Walk")
			elif ap.get_animation_list().size() > 0:
				ap.play(ap.get_animation_list()[0])
		i += 1
	i = 0
	for n in FBXS:
		var ps2: PackedScene = load("res://assets/chars/%s.fbx" % n)
		if ps2 == null:
			print("MISSING FBX ", n)
			continue
		var inst2: Node3D = ps2.instantiate()
		inst2.position = Vector3(-6.0 + i * 4.0, 0, 8)
		add_child(inst2)
		_dump("FBX " + n, inst2)
		i += 1
	cam = Camera3D.new()
	add_child(cam)
	cam.position = Vector3(-2, 1.6, 9)
	cam.look_at(Vector3(-2, 1.0, 0))
	cam.current = true
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("D:/Sim Life/shots/char_check.png")
	print("SHOT_SAVED")
	get_tree().quit()


func _dump(tag: String, root: Node3D) -> void:
	var aabb := _mesh_aabb(root)
	print(tag, " aabb_size=", aabb.size, " aabb_pos=", aabb.position)
	var sk := _find_skel(root)
	if sk:
		var bones := []
		for b in range(mini(sk.get_bone_count(), 10)):
			bones.append(sk.get_bone_name(b))
		print("  bones=", sk.get_bone_count(), " ", bones)
	var ap := _find_ap(root)
	if ap:
		var list := ap.get_animation_list()
		print("  anims=", list)
		for an in list.slice(0, 2):
			var a: Animation = ap.get_animation(an)
			var tracks := []
			for t in range(mini(a.get_track_count(), 4)):
				tracks.append(a.track_get_path(t))
			print("   anim ", an, " tracks=", a.get_track_count(), " first=", tracks)


func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r:
			return r
	return null


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skel(c)
		if r:
			return r
	return null


func _mesh_aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in _all_meshes(n):
		var b: AABB = mi.get_aabb()
		b = mi.global_transform * b
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box


func _all_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_meshes(c))
	return out


func _setup_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.28, 0.46, 0.74)
	sm.sky_horizon_color = Color(0.76, 0.82, 0.88)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.2
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.6
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.55, 0.55, 0.52)
	ground.material_override = gm
	add_child(ground)
