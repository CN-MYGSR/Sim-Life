extends Control
class_name MapView
## 平板地图：自绘俯视图，含街区/道路/地点/房产/任务/玩家

var _t: float = 0.0
var _pulse: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(560, 560)
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if _t > 0.08:
		_t = 0.0
		_pulse = fmod(_pulse + 0.08, 2.0)
		queue_redraw()


func w2s(p: Vector3) -> Vector2:
	var pad := 26.0
	var s := minf(size.x, size.y) - pad * 2.0
	var sc := s / (Data.CITY_HALF * 2.0)
	return Vector2(size.x * 0.5 + p.x * sc, size.y * 0.5 + p.z * sc)


func _scale() -> float:
	var pad := 26.0
	var s := minf(size.x, size.y) - pad * 2.0
	return s / (Data.CITY_HALF * 2.0)


func _get_tooltip(at_position: Vector2) -> String:
	for property in Data.PROPERTIES:
		var center: Vector3 = Data.cell_center(property["cell"]) + property["offset"]
		if w2s(center).distance_to(at_position) < 9:
			return str(property["name"]) + (" · 已购" if Game.owns_property(property["id"]) else " · $%d" % int(property["price"]))
	for place in Data.PLACES:
		var center := w2s(Data.cell_center(place["cell"]))
		var size: Vector2 = place["size"] * _scale()
		if Rect2(center - size * 0.5, size).has_point(at_position):
			return str(place["name"])
	return ""


func _draw() -> void:
	var font := Game.get_font()
	var sc := _scale()

	# 背景
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.045, 0.055, 0.07), true)
	# 外框
	draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color(0.16, 0.19, 0.23), false, 2.0)

	# 街区
	for i in range(Data.GRID):
		for j in range(Data.GRID):
			var c := Data.cell_center(Vector2i(i, j))
			var tl := w2s(c + Vector3(-Data.BLOCK * 0.5, 0, -Data.BLOCK * 0.5))
			var br := w2s(c + Vector3(Data.BLOCK * 0.5, 0, Data.BLOCK * 0.5))
			var is_park := Data.is_park_cell(Vector2i(i, j))
			var col := Color(0.12, 0.20, 0.13) if is_park else Color(0.13, 0.145, 0.16)
			draw_rect(Rect2(tl, br - tl), col, true)

	# 道路
	var road_w := Data.ROAD * sc
	for k in range(Data.GRID + 1):
		var off := -Data.CITY_HALF + Data.ROAD * 0.5 + k * Data.CELL_PITCH
		var a := w2s(Vector3(off, 0, -Data.CITY_HALF))
		var b := w2s(Vector3(off, 0, Data.CITY_HALF))
		draw_line(a, b, Color(0.085, 0.09, 0.10), road_w)
		var a2 := w2s(Vector3(-Data.CITY_HALF, 0, off))
		var b2 := w2s(Vector3(Data.CITY_HALF, 0, off))
		draw_line(a2, b2, Color(0.085, 0.09, 0.10), road_w)

	# 地点
	for p in Data.PLACES:
		if p["kind"] == "park":
			continue
		var c := Data.cell_center(p["cell"])
		var sz: Vector2 = p["size"]
		if sz == Vector2.ZERO:
			continue
		var tl := w2s(c + Vector3(-sz.x * 0.5, 0, -sz.y * 0.5))
		var br := w2s(c + Vector3(sz.x * 0.5, 0, sz.y * 0.5))
		var col: Color = p["color"]
		draw_rect(Rect2(tl, br - tl), Color(col.r, col.g, col.b, 0.85), true)
		draw_rect(Rect2(tl, br - tl), col.lightened(0.4), false, 1.0)
		if sz.x * sc > 26:
			var tp := tl + Vector2(5, 13)
			var txt: String = p["name"]
			draw_string(font, tp + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, br.x - tl.x - 8, 12, Color(0, 0, 0, 0.85))
			draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, br.x - tl.x - 8, 12, Color(1, 1, 1, 0.95))

	# 房产
	for p in Data.PROPERTIES:
		var c: Vector3 = Data.cell_center(p["cell"]) + p["offset"]
		var sp := w2s(c)
		var owned: bool = Game.owns_property(p["id"])
		var col := Color(0.35, 0.85, 0.55) if owned else Color(0.98, 0.78, 0.30)
		var r := 5.0
		draw_rect(Rect2(sp - Vector2(r, r), Vector2(r, r) * 2.0), col, true)
		draw_rect(Rect2(sp - Vector2(r, r), Vector2(r, r) * 2.0), Color(0, 0, 0, 0.5), false, 1.0)

	# 已购车辆
	if is_instance_valid(Game.world) and Game.world.get("vehicles_root"):
		var vr = Game.world.get("vehicles_root")
		if is_instance_valid(vr):
			for c in vr.get_children():
				if c is Node3D:
					var vp := w2s((c as Node3D).global_position)
					draw_rect(Rect2(vp - Vector2(4, 4), Vector2(8, 8)), Color(0.45, 0.85, 1.0), true)
					draw_rect(Rect2(vp - Vector2(4, 4), Vector2(8, 8)), Color(0, 0, 0, 0.6), false, 1.0)

	# 任务目标
	for m in Game.missions:
		var tps: Array = [m["target"]]
		if m.has("targets"):
			tps = []
			for point_index in range(m["targets"].size()):
				if point_index not in m["meta"].get("visited", []):
					tps.append(m["targets"][point_index])
		var col := Color(0.95, 0.35, 0.40) if m["type"] in ["arrest", "rob", "fire"] else Data.C_TEAL
		var k := fmod(_pulse, 1.0)
		for tp in tps:
			var sp := w2s(tp)
			draw_arc(sp, 6.0 + k * 14.0, 0, TAU, 24, Color(col.r, col.g, col.b, 1.0 - k), 2.0)
			draw_circle(sp, 5.0, col)
			draw_string(font, sp + Vector2(9, -7), str(m["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)

	# 玩家
	if is_instance_valid(Game.player):
		var pp: Vector3 = Game.player.global_position
		var sp := w2s(pp)
		var ang: float = Game.player.rotation.y
		var fwd := Vector2(-sin(ang), -cos(ang))
		var right := Vector2(-fwd.y, fwd.x)
		var tip := sp + fwd * 9.0
		var l := sp - fwd * 5.0 + right * 5.0
		var r := sp - fwd * 5.0 - right * 5.0
		draw_colored_polygon(PackedVector2Array([tip, l, r]), Color(1, 1, 1))
		draw_circle(sp, 11.0, Color(0.4, 0.75, 1.0, 0.20))

	# 图例
	var ly := size.y - 22.0
	draw_circle(Vector2(18, ly), 4.0, Color(1, 1, 1))
	draw_string(font, Vector2(27, ly + 4), "你", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Data.C_DIM)
	draw_rect(Rect2(Vector2(56, ly - 4), Vector2(8, 8)), Color(0.98, 0.78, 0.30), true)
	draw_string(font, Vector2(70, ly + 4), "待售房产", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Data.C_DIM)
	draw_rect(Rect2(Vector2(140, ly - 4), Vector2(8, 8)), Color(0.35, 0.85, 0.55), true)
	draw_string(font, Vector2(154, ly + 4), "已购", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Data.C_DIM)
	draw_circle(Vector2(196, ly), 4.0, Data.C_TEAL)
	draw_string(font, Vector2(206, ly + 4), "任务点", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Data.C_DIM)
