extends Node
class_name WorldBuilder
## 程序化城市生成：地面 / 道路 / 建筑 / 房产 / 公园 / 停车场 / 路灯

const BUILDING_SHADER := preload("res://assets/shaders/building.gdshader")

const C_ROAD := Color(0.145, 0.152, 0.165)
const C_LINE := Color(0.78, 0.72, 0.36)
const C_SIDEWALK := Color(0.40, 0.41, 0.42)
const C_GROUND := Color(0.26, 0.31, 0.24)

var root: Node3D
var host: Node
var rng := RandomNumberGenerator.new()
var building_mats: Array = []
var street_lights: Array = []
var _mat_cache: Dictionary = {}


func build(target: Node3D, main_node: Node) -> void:
	root = target
	host = main_node
	rng.seed = 20261031
	_make_ground()
	_make_roads()
	_make_blocks()
	_make_places()
	_make_properties()
	_make_park_decor()
	_make_parking_lot()
	_make_street_lights()
	_make_clouds()
	_make_boundary()


# ═══════════════ 基础工具 ═══════════════
func mat(color: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(false), rough, metal]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	_mat_cache[key] = m
	return m


func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, collide := false, rot_y := 0.0, rough := 0.85) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(color, rough)
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		sb.position = pos
		sb.rotation.y = rot_y
		parent.add_child(sb)
	return mi


func label3d(parent: Node3D, text: String, pos: Vector3, px: int, color: Color, rot_y := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Game.get_font()
	l.font_size = px
	l.pixel_size = 0.0075
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.65)
	l.position = pos
	l.rotation.y = rot_y
	l.no_depth_test = false
	l.shaded = false
	parent.add_child(l)
	return l


func building_material(color: Color, win_ratio := 0.55, win_x := 3.2, win_y := 3.6) -> ShaderMaterial:
	var key := "%s|%.2f|%.1f|%.1f" % [color.to_html(false), win_ratio, win_x, win_y]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := ShaderMaterial.new()
	m.shader = BUILDING_SHADER
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("window_color", Color(0.09, 0.14, 0.21))
	m.set_shader_parameter("glow_color", Color(1.0, 0.84, 0.55))
	m.set_shader_parameter("win_x", win_x)
	m.set_shader_parameter("win_y", win_y)
	m.set_shader_parameter("win_ratio", win_ratio)
	m.set_shader_parameter("night", 0.0)
	_mat_cache[key] = m
	building_mats.append(m)
	return m


