extends Node
## 全局游戏状态：经济 / 时间 / 职业 / 房产 / 车辆 / 店铺 / 任务 / 通缉度
## 所有系统通过信号联动，UI 只读这里的字段

signal cash_changed
signal job_changed
signal time_changed
signal heat_changed
signal missions_changed
signal properties_changed
signal vehicles_changed
signal shops_changed
signal weapons_changed
signal toast(text: String, kind: String)

# ─────────────── 运行时状态 ───────────────
var cash: int = Data.START_CASH
var bank: int = 0
var job: String = "unemployed"
var gang: String = ""
var health: float = 100.0
var stamina: float = 100.0
var heat: float = 0.0                  # 通缉度 0..5
var day: int = 1
var clock: float = 0.0                 # 秒，0..Data.DAY_LENGTH

var properties: Dictionary = {}        # id -> {"owned": true, "furniture": [ {...} ]}
var vehicles: Array = []               # [{"uid":int,"type":String,"engine":int,"tires":int,"paint":Color,"name":String}]
var active_vehicle: int = -1
var shops: Dictionary = {}             # shop_id -> expire_day
var missions: Array = []               # [{id,type,title,reward,target,progress,need,meta}]
var weapons_owned: Dictionary = {}     # weapon_id -> true
var weapon: String = ""                # 当前装备的武器 id
var weapon_ammo: Dictionary = {}
var player_state: Dictionary = {"position": Vector3(2, 0.3, 14), "yaw": 0.0, "pitch": 0.0}
var save_path := "user://saves/city.save"
var persistence_enabled := true
var stats: Dictionary = {"missions_done": 0, "earned": 0, "arrests": 0, "fires": 0, "heals": 0}

# ─────────────── 场景引用 ───────────────
var player: Node3D = null
var world: Node3D = null
var hud = null
var tablet = null

var places: Dictionary = {}            # place_id -> Vector3 (门口世界坐标)
var _mission_seq: int = 0
var _font: FontFile = null
var _theme: Theme = null
var _ui_tick := 0.0
var _last_heat_stars := 0


func _init() -> void:
	clock = Data.START_HOUR / 24.0 * Data.DAY_LENGTH
	_setup_input()


func _ready() -> void:
	var f = load("res://assets/fonts/NotoSansSC.otf")
	if f is FontFile:
		_font = f
	else:
		_font = FontFile.new()
		var err := _font.load_dynamic_font("res://assets/fonts/NotoSansSC.otf")
		if err != OK:
			push_warning("中文字体加载失败，界面可能显示为方块")
	ThemeDB.fallback_font = _font
	_theme = _build_theme()
	var win := get_window()
	if win:
		win.theme = _theme
	persistence_enabled = not "--no-save" in OS.get_cmdline_user_args()
	if persistence_enabled:
		load_game(false)


# ═══════════════ 输入映射 ═══════════════
func _setup_input() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("jump", [KEY_SPACE])
	_bind("sprint", [KEY_SHIFT])
	_bind("crouch", [KEY_CTRL, KEY_C])
	_bind("interact", [KEY_E])
	_bind("tablet", [KEY_TAB])
	_bind("cancel", [KEY_ESCAPE])
	_bind("decorate", [KEY_B])
	_bind("horn", [KEY_H])
	_bind("map_zoom", [KEY_M])
	_bind("reload", [KEY_R])
	for i in range(4):
		_bind("weapon_%d" % (i + 1), [KEY_1 + i])
	_bind_mouse("shoot", MOUSE_BUTTON_LEFT)


func _bind_mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


# ═══════════════ 主题 ═══════════════
func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font = _font
	t.default_font_size = 16

	t.set_color("font_color", "Label", Data.C_TEXT)
	t.set_color("font_color", "Button", Data.C_TEXT)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", Data.C_TEAL)
	t.set_color("font_disabled_color", "Button", Data.C_DIM)
	t.set_color("font_color", "CheckBox", Data.C_TEXT)
	t.set_color("font_color", "ItemList", Data.C_TEXT)
	t.set_color("font_color", "OptionButton", Data.C_TEXT)

	var normal := _box(Data.C_PANEL2, 8, Color(1, 1, 1, 0.06))
	var hover := _box(Data.C_ACCENT.darkened(0.45), 8, Data.C_ACCENT)
	var pressed := _box(Data.C_ACCENT.darkened(0.25), 8, Data.C_ACCENT)
	var disabled := _box(Data.C_PANEL, 8, Color(1, 1, 1, 0.03))
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_constant("outline_size", "Button", 0)

	var panel := _box(Data.C_PANEL, 14, Data.C_LINE)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.35)
	sb.set_corner_radius_all(6)
	t.set_stylebox("scroll", "VScrollBar", sb)
	var grab := _box(Color(1, 1, 1, 0.18), 6)
	t.set_stylebox("grabber", "VScrollBar", grab)
	var grabh := _box(Data.C_ACCENT, 6)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabh)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabh)

	t.set_color("font_color", "RichTextLabel", Data.C_TEXT)
	t.set_color("default_color", "RichTextLabel", Data.C_TEXT)
	t.set_font("normal_font", "RichTextLabel", _font)
	t.set_font("bold_font", "RichTextLabel", _font)
	return t


