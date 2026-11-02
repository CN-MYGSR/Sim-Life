extends Node3D
class_name MissionTarget
## 任务目标实体：地面光圈 + 类型化视觉 + 按住 E 交互

var mission: Dictionary = {}
var mtype: String = ""
var mid: int = 0
var radius: float = 4.6
var hold_need: float = 0.0
var hold: float = 0.0
var stand_need: float = 0.0
var stand: float = 0.0
var done: bool = false
var prompt_text: String = ""

var _ring: MeshInstance3D
var _beam: MeshInstance3D
var _npc: NPC
var _fire_parts: Array = []
var _t: float = 0.0
var _showing_hold := false


func setup(m: Dictionary) -> void:
	mission = m
	mtype = str(m["type"])
	mid = int(m["id"])
	position = m["target"]
	match mtype:
		"arrest":
			radius = 5.0
			hold_need = 1.8
			prompt_text = "按住 E 逮捕通缉犯"
			_spawn_criminal()
		"fire":
			radius = 5.5
			hold_need = 3.0
			prompt_text = "按住 E 扑灭火情"
			_make_fire()
		"heal":
			radius = 4.2
			hold_need = 3.2
			prompt_text = "按住 E 进行急救"
			_spawn_patient()
		"patrol":
			radius = 4.0
			prompt_text = "巡逻点"
			_make_beam(Data.C_TEAL)
		"capture":
			radius = 7.0
			stand_need = 8.0
			prompt_text = "驻守据点"
			_make_beam(Data.C_PURPLE)
		"deliver":
			radius = 4.5
			hold_need = 1.2
			prompt_text = "按住 E 交付货物"
			_make_crate()
		"parcel":
			radius = 4.0
			hold_need = 1.5
			prompt_text = "按住 E 领取包裹" if float(m["progress"]) < 1 else "按住 E 交付包裹"
			_make_crate()
		"rob":
			radius = 4.0
			hold_need = 4.0
			prompt_text = "按住 E 撬开收银台"
			_make_beam(Data.C_RED)
	_build_ring()


func _build_ring() -> void:
	# 地面光圈：低亮度、低饱和、宽一点的半透明环，避免刺眼
	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius - 0.22
	tm.outer_radius = radius
	tm.rings = 44
	tm.ring_segments = 6
	_ring.mesh = tm
	_ring.position.y = 0.08
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.52, 0.84, 0.95, 0.26)
	mat.emission_enabled = true
	mat.emission = Color(0.36, 0.72, 0.86)
	mat.emission_energy_multiplier = 0.55
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.material_override = mat
	add_child(_ring)


func _make_beam(color: Color) -> void:
	_beam = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.35
	cm.bottom_radius = radius * 0.35
	cm.height = 14.0
	cm.radial_segments = 18
	cm.cap_top = false
	cm.cap_bottom = false
	_beam.mesh = cm
	_beam.position.y = 7.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, 0.10)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.material_override = mat
	add_child(_beam)


func _spawn_criminal() -> void:
	_npc = NPC.spawn(self, Vector3(0, 0, 0), "criminal", Color(0.55, 0.16, 0.18))
	_npc.mission_id = mid


func _spawn_patient() -> void:
	_npc = NPC.spawn(self, Vector3(0.6, 0, 0), "patient", Color(0.35, 0.42, 0.55))
	_npc.mission_id = mid
	# 急救包
	var kit := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.42, 0.26, 0.3)
	kit.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.92, 0.94, 0.95)
	kit.material_override = m
	kit.position = Vector3(-0.4, 0.15, 0)
	add_child(kit)
	var cross := MeshInstance3D.new()
	var cbm := BoxMesh.new()
	cbm.size = Vector3(0.22, 0.05, 0.05)
	cross.mesh = cbm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.9, 0.2, 0.2)
	cm.emission_enabled = true
	cm.emission = Color(0.9, 0.2, 0.2)
	cross.material_override = cm
	cross.position = Vector3(-0.4, 0.28, 0)
	add_child(cross)


func _make_fire() -> void:
	var root := Node3D.new()
	add_child(root)
	for i in range(11):
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = randf_range(0.28, 0.60)
		cm.height = randf_range(1.4, 2.9)
		cm.radial_segments = 7
		c.mesh = cm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.55, 0.12)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.48, 0.08)
		m.emission_energy_multiplier = 3.4
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		c.material_override = m
		c.position = Vector3(randf_range(-1.1, 1.1), 0.9, randf_range(-1.1, 1.1))
		c.set_meta("base_y", c.position.y)
		c.set_meta("phase", randf() * TAU)
		root.add_child(c)
		_fire_parts.append(c)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.52, 0.20)
	light.light_energy = 5.5
	light.omni_range = 18.0
	light.position.y = 2.0
	root.add_child(light)
	# 焦黑地面
	var scorch := MeshInstance3D.new()
	var scm := CylinderMesh.new()
	scm.top_radius = 2.8
	scm.bottom_radius = 2.8
	scm.height = 0.04
	scorch.mesh = scm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.09, 0.08, 0.08)
	scorch.material_override = sm
	scorch.position.y = 0.02
	add_child(scorch)


