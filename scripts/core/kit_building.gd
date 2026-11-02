extends Node3D
class_name KitBuilding
## 用 Quaternius Downtown City MegaKit 生成「可进入 + 多层 + 有内饰」的建筑。
## 外观 / 内饰墙体用 MultiMesh 合批；行走碰撞用简化盒体；夜里窗户亮灯。

const STOREY := 3.0
const MOD := 2.0
const WALL_T := 0.3
const HOLE := 4.0

var place: Dictionary
var host: Node
var rng: RandomNumberGenerator

var w: float
var d: float
var floors: int
var style: String
var kind: String
var door_slot: int
var stair_x0: float
var stair_z0: float
var floor_color := Color(0.52, 0.50, 0.46)

var _root: Node3D
var _batch: Dictionary = {}
var _boxes: Dictionary = {}
var _win_transforms: Array = []
var _win_glow: MultiMeshInstance3D
var batched_boxes := 0


func setup(p: Dictionary, main_node: Node, r: RandomNumberGenerator) -> void:
	place = p
	host = main_node
	rng = r
	w = float(p["size"].x)
	d = float(p["size"].y)
	# 保证宽度是奇数个 2m 模数：这样正中间一定有一个门洞，玩家从正面中心能直走进去
	if int(w / MOD) % 2 == 0:
		w += MOD
	kind = str(p["kind"])
	style = _style_for(kind)
	floors = _floors_for(kind, place)
	door_slot = int(w / MOD * 0.5)
	# 楼梯井放在右前角：进门往右前方就能看到楼梯，两跑楼梯并排折返
	stair_x0 = w * 0.5 - 4.25
	stair_z0 = d * 0.5 - 5.75
	if kind == "diner":
		floor_color = Color(0.44, 0.33, 0.25)
	elif kind == "hospital":
		floor_color = Color(0.62, 0.63, 0.62)
	elif kind == "bank":
		floor_color = Color(0.58, 0.56, 0.50)
	elif kind == "deco":
		floor_color = Color(0.50, 0.50, 0.52)


func build_to(parent: Node3D) -> Node3D:
	_root = Node3D.new()
	_root.name = "KitBody"
	parent.add_child(_root)
	_build_facade()
	_build_floors()
	_build_stairs()
	_build_interior()
	_build_roof()
	_build_sign()
	_build_decor()
	_flush_all()
	batched_boxes = StaticBatcher.batch_boxes(_root)
	return _root


# ── 合批工具 ────────────────────────────────────────────────
func _bp(name: String, pos: Vector3, rot_y := 0.0) -> void:
	if not _batch.has(name):
		_batch[name] = []
	_batch[name].append(Transform3D(Basis(Vector3.UP, rot_y), pos))


func _bb(pos: Vector3, size: Vector3, color: Color, rot_y := 0.0) -> void:
	var key := color.to_html(false)
	if not _boxes.has(key):
		_boxes[key] = {"color": color, "xf": []}
	_boxes[key]["xf"].append(Transform3D(Basis(Vector3.UP, rot_y) * Basis.from_scale(size), pos))


func _flush_all() -> void:
	for name in _batch.keys():
		KitLib.multimesh(_root, name, _batch[name])
	_batch.clear()
	for key in _boxes.keys():
		var entry: Dictionary = _boxes[key]
		KitLib.box_multimesh(_root, entry["xf"], entry["color"])
	_boxes.clear()
	_build_window_glow()


# ─────────────────────────── 外观 ───────────────────────────
func _build_facade() -> void:
	for f in range(floors):
		_side(f, STOREY * f, true)
		_side(f, STOREY * f, false)
		_side_x(f, STOREY * f, -1.0)
		_side_x(f, STOREY * f, 1.0)
	for f in range(floors):
		_collide_side(f, STOREY * f)


func _side(f: int, y: float, front: bool) -> void:
	var z := d * 0.5 if front else -d * 0.5
	var rot := 0.0 if front else PI
	var n := int(w / MOD)
	for i in range(n):
		var x := -w * 0.5 + MOD * 0.5 + i * MOD
		var name := _slot_module(f, i, n, front)
		if name == "":
			continue
		_bp(name, Vector3(x, y, z), rot)
		if _is_window(name):
			_win_transforms.append(Transform3D(Basis(Vector3.UP, rot), Vector3(x, y + 1.5, z + (0.14 if front else -0.14))))
		if front and f == 0 and i == door_slot:
			_place_open_door(x, y, z)
	if f == floors - 1:
		_cornice_line(front)


