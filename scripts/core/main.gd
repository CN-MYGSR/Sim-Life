extends Node3D
## 主控：环境 / 城市 / 玩家 / UI / 任务生成 / 装修 / 昼夜

var player: Player
var hud: HUD
var tablet: Tablet
var builder: WorldBuilder
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial

var vehicles_root: Node3D
var npc_root: Node3D
var missions_root: Node3D
var decor_root: Node3D
var bank_layer: CanvasLayer
var decor_ui = null

var _env_t: float = 0.0
var _decorating: bool = false
var _decor_prop: String = ""
var _debug_mode: bool = false

# 店铺经营
var _biz_active: bool = false
var _biz_shop: String = ""
var _biz_timer: float = 0.0
var _biz_total: float = 8.0
var _biz_cd: float = 0.0

const PED_COLORS := [
	Color(0.62, 0.30, 0.28), Color(0.30, 0.42, 0.58), Color(0.45, 0.45, 0.40),
	Color(0.70, 0.62, 0.36), Color(0.35, 0.50, 0.40), Color(0.55, 0.40, 0.55),
	Color(0.80, 0.78, 0.74), Color(0.25, 0.30, 0.36),
]


func _ready() -> void:
	Game.world = self
	randomize()
	_setup_env()

	vehicles_root = Node3D.new()
	vehicles_root.name = "Vehicles"
	add_child(vehicles_root)
	npc_root = Node3D.new()
	npc_root.name = "NPCs"
	add_child(npc_root)
	missions_root = Node3D.new()
	missions_root.name = "Missions"
	add_child(missions_root)
	decor_root = Node3D.new()
	decor_root.name = "Furniture"
	add_child(decor_root)

	builder = WorldBuilder.new()
	add_child(builder)
	builder.build(self, self)

	_spawn_player()

	hud = HUD.new()
	add_child(hud)
	tablet = Tablet.new()
	add_child(tablet)

	Game.vehicles_changed.connect(_on_vehicles_changed)
	Game.missions_changed.connect(_on_missions_changed)

	spawn_ambient_npcs()
	refresh_vehicles()
	_intro()
	_handle_debug()


# ═══════════════ 调试截图 ═══════════════
func _handle_debug() -> void:
	var args := OS.get_cmdline_user_args()
	var shot := ""
	var delay := 2.5
	var at := Vector3.INF
	var yaw := 0.0
	for a in args:
		if a.begins_with("--shot="):
			shot = a.substr(7)
		elif a.begins_with("--delay="):
			delay = float(a.substr(8))
		elif a.begins_with("--at="):
			var parts := a.substr(5).split(",")
			if parts.size() >= 2:
				at = Vector3(float(parts[0]), 0.3, float(parts[1]))
			if parts.size() >= 3:
				yaw = float(parts[2])
		elif a.begins_with("--job="):
			Game.set_job(a.substr(6))
		elif a.begins_with("--page="):
			var pg := a.substr(7)
			tablet.open(pg)
		elif a.begins_with("--time="):
			Game.clock = float(a.substr(7)) / 24.0 * Data.DAY_LENGTH
		elif a == "--topview":
			var tc := Camera3D.new()
			add_child(tc)
			tc.position = Vector3(0, 185, 105)
			tc.look_at(Vector3(0, 0, 6))
			tc.fov = 58.0
			tc.far = 800.0
			tc.current = true
			player.set_physics_process(false)
			player.visible = false
	if at != Vector3.INF:
		player.teleport(at)
		player.rotation.y = yaw
	for a in args:
		if a.begins_with("--test="):
			_run_test(a.substr(7))
	if shot != "":
		# 截图模式：释放鼠标并屏蔽输入，避免焦点变化导致视角乱转 / 误开界面
		_debug_mode = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_screenshot_after(shot, delay)


