extends Node3D
class_name CharacterModel
## Quaternius 人形角色（自带 Idle / Walk / Run / Death 等 17 个动画）
## 挂到 NPC 身上作为可视模型；动画由 NPC 根据速度切换。

const DIR := "res://assets/chars/"
static var _scene_cache: Dictionary = {}

## 行人 / 顾客的模型池（男女混搭）
const PEDS := [
	"Casual_Male", "Casual_Female", "Casual2_Male", "Casual2_Female",
	"Casual3_Male", "Casual3_Female", "Casual_Bald",
	"OldClassy_Male", "OldClassy_Female", "Worker_Male", "Worker_Female",
	"Suit_Male", "Suit_Female",
]
const CRIMINALS := ["Pirate_Male", "Ninja_Male", "Zombie_Male"]
const PATIENTS := ["Casual_Male", "Casual_Female", "Worker_Female"]

var anim_player: AnimationPlayer
var model_name: String = ""
var _cur: String = ""
var _scale: float = 1.0

## 动画内隐含的移动速度（scale=1 时）：走路约 2.83 m/s，跑步约 4.84 m/s
const BASE_WALK := 2.83
const BASE_RUN := 4.84


static func create(name: String) -> CharacterModel:
	var cm := CharacterModel.new()
	cm.setup(name)
	return cm


static func pick(kind: String) -> String:
	match kind:
		"criminal":
			return CRIMINALS[randi() % CRIMINALS.size()]
		"patient":
			return PATIENTS[randi() % PATIENTS.size()]
		_:
			return PEDS[randi() % PEDS.size()]


func setup(name: String) -> void:
	model_name = name
	var ps: PackedScene = _scene_cache.get(name)
	if not _scene_cache.has(name):
		var path := DIR + name + ".gltf"
		ps = load(path) as PackedScene if ResourceLoader.exists(path) else null
		_scene_cache[name] = ps
	var inst: Node3D
	if ps != null:
		inst = ps.instantiate() as Node3D
	else:
		inst = ProceduralAssets.person()
	add_child(inst)
	# 模型按米制导出时约 3.3m 高，缩放到正常人形身高
	var raw_h := _height(inst, Transform3D.IDENTITY)
	if raw_h > 0.1:
		var s := 1.70 / raw_h
		inst.scale = Vector3(s, s, s)
		_scale = s
	anim_player = _find_ap(inst)
	if anim_player:
		for a in ["Idle", "Walk", "Run"]:
			if anim_player.has_animation(a):
				anim_player.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_fix_materials(inst)
	# 模型正面为 +Z；NPC 旋转 0 时朝 -Z（游戏前进方向）
	rotation.y = PI


## glTF 里的材质是接近黑色的线性色值，这里换成正常的低模配色并做出变化
func _fix_materials(inst: Node) -> void:
	var skin := Color(0.86, 0.67, 0.53)
	var skins := [Color(0.90, 0.73, 0.60), Color(0.80, 0.60, 0.46), Color(0.62, 0.44, 0.33)]
	var hairs := [Color(0.10, 0.07, 0.05), Color(0.24, 0.15, 0.09), Color(0.44, 0.30, 0.16), Color(0.62, 0.50, 0.32)]
	var shirts := [
		Color(0.24, 0.38, 0.58), Color(0.62, 0.22, 0.20), Color(0.26, 0.44, 0.30),
		Color(0.76, 0.66, 0.30), Color(0.42, 0.32, 0.46), Color(0.80, 0.80, 0.78),
		Color(0.30, 0.30, 0.32), Color(0.52, 0.42, 0.30),
	]
	var pants := [Color(0.16, 0.19, 0.25), Color(0.10, 0.10, 0.12), Color(0.28, 0.24, 0.20), Color(0.22, 0.26, 0.22)]
	skin = skins[randi() % skins.size()]
	for mi in _all_meshes(inst):
		if mi.mesh == null:
			continue
		for i in range(mi.mesh.get_surface_count()):
			var base: Material = mi.mesh.surface_get_material(i)
			if base == null:
				continue
			var m: StandardMaterial3D = base.duplicate() as StandardMaterial3D
			if m == null:
				continue
			var nm := String(base.resource_name)
			match nm:
				"Skin":
					m.albedo_color = skin
				"Face":
					m.albedo_color = Color(0.96, 0.90, 0.82)
				"Hair":
					m.albedo_color = hairs[randi() % hairs.size()]
				"Shirt":
					m.albedo_color = shirts[randi() % shirts.size()]
				"Pants":
					m.albedo_color = pants[randi() % pants.size()]
				"Belt":
					m.albedo_color = Color(0.14, 0.11, 0.09)
			m.roughness = 0.85
			mi.set_surface_override_material(i, m)


func _all_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_meshes(c))
	return out


func _height(n: Node, xf: Transform3D) -> float:
	return _aabb(n, xf).size.y


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			box = xf * mi.get_aabb()
			first = false
	for c in n.get_children():
		var t := xf
		if c is Node3D:
			t = xf * (c as Node3D).transform
		var cb := _aabb(c, t)
		if cb.size != Vector3.ZERO:
			if first:
				box = cb
				first = false
			else:
				box = box.merge(cb)
	return box



func play(anim: String, speed_scale := 1.0) -> void:
	if anim_player == null or not anim_player.has_animation(anim):
		return
	if _cur != anim:
		_cur = anim
		anim_player.play(anim, 0.18)
	anim_player.speed_scale = speed_scale


## 按实际移动速度调整走路/跑步动画播放速率，减少脚底打滑
func play_move(anim: String, world_speed: float) -> void:
	var base := BASE_WALK if anim == "Walk" else BASE_RUN
	var s := world_speed / maxf(0.1, base * _scale)
	play(anim, clampf(s, 0.45, 2.4))


## 定格在某段动画的末尾（伤员倒地）
func play_pose(anim: String, ratio := 1.0) -> void:
	if anim_player == null or not anim_player.has_animation(anim):
		return
	_cur = anim
	var a := anim_player.get_animation(anim)
	anim_player.play(anim, 0.0)
	anim_player.seek(a.length * ratio, true)
	anim_player.pause()


func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r != null:
			return r
	return null
