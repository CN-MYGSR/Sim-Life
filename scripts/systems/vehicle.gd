extends CharacterBody3D
class_name Vehicle
## 街机式载具：贴地行驶、不会翻车，手感稳定

var uid: int = 0
var vtype: String = "sedan"
var paint: Color = Color.WHITE
var stats: Dictionary = {}
var driven: bool = false
var driver: Node3D = null
var prompt: String = "上车"

var speed: float = 0.0
var cam: Camera3D
var wheels: Array = []
var body_root: Node3D
var _steer_visual: float = 0.0
var _cam_base_z: float = 7.8

const GRAV := 22.0
const MAX_REVERSE := 7.0


func setup(p_uid: int, vdata: Dictionary) -> void:
	uid = p_uid
	vtype = vdata["type"]
	paint = vdata["paint"]
	stats = Game.vehicle_stats(vdata)
	_build(vdata)


func _build(vdata: Dictionary) -> void:
	collision_layer = 1 << 2
	collision_mask = 1 | (1 << 1) | (1 << 2) | (1 << 3)
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50.0)

	var sz: Vector3 = stats.get("size", Vector3(1.9, 1.3, 4.4))
	var w := float(sz.x)
	var h := float(sz.y)
	var l := float(sz.z)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w * 0.92, h * 0.85, l * 0.92)
	cs.shape = bs
	cs.position.y = h * 0.5 + 0.15
	add_child(cs)

	body_root = Node3D.new()
	add_child(body_root)

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = paint
	body_mat.roughness = 0.28
	body_mat.metallic = 0.65

	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.06, 0.09, 0.13)
	glass.roughness = 0.06
	glass.metallic = 0.8

	# 主车身
	var b := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h * 0.55, l)
	b.mesh = bm
	b.material_override = body_mat
	b.position.y = h * 0.28 + 0.25
	body_root.add_child(b)

	# 座舱
	var cab := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(w * 0.88, h * 0.42, l * 0.48)
	cab.mesh = cm
	cab.material_override = glass
	cab.position.y = h * 0.72 + 0.25
	cab.position.z = -l * 0.06
	body_root.add_child(cab)

	# 车顶
	var roof := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(w * 0.86, 0.08, l * 0.42)
	roof.mesh = rm
	roof.material_override = body_mat
	roof.position.y = h * 0.92 + 0.25
	roof.position.z = -l * 0.06
	body_root.add_child(roof)

	# 前后灯
	var head_l := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(w * 0.22, 0.14, 0.08)
	head_l.mesh = hm
	head_l.material_override = _emissive(Color(1.0, 0.95, 0.78))
	head_l.position = Vector3(-w * 0.30, h * 0.30 + 0.3, -l * 0.5 - 0.02)
	body_root.add_child(head_l)
	var head_r := head_l.duplicate()
	head_r.position.x = w * 0.30
	body_root.add_child(head_r)

	var tail := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(w * 0.22, 0.12, 0.08)
	tail.mesh = tm
	tail.material_override = _emissive(Color(0.9, 0.15, 0.15))
	tail.position = Vector3(-w * 0.30, h * 0.30 + 0.3, l * 0.5 + 0.02)
	body_root.add_child(tail)
	var tail_r := tail.duplicate()
	tail_r.position.x = w * 0.30
	body_root.add_child(tail_r)

	# 轮子
	var tire_mat := StandardMaterial3D.new()
	tire_mat.albedo_color = Color(0.08, 0.08, 0.09)
	tire_mat.roughness = 0.9
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color(0.72, 0.74, 0.78)
	rim_mat.roughness = 0.35
	rim_mat.metallic = 0.9

	var wx := w * 0.5 - 0.06
	var wz := l * 0.5 - 0.85
	var wy := 0.36
	var wheel_pos := [Vector3(-wx, wy, -wz), Vector3(wx, wy, -wz), Vector3(-wx, wy, wz), Vector3(wx, wy, wz)]
	for i in range(4):
		var pivot := Node3D.new()
		pivot.position = wheel_pos[i]
		body_root.add_child(pivot)
		var spin := Node3D.new()
		pivot.add_child(spin)
		var tire := MeshInstance3D.new()
		var tcm := CylinderMesh.new()
		tcm.top_radius = 0.36
		tcm.bottom_radius = 0.36
		tcm.height = 0.26
		tcm.radial_segments = 14
		tire.mesh = tcm
		tire.material_override = tire_mat
		tire.rotation.z = PI * 0.5
		spin.add_child(tire)
		var rim := MeshInstance3D.new()
		var rcm := CylinderMesh.new()
		rcm.top_radius = 0.19
		rcm.bottom_radius = 0.19
		rcm.height = 0.28
		rcm.radial_segments = 10
		rim.mesh = rcm
		rim.material_override = rim_mat
		rim.rotation.z = PI * 0.5
		spin.add_child(rim)
		wheels.append({"pivot": pivot, "spin": spin, "front": i < 2})

	# 车载摄像机
	cam = Camera3D.new()
	cam.fov = 72.0
	cam.near = 0.1
	cam.far = 400.0
	cam.position = Vector3(0, h + 2.1, _cam_base_z)
	cam.rotation.x = -0.13
	add_child(cam)
	cam.current = false