func solid(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	sb.position = pos
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	parent.add_child(sb)
	return sb


# ═══════════════ 地面与道路 ═══════════════
func _make_ground() -> void:
	var g := box(root, Vector3(0, -0.35, 0), Vector3(620, 0.6, 620), C_GROUND, false, 0.0, 0.95)
	g.name = "Ground"
	solid(root, Vector3(0, -0.3, 0), Vector3(620, 0.6, 620))


func _make_roads() -> void:
	var half_len := Data.CITY_HALF
	for k in range(Data.GRID + 1):
		var off := -half_len + Data.ROAD * 0.5 + k * Data.CELL_PITCH
		# 纵向
		box(root, Vector3(off, -0.02, 0), Vector3(Data.ROAD, 0.04, half_len * 2.0), C_ROAD, false, 0.0, 0.7)
		box(root, Vector3(off, 0.006, 0), Vector3(0.28, 0.012, half_len * 2.0), C_LINE, false, 0.0, 0.6)
		# 横向
		box(root, Vector3(0, -0.02, off), Vector3(half_len * 2.0, 0.04, Data.ROAD), C_ROAD, false, 0.0, 0.7)
		box(root, Vector3(0, 0.006, off), Vector3(half_len * 2.0, 0.012, 0.28), C_LINE, false, 0.0, 0.6)


func _make_blocks() -> void:
	for i in range(Data.GRID):
		for j in range(Data.GRID):
			var c := Data.cell_center(Vector2i(i, j))
			var is_park := (i == 1 and j == 2)
			var col := Color(0.30, 0.42, 0.26) if is_park else C_SIDEWALK
			box(root, Vector3(c.x, -0.01, c.z), Vector3(Data.BLOCK, 0.02, Data.BLOCK), col, false, 0.0, 0.95)


# ═══════════════ 建筑 ═══════════════
func _make_places() -> void:
	for p in Data.PLACES:
		var c := Data.cell_center(p["cell"])
		var sz: Vector2 = p["size"]
		if p["kind"] == "park" or p["kind"] == "parking" or sz == Vector2.ZERO:
			continue
		_make_one_place(c, p)


func _make_one_place(c: Vector3, p: Dictionary) -> void:
	var w: float = p["size"].x
	var d: float = p["size"].y
	var h: float = p["height"]
	var col: Color = p["color"]
	var kind: String = p["kind"]

	var g := Node3D.new()
	g.name = "B_" + str(p["id"])
	g.position = c
	root.add_child(g)

	# 主体（带程序化窗户）
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, h, d)
	body.mesh = bm
	body.material_override = building_material(col)
	body.position.y = h * 0.5
	g.add_child(body)
	solid(g, Vector3(0, h * 0.5, 0), Vector3(w, h, d))

	# 檐口
	box(g, Vector3(0, h + 0.25, 0), Vector3(w + 0.8, 0.5, d + 0.8), col.darkened(0.25), false, 0.0, 0.8)
	# 屋顶设备
	box(g, Vector3(w * 0.25, h + 1.0, -d * 0.2), Vector3(2.4, 1.2, 2.4), Color(0.42, 0.44, 0.46), false)
	box(g, Vector3(-w * 0.22, h + 0.8, d * 0.15), Vector3(1.6, 0.8, 1.6), Color(0.38, 0.40, 0.42), false)

	# 正门
	var door_w := 2.6
	var door_h := 3.2
	box(g, Vector3(0, door_h * 0.5, d * 0.5 + 0.06), Vector3(door_w, door_h, 0.16), Color(0.10, 0.11, 0.13), false, 0.0, 0.4)
	box(g, Vector3(0, door_h + 0.18, d * 0.5 + 0.06), Vector3(door_w + 0.7, 0.36, 0.3), col.lightened(0.18), false)
	# 台阶
	box(g, Vector3(0, 0.09, d * 0.5 + 0.9), Vector3(door_w + 2.0, 0.18, 1.8), Color(0.55, 0.55, 0.56), false, 0.0, 0.9)

	# 招牌
	if p["sign"] != "":
		var sign_col := Color(0.95, 0.95, 0.95)
		if kind == "police": sign_col = Color(0.55, 0.75, 1.0)
		elif kind == "fire": sign_col = Color(1.0, 0.62, 0.55)
		elif kind == "hospital": sign_col = Color(1.0, 0.55, 0.55)
		elif kind == "diner": sign_col = Color(1.0, 0.80, 0.42)
		elif kind == "mart": sign_col = Color(0.55, 1.0, 0.75)
		elif kind == "gang": sign_col = Color(0.75, 0.60, 1.0)
		elif kind == "garage": sign_col = Color(1.0, 0.92, 0.45)
		box(g, Vector3(0, h - 1.2, d * 0.5 + 0.12), Vector3(w * 0.62, 1.7, 0.14), Color(0.07, 0.08, 0.10), false, 0.0, 0.35)
		label3d(g, p["sign"], Vector3(0, h - 1.2, d * 0.5 + 0.22), 96, sign_col)

	# 类型专属装饰
	match kind:
		"police":
			# 蓝色警灯条
			box(g, Vector3(0, h + 0.9, 0), Vector3(3.2, 0.35, 0.5), Color(0.25, 0.55, 1.0), false, 0.0, 0.2)
			for i in range(3):
				box(g, Vector3(-w * 0.5 - 0.4, 1.0 + i * 3.2, d * 0.5 - 1.5), Vector3(0.3, 1.6, 0.3), Color(0.75, 0.78, 0.82), false)
		"fire":
			# 卷帘车库门
			for i in range(2):
				box(g, Vector3(-w * 0.28 + i * w * 0.56, 2.4, d * 0.5 + 0.1), Vector3(6.0, 4.6, 0.2), Color(0.62, 0.20, 0.18), false, 0.0, 0.55)
			box(g, Vector3(0, h + 0.9, 0), Vector3(2.6, 0.3, 0.4), Color(1.0, 0.35, 0.25), false, 0.0, 0.2)
		"hospital":
			# 红十字
			box(g, Vector3(0, h - 4.0, d * 0.5 + 0.14), Vector3(0.6, 3.0, 0.1), Color(0.92, 0.30, 0.32), false, 0.0, 0.5)
			box(g, Vector3(0, h - 4.0, d * 0.5 + 0.14), Vector3(3.0, 0.6, 0.1), Color(0.92, 0.30, 0.32), false, 0.0, 0.5)
		"diner":
			# 遮阳篷（水平面 + 前缘竖板）
			for i in range(6):
				var ax := -w * 0.42 + i * (w * 0.84 / 5.0)
				var ac := Color(0.90, 0.32, 0.28) if i % 2 == 0 else Color(0.95, 0.93, 0.88)
				box(g, Vector3(ax, 3.42, d * 0.5 + 1.15), Vector3(w * 0.84 / 5.0, 0.10, 2.0), ac, false, 0.0, 0.6)
				box(g, Vector3(ax, 3.12, d * 0.5 + 2.12), Vector3(w * 0.84 / 5.0, 0.5, 0.09), ac, false, 0.0, 0.6)
		"mart":
			# 霓虹条
			box(g, Vector3(0, 3.9, d * 0.5 + 0.14), Vector3(w * 0.7, 0.22, 0.1), Color(0.35, 1.0, 0.62), false, 0.0, 0.2)
			for i in range(4):
				box(g, Vector3(-3.0 + i * 2.0, 1.2, d * 0.5 + 1.6), Vector3(0.5, 1.2, 0.5), Color(0.5, 0.55, 0.5), false)
		"garage":
			# 展示橱窗
			box(g, Vector3(0, 2.2, d * 0.5 + 0.12), Vector3(w * 0.8, 3.4, 0.12), Color(0.12, 0.16, 0.22), false, 0.0, 0.1)
			box(g, Vector3(-w * 0.2, 3.9, d * 0.5 + 0.2), Vector3(w * 0.5, 0.9, 0.1), Color(1.0, 0.85, 0.30), false, 0.0, 0.3)
		"bank":
			# 罗马柱
			for i in range(4):
				var cx := -w * 0.36 + i * (w * 0.72 / 3.0)
				box(g, Vector3(cx, 3.0, d * 0.5 + 1.4), Vector3(1.1, 6.0, 1.1), Color(0.82, 0.80, 0.74), false, 0.0, 0.7)
			box(g, Vector3(0, 6.4, d * 0.5 + 1.4), Vector3(w * 0.8, 0.7, 1.4), Color(0.75, 0.73, 0.68), false, 0.0, 0.7)
		"gang":
			# 铁皮与油桶
			for i in range(5):
				box(g, Vector3(-w * 0.4 + i * w * 0.2, h * 0.5, d * 0.5 + 0.08), Vector3(0.18, h, 0.1), Color(0.18, 0.16, 0.20), false)
			for i in range(3):
				var bp := Vector3(w * 0.5 + 1.6 + i * 1.3, 0.55, d * 0.5 - 1.0)
				var bc := Color(0.72, 0.32, 0.22) if i % 2 == 0 else Color(0.30, 0.42, 0.36)
				var cyl := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = 0.45
				cm.bottom_radius = 0.45
				cm.height = 1.1
				cyl.mesh = cm
				cyl.material_override = mat(bc, 0.6, 0.4)
				cyl.position = bp
				g.add_child(cyl)

	# 门口交互点
	var door_pos := c + Vector3(0, 0, d * 0.5 + 2.2)
	Game.register_place(p["id"], door_pos)
	var prompt := ""
	var cb := Callable()
	match kind:
		"police": prompt = "警局 · 查看勤务"; cb = Callable(host, "open_job_panel").bind("police")
		"fire": prompt = "消防站 · 查看勤务"; cb = Callable(host, "open_job_panel").bind("firefighter")
		"hospital": prompt = "医院 · 查看勤务"; cb = Callable(host, "open_job_panel").bind("doctor")
		"diner": prompt = "日落餐厅 · 店铺"; cb = Callable(host, "open_shop_panel").bind("diner")
		"mart": prompt = "便利店 · 店铺"; cb = Callable(host, "open_shop_panel").bind("mart")
		"shopfront": prompt = "空置商铺 · 店铺"; cb = Callable(host, "open_shop_panel").bind("shopfront")
		"garage": prompt = "车行 · 购车与改装"; cb = Callable(host, "open_vehicle_panel")
		"bank": prompt = "银行 · 存取款"; cb = Callable(host, "open_bank_panel")
		"gang": prompt = "仓库 · 帮派事务"; cb = Callable(host, "open_gang_panel")
	if cb.is_valid():
		Interactable.create(g, Vector3(0, 1.4, d * 0.5 + 2.2), Vector3(3.4, 2.8, 1.6), prompt, cb)
		# 地面引导标记
		box(g, Vector3(0, 0.012, d * 0.5 + 2.2), Vector3(2.4, 0.02, 2.4), Color(0.20, 0.42, 0.68), false, 0.0, 0.7)