func _side_x(f: int, y: float, dir: float) -> void:
	var x := w * 0.5 * dir
	var rot := PI * 0.5 * dir
	var n := int(d / MOD)
	for i in range(n):
		var z := -d * 0.5 + MOD * 0.5 + i * MOD
		var name := _slot_module_x(f, i, n)
		if name == "":
			continue
		_bp(name, Vector3(x, y, z), rot)
		if _is_window(name):
			_win_transforms.append(Transform3D(Basis(Vector3.UP, rot), Vector3(x + 0.14 * dir, y + 1.5, z)))
	if f == floors - 1:
		_cornice_line_x(dir)


func _is_window(name: String) -> bool:
	return name.contains("Window") or name.contains("FullWindow")


func _slot_module(f: int, i: int, n: int, front: bool) -> String:
	var plain := _plain_name()
	if f == 0:
		if front and i == door_slot:
			return "DoorFrame_Trim"
		if i >= 1 and i <= n - 2 and (i % 2 == 1):
			return _ground_window_name(i)
		return _ground_plain_name()
	if i >= 1 and i <= n - 2:
		if (i + f) % 2 == 1:
			return _upper_window_name(i)
	if f == floors - 1 and i % 3 == 0:
		return _top_trim_name()
	return plain


func _slot_module_x(f: int, i: int, n: int) -> String:
	var plain := _plain_name()
	if f == 0:
		if i >= 1 and i <= n - 2 and i % 3 == 1:
			return _ground_window_name(i)
		return _ground_plain_name()
	if i >= 1 and i <= n - 2 and (i + f) % 2 == 1:
		return _upper_window_name(i)
	return plain


func _plain_name() -> String:
	match style:
		"metal": return "Metal_Plain_3"
		"trim": return "Trim_Plain_3"
		_: return "Brick_Plain_3"


func _ground_plain_name() -> String:
	match style:
		"metal": return "Metal_FirstFloor_Wall"
		"trim": return "Trim_FirstFloor_Wall"
		_: return "Brick_BottomTrim"


func _top_trim_name() -> String:
	match style:
		"metal": return "Metal_Plain_3"
		"trim": return "Trim_Plain_3"
		_: return "Brick_TopTrim"


func _ground_window_name(i: int) -> String:
	match style:
		"metal": return "Metal_FirstFloor_Window"
		"trim": return "Trim_FirstFloor_Window_001"
		_: return "Brick_Window_Trim_Single" if i % 2 == 1 else "Brick_Window_Square_Single"


func _upper_window_name(i: int) -> String:
	match style:
		"metal": return "Metal_Window_Half" if i % 2 == 1 else "Metal_FullWindow"
		"trim": return "Trim_Window"
		_: return "Brick_Window_Trim_Single" if i % 2 == 1 else "Brick_Window_Square_Single"


func _place_open_door(x: float, y: float, z: float) -> void:
	KitLib.place(_root, "Door_1", Vector3(x - 0.95, y, z - 0.02), -1.25)


func _collide_side(f: int, y: float) -> void:
	var cy := y + STOREY * 0.5
	var z := d * 0.5
	if f == 0:
		var door_left := -w * 0.5 + door_slot * MOD
		var door_right := door_left + MOD
		var left_w := door_left - (-w * 0.5)
		if left_w > 0.05:
			KitLib.solid(_root, Vector3(-w * 0.5 + left_w * 0.5, cy, z), Vector3(left_w, STOREY, WALL_T))
		var right_w := w * 0.5 - door_right
		if right_w > 0.05:
			KitLib.solid(_root, Vector3(w * 0.5 - right_w * 0.5, cy, z), Vector3(right_w, STOREY, WALL_T))
	else:
		KitLib.solid(_root, Vector3(0, cy, z), Vector3(w, STOREY, WALL_T))
	KitLib.solid(_root, Vector3(0, cy, -d * 0.5), Vector3(w, STOREY, WALL_T))
	KitLib.solid(_root, Vector3(-w * 0.5, cy, 0), Vector3(WALL_T, STOREY, d))
	KitLib.solid(_root, Vector3(w * 0.5, cy, 0), Vector3(WALL_T, STOREY, d))