func _run_test(name: String) -> void:
	await get_tree().create_timer(0.6).timeout
	match name:
		"arrest":
			Game.set_job("police")
			Game.add_cash(6000, "")
			var m: Dictionary = Game.accept_mission("arrest")
			await get_tree().create_timer(0.4).timeout
			if not m.is_empty():
				var t: Vector3 = m["target"]
				player.teleport(t + Vector3(0, 0.2, 6.5))
				player.rotation.y = 0.0
				player.head.rotation.x = -0.08
		"fire":
			Game.set_job("firefighter")
			var m2: Dictionary = Game.accept_mission("fire")
			await get_tree().create_timer(0.4).timeout
			if not m2.is_empty():
				var t2: Vector3 = Data.cell_center(Vector2i(1, 2))
				for c in missions_root.get_children():
					if c is MissionTarget:
						c.global_position = t2
				player.teleport(t2 + Vector3(0, 0.3, 12.0))
				player.rotation.y = 0.0
				print("FIRE_TEST player=", player.global_position, " target=", t2)
		"drive":
			Game.add_cash(30000, "")
			Game.buy_vehicle("sedan")
			await get_tree().create_timer(0.6).timeout
			var veh: Vehicle = null
			for c in vehicles_root.get_children():
				if c is Vehicle:
					veh = c
					break
			if veh == null:
				print("TEST_FAIL no vehicle")
				return
			veh.enter(player)
			var p0 := veh.global_position
			Input.action_press("move_forward")
			await get_tree().create_timer(2.6).timeout
			Input.action_release("move_forward")
			await get_tree().create_timer(0.3).timeout
			print("TEST_DRIVE from=", p0, " to=", veh.global_position, " speed=", veh.speed)
		"decorate":
			Game.add_cash(60000, "")
			Game.buy_property("apt201")
			var pc := Data.cell_center(Vector2i(3, 1)) + Vector3(-12, 0, -6)
			player.teleport(pc + Vector3(0, 0.3, 3.0))
			await get_tree().create_timer(0.5).timeout
			enter_decorate("apt201")
			await get_tree().create_timer(0.4).timeout
			place_furniture("sofa")
			await get_tree().create_timer(0.25).timeout
			place_furniture("rug")
			await get_tree().create_timer(0.25).timeout
			place_furniture("tv")
			await get_tree().create_timer(0.3).timeout
			print("TEST_FURN count=", Game.properties["apt201"]["furniture"].size())
		"shop":
			Game.add_cash(40000, "")
			Game.rent_shop("diner")
			Game.set_job("chef")
			var dc := Data.cell_center(Vector2i(3, 0))
			player.teleport(dc + Vector3(0, 0.3, 22.0))
			player.rotation.y = 0.0
			print("DBG shop player=", player.global_position, " rot=", player.rotation.y, " diner=", dc)
		"full":
			# 端到端：接警察任务 → 靠近目标 → 按住 E → 校验结算
			Game.set_job("police")
			var mm: Dictionary = Game.accept_mission("arrest")
			await get_tree().create_timer(0.5).timeout
			if mm.is_empty():
				print("TEST_FAIL no mission")
				return
			var tt: Vector3 = mm["target"]
			player.teleport(tt + Vector3(0, 0.2, 3.0))
			await get_tree().create_timer(0.8).timeout
			print("TEST_BEFORE cash=", Game.cash, " missions=", Game.missions.size())
			Input.action_press("interact")
			await get_tree().create_timer(3.0).timeout
			Input.action_release("interact")
			await get_tree().create_timer(0.4).timeout
			print("TEST_AFTER cash=", Game.cash, " missions=", Game.missions.size(), " done=", Game.stats["missions_done"])
		"biz":
			Game.add_cash(40000, "")
			Game.rent_shop("diner")
			Game.set_job("chef")
			var bc := Data.cell_center(Vector2i(3, 0))
			player.teleport(bc + Vector3(0, 0.3, 14.0))
			player.rotation.y = 0.0
			await get_tree().create_timer(0.8).timeout
			_start_business("diner")
			await get_tree().create_timer(9.0).timeout
			print("BIZ cash=", Game.cash)
		"climb2":
			# 逐跑验证每一跑楼梯（警察局 3 层 + 医院 4 层）
			Game.set_job("police")
			for id in ["police", "hospital"]:
				for kb in builder.kit_buildings:
					if str(kb.place.get("id", "")) != id:
						continue
					var base: Vector3 = kb.global_position
					var sx1: float = kb.stair_x0 + 1.0
					var sx2: float = kb.stair_x0 + 3.0
					var z0: float = kb.stair_z0
					var z1: float = z0 + 4.0
					for f in range(1, kb.floors - 1):
						var by: float = 3.0 * f
						if f % 2 == 1:
							player.teleport(base + Vector3(sx2, by + 0.3, z0 - 1.2))
							player.rotation.y = PI
						else:
							player.teleport(base + Vector3(sx1, by + 0.3, z1 + 0.7))
							player.rotation.y = 0.0
						await _walk_forward(4.5)
						print("CLIMB2 ", id, " flight=", f, " y=", snappedf(player.global_position.y, 0.1))
		"walk":
			# 走进警局大门 → 到楼梯口 → 上楼
			Game.set_job("police")
			var pc := Data.cell_center(Vector2i(0, 0))
			player.teleport(pc + Vector3(0, 0.3, 12.2))
			player.rotation.y = 0.0
			await _walk_forward(2.6)
			print("WALK_DOOR pos=", player.global_position)
			player.teleport(pc + Vector3(30.0 * 0.5 - 4.25 + 1.0, 0.3, 20.0 * 0.5 - 5.75 + 4.7))
			player.rotation.y = 0.0
			await _walk_forward(5.0)
			print("WALK_STAIRS pos=", player.global_position)
		"climball":
			# 逐个建筑验证：能进门 + 能上到二层
			Game.set_job("police")
			for kb in builder.kit_buildings:
				var base: Vector3 = kb.global_position
				var dhalf: float = kb.d * 0.5
				player.teleport(base + Vector3(0, 0.3, dhalf + 2.4))
				player.rotation.y = 0.0
				await _walk_forward(2.2)
				var inside: bool = player.global_position.z < base.z + dhalf - 1.5
				var sx: float = kb.stair_x0 + 1.0
				var z_low: float = kb.stair_z0 + 4.0
				player.teleport(base + Vector3(sx, 0.3, z_low + 0.7))
				player.rotation.y = 0.0
				await _walk_forward(4.5)
				print("CLIMB ", kb.kind, " id=", kb.place.get("id", ""), " inside=", inside, " y=", snappedf(player.global_position.y, 0.1))
		"tour":
			Game.set_job("police")
			var tc := Data.cell_center(Vector2i(0, 0))
			player.teleport(tc + Vector3(0, 0.3, 12.2))
			player.rotation.y = 0.0
			for i in range(6):
				await _walk_forward(0.8)
				print("TOUR ", i, " pos=", player.global_position)
				await _shot_now("D:/Sim Life/shots/tour_%d.png" % i)
			# 楼梯
			player.teleport(tc + Vector3(30.0 * 0.5 - 4.25 + 1.0, 0.3, 20.0 * 0.5 - 5.75 + 4.7))
			player.rotation.y = 0.0
			for i in range(8):
				await _walk_forward(0.9)
				print("STAIR ", i, " pos=", player.global_position)
				await _shot_now("D:/Sim Life/shots/tour_s%d.png" % i)
		"fire_done":
			await _test_hold("firefighter", "fire", 3.8)
		"heal_done":
			await _test_hold("doctor", "heal", 4.0)
		"patrol_done":
			Game.set_job("police")
			var pm: Dictionary = Game.accept_mission("patrol")
			await get_tree().create_timer(0.5).timeout
			if pm.is_empty():
				print("TEST_FAIL patrol")
				return
			print("BEFORE patrol cash=", Game.cash)
			var pts: Array = pm.get("targets", [])
			for p in pts:
				player.teleport(p + Vector3(0, 0.2, 1.5))
				await get_tree().create_timer(0.9).timeout
			await get_tree().create_timer(0.4).timeout
			print("AFTER patrol cash=", Game.cash, " done=", Game.stats["missions_done"])
		"capture_done":
			await _test_hold("gangster", "capture", 9.5)