# ═══════════════ 房产（可进入的空壳） ═══════════════
func _make_properties() -> void:
	for p in Data.PROPERTIES:
		var c: Vector3 = Data.cell_center(p["cell"]) + p["offset"]
		_make_house(c, p)


func _make_house(c: Vector3, p: Dictionary) -> void:
	var w: float = p["size"].x
	var d: float = p["size"].y
	var h := 5.2
	var col: Color = p["color"]

	var g := Node3D.new()
	g.name = "H_" + str(p["id"])
	g.position = c
	root.add_child(g)

	# 地板
	box(g, Vector3(0, -0.01, 0), Vector3(w, 0.02, d), Color(0.32, 0.28, 0.24), false, 0.0, 0.95)
	# 四壁（正面留门洞）
	var t := 0.35
	var door_w := 2.6
	box(g, Vector3(0, h * 0.5, -d * 0.5 + t * 0.5), Vector3(w, h, t), col, true, 0.0, 0.85)
	box(g, Vector3(-w * 0.5 + t * 0.5, h * 0.5, 0), Vector3(t, h, d), col, true, 0.0, 0.85)
	box(g, Vector3(w * 0.5 - t * 0.5, h * 0.5, 0), Vector3(t, h, d), col, true, 0.0, 0.85)
	var seg := (w - door_w) * 0.5
	box(g, Vector3(-(door_w * 0.5 + seg * 0.5), h * 0.5, d * 0.5 - t * 0.5), Vector3(seg, h, t), col, true, 0.0, 0.85)
	box(g, Vector3(door_w * 0.5 + seg * 0.5, h * 0.5, d * 0.5 - t * 0.5), Vector3(seg, h, t), col, true, 0.0, 0.85)
	# 门楣
	box(g, Vector3(0, h - (h - 2.8) * 0.5, d * 0.5 - t * 0.5), Vector3(door_w, h - 2.8, t), col, true, 0.0, 0.85)
	# 屋顶
	box(g, Vector3(0, h + 0.15, 0), Vector3(w + 1.0, 0.3, d + 1.0), col.darkened(0.35), false, 0.0, 0.9)
	box(g, Vector3(0, h + 0.5, 0), Vector3(w * 0.7, 0.4, d * 0.7), col.darkened(0.45), false, 0.0, 0.9)
	# 门框
	box(g, Vector3(0, 1.4, d * 0.5), Vector3(door_w + 0.3, 2.8, 0.18), Color(0.20, 0.16, 0.13), false, 0.0, 0.7)
	# 窗（外立面装饰）
	box(g, Vector3(-w * 0.28, 3.0, d * 0.5 + 0.02), Vector3(2.2, 1.6, 0.1), Color(0.10, 0.16, 0.24), false, 0.0, 0.15)
	box(g, Vector3(w * 0.28, 3.0, d * 0.5 + 0.02), Vector3(2.2, 1.6, 0.1), Color(0.10, 0.16, 0.24), false, 0.0, 0.15)
	# 门牌
	label3d(g, p["name"], Vector3(0, 2.45, d * 0.5 + 0.12), 56, Color(0.95, 0.92, 0.85))

	# 室内灯
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, h - 0.5, 0)
	lamp.light_color = Color(1.0, 0.90, 0.76)
	lamp.light_energy = 4.6
	lamp.omni_range = 26.0
	lamp.omni_attenuation = 0.7
	lamp.shadow_enabled = false
	g.add_child(lamp)
	var lamp2 := OmniLight3D.new()
	lamp2.position = Vector3(0, 2.0, 0)
	lamp2.light_color = Color(1.0, 0.88, 0.72)
	lamp2.light_energy = 2.2
	lamp2.omni_range = 14.0
	lamp2.omni_attenuation = 0.8
	lamp2.shadow_enabled = false
	g.add_child(lamp2)

	# 交互点（门口）
	var door_pos := c + Vector3(0, 0, d * 0.5 + 1.8)
	Game.register_place(p["id"], door_pos)
	Interactable.create(g, Vector3(0, 1.3, d * 0.5 + 1.8), Vector3(3.0, 2.6, 1.4), "房产 · %s" % p["name"],
		Callable(host, "on_property_door").bind(p["id"]))
	box(g, Vector3(0, 0.012, d * 0.5 + 1.8), Vector3(2.2, 0.02, 2.2), Color(0.62, 0.50, 0.22), false, 0.0, 0.7)


