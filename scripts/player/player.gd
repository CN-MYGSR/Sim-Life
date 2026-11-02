extends CharacterBody3D
class_name Player
## 第一人称控制器：走/跑/蹲/跳 + 射线交互 + 头部晃动

const WALK := 4.3
const RUN := 7.6
const CROUCH := 2.2
const JUMP_VELOCITY := 6.8
const MOUSE_SENS := 0.0022
const ACCEL_GROUND := 12.0
const ACCEL_AIR := 3.0

var cam: Camera3D
var head: Node3D
var torch: OmniLight3D
var weapon_sys: WeaponSystem
var shape: CollisionShape3D
var cap: CapsuleShape3D

var locked: bool = false
var driving: bool = false
var in_ui: bool = false
var decor_mode: bool = false

var _bob_t: float = 0.0
var _bob_amp: float = 0.0
var _crouching: bool = false
var _stand_h: float = 1.8
var _crouch_h: float = 1.15
var _cur_height: float = 1.8
var _current_target: Node = null
var _step_timer: float = 0.0

var gravity: float = 18.0


func _ready() -> void:
	collision_layer = 1 << 1
	collision_mask = 1 | (1 << 2) | (1 << 3)
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)

	cap = CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = _stand_h
	shape = CollisionShape3D.new()
	shape.shape = cap
	shape.position.y = _stand_h * 0.5
	add_child(shape)

	head = Node3D.new()
	head.position.y = 1.64
	add_child(head)

	cam = Camera3D.new()
	cam.fov = 78.0
	cam.near = 0.05
	cam.far = 420.0
	head.add_child(cam)
	cam.current = true

	# 随身照明：夜里能看清脚下
	torch = OmniLight3D.new()
	torch.light_color = Color(1.0, 0.94, 0.82)
	torch.light_energy = 0.0
	torch.omni_range = 18.0
	torch.omni_attenuation = 0.7
	torch.shadow_enabled = false
	torch.position = Vector3(0, 0.1, -0.6)
	cam.add_child(torch)

	# 第一人称武器
	weapon_sys = WeaponSystem.new()
	cam.add_child(weapon_sys)

	gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))


func set_weapon_visual(id: String) -> void:
	if is_instance_valid(weapon_sys):
		weapon_sys.set_weapon(id)


func _unhandled_input(event: InputEvent) -> void:
	if decor_mode:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not in_ui:
		var mm := event as InputEventMouseMotion
		rotate_y(-mm.relative.x * MOUSE_SENS)
		head.rotation.x = clampf(head.rotation.x - mm.relative.y * MOUSE_SENS, -1.45, 1.45)
	elif event.is_action_pressed("interact") and not in_ui and not locked:
		if driving:
			return
		if _current_target and is_instance_valid(_current_target):
			_current_target.call("interact", self)


func _physics_process(delta: float) -> void:
	if driving:
		return
	if in_ui or locked:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return

	if driving:
		return

	# 重力
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -0.5

	# 蹲下
	var want_crouch := Input.is_action_pressed("crouch")
	if want_crouch and not _crouching:
		_crouching = true
	elif not want_crouch and _crouching:
		# 头顶有障碍就不站起来
		if _can_stand():
			_crouching = false

	var target_h := _crouch_h if _crouching else _stand_h
	_cur_height = lerpf(_cur_height, target_h, delta * 12.0)
	cap.height = _cur_height
	shape.position.y = _cur_height * 0.5
	var eye := _cur_height - 0.16
	head.position.y = lerpf(head.position.y, eye, delta * 12.0)

	# 输入
	var iv := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(iv.x, 0.0, iv.y))
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()

	var sprinting := Input.is_action_pressed("sprint") and not _crouching and iv.length() > 0.1 and Game.stamina > 1.0
	var speed := CROUCH if _crouching else (RUN if sprinting else WALK)

	if sprinting:
		Game.stamina = maxf(0.0, Game.stamina - delta * 16.0)
	else:
		Game.stamina = minf(100.0, Game.stamina + delta * 9.0)

	var target_vel := dir * speed
	var accel := ACCEL_GROUND if is_on_floor() else ACCEL_AIR
	velocity.x = lerpf(velocity.x, target_vel.x, clampf(accel * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, target_vel.z, clampf(accel * delta, 0.0, 1.0))

	# 跳跃
	if Input.is_action_just_pressed("jump") and is_on_floor() and not _crouching:
		velocity.y = JUMP_VELOCITY

	move_and_slide()

	# 头部晃动 + 脚步声
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.6:
		_bob_t += delta * (6.0 + hspeed * 1.1)
		_bob_amp = lerpf(_bob_amp, clampf(hspeed / RUN, 0.15, 1.0) * 0.055, delta * 8.0)
		_step_timer += delta * hspeed
	else:
		_bob_amp = lerpf(_bob_amp, 0.0, delta * 6.0)
	cam.position.y = sin(_bob_t * 2.0) * _bob_amp
	cam.position.x = cos(_bob_t) * _bob_amp * 0.6
	# 跑步时视野轻微拉伸
	cam.fov = lerpf(cam.fov, 78.0 + (8.0 if sprinting else 0.0), delta * 6.0)
	# 夜间随身光
	var want_light := 2.6 if Game.is_night() else 0.0
	torch.light_energy = lerpf(torch.light_energy, want_light, delta * 2.0)

	_update_interaction()


func _can_stand() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, _crouch_h, 0),
		global_position + Vector3(0, _stand_h + 0.1, 0))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return space.intersect_ray(q).is_empty()


func _update_interaction() -> void:
	if driving:
		return
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * Data.INTERACT_DIST
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1 | (1 << 4) | (1 << 2)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var found: Node = null
	if not hit.is_empty():
		var col = hit.get("collider")
		if col is Node and col.has_method("interact"):
			found = col
	if found != _current_target:
		_current_target = found
		if Game.hud and Game.hud.has_method("set_prompt"):
			var p := ""
			if found:
				var raw = found.get("prompt")
				p = str(raw) if raw != null else "交互"
			Game.hud.set_prompt(p)


func is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 0.5


func get_camera() -> Camera3D:
	return cam


func set_active(active: bool) -> void:
	shape.set_deferred("disabled", not active)
	cam.current = active
	visible = active
	set_physics_process(active)
	if active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO


func set_target(prompt: String, cb: Callable) -> void:
	# 供任务目标临时占用交互提示
	if Game.hud and Game.hud.has_method("set_prompt"):
		Game.hud.set_prompt(prompt)