func _cornice_name() -> String:
	match style:
		"metal": return "Cornice_Metal_Center"
		"trim": return "Cornice_Trim_Center"
		_: return "Cornice_Brick_Center"


func _cornice_line(front: bool) -> void:
	var y := STOREY * floors
	var z := d * 0.5 if front else -d * 0.5
	var rot := 0.0 if front else PI
	var n := int(w / MOD)
	for i in range(n):
		_bp(_cornice_name(), Vector3(-w * 0.5 + MOD * 0.5 + i * MOD, y, z), rot)


func _cornice_line_x(dir: float) -> void:
	var y := STOREY * floors
	var x := w * 0.5 * dir
	var rot := PI * 0.5 * dir
	var n := int(d / MOD)
	for i in range(n):
		_bp(_cornice_name(), Vector3(x, y, -d * 0.5 + MOD * 0.5 + i * MOD), rot)


# ─────────────────────────── 楼板 / 屋顶 ───────────────────────────
func _slab(rect: Rect2, y_top: float, color: Color, collide := true) -> void:
	var cx := rect.position.x + rect.size.x * 0.5
	var cz := rect.position.y + rect.size.y * 0.5
	_bb(Vector3(cx, y_top - 0.1, cz), Vector3(rect.size.x, 0.2, rect.size.y), color)
	if collide:
		KitLib.solid(_root, Vector3(cx, y_top - 0.1, cz), Vector3(rect.size.x, 0.2, rect.size.y))


func _build_floors() -> void:
	_slab(Rect2(-w * 0.5 + 0.15, -d * 0.5 + 0.15, w - 0.3, d - 0.3), 0.02, floor_color)
	var hx := stair_x0
	var hz := stair_z0
	for f in range(1, floors):
		var y := STOREY * f
		_slab(Rect2(-w * 0.5 + 0.15, -d * 0.5 + 0.15, hx - (-w * 0.5 + 0.15), d - 0.3), y, floor_color)
		var rx := hx + HOLE
		_slab(Rect2(rx, -d * 0.5 + 0.15, (w * 0.5 - 0.15) - rx, d - 0.3), y, floor_color)
		_slab(Rect2(hx, -d * 0.5 + 0.15, HOLE, hz - (-d * 0.5 + 0.15)), y, floor_color)
		var fz := hz + HOLE
		_slab(Rect2(hx, fz, HOLE, (d * 0.5 - 0.15) - fz), y, floor_color)
		_stair_rail(f, hz, y)


func _stair_rail(f: int, hz: float, y: float) -> void:
	var col := Color(0.30, 0.32, 0.34)
	var hx := stair_x0
	var arrive_back := (f - 1) % 2 == 0
	var rail_z := hz + HOLE if arrive_back else hz
	_bb(Vector3(hx + HOLE * 0.5, y + 0.45, rail_z), Vector3(HOLE, 0.9, 0.08), col)
	KitLib.solid(_root, Vector3(hx + HOLE * 0.5, y + 0.45, rail_z), Vector3(HOLE, 0.9, 0.08))
	# 左右两侧栏杆
	_bb(Vector3(hx, y + 0.45, hz + HOLE * 0.5), Vector3(0.08, 0.9, HOLE), col)
	KitLib.solid(_root, Vector3(hx, y + 0.45, hz + HOLE * 0.5), Vector3(0.08, 0.9, HOLE))
	_bb(Vector3(hx + HOLE, y + 0.45, hz + HOLE * 0.5), Vector3(0.08, 0.9, HOLE), col)
	KitLib.solid(_root, Vector3(hx + HOLE, y + 0.45, hz + HOLE * 0.5), Vector3(0.08, 0.9, HOLE))