func _make_crate() -> void:
	var crate := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.1, 0.9, 1.1)
	crate.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.34, 0.20)
	m.roughness = 0.9
	crate.material_override = m
	crate.position.y = 0.45
	add_child(crate)


func _physics_process(delta: float) -> void:
	if done:
		return
	_t += delta
	# 光圈脉动：幅度小、节奏慢，安静地呼吸
	if is_instance_valid(_ring):
		var s := 1.0 + sin(_t * 1.6) * 0.02
		_ring.scale = Vector3(s, 1.0, s)
	# 火焰跳动
	for c in _fire_parts:
		if not is_instance_valid(c):
			continue
		var ph: float = c.get_meta("phase")
		var by: float = c.get_meta("base_y")
		c.position.y = by + sin(_t * 7.0 + ph) * 0.16
		var k := 0.85 + sin(_t * 9.0 + ph) * 0.18
		c.scale = Vector3(k, 1.0 + sin(_t * 6.0 + ph) * 0.2, k)

	if not is_instance_valid(Game.player):
		return
	if Game.player.in_ui or Game.player.driving or Game.player.decor_mode or Game.player.locked:
		_release_hold(delta)
		return
	var pp: Vector3 = Game.player.global_position
	var target := global_position
	if is_instance_valid(_npc):
		target = _npc.global_position
		mission["target"] = target
		_ring.position = _npc.position + Vector3(0, 0.08, 0)
	var flat := Vector2(pp.x - target.x, pp.z - target.z)
	var dist := flat.length()
	var in_range := dist <= radius and absf(pp.y - target.y) < 2.5
	if in_range:
		var query := PhysicsRayQueryParameters3D.create(Game.player.cam.global_position, target + Vector3.UP)
		query.collision_mask = 1
		in_range = get_world_3d().direct_space_state.intersect_ray(query).is_empty()

	if not in_range:
		_release_hold(delta)
		return
	_showing_hold = true

	if hold_need > 0.0:
		if Input.is_action_pressed("interact"):
			if is_instance_valid(_npc):
				_npc.set_physics_process(false)
			hold += delta
			if Game.hud:
				Game.hud.set_hold(true, clampf(hold / hold_need, 0.0, 1.0), prompt_text)
			if hold >= hold_need:
				_finish()
		else:
			if is_instance_valid(_npc) and _npc.alive:
				_npc.set_physics_process(true)
			hold = maxf(0.0, hold - delta * 0.8)
			if Game.hud:
				Game.hud.set_hold(true, clampf(hold / hold_need, 0.0, 1.0), prompt_text)
	elif stand_need > 0.0:
		stand += delta
		if Game.hud:
			Game.hud.set_hold(true, clampf(stand / stand_need, 0.0, 1.0), prompt_text)
		if stand >= stand_need:
			_finish()
	else:
		# 巡逻点：进入即完成
		_finish()


func _release_hold(delta: float) -> void:
	hold = maxf(0.0, hold - delta * 1.2)
	stand = 0.0
	if is_instance_valid(_npc) and _npc.alive:
		_npc.set_physics_process(true)
	if _showing_hold and is_instance_valid(Game.hud):
		Game.hud.set_hold(false, 0.0, "")
	_showing_hold = false


func _finish() -> void:
	if done:
		return
	if mtype == "parcel" and float(mission["progress"]) < 1:
		Game.mission_progress(mid, 1.0)
		mission["target"] = mission["delivery_target"]
		global_position = mission["target"]
		hold = 0.0
		prompt_text = "按住 E 交付包裹"
		Game.toast.emit("包裹已领取，前往地图上的收件点", "ok")
		return
	done = true
	if mtype == "patrol":
		var visited: Array = mission["meta"].get("visited", [])
		visited.append(int(mission.get("point_index", 0)))
		mission["meta"]["visited"] = visited
	if Game.hud:
		Game.hud.set_hold(false, 0.0, "")
	Game.mission_progress(mid, 1.0)
	if is_instance_valid(_npc):
		_npc.queue_free()
	if is_instance_valid(_ring):
		_ring.visible = false
	if is_instance_valid(_beam):
		_beam.visible = false
	for c in _fire_parts:
		if is_instance_valid(c):
			c.visible = false
	queue_free()