# ═══════════════ 公园与停车场 ═══════════════
func _make_park_decor() -> void:
	var c := Data.cell_center(Vector2i(1, 2))
	# 小池塘
	var pond := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 6.0
	cm.bottom_radius = 6.0
	cm.height = 0.12
	pond.mesh = cm
	pond.material_override = mat(Color(0.16, 0.36, 0.46), 0.08, 0.2)
	pond.position = c + Vector3(-8, 0.06, 2)
	root.add_child(pond)

	for i in range(9):
		var ang := TAU * float(i) / 9.0
		var r := 13.0 + rng.randf_range(-2.0, 2.0)
		var p := c + Vector3(cos(ang) * r, 0, sin(ang) * r)
		_make_tree(p, rng.randf_range(0.85, 1.25))

	# 长椅
	for i in range(4):
		var ang := TAU * float(i) / 4.0 + 0.4
		var p := c + Vector3(cos(ang) * 9.0, 0, sin(ang) * 9.0)
		_make_bench(p, -ang)
	# 公园交互点
	Interactable.create(root, c + Vector3(0, 1.2, -13), Vector3(5, 2.4, 3), "公园长椅 · 休息",
		Callable(host, "rest_at_park"))


func _make_tree(pos: Vector3, s: float) -> void:
	var g := Node3D.new()
	g.position = pos
	g.scale = Vector3(s, s, s)
	root.add_child(g)
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.22
	tm.bottom_radius = 0.32
	tm.height = 3.0
	trunk.mesh = tm
	trunk.material_override = mat(Color(0.30, 0.22, 0.16), 0.95)
	trunk.position.y = 1.5
	g.add_child(trunk)
	for i in range(3):
		var leaf := MeshInstance3D.new()
		var lm := CylinderMesh.new()
		lm.top_radius = 0.0
		lm.bottom_radius = 1.9 - i * 0.42
		lm.height = 2.0
		leaf.mesh = lm
		leaf.material_override = mat(Color(0.20, 0.40 + i * 0.04, 0.22), 0.95)
		leaf.position.y = 3.2 + i * 1.05
		g.add_child(leaf)
	solid(g, Vector3(0, 1.5, 0), Vector3(0.6, 3.0, 0.6))


