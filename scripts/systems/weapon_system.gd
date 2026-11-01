extends Node3D
class_name WeaponSystem
## 第一人称武器：手持模型 / 开火 / 弹匣 / 换弹 / 命中判定
## 挂在玩家的 Camera3D 下，通过 Game.weapon 同步当前装备。

const WEAPON_ASSETS := "res://scripts/core/weapon_assets.gd"

var weapon_id: String = ""
var data: Dictionary = {}
var mag: int = 0
var mag_cap: int = 0
var cooldown: float = 0.0
var reload_t: float = 0.0

var holder: Node3D
var model_root: Node3D
var muzzle: Node3D
var muzzle_light: OmniLight3D
var flash_t: float = 0.0
var _recoil: float = 0.0
var _bob: float = 0.0
var _shoot_prev: bool = false


func _ready() -> void:
	holder = Node3D.new()
	holder.position = Vector3(0.27, -0.23, -0.52)
	add_child(holder)
	model_root = Node3D.new()
	holder.add_child(model_root)
	muzzle = Node3D.new()
	muzzle.position = Vector3(0, 0.03, -0.42)
	holder.add_child(muzzle)
	muzzle_light = OmniLight3D.new()
	muzzle_light.light_color = Color(1.0, 0.75, 0.35)
	muzzle_light.light_energy = 0.0
	muzzle_light.omni_range = 7.0
	muzzle_light.shadow_enabled = false
	muzzle.add_child(muzzle_light)
	# 简易枪口闪光片
	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	flash.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(1.0, 0.85, 0.4, 0.0)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.emission_enabled = true
	fm.emission = Color(1.0, 0.8, 0.4)
	fm.emission_energy_multiplier = 3.0
	flash.material_override = fm
	flash.name = "Flash"
	flash.position = Vector3(0, 0.03, -0.44)
	muzzle.add_child(flash)
	flash_t = 0.0
	_apply_weapon(Game.weapon)


func set_weapon(id: String) -> void:
	_apply_weapon(id)


func _apply_weapon(id: String) -> void:
	weapon_id = id
	reload_t = 0.0
	cooldown = 0.0
	for c in model_root.get_children():
		model_root.remove_child(c)
		c.queue_free()
	if id == "":
		data = {}
		holder.visible = false
		if Game.hud:
			Game.hud.set_weapon_info("", 0, 0)
		return
	data = Game.weapon_info(id)
	if data.is_empty():
		id = ""
		weapon_id = ""
		holder.visible = false
		return
	holder.visible = true
	mag_cap = int(data.get("mag", 12))
	mag = mag_cap
	_build_model(id)
	_update_hud()


func _build_model(id: String) -> void:
	var inst: Node3D = null
	var wa = null
	if ResourceLoader.exists(WEAPON_ASSETS):
		wa = load(WEAPON_ASSETS)
	if wa != null:
		var ps = wa.scene(id)
		if ps != null:
			inst = ps.instantiate() as Node3D
	if inst == null:
		inst = _fallback_model(id)
	var cfg := {}
	if wa != null:
		var cat = wa.CATALOG
		if cat is Dictionary and cat.has(id):
			cfg = cat[id]
	model_root.add_child(inst)
	inst.scale = Vector3.ONE * float(cfg.get("scale", 1.0))
	if cfg.has("grip_rotation"):
		inst.rotation_degrees = cfg["grip_rotation"]
	if cfg.has("grip_offset"):
		inst.position = cfg["grip_offset"]
	if cfg.has("muzzle_offset"):
		muzzle.position = cfg["muzzle_offset"]


func _fallback_model(id: String) -> Node3D:
	var root := Node3D.new()
	var c: Color = data.get("color", Color(0.3, 0.3, 0.32))
	var kind := str(data.get("kind", ""))
	var body_size := Vector3(0.06, 0.10, 0.30)
	var stock := Vector3(0.05, 0.08, 0.18)
	if kind == "手枪":
		body_size = Vector3(0.055, 0.13, 0.24)
	elif kind == "步枪":
		body_size = Vector3(0.07, 0.11, 0.62)
		stock = Vector3(0.05, 0.09, 0.26)
	elif kind == "冲锋枪":
		body_size = Vector3(0.07, 0.13, 0.38)
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = body_size
	mi.mesh = bm
	mi.material_override = m
	root.add_child(mi)
	if kind == "步枪" or kind == "冲锋枪":
		var st := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = stock
		st.mesh = bm2
		st.position = Vector3(0, -0.02, 0.30)
		var m2 := StandardMaterial3D.new()
		m2.albedo_color = Color(0.18, 0.18, 0.2)
		st.material_override = m2
		root.add_child(st)
	var grip := MeshInstance3D.new()
	var bm3 := BoxMesh.new()
	bm3.size = Vector3(0.05, 0.16, 0.07)
	grip.mesh = bm3
	grip.position = Vector3(0, -0.12, 0.02)
	grip.rotation_degrees.x = 12.0
	var m3 := StandardMaterial3D.new()
	m3.albedo_color = Color(0.12, 0.12, 0.14)
	grip.material_override = m3
	root.add_child(grip)
	root.position = Vector3(0, 0.02, -0.30)
	return root


