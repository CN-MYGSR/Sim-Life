extends CharacterBody3D
class_name NPC
## 简化人形 NPC：行人 / 通缉犯 / 伤员 / 顾客

const GRAV := 18.0

var kind: String = "pedestrian"
var speed: float = 1.7
var body_color: Color = Color(0.5, 0.5, 0.55)
var target_pos: Vector3 = Vector3.ZERO
var flee_from: Node3D = null
var fleeing: bool = false
var alive: bool = true

var _t: float = 0.0
var _wander: float = 0.0
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _step_phase: float = 0.0


static func spawn(parent: Node3D, pos: Vector3, p_kind: String, color: Color) -> NPC:
	var n := NPC.new()
	n.kind = p_kind
	n.body_color = color
	n.position = pos
	parent.add_child(n)
	return n


func _ready() -> void:
	collision_layer = 1 << 3
	collision_mask = 1 | (1 << 1)
	floor_snap_length = 0.4

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.30
	cap.height = 1.7
	cs.shape = cap
	cs.position.y = 0.85
	add_child(cs)

	_build_body()
	match kind:
		"criminal":
			speed = 4.6
			body_color = Color(0.55, 0.16, 0.18)
		"patient":
			speed = 0.0
			_rotate_down()
		"customer":
			speed = 1.4
		_:
			speed = 1.7
	_wander = randf_range(1.0, 3.0)
	_pick_wander_target()


func _build_body() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = body_color
	m.roughness = 0.85
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.86, 0.70, 0.58)
	skin.roughness = 0.8
	var pants := StandardMaterial3D.new()
	pants.albedo_color = body_color.darkened(0.35)
	pants.roughness = 0.9

	var torso := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.52, 0.72, 0.30)
	torso.mesh = bm
	torso.material_override = m
	torso.position.y = 1.14
	add_child(torso)

	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.17
	sm.height = 0.34
	head.mesh = sm
	head.material_override = skin
	head.position.y = 1.63
	add_child(head)

	_leg_l = _limb(Vector3(-0.14, 0.78, 0), Vector3(0.17, 0.78, 0.19), pants)
	_leg_r = _limb(Vector3(0.14, 0.78, 0), Vector3(0.17, 0.78, 0.19), pants)
	_arm_l = _limb(Vector3(-0.34, 1.44, 0), Vector3(0.14, 0.62, 0.15), m)
	_arm_r = _limb(Vector3(0.34, 1.44, 0), Vector3(0.14, 0.62, 0.15), m)


func _limb(pivot_pos: Vector3, size: Vector3, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_pos
	add_child(pivot)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position.y = -size.y * 0.5
	pivot.add_child(mi)
	return pivot


func _rotate_down() -> void:
	# 伤员：整体倒地
	var pivot := Node3D.new()
	add_child(pivot)
	rotation.z = PI * 0.5
	position.y += 0.25


func _pick_wander_target() -> void:
	var a := randf() * TAU
	var r := randf_range(6.0, 20.0)
	target_pos = global_position + Vector3(cos(a) * r, 0, sin(a) * r)
	# 避免走出城市
	var lim := Data.CITY_HALF - 8.0
	target_pos.x = clampf(target_pos.x, -lim, lim)
	target_pos.z = clampf(target_pos.z, -lim, lim)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAV * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5

	var move_dir := Vector3.ZERO
	var moving := false

	if kind == "patient":
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if kind == "criminal" and is_instance_valid(Game.player):
		fleeing = true
		var away := global_position - Game.player.global_position
		away.y = 0.0
		if away.length() < 26.0:
			move_dir = away.normalized()
			moving = true
			# 撞墙时侧向绕行
			if is_on_wall():
				var side := Vector3(-away.z, 0, away.x).normalized()
				move_dir = (move_dir + side * 0.9).normalized()
		else:
			_wander -= delta
			if _wander <= 0.0:
				_wander = 2.0
				_pick_wander_target()
			move_dir = (target_pos - global_position)
			move_dir.y = 0.0
			if move_dir.length() > 1.5:
				move_dir = move_dir.normalized()
				moving = true
	else:
		_wander -= delta
		var to_t := target_pos - global_position
		to_t.y = 0.0
		if _wander <= 0.0 or to_t.length() < 1.5:
			_wander = randf_range(2.5, 6.0)
			_pick_wander_target()
		elif to_t.length() > 0.5:
			move_dir = to_t.normalized()
			moving = true

	var target_v := move_dir * speed
	velocity.x = lerpf(velocity.x, target_v.x, clampf(delta * 8.0, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, target_v.z, clampf(delta * 8.0, 0.0, 1.0))
	move_and_slide()

	# 朝向移动方向
	if moving and Vector2(velocity.x, velocity.z).length() > 0.2:
		var want := atan2(-velocity.x, -velocity.z)
		rotation.y = lerp_angle(rotation.y, want, delta * 8.0)

	# 走路摆腿
	var hs := Vector2(velocity.x, velocity.z).length()
	_step_phase += delta * (4.0 + hs * 2.2)
	var amp := clampf(hs / 3.0, 0.0, 1.0) * 0.65
	if _leg_l:
		_leg_l.rotation.x = sin(_step_phase) * amp
		_leg_r.rotation.x = -sin(_step_phase) * amp
		_arm_l.rotation.x = -sin(_step_phase) * amp * 0.7
		_arm_r.rotation.x = sin(_step_phase) * amp * 0.7