func _box(bg: Color, radius: int, border: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 9
	sb.content_margin_bottom = 9
	if border.a > 0.0:
		sb.border_color = border
		sb.set_border_width_all(1)
	return sb


func get_theme_res() -> Theme:
	return _theme


func get_font() -> FontFile:
	return _font


# ═══════════════ 时间 ═══════════════
func _process(delta: float) -> void:
	if get_tree().paused:
		return
	clock += delta
	while clock >= Data.DAY_LENGTH:
		clock -= Data.DAY_LENGTH
		day += 1
		_decay_shop_rent()
		_payday()
	_ui_tick += delta
	if _ui_tick >= 0.25:
		_ui_tick = fmod(_ui_tick, 0.25)
		time_changed.emit()
	# 体力恢复
	if is_instance_valid(player) and player.has_method("is_moving") and not bool(player.call("is_moving")):
		stamina = min(100.0, stamina + delta * 6.0)
	# 通缉度缓慢衰减
	if heat > 0.0:
		heat = max(0.0, heat - delta * 0.02)
		var stars := ceili(heat)
		if stars != _last_heat_stars:
			_last_heat_stars = stars
			heat_changed.emit()


func get_hour() -> float:
	return clock / Data.DAY_LENGTH * 24.0


func get_time_string() -> String:
	var h := get_hour()
	var hh := int(h)
	var mm := int((h - hh) * 60.0)
	return "第 %d 天  %02d:%02d" % [day, hh, mm]


func is_night() -> bool:
	var h := get_hour()
	return h < 6.0 or h > 20.0


func _payday() -> void:
	var info: Dictionary = Data.JOBS.get(job, Data.JOBS["unemployed"])
	var salary: int = int(info.get("salary", 0))
	if salary > 0:
		add_cash(salary, "日薪 · %s" % info.get("name", ""))
		toast.emit("工资到账 +$%d（%s）" % [salary, info.get("name", "")], "money")


func _decay_shop_rent() -> void:
	var changed := false
	for k in shops.keys():
		if shops[k] < day:
			shops.erase(k)
			changed = true
	if changed:
		if not job_has_shop(job):
			set_job("unemployed")
		shops_changed.emit()
		toast.emit("有店铺租约已到期", "warn")


# ═══════════════ 金钱 ═══════════════
func add_cash(n: int, reason: String = "") -> void:
	cash += n
	if n > 0:
		stats["earned"] = int(stats["earned"]) + n
	cash_changed.emit()
	if reason != "":
		toast.emit("%s  %s$%d" % [reason, "+" if n >= 0 else "-", absi(n)], "money" if n >= 0 else "warn")


func try_spend(n: int, reason: String = "") -> bool:
	if n <= 0:
		return false
	if cash < n:
		toast.emit("现金不足，还差 $%d" % (n - cash), "error")
		return false
	cash -= n
	cash_changed.emit()
	if reason != "":
		toast.emit("%s  -$%d" % [reason, n], "money")
	return true


# ═══════════════ 职业 ═══════════════
func set_job(id: String) -> bool:
	if not Data.JOBS.has(id):
		return false
	var info: Dictionary = Data.JOBS[id]
	var need: String = info.get("need_shop", "")
	if need != "" and not job_has_shop(id):
		toast.emit("需要先租下「%s」的使用权" % _shop_name(need), "error")
		return false
	if job != id:
		for mission in missions.duplicate():
			if Data.MISSION_TYPES[mission["type"]]["job"] != id:
				abandon_mission(int(mission["id"]))
	job = id
	job_changed.emit()
	toast.emit("职业已变更为「%s」" % info.get("name", ""), "ok")
	if id == "police":
		_grant_police_loadout()
	return true


# ─────────────── 武器 ───────────────
func _grant_police_loadout() -> void:
	if not weapons_owned.has("glock"):
		weapons_owned["glock"] = true
		weapons_changed.emit()
		toast.emit("警局配发：Glock 17（免费）", "ok")
		if weapon == "":
			equip_weapon("glock")


func weapon_info(id: String) -> Dictionary:
	return _find(Data.WEAPONS, id)


func owns_weapon(id: String) -> bool:
	return weapons_owned.has(id)


func own_weapon_list() -> Array:
	var out: Array = []
	for id in Data.WEAPON_ORDER:
		if weapons_owned.has(id):
			out.append(id)
	return out


func give_weapon(id: String) -> bool:
	if weapon_info(id).is_empty() or weapons_owned.has(id):
		return false
	weapons_owned[id] = true
	weapons_changed.emit()
	return true


## 购买（答题校验由界面层负责，这里只校验钱与重复购买）
func buy_weapon(id: String) -> bool:
	var w := weapon_info(id)
	if w.is_empty():
		return false
	if weapons_owned.has(id):
		toast.emit("你已经拥有 %s 了" % w["name"], "warn")
		return false
	if id == "glock":
		toast.emit("Glock 17 只对警察免费配发", "error")
		return false
	var price := int(w["price"])
	if not try_spend(price, "购买 · %s" % w["name"]):
		return false
	weapons_owned[id] = true
	weapons_changed.emit()
	toast.emit("已购入 %s" % w["name"], "ok")
	equip_weapon(id)
	return true


func equip_weapon(id: String) -> void:
	if not weapons_owned.has(id):
		return
	weapon = id
	weapons_changed.emit()
	if is_instance_valid(player):
		player.set_weapon_visual(id)


func holster_weapon() -> void:
	weapon = ""
	weapons_changed.emit()
	if is_instance_valid(player):
		player.set_weapon_visual("")


func _shop_name(id: String) -> String:
	for s in Data.SHOPS:
		if s["id"] == id:
			return s["name"]
	return id


func has_shop(id: String) -> bool:
	return shops.has(id) and int(shops[id]) >= day


func job_has_shop(job_id: String) -> bool:
	if str(Data.JOBS.get(job_id, {}).get("need_shop", "")) == "":
		return true
	for shop in Data.SHOPS:
		if shop["job"] == job_id and has_shop(shop["id"]):
			return true
	return false


func rent_shop(id: String) -> bool:
	var data: Dictionary = {}
	for s in Data.SHOPS:
		if s["id"] == id:
			data = s
			break
	if data.is_empty():
		return false
	if has_shop(id):
		toast.emit("该店铺已在租期内", "warn")
		return false
	var rent: int = data["rent"]
	if not try_spend(rent, "租金 · %s" % data["name"]):
		return false
	shops[id] = day + 6
	shops_changed.emit()
	toast.emit("已租下「%s」，有效期 7 天" % data["name"], "ok")
	return true


# ═══════════════ 房产 ═══════════════
func owns_property(id: String) -> bool:
	return properties.has(id) and properties[id].get("owned", false)


func buy_property(id: String) -> bool:
	if owns_property(id):
		toast.emit("你已经拥有这处房产", "warn")
		return false
	var data: Dictionary = _find(Data.PROPERTIES, id)
	if data.is_empty():
		return false
	if not try_spend(int(data["price"]), "购房 · %s" % data["name"]):
		return false
	properties[id] = {"owned": true, "furniture": []}
	properties_changed.emit()
	toast.emit("恭喜！「%s」现在是你的了，按 B 可以开始装修" % data["name"], "ok")
	return true


func can_place_furniture(prop_id: String, furn_id: String, pos: Vector3, rot_y: float) -> bool:
	var prop := _find(Data.PROPERTIES, prop_id)
	var furn := _find(Data.FURNITURE, furn_id)
	if not owns_property(prop_id) or prop.is_empty() or furn.is_empty() or not pos.is_finite() or not is_finite(rot_y):
		return false
	var center: Vector3 = Data.cell_center(prop["cell"]) + prop["offset"]
	var size: Vector3 = furn["size"]
	var half_x := (absf(cos(rot_y)) * size.x + absf(sin(rot_y)) * size.z) * 0.5
	var half_z := (absf(sin(rot_y)) * size.x + absf(cos(rot_y)) * size.z) * 0.5
	if absf(pos.x - center.x) + half_x > prop["size"].x * 0.5 - 0.5 or absf(pos.z - center.z) + half_z > prop["size"].y * 0.5 - 0.5:
		return false
	if pos.y < -0.1 or pos.y + size.y > 5.0:
		return false
	for existing in properties[prop_id]["furniture"]:
		var other := _find(Data.FURNITURE, existing["id"])
		var other_size: Vector3 = other["size"]
		var other_rot: float = existing["rot"]
		var other_half := Vector2(absf(cos(other_rot)) * other_size.x + absf(sin(other_rot)) * other_size.z, absf(sin(other_rot)) * other_size.x + absf(cos(other_rot)) * other_size.z) * 0.5
		var diff: Vector3 = existing["pos"] - pos
		if absf(diff.x) < half_x + other_half.x + 0.1 and absf(diff.z) < half_z + other_half.y + 0.1:
			return false
	return true


func add_furniture(prop_id: String, furn_id: String, pos: Vector3, rot_y: float) -> bool:
	if not can_place_furniture(prop_id, furn_id, pos, rot_y):
		return false
	var furn := _find(Data.FURNITURE, furn_id)
	if not try_spend(int(furn["price"]), "购买家具 · %s" % furn["name"]):
		return false
	properties[prop_id]["furniture"].append({"id": furn_id, "pos": pos, "rot": rot_y})
	properties_changed.emit()
	return true


func remove_furniture(prop_id: String, index: int) -> void:
	if not owns_property(prop_id):
		return
	var arr: Array = properties[prop_id]["furniture"]
	if index < 0 or index >= arr.size():
		return
	var fid: String = arr[index]["id"]
	var fd: Dictionary = _find(Data.FURNITURE, fid)
	if not fd.is_empty():
		var refund := int(int(fd["price"]) * 0.6)
		add_cash(refund, "家具回收")
	arr.remove_at(index)
	properties_changed.emit()


func owned_property_list() -> Array:
	var out: Array = []
	for p in Data.PROPERTIES:
		if owns_property(p["id"]):
			out.append(p)
	return out


# ═══════════════ 车辆 ═══════════════
func buy_vehicle(type_id: String) -> bool:
	if vehicles.size() >= 12:
		toast.emit("车库已满（12 辆），请使用现有车辆", "warn")
		return false
	var data: Dictionary = _find(Data.VEHICLES, type_id)
	if data.is_empty():
		return false
	if not try_spend(int(data["price"]), "购车 · %s" % data["name"]):
		return false
	var uid := 1
	for v in vehicles:
		uid = maxi(uid, int(v["uid"]) + 1)
	vehicles.append({
		"uid": uid, "type": type_id, "engine": 0, "tires": 0,
		"paint": data["color"], "name": data["name"],
	})
	vehicles_changed.emit()
	toast.emit("「%s」已停进车行停车场，走过去按 E 上车" % data["name"], "ok")
	return true


func vehicle_by_uid(uid: int) -> Dictionary:
	for v in vehicles:
		if int(v["uid"]) == uid:
			return v
	return {}


func upgrade_vehicle(uid: int, part: String) -> bool:
	if not Data.UPGRADES.has(part):
		return false
	var v := vehicle_by_uid(uid)
	if v.is_empty():
		return false
	var tiers: Array = Data.UPGRADES[part]["levels"]
	var cur: int = int(v.get(part, 0))
	if cur >= tiers.size() - 1:
		toast.emit("已经是最高等级了", "warn")
		return false
	var nxt: Dictionary = tiers[cur + 1]
	if not try_spend(int(nxt["cost"]), "改装 · %s" % nxt["name"]):
		return false
	v[part] = cur + 1
	vehicles_changed.emit()
	toast.emit("%s 升级为「%s」" % [Data.UPGRADES[part]["name"], nxt["name"]], "ok")
	return true


func paint_vehicle(uid: int, paint_index: int) -> bool:
	if paint_index < 0 or paint_index >= Data.PAINTS.size():
		return false
	var v := vehicle_by_uid(uid)
	if v.is_empty():
		return false
	var p: Dictionary = Data.PAINTS[paint_index]
	if not try_spend(int(p["cost"]), "喷漆 · %s" % p["name"]):
		return false
	v["paint"] = p["color"]
	vehicles_changed.emit()
	toast.emit("车身已喷涂为「%s」" % p["name"], "ok")
	return true


func vehicle_stats(v: Dictionary) -> Dictionary:
	var base: Dictionary = _find(Data.VEHICLES, v["type"])
	if base.is_empty():
		return {"top": 20.0, "accel": 6.0, "grip": 1.0}
	var eb: float = Data.UPGRADES["engine"]["levels"][int(v.get("engine", 0))]["bonus"]
	var tb: float = Data.UPGRADES["tires"]["levels"][int(v.get("tires", 0))]["bonus"]
	return {
		"top": float(base["top"]) * (1.0 + eb),
		"accel": float(base["accel"]) * (1.0 + eb * 0.8),
		"grip": float(base["grip"]) * (1.0 + tb),
		"size": base["size"],
	}


# ═══════════════ 任务 ═══════════════
func active_missions() -> Array:
	return missions


func accept_mission(type_id: String) -> Dictionary:
	if not Data.MISSION_TYPES.has(type_id):
		return {}
	var tpl: Dictionary = Data.MISSION_TYPES[type_id]
	if tpl["job"] != job:
		toast.emit("当前职业无法接取该任务", "error")
		return {}
	for m in missions:
		if m["type"] == type_id and not m.get("delivered", false):
			toast.emit("该类型的任务已在进行中", "warn")
			return {}
	_mission_seq += 1
	var target := _pick_mission_target(type_id)
	var extra: Dictionary = {}
	if type_id == "patrol":
		var pts := [
			Data.cell_center(Vector2i(1, 1)) + Vector3(0, 0, 19),
			Data.cell_center(Vector2i(3, 2)) + Vector3(0, 0, 17),
			Data.cell_center(Vector2i(0, 3)) + Vector3(0, 0, 17),
		]
		target = pts[0]
		extra["targets"] = pts
	var need := 1
	match type_id:
		"patrol":
			need = 3
		"capture":
			need = 1
	var m := {
		"id": _mission_seq,
		"type": type_id,
		"title": tpl["name"],
		"reward": int(tpl["reward"]),
		"heat": float(tpl["heat"]),
		"target": target,
		"progress": 0.0,
		"need": need,
		"meta": {},
	}
	m.merge(extra, true)
	missions.append(m)
	missions_changed.emit()
	toast.emit("已接取任务：%s（$%d）" % [m["title"], m["reward"]], "ok")
	if world and world.has_method("spawn_mission"):
		world.spawn_mission(m)
	return m


func _pick_mission_target(type_id: String) -> Vector3:
	match type_id:
		"patrol":
			var pts := [
				Data.cell_center(Vector2i(1, 1)) + Vector3(0, 0, 14),
				Data.cell_center(Vector2i(3, 2)) + Vector3(0, 0, 14),
				Data.cell_center(Vector2i(0, 3)) + Vector3(0, 0, 14),
			]
			return pts[randi() % pts.size()]
		"rob":
			return places.get("mart", Vector3.ZERO) + Vector3(0, 0, 2)
		_:
			# 生成在街区外沿的人行道上，避开建筑与树木
			var cells := [Vector2i(0, 3), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 1), Vector2i(2, 2)]
			var c: Vector2i = cells[randi() % cells.size()]
			var base := Data.cell_center(c)
			var dirs := [Vector3(19, 0, 0), Vector3(-19, 0, 0), Vector3(0, 0, 19), Vector3(0, 0, -19)]
			var d: Vector3 = dirs[randi() % dirs.size()]
			return base + d + Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, 2.0))