func _walk_forward(sec: float) -> void:
	Input.action_press("move_forward")
	await get_tree().create_timer(sec).timeout
	Input.action_release("move_forward")
	await get_tree().create_timer(0.25).timeout


func _shot_now(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)


func _test_hold(job_id: String, mtype: String, hold_sec: float) -> void:
	Game.set_job(job_id)
	var m: Dictionary = Game.accept_mission(mtype)
	await get_tree().create_timer(0.5).timeout
	if m.is_empty():
		print("TEST_FAIL ", mtype)
		return
	var t: Vector3 = m["target"]
	player.teleport(t + Vector3(0, 0.2, 2.2))
	await get_tree().create_timer(0.6).timeout
	print("BEFORE ", mtype, " cash=", Game.cash, " heat=", Game.heat)
	Input.action_press("interact")
	await get_tree().create_timer(hold_sec).timeout
	Input.action_release("interact")
	await get_tree().create_timer(0.5).timeout
	print("AFTER ", mtype, " cash=", Game.cash, " heat=", Game.heat, " done=", Game.stats["missions_done"])


func _screenshot_after(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	if is_instance_valid(player) and is_instance_valid(player.cam):
		print("DBG camdir=", -player.cam.global_transform.basis.z, " yaw=", player.rotation.y, " pos=", player.global_position)
		print("DBG camworld=", player.cam.global_position, " camcurrent=", player.cam.current, " vp=", get_viewport().get_visible_rect().size)
		print("DBG FPS=", Engine.get_frames_per_second())
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT_SAVED: ", path)
	get_tree().quit()


# ═══════════════ 环境 ═══════════════
func _setup_env() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.28, 0.46, 0.74)
	sky_mat.sky_horizon_color = Color(0.76, 0.82, 0.88)
	sky_mat.ground_bottom_color = Color(0.13, 0.15, 0.17)
	sky_mat.ground_horizon_color = Color(0.52, 0.57, 0.62)
	sky_mat.sun_angle_max = 18.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.fog_enabled = true
	env.fog_light_color = Color(0.66, 0.73, 0.82)
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.25
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_bias = 0.03
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.5
	add_child(sun)


