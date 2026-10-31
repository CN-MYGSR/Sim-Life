extends RefCounted
class_name InteriorFurnish
## 程序化室内家具：只用盒子网格（MeshInstance3D + BoxMesh + StandardMaterial3D），
## 为 KitBuilding 的多层可进入建筑布置家具。
##
## 用法（每层调用一次）：
##     InteriorFurnish.furnish(building_root, "police", 0.0, Rect2(x, z, w, d), rng)
##
## 约定：
## - 家具挂在 parent（建筑根节点）下，使用 parent 局部坐标。
## - floor_y 是该层可行走地面 Y；area = Rect2(x, z, w, d) 是该层可用室内矩形。
## - 每件家具是一个 Node3D 容器（计入「节点数」），内部由若干 MeshInstance3D 盒子组成；
##   会挡路的家具在容器内加一个 StaticBody3D + BoxShape3D（碰撞层 1）。
## - 每层 8~18 件家具；每件高度 ≤ 2.2m；中间靠前留出 1.8m 宽的通道（lane）。
## - 布局由传入的 rng 决定：同一种子 → 同一结果。不加载任何外部资源、不加灯光和脚本。
##
## kind 支持：
##   底层：police / fire / hospital / diner / mart / garage / bank / gang / shopfront
##   上层：deco_office / deco_apartment / deco_warehouse
##   另外，若传入底层 kind 但 floor_y >= 1.0（上层），会自动换成合理的上层布局：
##   police/fire/bank → 办公层，hospital → 病房层，diner/mart/garage/gang/shopfront → 仓储层。