func mission_progress(mid: int, amount: float) -> void:
	if amount <= 0.0 or not is_finite(amount):
		return
	for m in missions:
		if int(m["id"]) != mid:
			continue
		m["progress"] = float(m["progress"]) + amount
		if float(m["progress"]) >= float(m["need"]):
			_complete_mission(m)
		else:
			missions_changed.emit()
		return


func complete_mission(mid: int) -> void:
	for m in missions:
		if int(m["id"]) == mid:
			_complete_mission(m)
			return


func _complete_mission(m: Dictionary) -> void:
	if m.get("delivered", false):
		return
	m["delivered"] = true
	add_cash(int(m["reward"]), "任务完成 · %s" % m["title"])
	if float(m["heat"]) > 0.0:
		add_heat(float(m["heat"]))
	stats["missions_done"] = int(stats["missions_done"]) + 1
	match m["type"]:
		"arrest":
			stats["arrests"] = int(stats["arrests"]) + 1
		"fire":
			stats["fires"] = int(stats["fires"]) + 1
		"heal":
			stats["heals"] = int(stats["heals"]) + 1
	missions.erase(m)
	missions_changed.emit()
	if world and world.has_method("clear_mission_entity"):
		world.clear_mission_entity(m)


func abandon_mission(mid: int) -> void:
	for m in missions:
		if int(m["id"]) == mid:
			missions.erase(m)
			missions_changed.emit()
			if world and world.has_method("clear_mission_entity"):
				world.clear_mission_entity(m)
			toast.emit("已放弃任务", "warn")
			return