func _process(delta: float) -> void:
	_update_business(delta)
	_env_t += delta
	if _env_t < 0.12:
		return
	_env_t = 0.0
	_update_sky()


# ═══════════════ 店铺经营 ═══════════════
func _update_business(delta: float) -> void:
	if _biz_cd > 0.0:
		_biz_cd = maxf(0.0, _biz_cd - delta)
	if not _biz_active:
		return
	_biz_timer -= delta
	var p := 1.0 - clampf(_biz_timer / _biz_total, 0.0, 1.0)
	if Game.hud:
		Game.hud.set_hold(true, p, "营业中 · 顾客上门")
	if _biz_timer <= 0.0:
		_finish_business()


func _start_business(shop_id: String) -> void:
	if _biz_active:
		Game.toast.emit("已经在营业了", "warn")
		return
	if _biz_cd > 0.0:
		Game.toast.emit("客流还没回来，等 %d 秒" % int(_biz_cd), "warn")
		return
	_biz_active = true
	_biz_shop = shop_id
	_biz_total = 8.0
	_biz_timer = 8.0
	var nm := "店铺"
	for s in Data.SHOPS:
		if s["id"] == shop_id:
			nm = s["name"]
	Game.toast.emit("「%s」开门营业！" % nm, "ok")
	_spawn_customers(shop_id)


func _spawn_customers(shop_id: String) -> void:
	var door: Vector3 = Game.place_pos(shop_id)
	var count := 4 if shop_id == "diner" else 5
	for i in range(count):
		var ang := randf() * TAU
		var pos := door + Vector3(cos(ang) * 7.0, 0.2, sin(ang) * 7.0 + 5.0)
		var c: Color = PED_COLORS[randi() % PED_COLORS.size()]
		NPC.spawn(npc_root, pos, "customer", c)