func _build_roof() -> void:
	var top := STOREY * floors
	_bb(Vector3(0, top + 0.15, 0), Vector3(w + 0.5, 0.3, d + 0.5), Color(0.17, 0.18, 0.20))
	KitLib.solid(_root, Vector3(0, top + 0.15, 0), Vector3(w + 0.5, 0.3, d + 0.5))
	var pc := Color(0.32, 0.30, 0.28)
	_bb(Vector3(0, top + 0.55, d * 0.5), Vector3(w, 0.5, 0.25), pc)
	_bb(Vector3(0, top + 0.55, -d * 0.5), Vector3(w, 0.5, 0.25), pc)
	_bb(Vector3(-w * 0.5, top + 0.55, 0), Vector3(0.25, 0.5, d), pc)
	_bb(Vector3(w * 0.5, top + 0.55, 0), Vector3(0.25, 0.5, d), pc)
	KitLib.place(_root, "Prop_ACUnit", Vector3(w * 0.22, top + 0.3, -d * 0.15))
	KitLib.place(_root, "Prop_ACUnit", Vector3(w * 0.30, top + 0.3, -d * 0.15))
	_bb(Vector3(-w * 0.2, top + 0.75, d * 0.1), Vector3(2.0, 1.1, 2.0), Color(0.40, 0.41, 0.43))


# ─────────────────────────── 楼梯 ───────────────────────────
func _build_stairs() -> void:
	var z0 := stair_z0
	var z1 := stair_z0 + HOLE
	for f in range(floors - 1):
		var base := STOREY * f
		var up_neg_z := (f % 2 == 0)
		# 两跑并排：偶数跑左半、奇数跑右半，避免上下两跑叠在一起挡头
		var sx := stair_x0 + (1.0 if up_neg_z else 3.0)
		var step_col := Color(0.56, 0.54, 0.51)
		for i in range(10):
			var h: float = 0.3 * (i + 1)
			var zz: float
			if up_neg_z:
				zz = z1 - 0.4 * (i + 0.5)
			else:
				zz = z0 + 0.4 * (i + 0.5)
			_bb(Vector3(sx, base + h * 0.5, zz), Vector3(1.7, h, 0.4), step_col)
		var ang := atan2(3.0, 4.0)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3(sx, base + 1.5, (z0 + z1) * 0.5)
		body.rotation.x = ang if up_neg_z else -ang
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(1.7, 0.2, 5.0)
		cs.shape = sh
		body.add_child(cs)
		_root.add_child(body)


# ─────────────────────────── 内饰 ───────────────────────────
func _build_interior() -> void:
	# 家具类型（deco 楼按用途细分）
	var fkind: String = str(place.get("interior", kind))
	if kind == "deco" and not place.has("interior"):
		var id := str(place.get("id", ""))
		if id == "deco_a":
			fkind = "deco_office"
		elif id == "deco_b":
			fkind = "deco_apartment"
		else:
			fkind = "deco_warehouse"
	for f in range(floors):
		var y := STOREY * f
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.90, 0.75)
		light.light_energy = 3.6 if w >= 26.0 else 2.8
		light.omni_range = 18.0
		light.omni_attenuation = 0.9
		light.shadow_enabled = false
		light.position = Vector3(0, y + 2.45, 0)
		_root.add_child(light)
		_bb(Vector3(0, y + 2.82, 0), Vector3(1.6, 0.06, 0.5), Color(1.0, 0.96, 0.86))
	# 室内家具：整层摆放，再把挡在「进门 → 楼梯」主通道上的家具清掉
	var before := {}
	for c in _root.get_children():
		before[c] = true
	var area := Rect2(-w * 0.5 + 0.7, -d * 0.5 + 0.7, w - 1.4, d - 1.4)
	for f in range(floors):
		InteriorFurnish.furnish(_root, fkind, STOREY * f, area, rng)
	_prune_path_furniture(before)


func _path_rects() -> Array:
	var z1 := stair_z0 + HOLE
	return [
		Rect2(-1.7, -d * 0.5, 3.4, d),
		Rect2(-2.0, z1 - 0.6, w * 0.5 + 2.0 - (-2.0), d * 0.5 - (z1 - 0.6)),
		Rect2(stair_x0 - 0.4, stair_z0 - 0.4, HOLE + 0.8, HOLE + 0.8),
	]