func _emissive(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.6
	return m


func refresh_from_data(vdata: Dictionary) -> void:
	paint = vdata["paint"]
	stats = Game.vehicle_stats(vdata)
	var body_mat: StandardMaterial3D = null
	for c in body_root.get_children():
		if c is MeshInstance3D and c.material_override is StandardMaterial3D:
			var mm: StandardMaterial3D = c.material_override
			if mm.metallic > 0.5 and mm.roughness < 0.4:
				mm.albedo_color = paint


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAV * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5

	if not driven:
		# 未驾驶时缓慢停下
		speed = move_toward(speed, 0.0, 8.0 * delta)
		velocity.x = -transform.basis.z.x * speed
		velocity.z = -transform.basis.z.z * speed
		move_and_slide()
		return

	var throttle := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	var steer_in := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")

	var top: float = float(stats.get("top", 24.0))
	var accel: float = float(stats.get("accel", 7.5))
	var grip: float = float(stats.get("grip", 1.0))

	if throttle > 0.05:
		speed += accel * throttle * delta
	elif throttle < -0.05:
		if speed > 0.5:
			speed -= 24.0 * absf(throttle) * delta     # 刹车
		else:
			speed -= accel * 0.6 * absf(throttle) * delta
	else:
		speed = move_toward(speed, 0.0, 3.2 * delta)

	speed = clampf(speed, -MAX_REVERSE, top * (1.0 + 0.08))

	# 转向：速度越快越钝
	var speed_factor := clampf(absf(speed) / 9.0, 0.0, 1.0)
	var turn_rate := 1.75 * grip * speed_factor * signf(speed)
	rotate_y(-steer_in * turn_rate * delta)
	_steer_visual = lerpf(_steer_visual, steer_in * 0.5, delta * 8.0)

	var fwd := -transform.basis.z
	velocity.x = fwd.x * speed
	velocity.z = fwd.z * speed
	move_and_slide()

	# 轮子动画
	for wd in wheels:
		var spin: Node3D = wd["spin"]
		spin.rotation.x -= speed * delta / 0.36
		if wd["front"]:
			var pv: Node3D = wd["pivot"]
			pv.rotation.y = _steer_visual

	# 摄像机随速度微调
	cam.position.z = lerpf(cam.position.z, _cam_base_z + absf(speed) * 0.05, delta * 2.0)


func enter(p) -> void:
	driven = true
	driver = p
	if p.has_method("set_active"):
		p.call("set_active", false)
	p.set("driving", true)
	cam.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Game.hud:
		Game.hud.set_prompt("")
	Game.toast.emit("已上车 · W/S 油门刹车，A/D 转向，E 下车", "ok")


func exit() -> void:
	if not driven:
		return
	driven = false
	cam.current = false
	var p = driver
	driver = null
	if is_instance_valid(p):
		p.set("driving", false)
		var side := global_transform.basis.x * 2.6
		p.global_position = global_position + side + Vector3(0, 0.4, 0)
		p.call("set_active", true)
		var pc = p.get("cam")
		if pc is Camera3D:
			pc.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.toast.emit("已下车", "")


func _unhandled_input(event: InputEvent) -> void:
	if driven and event.is_action_pressed("interact"):
		exit()
		get_viewport().set_input_as_handled()


func interact(player) -> void:
	if not driven:
		enter(player)