func _finish_business() -> void:
	_biz_active = false
	if Game.hud:
		Game.hud.set_hold(false, 0.0, "")
	var income := 0
	if _biz_shop == "diner":
		income = randi_range(430, 690)
	else:
		income = randi_range(300, 520)
	Game.add_cash(income, "营业收入")
	_biz_cd = 22.0
	Game.toast.emit("打烊结算，进账 $%d" % income, "money")


func _update_sky() -> void:
	var hour := Game.get_hour()
	var day_f := clampf(sin((hour - 6.0) / 24.0 * TAU), 0.0, 1.0)
	var noon_f := clampf(1.0 - absf(hour - 12.0) / 6.5, 0.0, 1.0)

	var ang := (hour - 6.0) / 12.0 * 180.0
	sun.rotation_degrees = Vector3(-ang, -35.0, 0.0)
	sun.light_energy = 0.06 + day_f * 1.65
	var warm := noon_f
	sun.light_color = Color(1.0, 0.94 + warm * 0.05, 0.86 + warm * 0.12)
	sun.visible = day_f > 0.02

	sky_mat.sky_top_color = Color(0.055, 0.075, 0.15).lerp(Color(0.30, 0.50, 0.80), day_f)
	sky_mat.sky_horizon_color = Color(0.10, 0.12, 0.19).lerp(Color(0.78, 0.84, 0.90), day_f)
	sky_mat.ground_bottom_color = Color(0.03, 0.035, 0.05).lerp(Color(0.16, 0.17, 0.19), day_f)

	env.ambient_light_energy = 0.30 + day_f * 0.78
	env.fog_density = 0.0014 + (1.0 - day_f) * 0.0026
	env.fog_light_color = Color(0.10, 0.12, 0.18).lerp(Color(0.66, 0.73, 0.82), day_f)

	if builder:
		builder.set_night(clampf(1.0 - day_f * 1.6, 0.0, 1.0))


# ═══════════════ 玩家 ═══════════════
func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.position = Vector3(2, 0.3, 14)
	add_child(player)
	Game.player = player
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _intro() -> void:
	await get_tree().create_timer(0.8).timeout
	Game.toast.emit("欢迎来到这座城市。按 TAB 打开平板。", "ok")
	await get_tree().create_timer(4.2).timeout
	Game.toast.emit("先去「职业中心」找份工作，再去接任务赚钱。", "")


# ═══════════════ 环境 NPC ═══════════════
func spawn_ambient_npcs() -> void:
	for i in range(16):
		var cell := Vector2i(randi() % Data.GRID, randi() % Data.GRID)
		var c := Data.cell_center(cell)
		var a := randf() * TAU
		var r := randf_range(18.0, 21.0)
		var pos := c + Vector3(cos(a) * r, 0.15, sin(a) * r)
		var col: Color = PED_COLORS[randi() % PED_COLORS.size()]
		NPC.spawn(npc_root, pos, "pedestrian", col)


# ═══════════════ 车辆 ═══════════════
func _on_vehicles_changed() -> void:
	refresh_vehicles()


func refresh_vehicles() -> void:
	for c in vehicles_root.get_children():
		vehicles_root.remove_child(c)
		c.queue_free()
	var base := Data.cell_center(Vector2i(2, 3))
	var i := 0
	for v in Game.vehicles:
		var veh := Vehicle.new()
		veh.position = base + Vector3(-13.0 + i * 6.5, 0.2, -10.0)
		vehicles_root.add_child(veh)
		veh.setup(int(v["uid"]), v)
		veh.add_to_group("player_vehicle")
		i += 1


# ═══════════════ 任务 ═══════════════
func spawn_mission(m: Dictionary) -> void:
	if str(m["type"]) == "patrol":
		var pts: Array = m.get("targets", [m["target"]])
		for p in pts:
			var mt := MissionTarget.new()
			missions_root.add_child(mt)
			var mm := m.duplicate(true)
			mm["target"] = p
			mt.setup(mm)
		return
	var mt2 := MissionTarget.new()
	missions_root.add_child(mt2)
	mt2.setup(m)