func _prune_path_furniture(before: Dictionary) -> void:
	var paths := _path_rects()
	var pieces: Array = []
	for c in _root.get_children():
		if before.has(c) or not (c is Node3D):
			continue
		pieces.append(c)
	for piece in pieces:
		var r := _piece_block_rect(piece)
		if r.size.x > 0.0 or r.size.y > 0.0:
			var blocked := false
			for pr in paths:
				if r.intersects(pr):
					blocked = true
					break
			if blocked:
				piece.free()
				continue
		# 家具不再参与碰撞：保证任何情况下都不会把人卡住
		for ch in piece.get_children():
			if ch is StaticBody3D:
				ch.free()


func _piece_block_rect(piece: Node3D) -> Rect2:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	var found := false
	for sb in piece.get_children():
		if not (sb is StaticBody3D):
			continue
		for cs in sb.get_children():
			if not (cs is CollisionShape3D):
				continue
			var sh = cs.shape
			if not (sh is BoxShape3D):
				continue
			var sz: Vector3 = sh.size
			var loc: Vector3 = sb.position + cs.position
			var yaw := piece.rotation.y
			var c2 := Vector2(loc.x, loc.z).rotated(yaw)
			var hx := absf(cos(yaw)) * sz.x * 0.5 + absf(sin(yaw)) * sz.z * 0.5
			var hz := absf(sin(yaw)) * sz.x * 0.5 + absf(cos(yaw)) * sz.z * 0.5
			var center := Vector2(piece.position.x, piece.position.z) + c2
			mn.x = minf(mn.x, center.x - hx)
			mn.y = minf(mn.y, center.y - hz)
			mx.x = maxf(mx.x, center.x + hx)
			mx.y = maxf(mx.y, center.y + hz)
			found = true
	if not found:
		return Rect2()
	return Rect2(mn, mx - mn)


# ─────────────────────────── 窗户亮灯 ───────────────────────────
func _build_window_glow() -> void:
	_win_glow = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2(1.35, 1.65)
	mm.mesh = quad
	var lit: Array = []
	for xf in _win_transforms:
		if rng.randf() < 0.78:
			lit.append(xf)
	mm.instance_count = lit.size()
	for i in range(lit.size()):
		mm.set_instance_transform(i, lit[i])
	_win_glow.multimesh = mm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.82, 0.52, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(1.0, 0.78, 0.45)
	m.emission_energy_multiplier = 0.9
	_win_glow.material_override = m
	_win_glow.visible = false
	_root.add_child(_win_glow)


func set_night(amount: float) -> void:
	if is_instance_valid(_win_glow):
		_win_glow.visible = amount > 0.12
		if _win_glow.material_override is StandardMaterial3D:
			var m := _win_glow.material_override as StandardMaterial3D
			m.albedo_color.a = clampf(0.25 + amount * 0.7, 0.0, 1.0)


# ─────────────────────────── 招牌 & 装饰 ───────────────────────────
func _build_sign() -> void:
	var sign: String = str(place.get("sign", ""))
	if sign == "":
		return
	var top := STOREY * floors
	var sign_col := Color(0.95, 0.95, 0.95)
	match kind:
		"police": sign_col = Color(0.55, 0.75, 1.0)
		"fire": sign_col = Color(1.0, 0.62, 0.55)
		"hospital": sign_col = Color(1.0, 0.55, 0.55)
		"diner": sign_col = Color(1.0, 0.80, 0.42)
		"mart": sign_col = Color(0.55, 1.0, 0.75)
		"gang": sign_col = Color(0.75, 0.60, 1.0)
		"garage": sign_col = Color(1.0, 0.92, 0.45)
	var bw := clampf(w * 0.45, 5.0, 9.0)
	var sy := top + 1.55
	var sz := d * 0.5 - 1.4
	_bb(Vector3(0, sy, sz), Vector3(bw, 1.5, 0.18), Color(0.08, 0.09, 0.11))
	_bb(Vector3(-bw * 0.38, sy - 1.0, sz), Vector3(0.12, 1.0, 0.12), Color(0.25, 0.26, 0.28))
	_bb(Vector3(bw * 0.38, sy - 1.0, sz), Vector3(0.12, 1.0, 0.12), Color(0.25, 0.26, 0.28))
	var label := Label3D.new()
	label.text = sign
	label.font = Game.get_font()
	label.font_size = 90
	label.pixel_size = 0.0075
	label.modulate = sign_col
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 0.65)
	label.position = Vector3(0, sy, sz + 0.12)
	label.shaded = false
	_root.add_child(label)