func _make_bench(pos: Vector3, rot_y: float) -> void:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	root.add_child(g)
	var wood := Color(0.45, 0.32, 0.20)
	box(g, Vector3(0, 0.45, 0), Vector3(1.9, 0.12, 0.6), wood, false)
	box(g, Vector3(0, 0.85, -0.26), Vector3(1.9, 0.5, 0.1), wood, false)
	box(g, Vector3(-0.8, 0.22, 0), Vector3(0.12, 0.45, 0.55), Color(0.22, 0.22, 0.24), false)
	box(g, Vector3(0.8, 0.22, 0), Vector3(0.12, 0.45, 0.55), Color(0.22, 0.22, 0.24), false)


func _make_parking_lot() -> void:
	var c := Data.cell_center(Vector2i(2, 3))
	box(root, Vector3(c.x, -0.005, c.z), Vector3(Data.BLOCK, 0.01, Data.BLOCK), Color(0.19, 0.20, 0.21), false, 0.0, 0.9)
	# 车位线
	for i in range(6):
		for j in range(3):
			var px := c.x - 16.0 + i * 6.0
			var pz := c.z - 10.0 + j * 10.0
			box(root, Vector3(px, 0.008, pz), Vector3(0.14, 0.01, 5.0), Color(0.70, 0.70, 0.68), false)
	# 几辆静态装饰车
	var car_cols := [Color(0.20, 0.24, 0.30), Color(0.32, 0.18, 0.18), Color(0.18, 0.26, 0.22), Color(0.28, 0.28, 0.30)]
	for i in range(4):
		var px := c.x - 14.0 + i * 8.5
		var pz := c.z + 6.0
		var col: Color = car_cols[i % car_cols.size()]
		var car := Node3D.new()
		car.position = Vector3(px, 0, pz)
		root.add_child(car)
		box(car, Vector3(0, 0.52, 0), Vector3(1.85, 0.62, 4.2), col, true, 0.0, 0.3)
		box(car, Vector3(0, 1.06, -0.15), Vector3(1.66, 0.5, 2.0), Color(0.07, 0.10, 0.14), false, 0.0, 0.12)
		box(car, Vector3(0, 1.33, -0.15), Vector3(1.6, 0.08, 1.9), col.darkened(0.2), false, 0.0, 0.35)
		for k in range(4):
			var wx := -0.92 if k % 2 == 0 else 0.92
			var wz := -1.35 if k < 2 else 1.35
			var tire := MeshInstance3D.new()
			var tcm := CylinderMesh.new()
			tcm.top_radius = 0.33
			tcm.bottom_radius = 0.33
			tcm.height = 0.24
			tcm.radial_segments = 12
			tire.mesh = tcm
			tire.material_override = mat(Color(0.07, 0.07, 0.08), 0.9)
			tire.rotation.z = PI * 0.5
			tire.position = Vector3(wx, 0.33, wz)
			car.add_child(tire)