# ═══════════════ 通缉度 ═══════════════
func add_heat(x: float) -> void:
	heat = clampf(heat + x, 0.0, 5.0)
	heat_changed.emit()
	if heat >= 3.0:
		toast.emit("通缉度上升！警察开始注意你了", "error")
	elif heat > 0.0:
		toast.emit("通缉度 +%.1f" % x, "warn")


func clear_heat() -> void:
	if heat <= 0.0:
		return
	var fine := int(heat * 220)
	if not try_spend(fine, "缴纳罚款"):
		return
	heat = 0.0
	heat_changed.emit()
	toast.emit("已缴纳罚款 $%d，通缉解除" % fine, "money")


# ═══════════════ 地点注册 ═══════════════
func register_place(id: String, door: Vector3) -> void:
	places[id] = door


func place_pos(id: String) -> Vector3:
	return places.get(id, Vector3.ZERO)


# ═══════════════ 工具 ═══════════════
func _find(arr: Array, id: String) -> Dictionary:
	for d in arr:
		if d.get("id", "") == id:
			return d
	return {}


func job_info() -> Dictionary:
	return Data.JOBS.get(job, Data.JOBS["unemployed"])


func reset_new_game() -> void:
	cash = Data.START_CASH
	bank = 0
	job = "unemployed"
	gang = ""
	health = 100.0
	stamina = 100.0
	heat = 0.0
	day = 1
	clock = Data.START_HOUR / 24.0 * Data.DAY_LENGTH
	properties.clear()
	vehicles.clear()
	weapons_owned.clear()
	weapon = ""
	weapon_ammo.clear()
	player_state = {"position": Vector3(2, 0.3, 14), "yaw": 0.0, "pitch": 0.0}
	_mission_seq = 0
	active_vehicle = -1
	shops.clear()
	missions.clear()
	stats = {"missions_done": 0, "earned": 0, "arrests": 0, "fires": 0, "heals": 0}
	cash_changed.emit()
	job_changed.emit()