func clear_mission_entity(m: Dictionary) -> void:
	for c in missions_root.get_children():
		if c is MissionTarget and int(c.mid) == int(m["id"]):
			if not c.is_queued_for_deletion():
				c.queue_free()


func _on_missions_changed() -> void:
	pass


# ═══════════════ 输入 ═══════════════
func _unhandled_input(event: InputEvent) -> void:
	if _debug_mode:
		return
	if event.is_action_pressed("tablet"):
		if is_instance_valid(tablet):
			tablet.toggle()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("decorate") and not _decorating:
		if is_instance_valid(tablet) and tablet.visible:
			return
		_try_decorate()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("cancel"):
		if is_instance_valid(tablet) and tablet.visible:
			return
		if _decorating:
			return
		_toggle_pause()
		get_viewport().set_input_as_handled()


# ═══════════════ 暂停菜单 ═══════════════
var pause_layer: CanvasLayer = null


func _toggle_pause() -> void:
	if is_instance_valid(pause_layer):
		_close_pause()
		return
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 30
	add_child(pause_layer)

	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.theme = Game.get_theme_res()
	pause_layer.add_child(c)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.055, 0.065, 0.085)
	ps.set_corner_radius_all(16)
	ps.border_color = Color(0.28, 0.32, 0.38)
	ps.set_border_width_all(2)
	ps.content_margin_left = 28
	ps.content_margin_right = 28
	ps.content_margin_top = 26
	ps.content_margin_bottom = 26
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var t := Label.new()
	t.text = "已暂停"
	t.add_theme_font_size_override("font_size", 26)
	v.add_child(t)

	var info := Label.new()
	info.text = "%s　·　现金 $%s　·　职业 %s" % [Game.get_time_string(), _fmt(Game.cash), Game.job_info().get("name", "")]
	info.add_theme_font_size_override("font_size", 13)
	info.add_theme_color_override("font_color", Data.C_DIM)
	v.add_child(info)

	var sep := HSeparator.new()
	v.add_child(sep)

	v.add_child(_mk_btn("继续游戏", func(): _close_pause(), "primary"))
	v.add_child(_mk_btn("退出到桌面", func(): get_tree().quit(), "normal"))

	var hint := Label.new()
	hint.text = "WASD 移动 · Shift 奔跑 · E 交互 · TAB 平板 · B 装修"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.4, 0.43, 0.47))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(hint)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.in_ui = true


func _close_pause() -> void:
	if is_instance_valid(pause_layer):
		pause_layer.queue_free()
		pause_layer = null
	if is_instance_valid(player):
		player.in_ui = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _try_decorate() -> void:
	var pid := _property_at(Game.player.global_position)
	if pid == "":
		Game.toast.emit("要装修请先走进自己的房子里", "warn")
		return
	if not Game.owns_property(pid):
		Game.toast.emit("这套房子还不属于你", "warn")
		return
	enter_decorate(pid)


func _property_at(pos: Vector3) -> String:
	for p in Data.PROPERTIES:
		var c: Vector3 = Data.cell_center(p["cell"]) + p["offset"]
		var sz: Vector2 = p["size"]
		if absf(pos.x - c.x) < sz.x * 0.5 + 0.4 and absf(pos.z - c.z) < sz.y * 0.5 + 0.4:
			return p["id"]
	return ""


# ═══════════════ 装修 ═══════════════
func enter_decorate(pid: String) -> void:
	if _decorating:
		return
	_decorating = true
	_decor_prop = pid
	player.decor_mode = true
	player.in_ui = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rebuild_furniture()
	decor_ui = DecorateUI.new()
	add_child(decor_ui)
	decor_ui.closed.connect(exit_decorate)
	decor_ui.setup(pid, self)


func exit_decorate() -> void:
	if not _decorating:
		return
	_decorating = false
	_decor_prop = ""
	player.decor_mode = false
	player.in_ui = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(decor_ui):
		decor_ui.queue_free()
		decor_ui = null