func _make_street_lights() -> void:
	var half := Data.CITY_HALF
	for k in range(Data.GRID + 1):
		var off := -half + Data.ROAD * 0.5 + k * Data.CELL_PITCH
		for m in range(Data.GRID):
			var t := -half + Data.ROAD + Data.BLOCK * 0.5 + m * Data.CELL_PITCH
			_make_lamp(Vector3(off + 5.5, 0, t - 13.0), true)
			_make_lamp(Vector3(t - 13.0, 0, off - 5.5), true)


func _make_lamp(pos: Vector3, with_light: bool) -> void:
	var g := Node3D.new()
	g.position = pos
	root.add_child(g)
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.09
	pm.bottom_radius = 0.13
	pm.height = 6.0
	pole.mesh = pm
	pole.material_override = mat(Color(0.26, 0.27, 0.29), 0.6, 0.5)
	pole.position.y = 3.0
	g.add_child(pole)
	box(g, Vector3(0, 6.0, 0.5), Vector3(0.16, 0.16, 1.2), Color(0.26, 0.27, 0.29), false)
	var head := box(g, Vector3(0, 5.92, 1.05), Vector3(0.5, 0.16, 0.8), Color(1.0, 0.92, 0.70), false, 0.0, 0.3)
	head.name = "LampHead"
	if with_light:
		var l := OmniLight3D.new()
		l.position = Vector3(0, 5.7, 1.05)
		l.light_color = Color(1.0, 0.86, 0.60)
		l.light_energy = 6.0
		l.omni_range = 24.0
		l.omni_attenuation = 0.6
		l.shadow_enabled = false
		l.set_meta("street", true)
		g.add_child(l)
		street_lights.append(l)


func _make_clouds() -> void:
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 4242
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.98, 0.99, 1.0, 0.82)
	cm.roughness = 1.0
	cm.metallic = 0.0
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in range(18):
		var g := Node3D.new()
		var a := rng2.randf() * TAU
		var r := rng2.randf_range(120.0, 430.0)
		g.position = Vector3(cos(a) * r, rng2.randf_range(120.0, 185.0), sin(a) * r)
		root.add_child(g)
		var n := rng2.randi_range(5, 8)
		for k in range(n):
			var s := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = rng2.randf_range(12.0, 26.0)
			sm.height = sm.radius * 2.0
			sm.radial_segments = 10
			sm.rings = 6
			s.mesh = sm
			s.material_override = cm
			s.position = Vector3(rng2.randf_range(-26, 26), rng2.randf_range(-3, 3), rng2.randf_range(-18, 18))
			s.scale = Vector3(1.0, 0.30, 1.0)
			g.add_child(s)


func _make_boundary() -> void:
	var e := Data.CITY_HALF + 6.0
	solid(root, Vector3(e, 5, 0), Vector3(2, 10, e * 2.0))
	solid(root, Vector3(-e, 5, 0), Vector3(2, 10, e * 2.0))
	solid(root, Vector3(0, 5, e), Vector3(e * 2.0, 10, 2))
	solid(root, Vector3(0, 5, -e), Vector3(e * 2.0, 10, 2))


# ═══════════════ 夜间 ═══════════════
func set_night(amount: float) -> void:
	for m in building_mats:
		if is_instance_valid(m):
			m.set_shader_parameter("night", amount)
	for l in street_lights:
		if is_instance_valid(l):
			l.light_energy = 6.0 * amount