func _process(delta: float) -> void:
	if weapon_id == "":
		return
	var p = Game.player
	holder.visible = is_instance_valid(p) and not p.in_ui and not p.driving and not p.decor_mode and not p.locked
	cooldown = maxf(0.0, cooldown - delta)
	if reload_t > 0.0:
		reload_t = maxf(0.0, reload_t - delta)
		if reload_t <= 0.0:
			mag = mag_cap
			_update_hud()
	# 后坐力回弹
	_recoil = lerpf(_recoil, 0.0, clampf(delta * 10.0, 0.0, 1.0))
	holder.position = Vector3(0.27, -0.23 + _bob, -0.52) + Vector3(0, 0, _recoil)
	# 枪口闪光计时
	if flash_t > 0.0:
		flash_t = maxf(0.0, flash_t - delta)
		muzzle_light.light_energy = 4.0 * (flash_t / 0.05)
		_set_flash_alpha(clampf(flash_t / 0.05, 0.0, 1.0))
	else:
		muzzle_light.light_energy = 0.0
		_set_flash_alpha(0.0)

	if not _can_use():
		return
	# 切枪
	for i in range(4):
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			var ids := Game.own_weapon_list()
			if i < ids.size():
				Game.equip_weapon(ids[i])
	# 换弹
	if Input.is_action_just_pressed("reload") and reload_t <= 0.0 and mag < mag_cap:
		reload_t = 1.1
		Game.toast.emit("换弹中…", "warn")
	# 开火
	var auto := bool(data.get("auto", false))
	var pressed := Input.is_action_pressed("shoot")
	var just := pressed and not _shoot_prev
	_shoot_prev = pressed
	var want := pressed if auto else just
	if not want or cooldown > 0.0 or reload_t > 0.0:
		return
	if mag <= 0:
		reload_t = 1.1
		Game.toast.emit("弹匣空了，换弹中…", "warn")
		return
	_fire()


func _can_use() -> bool:
	if not is_instance_valid(Game.player):
		return false
	var p = Game.player
	if p.in_ui or p.driving or p.decor_mode or p.locked:
		return false
	return true


func _fire() -> void:
	mag -= 1
	cooldown = float(data.get("rate", 0.15))
	flash_t = 0.05
	_recoil = 0.12
	_update_hud()
	var p = Game.player
	var cam: Camera3D = p.cam
	var from: Vector3 = cam.global_position
	var dir: Vector3 = -cam.global_transform.basis.z
	var spread := float(data.get("spread", 0.01))
	dir = (dir + Vector3(randf_range(-spread, spread), randf_range(-spread, spread), 0.0)).normalized()
	var far := float(data.get("range", 120.0))
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * far)
	q.collision_mask = 1 | (1 << 3)
	q.exclude = [p.get_rid()]
	var space := p.get_world_3d().direct_space_state
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return
	var col = hit.get("collider")
	if col is NPC:
		var dmg := float(data.get("damage", 20.0))
		col.take_damage(dmg)
		_spawn_hit_fx(hit.get("position", dir * 5.0), Color(0.8, 0.1, 0.1))
	else:
		_spawn_hit_fx(hit.get("position", dir * 5.0), Color(0.9, 0.85, 0.6))


func _spawn_hit_fx(pos: Vector3, col: Color) -> void:
	var root = Game.world
	if not is_instance_valid(root):
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	mi.material_override = m
	mi.position = pos
	root.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 2.2, 0.12)
	tw.tween_callback(mi.queue_free)


func _update_hud() -> void:
	if Game.hud:
		Game.hud.set_weapon_info(str(data.get("name", "")), mag, mag_cap)


func _set_flash_alpha(a: float) -> void:
	var fl = muzzle.get_node_or_null("Flash")
	if fl == null or fl.material_override == null:
		return
	var m: StandardMaterial3D = fl.material_override
	var c := m.albedo_color
	c.a = a
	m.albedo_color = c