class Ctx:
	# ── 调色板（低饱和低多边形，与 KitLib / 世界整体配色一致）──────────────
	const C_WOOD_DARK := Color(0.36, 0.28, 0.22)
	const C_WOOD := Color(0.47, 0.35, 0.26)
	const C_WOOD_LIGHT := Color(0.58, 0.46, 0.34)
	const C_METAL := Color(0.42, 0.44, 0.47)
	const C_METAL_DARK := Color(0.24, 0.26, 0.29)
	const C_STEEL := Color(0.55, 0.57, 0.60)
	const C_NAVY := Color(0.22, 0.30, 0.42)
	const C_RED := Color(0.55, 0.22, 0.20)
	const C_GREEN := Color(0.22, 0.34, 0.25)
	const C_PLASTIC := Color(0.85, 0.85, 0.82)
	const C_CREAM := Color(0.76, 0.73, 0.65)
	const C_CONCRETE := Color(0.50, 0.50, 0.48)
	const C_FABRIC := Color(0.45, 0.44, 0.42)
	const C_CLOTH := Color(0.62, 0.68, 0.66)
	const C_CARDBOARD := Color(0.55, 0.44, 0.30)
	const C_RUST := Color(0.48, 0.30, 0.21)
	const C_BLUE := Color(0.25, 0.42, 0.62)
	const C_YELLOW := Color(0.72, 0.64, 0.30)
	const C_SCREEN := Color(0.09, 0.11, 0.13)
	const C_WHITE := Color(0.82, 0.83, 0.84)
	const C_BLACK := Color(0.12, 0.12, 0.13)
	const C_GLASS := Color(0.35, 0.45, 0.50)
	const C_MARBLE := Color(0.70, 0.69, 0.64)

	const MIN_PIECES := 8
	const MAX_PIECES := 18
	const MAX_HEIGHT := 2.2

	var parent: Node3D
	var rng: RandomNumberGenerator
	var area := Rect2()
	var floor_y := 0.0
	var count := 0
	var occ: Array[Rect2] = []

	var x0 := 0.0
	var z0 := 0.0
	var x1 := 0.0
	var z1 := 0.0
	var cx := 0.0
	var lane := Rect2()

	# ═══════════════════════════ 初始化 / 入口 ═══════════════════════════
	func setup(p: Node3D, fy: float, a: Rect2, r: RandomNumberGenerator) -> void:
		parent = p
		floor_y = fy
		area = a
		rng = r
		x0 = a.position.x
		z0 = a.position.y
		x1 = a.end.x
		z1 = a.end.y
		cx = x0 + a.size.x * 0.5
		# 中间靠前的通道：不摆家具，保证玩家从门口走进去有路
		lane = Rect2(cx - 0.9, z0 + a.size.y * 0.35, 1.8, a.size.y * 0.65)

	func build(kind: String) -> void:
		match kind:
			"police":
				if floor_y < 1.0: _police()
				else: _office()
			"fire":
				if floor_y < 1.0: _fire()
				else: _office()
			"hospital":
				if floor_y < 1.0: _hospital()
				else: _apartment(true)
			"bank":
				if floor_y < 1.0: _bank()
				else: _office()
			"diner":
				if floor_y < 1.0: _diner()
				else: _warehouse()
			"mart":
				if floor_y < 1.0: _mart()
				else: _warehouse()
			"garage":
				if floor_y < 1.0: _garage()
				else: _warehouse()
			"gang":
				if floor_y < 1.0: _gang()
				else: _warehouse()
			"shopfront":
				if floor_y < 1.0: _shopfront()
				else: _warehouse()
			"deco_office":
				_office()
			"deco_apartment":
				_apartment(false)
			"deco_warehouse":
				_warehouse()
			_:
				_office()

	# ═══════════════════════════ 基础几何 ═══════════════════════════
	func _box(p: Node3D, x: float, y: float, z: float, sx: float, sy: float, sz: float,
			col: Color, rough := 0.85) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(sx, sy, sz)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = rough
		mi.material_override = m
		mi.position = Vector3(x, y, z)
		p.add_child(mi)
		return mi

	func _solid(p: Node3D, x: float, y: float, z: float, sx: float, sy: float, sz: float) -> void:
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		sb.collision_mask = 0
		sb.position = Vector3(x, y, z)
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(sx, sy, sz)
		cs.shape = sh
		sb.add_child(cs)
		p.add_child(sb)

	# 家具件：原点在 footprint 中心、地面高度；rot 绕 Y 旋转，本地坐标沿 +z 为正面。
	func _mk(x: float, z: float, fx: float, fz: float, tag: String, rot := 0.0) -> Node3D:
		if count >= MAX_PIECES:
			return null
		var r := _footprint(x, z, fx, fz, rot)
		if not _fits(r):
			return null
		occ.append(r)
		count += 1
		var p := Node3D.new()
		p.name = "%s_%02d" % [tag, count]
		p.position = Vector3(x, floor_y, z)
		p.rotation.y = rot
		parent.add_child(p)
		return p

	# 挂墙件（公告板 / 白板等）：只检查在区域内，不占地面位置、不加碰撞
	func _mk_wall(x: float, z: float, fx: float, fz: float, tag: String, rot := 0.0) -> Node3D:
		if count >= MAX_PIECES:
			return null
		var r := _footprint(x, z, fx, fz, rot)
		if not _in_area(r) or r.intersects(lane):
			return null
		count += 1
		var p := Node3D.new()
		p.name = "%s_%02d" % [tag, count]
		p.position = Vector3(x, floor_y, z)
		p.rotation.y = rot
		parent.add_child(p)
		return p

	# 旋转后的世界轴对齐 footprint（任意角度都按外接盒算，避免穿出区域/通道）
	func _footprint(x: float, z: float, fx: float, fz: float, rot: float) -> Rect2:
		var cs := absf(cos(rot))
		var sn := absf(sin(rot))
		var wx := fx * cs + fz * sn
		var wz := fx * sn + fz * cs
		return Rect2(x - wx * 0.5, z - wz * 0.5, wx, wz)

	# 地面装饰（地毯 / 展台）：可以踩，不占位、不加碰撞
	func _mk_pad(x: float, z: float, fx: float, fz: float, tag: String, col: Color) -> Node3D:
		if count >= MAX_PIECES:
			return null
		var r := Rect2(x - fx * 0.5, z - fz * 0.5, fx, fz)
		if not _in_area(r):
			return null
		count += 1
		var p := Node3D.new()
		p.name = "%s_%02d" % [tag, count]
		p.position = Vector3(x, floor_y, z)
		parent.add_child(p)
		_box(p, 0, 0.03, 0, fx, 0.06, fz, col, 0.95)
		return p

	func _in_area(r: Rect2) -> bool:
		var e := 0.02
		return r.position.x >= x0 - e and r.position.y >= z0 - e \
			and r.end.x <= x1 + e and r.end.y <= z1 + e

	func _fits(r: Rect2) -> bool:
		if not _in_area(r):
			return false
		if r.intersects(lane):
			return false
		for o in occ:
			if r.intersects(o.grow(0.05)):
				return false
		return true

	# 贴墙锚点：返回「背靠该墙」的家具中心坐标
	func _bz(fz: float) -> float:  # 靠后墙（-z），fz = 本地进深
		return z0 + fz * 0.5 + 0.03

	func _fz(fz: float) -> float:  # 靠前墙（+z）
		return z1 - fz * 0.5 - 0.03

	func _lx(fz: float) -> float:  # 靠左墙（-x）
		return x0 + fz * 0.5 + 0.03

	func _rx(fz: float) -> float:  # 靠右墙（+x）
		return x1 - fz * 0.5 - 0.03

	func _rnd_col(cols: Array) -> Color:
		return cols[rng.randi_range(0, cols.size() - 1)]

	# ═══════════════════════════ 通用家具组件 ═══════════════════════════
	# 椅子：本地正面 +z（facing 为椅子朝向）
	func _chair(p: Node3D, x: float, z: float, facing: String, col: Color) -> void:
		_box(p, x, 0.45, z, 0.46, 0.07, 0.46, col, 0.9)
		_box(p, x, 0.22, z, 0.09, 0.44, 0.09, C_METAL_DARK)
		_box(p, x, 0.03, z, 0.38, 0.05, 0.38, C_METAL_DARK)
		match facing:
			"+z": _box(p, x, 0.72, z - 0.2, 0.46, 0.5, 0.07, col, 0.9)
			"-z": _box(p, x, 0.72, z + 0.2, 0.46, 0.5, 0.07, col, 0.9)
			"+x": _box(p, x - 0.2, 0.72, z, 0.07, 0.5, 0.46, col, 0.9)
			"-x": _box(p, x + 0.2, 0.72, z, 0.07, 0.5, 0.46, col, 0.9)
		_solid(p, x, 0.48, z, 0.5, 0.96, 0.5)

	func _monitor(p: Node3D, x: float, z: float) -> void:
		_box(p, x, 0.80, z, 0.2, 0.03, 0.15, C_METAL_DARK)
		_box(p, x, 0.9, z, 0.06, 0.18, 0.06, C_METAL_DARK)
		_box(p, x, 1.13, z, 0.55, 0.36, 0.05, C_SCREEN, 0.25)

	func _register(p: Node3D, x: float, y: float, z: float) -> void:
		_box(p, x, y + 0.11, z, 0.36, 0.22, 0.32, C_METAL_DARK)
		_box(p, x, y + 0.26, z, 0.22, 0.1, 0.2, C_SCREEN, 0.3)

	# 柜台：本地 x 为长边，+z 为面向顾客的一侧，-z 为员工侧
	func _counter(p: Node3D, fx: float, fz: float, h: float, body: Color, top: Color,
			accent: Color, zoff := 0.0) -> void:
		_box(p, 0, (h - 0.06) * 0.5, zoff, fx - 0.06, h - 0.06, fz - 0.1, body)
		_box(p, 0, h - 0.035, zoff, fx, 0.07, fz, top, 0.55)
		_box(p, 0, (h - 0.22) * 0.5, zoff + fz * 0.5 - 0.02, fx - 0.1, h - 0.22, 0.05, accent, 0.7)
		_solid(p, 0, h * 0.5, zoff, fx, h, fz)

	# 办公桌套装：桌子朝 +z，人坐在 -z 侧
	func _desk_set(x: float, z: float, facing: String, col: Color) -> Node3D:
		var rot := 0.0
		match facing:
			"-z": rot = PI
			"+x": rot = PI * 0.5
			"-x": rot = -PI * 0.5
		var p := _mk(x, z, 1.9, 1.8, "Desk", rot)
		if p == null:
			return null
		_box(p, 0, 0.76, 0.28, 1.6, 0.06, 0.75, C_WOOD_LIGHT)
		_box(p, -0.76, 0.38, 0.28, 0.06, 0.72, 0.7, C_WOOD_DARK)
		_box(p, 0.76, 0.38, 0.28, 0.06, 0.72, 0.7, C_WOOD_DARK)
		_box(p, 0, 0.36, -0.08, 1.46, 0.58, 0.05, col, 0.85)
		_monitor(p, 0.0, 0.32)
		_box(p, 0.66, 0.82, 0.0, 0.32, 0.06, 0.32, C_METAL)  # 抽屉小柜
		_box(p, -0.6, 0.9, 0.34, 0.24, 0.2, 0.02, C_PLASTIC)  # 桌面纸张/文件
		_chair(p, 0, -0.55, "+z", C_NAVY)
		_solid(p, 0, 0.5, 0.1, 1.7, 1.0, 1.6)
		return p

	# 文件柜 / 档案柜
	func _filing(x: float, z: float, col: Color, rot := 0.0) -> Node3D:
		var p := _mk(x, z, 0.62, 0.95, "Cabinet", rot)
		if p == null:
			return null
		_box(p, 0, 0.75, 0, 0.58, 1.5, 0.9, col, 0.7)
		for i in range(3):
			_box(p, 0, 0.28 + i * 0.42, 0.46, 0.5, 0.34, 0.04, col.darkened(0.2))
			_box(p, 0, 0.28 + i * 0.42, 0.49, 0.16, 0.04, 0.03, C_METAL_DARK)
		_solid(p, 0, 0.75, 0, 0.58, 1.5, 0.9)
		return p

	# 货架（filled=false 为空的 / 落灰的，filled=true 带少量货物）
	func _shelf(x: float, z: float, width: float, depth: float, height: float, rot: float,
			col: Color, filled := true) -> Node3D:
		var p := _mk(x, z, width, depth, "Shelf", rot)
		if p == null:
			return null
		_box(p, 0, height * 0.5, 0, width, height, 0.04, col.darkened(0.16))
		_box(p, -width * 0.5 + 0.03, height * 0.5, 0, 0.06, height, depth, col)
		_box(p, width * 0.5 - 0.03, height * 0.5, 0, 0.06, height, depth, col)
		var boards := 3
		for i in range(boards):
			var y := 0.28 + i * (height - 0.5) / float(boards - 1)
			_box(p, 0, y, 0, width - 0.08, 0.05, depth - 0.06, col.lightened(0.08))
			if filled:
				var n := rng.randi_range(2, 3)
				for k in range(n):
					var gx := -width * 0.5 + 0.35
					if n > 1:
						gx += k * (width - 0.7) / float(n - 1)
					var gc := _rnd_col([C_CARDBOARD, C_RED, C_BLUE, C_GREEN, C_YELLOW])
					_box(p, gx, y + 0.14, 0.02, 0.22, 0.22, 0.22, gc, 0.9)
		_solid(p, 0, height * 0.5, 0, width, height, depth)
		return p

	# 储物柜
	func _locker(x: float, z: float, rot: float, col: Color, h := 1.85) -> Node3D:
		var p := _mk(x, z, 0.95, 0.55, "Locker", rot)
		if p == null:
			return null
		_box(p, 0, h * 0.5, 0, 0.95, h, 0.52, col, 0.7)
		_box(p, 0, h * 0.5, 0.265, 0.03, h - 0.08, 0.02, C_BLACK)
		_box(p, 0, h - 0.06, 0.27, 0.78, 0.04, 0.02, C_METAL_DARK)
		_box(p, 0.25, h * 0.5, 0.27, 0.05, 0.16, 0.03, C_METAL)
		_box(p, -0.25, h * 0.5, 0.27, 0.05, 0.16, 0.03, C_METAL)
		for i in range(3):
			_box(p, 0, h - 0.22 - i * 0.09, 0.275, 0.62, 0.03, 0.01, C_BLACK)
		_solid(p, 0, h * 0.5, 0, 0.95, h, 0.55)
		return p

	# 长凳：本地 x 为长边，-z 为靠背侧（人朝 +z 坐）
	func _bench(x: float, z: float, length: float, rot: float, col: Color) -> Node3D:
		var p := _mk(x, z, length, 0.55, "Bench", rot)
		if p == null:
			return null
		_box(p, 0, 0.42, 0, length, 0.08, 0.5, col, 0.95)
		_box(p, 0, 0.7, -0.22, length, 0.5, 0.08, col.darkened(0.08), 0.95)
		_box(p, -length * 0.5 + 0.1, 0.2, 0, 0.07, 0.4, 0.46, C_METAL_DARK)
		_box(p, length * 0.5 - 0.1, 0.2, 0, 0.07, 0.4, 0.46, C_METAL_DARK)
		_box(p, 0, 0.03, 0, length - 0.1, 0.06, 0.4, C_METAL_DARK)
		_solid(p, 0, 0.45, 0, length, 0.9, 0.55)
		return p

	# 床：本地 x 为宽度，-z 为床头；hospital=true 时加床尾护栏配色
	func _bed(x: float, z: float, rot: float, width: float, frame: Color, hospital := false) -> Node3D:
		var p := _mk(x, z, width, 2.05, "Bed", rot)
		if p == null:
			return null
		_box(p, 0, 0.3, 0, width - 0.04, 0.2, 1.95, frame, 0.7)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_box(p, sx * (width * 0.5 - 0.08), 0.15, sz * 0.9, 0.07, 0.3, 0.07, C_METAL_DARK)
		_box(p, 0, 0.48, 0.02, width - 0.1, 0.18, 1.9, C_WHITE, 0.9)
		var blanket := C_GREEN if hospital else C_NAVY
		_box(p, 0, 0.58, 0.28, width - 0.12, 0.09, 1.35, blanket, 0.95)
		_box(p, 0, 0.62, -0.72, width - 0.4, 0.13, 0.34, C_PLASTIC, 0.9)
		_box(p, 0, 0.62, -1.0, width, 0.7, 0.06, frame, 0.7)
		_box(p, 0, 0.5, 1.0, width, 0.42, 0.06, frame, 0.7)
		if hospital:
			_box(p, -width * 0.5 - 0.02, 0.72, 1.0, 0.05, 0.9, 0.05, C_METAL)  # 输液杆
			_box(p, -width * 0.5 - 0.02, 1.17, 1.0, 0.18, 0.06, 0.06, C_METAL)
		_solid(p, 0, 0.48, 0, width, 0.75, 2.05)
		return p

	func _crate(x: float, z: float, size: float, col: Color) -> Node3D:
		var p := _mk(x, z, size, size, "Crate", rng.randf_range(-0.25, 0.25))
		if p == null:
			return null
		_box(p, 0, size * 0.5, 0, size, size, size, col, 0.9)
		_box(p, 0, size * 0.5, size * 0.5 + 0.012, size * 0.9, 0.08, 0.03, col.darkened(0.28))
		_box(p, 0, size * 0.5, -size * 0.5 - 0.012, size * 0.9, 0.08, 0.03, col.darkened(0.28))
		_box(p, 0, size - 0.015, 0, size * 0.92, 0.04, size * 0.92, col.lightened(0.08))
		_solid(p, 0, size * 0.5, 0, size, size, size)
		return p

	func _barrel(x: float, z: float, col: Color) -> Node3D:
		var p := _mk(x, z, 0.58, 0.58, "Barrel", rng.randf_range(-0.3, 0.3))
		if p == null:
			return null
		_box(p, 0, 0.45, 0, 0.55, 0.9, 0.55, col, 0.75)
		_box(p, 0, 0.22, 0, 0.58, 0.05, 0.58, col.darkened(0.22))
		_box(p, 0, 0.68, 0, 0.58, 0.05, 0.58, col.darkened(0.22))
		_box(p, 0, 0.905, 0, 0.46, 0.02, 0.46, col.darkened(0.35))
		_solid(p, 0, 0.45, 0, 0.56, 0.9, 0.56)
		return p

	func _plant(x: float, z: float) -> Node3D:
		var p := _mk(x, z, 0.72, 0.72, "Plant")
		if p == null:
			return null
		_box(p, 0, 0.2, 0, 0.42, 0.4, 0.42, C_WOOD_DARK, 0.9)
		_box(p, 0, 0.75, 0, 0.62, 0.72, 0.62, C_GREEN, 0.95)
		_box(p, 0, 1.2, 0, 0.4, 0.32, 0.4, C_GREEN.lightened(0.12), 0.95)
		_solid(p, 0, 0.5, 0, 0.5, 1.0, 0.5)
		return p

	func _cooler(x: float, z: float) -> Node3D:
		var p := _mk(x, z, 0.46, 0.46, "Cooler")
		if p == null:
			return null
		_box(p, 0, 0.5, 0, 0.4, 1.0, 0.4, C_METAL, 0.6)
		_box(p, 0.0, 1.22, 0, 0.34, 0.42, 0.34, C_GLASS, 0.15)
		_box(p, 0, 1.05, 0.2, 0.22, 0.2, 0.03, C_METAL_DARK)
		_solid(p, 0, 0.6, 0, 0.42, 1.2, 0.42)
		return p

	# 挂墙板 / 公告板 / 白板（不收占位、不碰撞；高度限制在 2.2m 以内）
	func _wall_board(x: float, z: float, width: float, rot: float, col: Color, cy := 1.72) -> Node3D:
		var p := _mk_wall(x, z, width, 0.1, "Board", rot)
		if p == null:
			return null
		var y := minf(cy, 1.76)
		_box(p, 0, y, 0, width, 0.82, 0.06, col, 0.75)
		_box(p, 0, y, 0.04, width - 0.06, 0.72, 0.01, C_CREAM, 0.9)
		return p

	func _nightstand(x: float, z: float, rot := 0.0) -> Node3D:
		var p := _mk(x, z, 0.5, 0.45, "Nightstand", rot)
		if p == null:
			return null
		_box(p, 0, 0.28, 0, 0.48, 0.56, 0.42, C_WOOD)
		_box(p, 0, 0.56, 0, 0.52, 0.04, 0.46, C_WOOD_LIGHT)
		_box(p, 0, 0.15, 0.22, 0.36, 0.1, 0.02, C_METAL)
		_box(p, 0, 0.68, 0, 0.22, 0.2, 0.22, C_PLASTIC, 0.6)
		_solid(p, 0, 0.3, 0, 0.48, 0.6, 0.44)
		return p

	func _sofa(x: float, z: float, rot: float, col: Color) -> Node3D:
		var p := _mk(x, z, 2.2, 0.95, "Sofa", rot)
		if p == null:
			return null
		_box(p, 0, 0.2, 0, 2.2, 0.4, 0.9, col, 0.95)
		_box(p, 0, 0.62, -0.34, 2.2, 0.62, 0.2, col.darkened(0.1), 0.95)
		_box(p, -1.02, 0.52, 0, 0.18, 0.5, 0.9, col.darkened(0.06), 0.95)
		_box(p, 1.02, 0.52, 0, 0.18, 0.5, 0.9, col.darkened(0.06), 0.95)
		_box(p, 0, 0.44, 0.05, 1.8, 0.12, 0.62, col.lightened(0.08), 0.95)
		_box(p, 0, 0.03, 0, 2.0, 0.06, 0.8, C_METAL_DARK)
		_solid(p, 0, 0.45, 0, 2.2, 0.9, 0.95)
		return p

	func _coffee_table(x: float, z: float, rot := 0.0) -> Node3D:
		var p := _mk(x, z, 1.15, 0.7, "Coffee", rot)
		if p == null:
			return null
		_box(p, 0, 0.4, 0, 1.15, 0.06, 0.68, C_WOOD_LIGHT)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_box(p, sx * 0.48, 0.19, sz * 0.24, 0.06, 0.38, 0.06, C_WOOD_DARK)
		_box(p, 0, 0.46, 0, 0.26, 0.05, 0.2, C_RED, 0.9)  # 杂志
		_solid(p, 0, 0.22, 0, 1.15, 0.44, 0.68)
		return p

	func _tv_console(x: float, z: float, rot := 0.0) -> Node3D:
		var p := _mk(x, z, 1.7, 0.5, "TV", rot)
		if p == null:
			return null
		_box(p, 0, 0.25, 0, 1.6, 0.5, 0.45, C_WOOD_DARK)
		_box(p, 0, 0.51, 0, 1.66, 0.05, 0.5, C_WOOD_LIGHT)
		_box(p, 0, 1.1, -0.05, 1.3, 0.75, 0.07, C_BLACK, 0.3)
		_box(p, 0, 1.1, 0.005, 1.2, 0.64, 0.01, C_SCREEN, 0.15)
		_box(p, 0, 0.57, 0.02, 0.7, 0.07, 0.18, C_METAL_DARK)
		_solid(p, 0, 0.4, 0, 1.6, 0.8, 0.5)
		return p

	func _wardrobe(x: float, z: float, rot: float, col: Color) -> Node3D:
		var p := _mk(x, z, 1.7, 0.62, "Wardrobe", rot)
		if p == null:
			return null
		_box(p, 0, 1.02, 0, 1.7, 2.04, 0.6, col)
		_box(p, 0, 1.05, 0.305, 0.02, 1.9, 0.01, C_BLACK)
		_box(p, -0.12, 1.05, 0.315, 0.05, 0.16, 0.03, C_METAL)
		_box(p, 0.12, 1.05, 0.315, 0.05, 0.16, 0.03, C_METAL)
		_box(p, 0, 2.07, 0.02, 1.76, 0.06, 0.66, col.darkened(0.2))
		_solid(p, 0, 1.02, 0, 1.7, 2.05, 0.62)
		return p

	# 餐桌 + 两把椅子（沿本地 z 方向摆椅子）
	func _table_set(x: float, z: float, rot: float, chair_col: Color) -> Node3D:
		var p := _mk(x, z, 1.3, 2.2, "Table", rot)
		if p == null:
			return null
		_box(p, 0, 0.75, 0, 1.15, 0.07, 0.95, C_WOOD_LIGHT)
		_box(p, 0, 0.37, 0, 0.12, 0.72, 0.12, C_METAL_DARK)
		_box(p, 0, 0.03, 0, 0.65, 0.06, 0.55, C_METAL_DARK)
		_box(p, 0.3, 0.79, 0, 0.3, 0.02, 0.24, C_PLASTIC)  # 餐盘
		_chair(p, 0, 0.85, "-z", chair_col)
		_chair(p, 0, -0.85, "+z", chair_col)
		_solid(p, 0, 0.5, 0, 1.2, 1.0, 2.1)
		return p

	func _meeting_table(x: float, z: float, rot: float) -> Node3D:
		var p := _mk(x, z, 3.3, 1.25, "Meeting", rot)
		if p == null:
			return null
		_box(p, 0, 0.75, 0, 2.2, 0.07, 1.1, C_WOOD_LIGHT)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_box(p, sx * 1.02, 0.37, sz * 0.46, 0.08, 0.72, 0.08, C_METAL_DARK)
		_box(p, 0, 0.79, 0, 0.5, 0.02, 0.3, C_METAL)
		_chair(p, 1.35, 0, "-x", C_NAVY)
		_chair(p, -1.35, 0, "+x", C_NAVY)
		_solid(p, 0, 0.5, 0, 2.3, 1.0, 1.15)
		return p

	func _kitchen(x: float, z: float, rot: float) -> Node3D:
		var p := _mk(x, z, 2.7, 0.75, "Kitchen", rot)
		if p == null:
			return null
		_box(p, -0.35, 0.42, 0, 1.8, 0.84, 0.65, C_CREAM)
		_box(p, -0.35, 0.87, 0, 1.9, 0.06, 0.7, C_METAL, 0.5)
		_box(p, -0.9, 0.9, 0, 0.5, 0.03, 0.4, C_METAL_DARK)  # 水槽
		_box(p, 0.1, 0.9, 0, 0.55, 0.03, 0.5, C_BLACK, 0.4)  # 灶台
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_box(p, 0.1 + sx * 0.13, 0.92, sz * 0.13, 0.12, 0.015, 0.12, C_METAL_DARK)
		_box(p, 0.1, 1.75, -0.1, 0.6, 0.4, 0.45, C_METAL, 0.6)  # 抽油烟机
		_box(p, 1.05, 0.95, 0, 0.8, 1.9, 0.68, C_WHITE, 0.6)  # 冰箱
		_box(p, 0.66, 0.95, 0.34, 0.04, 0.5, 0.03, C_METAL)
		_solid(p, 0, 0.5, 0, 2.7, 1.0, 0.75)
		return p

	func _tool_bench(x: float, z: float, rot: float) -> Node3D:
		var p := _mk(x, z, 2.7, 0.85, "ToolBench", rot)
		if p == null:
			return null
		_box(p, 0, 0.45, 0, 2.7, 0.9, 0.75, C_WOOD_DARK)
		_box(p, 0, 0.93, 0, 2.78, 0.07, 0.8, C_METAL, 0.5)
		_box(p, 0, 1.5, -0.35, 2.6, 0.95, 0.06, C_WOOD_LIGHT)  # 洞洞板
		for i in range(4):
			_box(p, -1.0 + i * 0.65, 1.4, -0.31, 0.16, 0.3, 0.03, C_METAL_DARK)
		_box(p, -0.9, 1.05, 0.05, 0.5, 0.2, 0.3, C_RED, 0.8)  # 工具箱
		_box(p, 0.6, 1.03, 0, 0.6, 0.14, 0.4, C_METAL_DARK)
		_solid(p, 0, 0.5, 0, 2.7, 1.0, 0.85)
		return p

	func _tire_stack(x: float, z: float) -> Node3D:
		var p := _mk(x, z, 0.8, 0.8, "Tires")
		if p == null:
			return null
		for i in range(3):
			_box(p, 0, 0.13 + i * 0.245, 0, 0.74, 0.24, 0.74, C_BLACK, 0.95)
			_box(p, 0, 0.13 + i * 0.245, 0, 0.42, 0.245, 0.42, C_METAL_DARK, 0.8)
		_solid(p, 0, 0.37, 0, 0.76, 0.74, 0.76)
		return p

	func _pallet(x: float, z: float) -> Node3D:
		var p := _mk(x, z, 1.25, 1.05, "Pallet", rng.randf_range(0.0, 0.1))
		if p == null:
			return null
		_box(p, 0, 0.07, 0, 1.2, 0.14, 1.0, C_WOOD_LIGHT, 0.95)
		for i in range(3):
			_box(p, -0.4 + i * 0.4, 0.17, 0, 0.12, 0.06, 1.0, C_WOOD, 0.95)
		_box(p, 0, 0.45, 0, 0.9, 0.5, 0.8, C_CARDBOARD, 0.95)  # 纸箱
		_box(p, 0, 0.73, 0, 0.8, 0.06, 0.7, C_CARDBOARD.darkened(0.2), 0.95)
		_solid(p, 0, 0.4, 0, 1.2, 0.8, 1.0)
		return p

	func _vault_panel(x: float, z: float, rot: float) -> Node3D:
		var p := _mk(x, z, 2.4, 0.42, "Vault", rot)
		if p == null:
			return null
		_box(p, 0, 1.05, 0, 2.4, 2.1, 0.3, C_METAL, 0.45)
		_box(p, 0, 1.05, 0.16, 2.1, 1.85, 0.02, C_METAL_DARK)
		_box(p, 0, 1.15, 0.19, 0.55, 0.07, 0.06, C_STEEL, 0.4)
		_box(p, 0, 1.15, 0.19, 0.07, 0.55, 0.06, C_STEEL, 0.4)
		for i in range(4):
			_box(p, -0.8 + i * 0.53, 1.95, 0.16, 0.1, 0.1, 0.03, C_STEEL, 0.4)
		_box(p, 0, 0.1, 0, 2.4, 0.1, 0.36, C_METAL_DARK)
		_solid(p, 0, 1.05, 0, 2.4, 2.1, 0.42)
		return p

	func _atm(x: float, z: float, rot: float) -> Node3D:
		var p := _mk(x, z, 0.85, 0.72, "ATM", rot)
		if p == null:
			return null
		_box(p, 0, 0.78, 0, 0.8, 1.56, 0.66, C_METAL, 0.6)
		_box(p, 0, 1.15, 0.35, 0.5, 0.4, 0.03, C_SCREEN, 0.2)
		_box(p, 0, 0.85, 0.34, 0.46, 0.22, 0.03, C_METAL_DARK)
		_box(p, 0, 1.62, 0, 0.84, 0.14, 0.7, C_METAL_DARK)
		_solid(p, 0, 0.8, 0, 0.8, 1.6, 0.7)
		return p

	func _queue_row(x: float, z: float, rot: float, width := 2.8) -> Node3D:
		var p := _mk(x, z, width, 0.2, "Queue", rot)
		if p == null:
			return null
		var n := 3
		for i in range(n):
			var lx := -width * 0.5 + 0.2 + i * (width - 0.4) / float(n - 1)
			_box(p, lx, 0.5, 0, 0.11, 0.95, 0.11, C_METAL, 0.5)
			_box(p, lx, 0.025, 0, 0.34, 0.05, 0.34, C_METAL_DARK)
			_box(p, lx, 1.0, 0, 0.16, 0.1, 0.16, C_METAL_DARK)
			if i < n - 1:
				var rx := lx + (width - 0.4) / float(n - 1) * 0.5
				_box(p, rx, 0.85, 0, (width - 0.4) / float(n - 1) - 0.1, 0.035, 0.035, C_NAVY)
		_solid(p, 0, 0.5, 0, width, 1.0, 0.2)
		return p

	func _curtain(x: float, z: float, rot: float, width := 1.8) -> Node3D:
		var p := _mk(x, z, width, 0.14, "Curtain", rot)
		if p == null:
			return null
		_box(p, 0, 1.12, 0, width, 1.7, 0.05, C_CLOTH, 0.98)
		_box(p, 0, 2.0, 0, width + 0.1, 0.05, 0.05, C_METAL)
		_solid(p, 0, 1.05, 0, width, 2.0, 0.14)
		return p

	func _med_cabinet(x: float, z: float, rot: float) -> Node3D:
		var p := _mk(x, z, 1.5, 0.45, "MedCabinet", rot)
		if p == null:
			return null
		_box(p, 0, 0.9, 0, 1.45, 1.8, 0.38, C_WHITE, 0.6)
		_box(p, 0, 0.9, 0.2, 0.68, 1.6, 0.02, C_GLASS, 0.2)
		_box(p, 0, 0.9, 0.205, 0.02, 1.6, 0.01, C_METAL)
		for i in range(3):
			_box(p, 0, 0.35 + i * 0.5, 0.21, 1.3, 0.03, 0.01, C_WHITE.darkened(0.15))
		_solid(p, 0, 0.9, 0, 1.45, 1.8, 0.4)
		return p

	func _iv_stand(x: float, z: float) -> Node3D:
		var p := _mk(x, z, 0.34, 0.34, "IV")
		if p == null:
			return null
		_box(p, 0, 0.03, 0, 0.32, 0.05, 0.32, C_METAL_DARK)
		_box(p, 0, 0.85, 0, 0.04, 1.65, 0.04, C_METAL)
		_box(p, 0, 1.75, 0, 0.06, 0.06, 0.3, C_METAL)
		_box(p, 0, 1.6, 0.1, 0.2, 0.26, 0.08, C_PLASTIC, 0.6)
		_solid(p, 0, 0.85, 0, 0.1, 1.7, 0.1)
		return p

	func _supply_cart(x: float, z: float, rot: float) -> Node3D:
		var p := _mk(x, z, 0.72, 0.9, "Cart", rot)
		if p == null:
			return null
		_box(p, 0, 0.55, 0, 0.7, 0.09, 0.86, C_METAL)
		_box(p, 0, 0.2, 0, 0.7, 0.07, 0.86, C_METAL)
		for i in range(4):
			var lx := -0.3 if i % 2 == 0 else 0.3
			var lz := -0.38 if i < 2 else 0.38
			_box(p, lx, 0.15, lz, 0.05, 0.3, 0.05, C_METAL_DARK)
			_box(p, lx, 0.03, lz, 0.09, 0.06, 0.09, C_BLACK)
		_box(p, -0.1, 0.65, 0, 0.3, 0.12, 0.4, C_PLASTIC)
		_solid(p, 0, 0.35, 0, 0.72, 0.7, 0.9)
		return p

	func _freezer(x: float, z: float, rot: float) -> Node3D:
		var p := _mk(x, z, 1.9, 0.75, "Freezer", rot)
		if p == null:
			return null
		_box(p, 0, 0.95, 0, 1.9, 1.9, 0.72, C_WHITE, 0.5)
		_box(p, 0, 1.0, 0.37, 0.86, 1.5, 0.02, C_GLASS, 0.15)
		_box(p, 0, 1.0, 0.375, 0.02, 1.5, 0.01, C_METAL)
		for i in range(3):
			_box(p, 0, 0.6 + i * 0.45, 0.38, 0.8, 0.03, 0.01, C_METAL)
		_solid(p, 0, 0.95, 0, 1.9, 1.9, 0.72)
		return p

	func _stool(x: float, z: float, col: Color) -> Node3D:
		var p := _mk(x, z, 0.44, 0.44, "Stool")
		if p == null:
			return null
		_box(p, 0, 0.68, 0, 0.4, 0.07, 0.4, col, 0.8)
		_box(p, 0, 0.34, 0, 0.09, 0.64, 0.09, C_METAL_DARK)
		_box(p, 0, 0.03, 0, 0.34, 0.05, 0.34, C_METAL_DARK)
		_solid(p, 0, 0.36, 0, 0.4, 0.7, 0.4)
		return p

	func _chair_piece(x: float, z: float) -> Node3D:
		var p := _mk(x, z, 0.5, 0.5, "Chair")
		if p == null:
			return null
		_chair(p, 0, 0, _rand_facing(), _rnd_col([C_FABRIC, C_NAVY, C_RED]))
		return p

	func _rand_facing() -> String:
		return ["+z", "-z", "+x", "-x"][rng.randi_range(0, 3)]

	func _display_pad(x: float, z: float, fx: float, fz: float, col: Color) -> Node3D:
		var p := _mk_pad(x, z, fx, fz, "Pad", col)
		if p == null:
			return null
		_box(p, 0, 0.07, 0, fx - 0.16, 0.02, fz - 0.16, C_YELLOW, 0.7)
		return p

	# ═══════════════════════════ 底层布局 ═══════════════════════════
	func _police() -> void:
		# 前台：柜台 + 值勤椅 + 电脑
		var rec := _mk(cx, _bz(1.7), 3.8, 1.7, "Reception")
		if rec != null:
			_counter(rec, 3.5, 0.85, 1.0, C_WOOD_DARK, C_WOOD_LIGHT, C_NAVY, 0.32)
			_monitor(rec, 0.95, 0.32)
			_register(rec, -1.1, 1.0, 0.3)
			_chair(rec, 0, -0.55, "+z", C_NAVY)
		# 访客椅
		_chair_piece(cx - 1.7, z0 + 2.6)
		_chair_piece(cx + 1.7, z0 + 2.6)
		# 左侧储物柜
		_locker(_lx(0.55), z0 + 1.35, PI * 0.5, C_NAVY)
		_locker(_lx(0.55), z0 + 2.45, PI * 0.5, C_NAVY)
		# 右侧档案柜
		_filing(_rx(0.62), z0 + 1.3, C_METAL, -PI * 0.5)
		_filing(_rx(0.62), z0 + 2.35, C_METAL, -PI * 0.5)
		# 左墙长椅
		_bench(_lx(0.55), z1 - 2.6, 2.2, PI * 0.5, C_NAVY)
		# 后墙公告板 + 饮水机
		_wall_board(cx, z0 + 0.05, 2.6, 0.0, C_NAVY, 1.95)
		_cooler(x1 - 1.1, _bz(0.46))
		_finish("police")

	func _fire() -> void:
		# 装备柜
		_locker(_lx(0.55), z0 + 1.3, PI * 0.5, C_RED, 2.0)
		_locker(_lx(0.55), z0 + 2.4, PI * 0.5, C_RED, 2.0)
		_locker(_lx(0.55), z0 + 3.5, PI * 0.5, C_RED, 2.0)
		# 长凳（沿右墙）
		_bench(_rx(0.55), z0 + 1.7, 2.4, -PI * 0.5, C_WOOD)
		_bench(_rx(0.55), z0 + 4.3, 2.4, -PI * 0.5, C_WOOD)
		# 后墙消防服挂架
		var rack := _mk(cx, _bz(0.45), 2.4, 0.45, "GearRack")
		if rack != null:
			_box(rack, 0, 1.0, -0.16, 2.2, 2.0, 0.08, C_METAL_DARK)
			_box(rack, 0, 2.0, 0.02, 2.3, 0.07, 0.1, C_METAL)
			for i in range(3):
				var gx := -0.7 + i * 0.7
				_box(rack, gx, 1.45, 0.06, 0.42, 0.95, 0.24, C_RED, 0.85)  # 消防服
				_box(rack, gx, 1.98, 0.06, 0.3, 0.16, 0.3, C_YELLOW, 0.7)  # 头盔
			_solid(rack, 0, 1.0, 0, 2.2, 2.0, 0.4)
		# 值勤桌
		_desk_set(x1 - 2.2, z1 - 2.7, "-z", C_WOOD_DARK)
		# 器材箱
		_crate(x0 + 1.0, z0 + 0.6, 0.8, C_RUST)
		_crate(x1 - 1.0, z1 - 1.2, 0.7, C_METAL_DARK)
		_finish("fire")

	func _hospital() -> void:
		var rec := _mk(cx, _bz(1.7), 3.4, 1.7, "Reception")
		if rec != null:
			_counter(rec, 3.1, 0.85, 1.0, C_PLASTIC, C_METAL, C_GREEN, 0.32)
			_monitor(rec, 0.9, 0.32)
			_register(rec, -1.0, 1.0, 0.3)
			_chair(rec, 0, -0.55, "+z", C_GREEN)
		# 靠右墙两张病床（床头朝后墙）
		_bed(x1 - 0.53, z0 + 1.1, 0.0, 1.0, C_METAL, true)
		_bed(x1 - 0.53, z0 + 3.5, 0.0, 1.0, C_METAL, true)
		# 病床之间的帘子
		_curtain(x1 - 0.93, z0 + 2.3, 0.0, 1.8)
		# 左侧候诊长椅
		_bench(_lx(0.55), z1 - 2.8, 2.4, PI * 0.5, C_GREEN)
		# 后墙左角药柜
		_med_cabinet(x0 + 1.0, _bz(0.45), 0.0)
		# 输液架 + 推车
		_iv_stand(x1 - 1.7, z0 + 0.7)
		_supply_cart(x0 + 2.2, z1 - 2.4, 0.0)
		# 候诊椅
		_chair_piece(cx - 1.8, z0 + 2.7)
		_chair_piece(cx + 1.8, z0 + 2.7)
		_finish("hospital")

	func _diner() -> void:
		var clen := minf(6.0, area.size.y - 3.0)
		var ctr := _mk(_rx(0.65), z0 + 0.8 + clen * 0.5, clen, 0.65, "Counter", -PI * 0.5)
		if ctr != null:
			_counter(ctr, clen, 0.65, 1.05, C_WOOD_DARK, C_CREAM, C_RED)
			_box(ctr, -clen * 0.5 + 0.7, 1.2, 0.0, 0.5, 0.28, 0.3, C_METAL_DARK)  # 收银机
			_box(ctr, clen * 0.5 - 1.2, 1.22, 0.0, 0.55, 0.3, 0.4, C_GLASS, 0.15)  # 甜品柜
		# 吧台凳
		var sz := z0 + 1.4
		var si := 0
		while si < 3:
			_stool(_rx(0.65) - 0.95, sz, C_RED)
			sz += 1.35
			si += 1
		# 左侧餐桌
		_table_set(x0 + 2.3, z0 + 2.4, 0.0, C_RED)
		_table_set(x0 + 2.3, z0 + 5.2, 0.0, C_NAVY)
		# 靠后墙的卡座长凳
		_bench(x0 + 2.3, _bz(0.55), 2.2, 0.0, C_RED)
		# 后墙菜单板
		_wall_board(cx + 1.2, z0 + 0.05, 2.0, 0.0, C_WOOD_DARK, 1.8)
		_finish("diner")

	func _mart() -> void:
		# 货架两排（中间偏左）
		_shelf(cx - 2.6, z0 + 2.7, 3.0, 0.6, 1.7, 0.0, C_METAL, true)
		_shelf(cx - 2.6, z0 + 4.3, 3.0, 0.6, 1.7, 0.0, C_METAL, true)
		# 后墙货架
		_shelf(cx + 2.6, _bz(0.6), 2.4, 0.6, 1.7, 0.0, C_METAL, true)
		# 右侧冰柜
		_freezer(_rx(0.75), z0 + 1.6, -PI * 0.5)
		# 前右侧收银台
		var cash := _mk(x1 - 2.2, z1 - 2.4, 2.6, 1.2, "CashCounter")
		if cash != null:
			_counter(cash, 2.4, 0.9, 1.05, C_METAL_DARK, C_PLASTIC, C_GREEN, 0.1)
			_register(cash, 0.7, 1.05, 0.1)
			_box(cash, -0.5, 1.06, 0.1, 0.8, 0.02, 0.4, C_BLACK, 0.6)  # 传送带
		# 前左侧端头货架
		_shelf(x0 + 1.6, z1 - 2.7, 1.2, 0.55, 1.2, 0.0, C_WOOD, true)
		# 地上的货箱
		_crate(x0 + 1.1, z0 + 1.2, 0.65, C_CARDBOARD)
		_crate(x1 - 1.0, z1 - 1.1, 0.6, C_CARDBOARD)
		_finish("mart")

	func _garage() -> void:
		# 工具台（后墙）
		_tool_bench(cx - 1.2, _bz(0.85), 0.0)
		# 后左角轮胎堆
		_tire_stack(x0 + 0.8, _bz(0.8))
		# 展示台（可踩的地台）
		_display_pad(x0 + 3.2, z1 - 3.4, 3.0, 4.2, C_CONCRETE)
		# 举升机（右侧）
		var lift := _mk(x1 - 2.6, z0 + 5.2, 2.6, 0.55, "Lift")
		if lift != null:
			for sx in [-1.0, 1.0]:
				_box(lift, sx * 1.15, 1.05, 0, 0.26, 2.1, 0.3, C_YELLOW, 0.6)
				_solid(lift, sx * 1.15, 1.05, 0, 0.26, 2.1, 0.3)
			_box(lift, 0, 2.0, 0, 2.3, 0.22, 0.3, C_METAL_DARK)
		# 油桶
		_barrel(x0 + 0.9, z1 - 1.0, C_RUST)
		_barrel(x0 + 1.7, z1 - 1.0, C_METAL_DARK)
		# 左墙零件架
		_shelf(_lx(0.5), z0 + 4.2, 2.4, 0.5, 1.9, PI * 0.5, C_METAL_DARK, true)
		# 移动工作台
		var wb := _mk(x1 - 1.3, z1 - 1.7, 1.3, 0.7, "Workbench")
		if wb != null:
			_box(wb, 0, 0.85, 0, 1.25, 0.08, 0.65, C_METAL, 0.5)
			_box(wb, -0.45, 0.42, 0, 0.08, 0.84, 0.55, C_METAL_DARK)
			_box(wb, 0.45, 0.42, 0, 0.08, 0.84, 0.55, C_METAL_DARK)
			_box(wb, 0, 1.0, 0, 0.4, 0.22, 0.3, C_RED, 0.8)
			_solid(wb, 0, 0.5, 0, 1.25, 1.0, 0.65)
		_finish("garage")

	func _bank() -> void:
		# 后墙柜台（柜台 + 玻璃隔断 + 柜员椅）
		var tell := _mk(cx, _bz(1.35), 5.4, 1.35, "Teller")
		if tell != null:
			_counter(tell, 5.0, 0.9, 1.15, C_MARBLE, C_MARBLE.lightened(0.1), C_NAVY, 0.18)
			for i in range(3):
				var dx := -1.7 + i * 1.7
				_box(tell, dx, 1.55, 0.62, 0.06, 0.8, 0.06, C_GLASS, 0.15)
				_box(tell, dx, 1.13, 0.62, 0.5, 0.04, 0.3, C_METAL)
				_chair(tell, dx, -0.48, "+z", C_NAVY)
		# 排队柱
		_queue_row(cx, z0 + 2.8, 0.0, 2.8)
		# 右墙金库门
		_vault_panel(_rx(0.42), z0 + 5.2, -PI * 0.5)
		# 左墙等候长椅
		_bench(_lx(0.55), z0 + 4.6, 2.6, PI * 0.5, C_NAVY)
		# 前右 ATM、前左保安桌
		_atm(x1 - 1.1, z1 - 2.2, -PI * 0.5)
		_desk_set(x0 + 2.2, z1 - 2.8, "+z", C_WOOD_DARK)
		# 绿植 + 后墙行徽
		_plant(x0 + 0.7, z1 - 1.0)
		_wall_board(cx + 4.2, z0 + 0.05, 2.2, 0.0, C_WOOD_DARK, 1.72)
		_finish("bank")

	func _gang() -> void:
		_table_set(x0 + 2.0, z0 + 1.9, 0.0, C_RED)
		# 货箱 / 桶
		_crate(x1 - 1.1, _bz(0.9), 1.0, C_CARDBOARD)
		_crate(x1 - 2.3, _bz(0.85), 0.8, C_RUST)
		_crate(x1 - 1.0, z0 + 2.6, 0.75, C_CARDBOARD)
		_crate(_lx(0.9), z1 - 1.6, 0.9, C_RUST)
		_barrel(x0 + 0.9, _bz(0.7), C_METAL_DARK)
		_barrel(x0 + 1.8, _bz(0.7), C_RUST)
		_pallet(x1 - 1.2, z1 - 2.0)
		_finish("gang")

	func _shopfront() -> void:
		# 空货架（左墙 + 后墙）
		_shelf(_lx(0.5), z0 + 1.9, 2.2, 0.5, 1.8, PI * 0.5, C_WOOD_DARK, false)
		_shelf(_lx(0.5), z0 + 4.1, 2.2, 0.5, 1.8, PI * 0.5, C_WOOD_DARK, false)
		_shelf(cx + 2.4, _bz(0.55), 2.6, 0.55, 1.8, 0.0, C_WOOD_DARK, false)
		# 落灰的收银台
		var cash := _mk(x1 - 2.1, z1 - 2.3, 2.4, 1.1, "Counter")
		if cash != null:
			_counter(cash, 2.2, 0.85, 0.95, C_WOOD_DARK, C_WOOD, C_METAL_DARK, 0.1)
			_box(cash, 0.4, 1.0, 0.1, 0.34, 0.2, 0.3, C_METAL_DARK)
		# 地上的旧纸箱
		_crate(x0 + 1.2, z1 - 1.4, 0.7, C_CARDBOARD)
		_crate(x0 + 2.1, z1 - 1.7, 0.55, C_CARDBOARD)
		_crate(x0 + 1.5, z1 - 2.4, 0.5, C_CARDBOARD)
		# 垃圾桶
		var bin := _mk(cx + 0.2, z0 + 1.0, 0.5, 0.5, "Bin")
		if bin != null:
			_box(bin, 0, 0.45, 0, 0.44, 0.9, 0.44, C_METAL_DARK)
			_box(bin, 0, 0.92, 0, 0.48, 0.05, 0.48, C_METAL)
			_solid(bin, 0, 0.45, 0, 0.44, 0.9, 0.44)
		_finish("shopfront")

	# ═══════════════════════════ 上层布局 ═══════════════════════════
	func _office() -> void:
		# 会议桌在左后
		_meeting_table(cx - 2.9, z0 + 2.5, 0.0)
		# 办公桌 3 组
		_desk_set(x1 - 2.2, z0 + 2.2, "+z", C_WOOD_DARK)
		_desk_set(x0 + 2.1, z1 - 2.8, "+z", C_NAVY)
		_desk_set(x1 - 2.2, z1 - 2.8, "-z", C_NAVY)
		# 后墙档案柜
		_filing(x0 + 1.0, _bz(0.62), C_METAL, 0.0)
		_filing(x1 - 1.0, _bz(0.62), C_METAL, 0.0)
		# 左墙书架
		_shelf(_lx(0.5), z0 + 4.8, 2.2, 0.5, 2.0, PI * 0.5, C_WOOD_DARK, true)
		# 杂物
		_plant(x1 - 0.9, z1 - 1.0)
		_cooler(x0 + 0.8, z1 - 1.0)
		_wall_board(cx, z0 + 0.05, 2.2, 0.0, C_WHITE, 1.85)
		_finish("office")

	func _apartment(hospital: bool) -> void:
		# 厨房（后墙左）
		_kitchen(x0 + 2.0, _bz(0.75), 0.0)
		if hospital:
			_bed(x1 - 0.53, z0 + 1.1, 0.0, 1.0, C_METAL, true)
			_bed(x1 - 0.53, z0 + 3.5, 0.0, 1.0, C_METAL, true)
			_curtain(x1 - 0.93, z0 + 2.3, 0.0, 1.8)
			_bench(_lx(0.55), z1 - 2.8, 2.4, PI * 0.5, C_GREEN)
			_med_cabinet(x0 + 2.2, z0 + 1.0, 0.0)
			_iv_stand(x1 - 1.7, z0 + 0.7)
			_supply_cart(x0 + 2.4, z1 - 2.4, 0.0)
			_chair_piece(cx - 1.8, z0 + 2.7)
		else:
			_bed(x1 - 1.6, z0 + 1.1, 0.0, 1.6, C_WOOD_DARK, false)
			_nightstand(x1 - 2.9, z0 + 0.5, 0.0)
			_wardrobe(_rx(0.62), z0 + 4.8, -PI * 0.5, C_WOOD_DARK)
			_sofa(_lx(0.95), z0 + 2.9, PI * 0.5, C_NAVY)
			_coffee_table(x0 + 2.2, z0 + 2.9, 0.0)
			_tv_console(_rx(0.5), z0 + 2.9, -PI * 0.5)
			_table_set(x0 + 2.0, z1 - 2.6, 0.0, C_RED)
			_plant(x1 - 1.1, z1 - 1.2)
			_display_pad(x0 + 2.1, z0 + 2.9, 2.6, 2.0, C_RED.darkened(0.35))
		_finish("apartment")

	func _warehouse() -> void:
		# 后墙货架
		_shelf(cx - 2.8, _bz(0.62), 2.4, 0.62, 2.0, 0.0, C_METAL_DARK, true)
		_shelf(cx + 2.8, _bz(0.62), 2.4, 0.62, 2.0, 0.0, C_METAL_DARK, true)
		# 右墙货架
		_shelf(_rx(0.62), z0 + 3.6, 2.4, 0.62, 2.0, -PI * 0.5, C_METAL_DARK, true)
		# 托盘 + 货箱
		_pallet(x0 + 2.0, z0 + 1.0)
		_pallet(x1 - 2.2, z1 - 2.2)
		_crate(x0 + 0.9, z1 - 1.4, 0.95, C_CARDBOARD)
		_crate(x0 + 2.0, z1 - 1.3, 0.8, C_RUST)
		_crate(_lx(0.9), z0 + 3.2, 0.85, C_CARDBOARD)
		_barrel(x1 - 1.0, z0 + 1.1, C_RUST)
		_barrel(x1 - 1.9, z0 + 1.1, C_METAL_DARK)
		# 前左角小办公桌
		_desk_set(x0 + 2.2, z1 - 2.6, "+z", C_WOOD_DARK)
		_finish("warehouse")

	# ═══════════════════════════ 填充 / 兜底 ═══════════════════════════
	func _finish(mode: String) -> void:
		var target := clampi(int(area.size.x * area.size.y / 9.0), MIN_PIECES, MAX_PIECES)
		_fill_to(mode, target)

	func _fill_to(mode: String, target: int) -> void:
		if count >= target:
			return
		# 候选点：整块区域网格，洗牌后逐个尝试
		var spots: Array[Vector2] = []
		var z := z0 + 0.55
		while z <= z1 - 0.35:
			var x := x0 + 0.55
			while x <= x1 - 0.35:
				spots.append(Vector2(x, z))
				x += 1.0
			z += 1.0
		for i in range(spots.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: Vector2 = spots[i]
			spots[i] = spots[j]
			spots[j] = tmp
		var guard := 0
		for s in spots:
			if count >= target or count >= MAX_PIECES:
				break
			guard += 1
			if guard > 600:
				break
			_add_extra(mode, s.x, s.y)
		# 实在放不下就用最省地方的椅子/箱子补齐
		var guard2 := 0
		while count < MIN_PIECES and guard2 < 120:
			guard2 += 1
			var x := rng.randf_range(x0 + 0.4, x1 - 0.4)
			var z2 := rng.randf_range(z0 + 0.4, z1 - 0.4)
			if _chair_piece(x, z2) == null:
				_crate(x, z2, 0.55, C_CARDBOARD)

	func _add_extra(mode: String, x: float, z: float) -> void:
		match mode:
			"office":
				if _desk_set(x, z, _rand_facing(), _rnd_col([C_WOOD_DARK, C_NAVY])) != null:
					return
				if _filing(x, z, C_METAL, 0.0) != null:
					return
				if _plant(x, z) != null:
					return
				_chair_piece(x, z)
			"apartment":
				if _chair_piece(x, z) != null:
					return
				if _plant(x, z) != null:
					return
				_nightstand(x, z, 0.0)
			"warehouse", "gang", "shopfront", "mart":
				if _crate(x, z, rng.randf_range(0.55, 0.95), _rnd_col([C_CARDBOARD, C_RUST, C_METAL_DARK])) != null:
					return
				if _barrel(x, z, _rnd_col([C_RUST, C_METAL_DARK, C_GREEN])) != null:
					return
				if _pallet(x, z) != null:
					return
				_shelf(x, z, 1.6, 0.55, 1.7, 0.0, C_METAL_DARK, true)
			"diner":
				if _table_set(x, z, 0.0, _rnd_col([C_RED, C_NAVY])) != null:
					return
				if _chair_piece(x, z) != null:
					return
				_plant(x, z)
			"garage":
				if _barrel(x, z, _rnd_col([C_RUST, C_METAL_DARK])) != null:
					return
				if _crate(x, z, rng.randf_range(0.55, 0.9), C_CARDBOARD) != null:
					return
				_shelf(x, z, 1.6, 0.5, 1.6, 0.0, C_METAL_DARK, true)
			_:
				if _chair_piece(x, z) != null:
					return
				if _filing(x, z, C_METAL, 0.0) != null:
					return
				if _plant(x, z) != null:
					return
				_crate(x, z, rng.randf_range(0.55, 0.85), _rnd_col([C_CARDBOARD, C_RUST]))


# ═══════════════════════════ 对外入口 ═══════════════════════════
static func furnish(parent: Node3D, kind: String, floor_y: float, area: Rect2,
		rng: RandomNumberGenerator) -> void:
	if parent == null or rng == null:
		return
	if area.size.x < 2.0 or area.size.y < 2.0:
		return
	var ctx := Ctx.new()
	ctx.setup(parent, floor_y, area, rng)
	ctx.build(kind)