func snapshot() -> Dictionary:
	if is_instance_valid(world) and world.has_method("capture_state"):
		world.capture_state()
	return {
		"cash": cash, "bank": bank, "job": job, "gang": gang, "health": health,
		"stamina": stamina, "heat": heat, "day": day, "clock": clock,
		"properties": properties.duplicate(true), "vehicles": vehicles.duplicate(true),
		"shops": shops.duplicate(true), "missions": missions.duplicate(true),
		"weapons_owned": weapons_owned.duplicate(true), "weapon": weapon,
		"weapon_ammo": weapon_ammo.duplicate(true), "stats": stats.duplicate(true),
		"player_state": player_state.duplicate(true), "mission_seq": _mission_seq,
	}


func save_game(notify := true) -> bool:
	var state := snapshot()
	if not SaveValidation.valid(state):
		if notify:
			toast.emit("保存失败：当前状态未通过校验", "error")
		return false
	var err := SaveStore.write(save_path, state)
	if notify or err != OK:
		toast.emit("游戏已保存" if err == OK else "保存失败：%s" % error_string(err), "ok" if err == OK else "error")
	return err == OK


func load_game(notify := true) -> bool:
	var state := SaveStore.read(save_path)
	var recovered := false
	if not SaveValidation.valid(state):
		state = SaveStore.read(save_path + ".bak")
		recovered = true
	if not SaveValidation.valid(state):
		if notify:
			toast.emit("没有可读取的有效存档，当前游戏保持不变", "warn")
		return false
	for key in ["cash", "bank", "job", "gang", "health", "stamina", "heat", "day", "clock", "properties", "vehicles", "shops", "missions", "weapons_owned", "weapon", "weapon_ammo", "stats", "player_state"]:
		set(key, state[key])
	_mission_seq = int(state["mission_seq"])
	active_vehicle = -1
	_decay_shop_rent()
	if notify or recovered:
		toast.emit("已从备份存档恢复" if recovered else "存档已读取", "ok")
	return true
