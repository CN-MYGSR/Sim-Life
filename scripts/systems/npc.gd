extends CharacterBody3D
class_name NPC
## 人形 NPC：行人 / 通缉犯 / 伤员 / 顾客（Quaternius 角色 + 内置走路/跑步/待机动画）

const GRAV := 18.0

var kind: String = "pedestrian"
var speed: float = 1.7
var body_color: Color = Color(0.5, 0.5, 0.55)
var target_pos: Vector3 = Vector3.ZERO
var flee_from: Node3D = null
var fleeing: bool = false
var alive: bool = true
var health: float = 100.0
var mission_id: int = -1
var lifetime: float = -1.0

var _t: float = 0.0
var _wander: float = 0.0
var _actor: CharacterModel
var _posed: bool = false
var _route_corner := -1
var _route_cell := Vector2i.ZERO
var _detail_timer := 0.0


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

	_build_visual()
	match kind:
		"criminal":
			speed = 4.6
		"patient":
			speed = 0.0
		"customer":
			speed = 1.4
		_:
			speed = 1.7
	_wander = randf_range(1.0, 3.0)
	_pick_wander_target()


func _build_visual() -> void:
	var model := CharacterModel.pick(kind)
	_actor = CharacterModel.create(model)
	add_child(_actor)
	if kind == "patient":
		# Death 定格姿势会陷进地面一点，整体抬高
		_actor.position.y = 0.15


func _pick_wander_target() -> void:
	if _route_corner < 0:
		var half := (Data.GRID - 1) * 0.5
		_route_cell = Vector2i(clampi(roundi(global_position.x / Data.CELL_PITCH + half), 0, Data.GRID - 1), clampi(roundi(global_position.z / Data.CELL_PITCH + half), 0, Data.GRID - 1))
		var nearest := INF
		for corner in range(4):
			var distance := global_position.distance_squared_to(Data.sidewalk_point(_route_cell, corner))
			if distance < nearest:
				nearest = distance
				_route_corner = corner
	else:
		_route_corner = (_route_corner + 1) % 4
	target_pos = Data.sidewalk_point(_route_cell, _route_corner)


func _physics_process(delta: float) -> void:
	_detail_timer -= delta
	if _detail_timer <= 0.0:
		_detail_timer = 0.5
		if is_instance_valid(_actor.anim_player) and is_instance_valid(Game.player):
			_actor.anim_player.active = global_position.distance_squared_to(Game.player.global_position) < 120.0 * 120.0
	if lifetime > 0.0:
		lifetime -= delta
		if lifetime <= 0.0:
			queue_free()
			return
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
		_update_anim()
		return

	if kind == "criminal" and is_instance_valid(Game.player):
		fleeing = true
		var away := global_position - Game.player.global_position
		away.y = 0.0
		if away.length() < 26.0:
			move_dir = away.normalized()
			moving = true
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
		if to_t.length() < 1.5 or (is_on_wall() and _wander <= 0.0):
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

	_update_anim()


func take_damage(amount: float) -> void:
	if not alive:
		return
	health -= amount
	if health <= 0.0:
		_die()


func _die() -> void:
	if not alive:
		return
	alive = false
	velocity = Vector3.ZERO
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = true
	if _actor != null:
		_actor.play_pose("Death", 1.0)
		_actor.position.y = 0.15
	if mission_id >= 0:
		Game.abandon_mission(mission_id)
		Game.toast.emit("任务失败：目标死亡", "warn")
	if kind != "criminal":
		Game.add_heat(0.6)
		Game.toast.emit("你袭击了平民，通缉度上升", "error")
	await get_tree().create_timer(5.0).timeout
	queue_free()


func _update_anim() -> void:
	if _actor == null:
		return
	if kind == "patient":
		if not _posed:
			_actor.play_pose("Death", 1.0)
			_posed = true
		return
	var hs := Vector2(velocity.x, velocity.z).length()
	if hs < 0.25:
		_actor.play("Idle", 1.0)
	elif hs > 3.0:
		_actor.play_move("Run", hs)
	else:
		_actor.play_move("Walk", hs)