func _rebuild_furniture() -> void:
	for c in decor_root.get_children():
		decor_root.remove_child(c)
		c.queue_free()
	if _decor_prop == "" or not Game.properties.has(_decor_prop):
		return
	for f in Game.properties[_decor_prop]["furniture"]:
		var fd := {}
		for d in Data.FURNITURE:
			if d["id"] == f["id"]:
				fd = d
				break
		if fd.is_empty():
			continue
		var node := make_furniture(fd, f["pos"], f["rot"])
		decor_root.add_child(node)


func place_furniture(furn_id: String) -> void:
	var fd := {}
	for d in Data.FURNITURE:
		if d["id"] == furn_id:
			fd = d
			break
	if fd.is_empty():
		return
	if not Game.try_spend(int(fd["price"]), "购买家具 · %s" % fd["name"]):
		return
	# 放在玩家正前方，被占用则向右顺延
	var fwd := -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := player.global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var pos := player.global_position + fwd * 3.2
	var arr: Array = Game.properties[_decor_prop]["furniture"]
	var offs := [0.0, 1.8, -1.8, 3.6, -3.6, 5.4, -5.4, 7.2]
	for o in offs:
		pos = player.global_position + fwd * 3.2 + right * float(o)
		var blocked := false
		for f in arr:
			var fp: Vector3 = f["pos"]
			if Vector2(fp.x - pos.x, fp.z - pos.z).length() < 1.7:
				blocked = true
				break
		if not blocked:
			break
	pos.y = _floor_y_for(pos)
	var rot := player.rotation.y
	Game.add_furniture(_decor_prop, furn_id, pos, rot)
	_rebuild_furniture()
	if is_instance_valid(decor_ui) and decor_ui.has_method("_refresh_owned"):
		decor_ui._refresh_owned()
	Game.toast.emit("已摆放「%s」" % fd["name"], "ok")


func _floor_y_for(pos: Vector3) -> float:
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 3, 0), pos + Vector3(0, -1, 0))
	q.collision_mask = 1
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return 0.0
	return float(hit["position"].y)


func remove_furniture_at(index: int) -> void:
	Game.remove_furniture(_decor_prop, index)
	_rebuild_furniture()
	if is_instance_valid(decor_ui) and decor_ui.has_method("_refresh_owned"):
		decor_ui._refresh_owned()


func make_furniture(fd: Dictionary, pos: Vector3, rot_y: float) -> Node3D:
	var g := Node3D.new()
	g.position = pos
	g.rotation.y = rot_y
	var base_col: Color = fd["color"]
	for part in fd["parts"]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part["size"]
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = part.get("color", base_col)
		m.roughness = 0.88
		# 电视屏幕给一点自发光，别是死黑
		if str(fd["id"]) == "tv" and part["size"].x > 1.0:
			m.albedo_color = Color(0.05, 0.07, 0.10)
			m.emission_enabled = true
			m.emission = Color(0.14, 0.22, 0.34)
			m.emission_energy_multiplier = 1.2
			m.roughness = 0.15
		mi.material_override = m
		mi.position = part["pos"]
		g.add_child(mi)
	var cs := StaticBody3D.new()
	cs.collision_layer = 1
	cs.collision_mask = 0
	var sh := BoxShape3D.new()
	var sz: Vector3 = fd["size"]
	sh.size = Vector3(sz.x, maxf(sz.y, 0.3), sz.z)
	var cshape := CollisionShape3D.new()
	cshape.shape = sh
	cshape.position.y = sz.y * 0.5
	cs.add_child(cshape)
	g.add_child(cs)
	return g


# ═══════════════ 交互回调 ═══════════════
func open_job_panel(job_id: String) -> void:
	if is_instance_valid(tablet):
		tablet.open("jobs")
	var nm := str(Data.JOBS.get(job_id, {}).get("name", ""))
	if Game.job != job_id:
		Game.toast.emit("在「职业中心」申请成为%s" % nm, "")