func _build_decor() -> void:
	var top := STOREY * floors
	match kind:
		"police":
			_bb(Vector3(0, top + 1.0, 0), Vector3(3.2, 0.3, 0.5), Color(0.25, 0.55, 1.0))
			for i in range(3):
				_bb(Vector3(-w * 0.5 - 0.3, 1.0 + i * 2.6, d * 0.5 - 1.6), Vector3(0.25, 1.4, 0.25), Color(0.75, 0.78, 0.82))
		"fire":
			for i in range(2):
				_bb(Vector3(-w * 0.20 + i * w * 0.40, 1.3, d * 0.5 + 0.16), Vector3(5.2, 2.6, 0.1), Color(0.62, 0.20, 0.18))
			_bb(Vector3(0, top + 0.9, 0), Vector3(2.6, 0.3, 0.4), Color(1.0, 0.35, 0.25))
		"hospital":
			_bb(Vector3(0, top + 2.4, d * 0.5 - 1.3), Vector3(0.6, 2.6, 0.1), Color(0.92, 0.30, 0.32))
			_bb(Vector3(0, top + 2.4, d * 0.5 - 1.3), Vector3(2.6, 0.6, 0.1), Color(0.92, 0.30, 0.32))
		"diner":
			for i in range(6):
				var ax := -w * 0.40 + i * (w * 0.80 / 5.0)
				var ac := Color(0.90, 0.32, 0.28) if i % 2 == 0 else Color(0.95, 0.93, 0.88)
				_bb(Vector3(ax, 2.85, d * 0.5 + 1.1), Vector3(w * 0.80 / 5.0, 0.10, 1.8), ac)
				_bb(Vector3(ax, 2.60, d * 0.5 + 1.98), Vector3(w * 0.80 / 5.0, 0.4, 0.08), ac)
		"mart":
			_bb(Vector3(0, 2.95, d * 0.5 + 0.2), Vector3(w * 0.7, 0.20, 0.10), Color(0.35, 1.0, 0.62))
		"garage":
			_bb(Vector3(0, 2.85, d * 0.5 + 0.2), Vector3(w * 0.5, 0.6, 0.08), Color(1.0, 0.85, 0.30))
		"bank":
			for i in range(4):
				var cx := -w * 0.30 + i * (w * 0.60 / 3.0)
				KitLib.place(_root, "Brick_Column_TrimBricks", Vector3(cx, 0.0, d * 0.5 + 1.5))
			_bb(Vector3(0, 3.05, d * 0.5 + 1.5), Vector3(w * 0.7, 0.6, 1.4), Color(0.72, 0.70, 0.64))
		"gang":
			for i in range(3):
				var bp := Vector3(w * 0.5 + 1.6 + i * 1.3, 0.55, d * 0.5 - 1.0)
				var bc := Color(0.72, 0.32, 0.22) if i % 2 == 0 else Color(0.30, 0.42, 0.36)
				var cyl := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.45
				cm.bottom_radius = 0.45
				cm.height = 1.1
				cyl.mesh = cm
				var mm := StandardMaterial3D.new()
				mm.albedo_color = bc
				mm.roughness = 0.6
				cyl.material_override = mm
				cyl.position = bp
				_root.add_child(cyl)


# ─────────────────────────── 配置 ───────────────────────────
func _style_for(k: String) -> String:
	match k:
		"hospital", "bank": return "trim"
		"mart", "garage", "gang": return "metal"
		"deco":
			if str(place.get("id", "")) == "deco_a":
				return "trim"
			if str(place.get("id", "")) == "deco_d":
				return "metal"
			return "brick"
		_: return "brick"


func _floors_for(k: String, p: Dictionary) -> int:
	if p.has("floors"):
		return clampi(int(p["floors"]), 2, 4)
	match k:
		"diner", "mart", "shopfront": return 2
		"hospital", "bank": return 4
		"garage", "fire", "police", "gang": return 3
		"deco":
			var id := str(p.get("id", ""))
			if id == "deco_a": return 4
			if id == "deco_b": return 4
			return 3
		_: return 2