func open_shop_panel(shop_id: String) -> void:
	var need_job := ""
	for s in Data.SHOPS:
		if s["id"] == shop_id:
			need_job = str(s["job"])
	if Game.has_shop(shop_id) and Game.job == need_job:
		_start_business(shop_id)
		return
	if is_instance_valid(tablet):
		tablet.open("shops")
	if not Game.has_shop(shop_id):
		Game.toast.emit("这里还没租下来，去「店铺」页看看", "")
	else:
		Game.toast.emit("需要转职为%s才能在这里营业" % str(Data.JOBS.get(need_job, {}).get("name", "")), "warn")


func open_vehicle_panel() -> void:
	if is_instance_valid(tablet):
		tablet.open("vehicles")


func open_gang_panel() -> void:
	if is_instance_valid(tablet):
		tablet.open("gang")


func rest_at_park() -> void:
	Game.stamina = 100.0
	Game.health = minf(100.0, Game.health + 20.0)
	Game.toast.emit("在长椅上歇了一会儿，体力恢复", "ok")


# ═══════════════ 银行 ═══════════════
func open_bank_panel() -> void:
	if is_instance_valid(bank_layer):
		return
	bank_layer = CanvasLayer.new()
	bank_layer.layer = 25
	add_child(bank_layer)

	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.theme = Game.get_theme_res()
	bank_layer.add_child(c)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.02, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 0)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.055, 0.065, 0.085)
	ps.set_corner_radius_all(14)
	ps.border_color = Color(0.28, 0.32, 0.38)
	ps.set_border_width_all(2)
	ps.content_margin_left = 24
	ps.content_margin_right = 24
	ps.content_margin_top = 20
	ps.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)

	var t := Label.new()
	t.text = "中城区银行"
	t.add_theme_font_size_override("font_size", 22)
	v.add_child(t)

	var l1 := Label.new()
	l1.text = "现金  $%s" % _fmt(Game.cash)
	l1.add_theme_color_override("font_color", Data.C_GOLD)
	l1.add_theme_font_size_override("font_size", 17)
	v.add_child(l1)

	var l2 := Label.new()
	l2.text = "存款  $%s" % _fmt(Game.bank)
	l2.add_theme_color_override("font_color", Data.C_TEAL)
	l2.add_theme_font_size_override("font_size", 17)
	v.add_child(l2)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)

	var b1 := _mk_btn("存 $500", func():
		_bank_tx(500, true), "primary")
	row.add_child(b1)
	var b2 := _mk_btn("存全部", func():
		_bank_tx(Game.cash, true), "ok")
	row.add_child(b2)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	v.add_child(row2)
	var b3 := _mk_btn("取 $500", func():
		_bank_tx(500, false), "primary")
	row2.add_child(b3)
	var b4 := _mk_btn("取全部", func():
		_bank_tx(Game.bank, false), "ok")
	row2.add_child(b4)

	var b5 := _mk_btn("关闭", func():
		_close_bank(), "normal")
	v.add_child(b5)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.in_ui = true


func _mk_btn(text: String, cb: Callable, kind: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 38)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := Color(0.15, 0.17, 0.21)
	match kind:
		"primary": bg = Data.C_ACCENT.darkened(0.42)
		"ok": bg = Color(0.08, 0.28, 0.22)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	b.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate()
	hov.bg_color = bg.lightened(0.15)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", sb)
	b.pressed.connect(cb)
	return b


func _bank_tx(amount: int, deposit: bool) -> void:
	if amount <= 0:
		return
	if deposit:
		if Game.cash < amount:
			Game.toast.emit("现金不足", "error")
			return
		Game.cash -= amount
		Game.bank += amount
		Game.cash_changed.emit()
		Game.toast.emit("存入 $%d" % amount, "money")
	else:
		if Game.bank < amount:
			Game.toast.emit("存款不足", "error")
			return
		Game.bank -= amount
		Game.cash += amount
		Game.cash_changed.emit()
		Game.toast.emit("取出 $%d" % amount, "money")
	_close_bank()
	open_bank_panel()


func _close_bank() -> void:
	if is_instance_valid(bank_layer):
		bank_layer.queue_free()
		bank_layer = null
	if is_instance_valid(player):
		player.in_ui = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out
