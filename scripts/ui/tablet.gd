extends CanvasLayer
class_name Tablet
## 平板电脑：地图 / 职业 / 任务 / 房产 / 店铺 / 车辆 / 帮派 / 档案

const PAGES := [
	{"id": "map", "name": "城市地图", "hint": "查看全城与任务点"},
	{"id": "jobs", "name": "职业中心", "hint": "申请与切换工作"},
	{"id": "missions", "name": "任务", "hint": "接取与追踪"},
	{"id": "property", "name": "房产", "hint": "购买与装修"},
	{"id": "shops", "name": "店铺", "hint": "租赁使用权"},
	{"id": "vehicles", "name": "车辆", "hint": "购买与改装"},
	{"id": "weapons", "name": "武器", "hint": "购枪与装备"},
	{"id": "gang", "name": "帮派", "hint": "加入与接活"},
	{"id": "stats", "name": "档案", "hint": "生涯统计"},
]

var root: Control
var panel: PanelContainer
var sidebar: VBoxContainer
var content: VBoxContainer
var current_page: String = "map"
var nav: Dictionary = {}
var expanded_vehicle: int = -1
var _cash_label: Label
var _job_label: Label


func _ready() -> void:
	layer = 20
	Game.tablet = self
	_build()
	visible = false
	Game.job_changed.connect(_on_data_changed)
	Game.missions_changed.connect(_on_data_changed)
	Game.cash_changed.connect(_refresh_sidebar)
	Game.shops_changed.connect(_on_data_changed)
	Game.properties_changed.connect(_on_data_changed)
	Game.vehicles_changed.connect(_on_data_changed)
	Game.weapons_changed.connect(_on_data_changed)


func _on_data_changed() -> void:
	if visible:
		_rebuild()


func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = Game.get_theme_res()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.02, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(1120, 700)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.047, 0.055, 0.070)
	ps.set_corner_radius_all(18)
	ps.border_color = Color(0.24, 0.28, 0.34)
	ps.set_border_width_all(2)
	ps.shadow_color = Color(0, 0, 0, 0.55)
	ps.shadow_size = 26
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	panel.add_child(hb)

	# ── 侧栏 ──
	var side_bg := PanelContainer.new()
	side_bg.custom_minimum_size = Vector2(212, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.031, 0.039, 0.051)
	sb.corner_radius_top_left = 16
	sb.corner_radius_bottom_left = 16
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 20
	sb.content_margin_bottom = 16
	side_bg.add_theme_stylebox_override("panel", sb)
	hb.add_child(side_bg)

	sidebar = VBoxContainer.new()
	sidebar.add_theme_constant_override("separation", 5)
	side_bg.add_child(sidebar)

	var logo := Label.new()
	logo.text = "SIM LIFE"
	logo.add_theme_font_size_override("font_size", 22)
	logo.add_theme_color_override("font_color", Data.C_TEXT)
	sidebar.add_child(logo)

	var sub := Label.new()
	sub.text = "城市终端 v1.0"
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Data.C_DIM)
	sidebar.add_child(sub)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	sidebar.add_child(sp)

	for p in PAGES:
		var b := Button.new()
		b.text = p["name"]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 40)
		b.add_theme_font_size_override("font_size", 15)
		b.focus_mode = Control.FOCUS_NONE
		var id: String = p["id"]
		b.pressed.connect(func(): _show_page(id))
		sidebar.add_child(b)
		nav[id] = b

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(filler)

	var sep := HSeparator.new()
	sidebar.add_child(sep)

	_cash_label = Label.new()
	_cash_label.add_theme_font_size_override("font_size", 22)
	_cash_label.add_theme_color_override("font_color", Data.C_GOLD)
	sidebar.add_child(_cash_label)

	_job_label = Label.new()
	_job_label.add_theme_font_size_override("font_size", 13)
	_job_label.add_theme_color_override("font_color", Data.C_DIM)
	sidebar.add_child(_job_label)

	var hint := Label.new()
	hint.text = "TAB 关闭 · ESC 关闭"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.35, 0.38, 0.42))
	sidebar.add_child(hint)

	# ── 内容区 ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hb.add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	scroll.add_child(margin)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(content)


# ═══════════════ 开关 ═══════════════
func open(page: String = "") -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(Game.player):
		Game.player.in_ui = true
	if page != "":
		current_page = page
	_show_page(current_page)


func close() -> void:
	visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(Game.player):
		Game.player.in_ui = false


func toggle(page: String = "") -> void:
	if visible:
		close()
	else:
		open(page)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("cancel"):
		close()
		get_viewport().set_input_as_handled()


func _show_page(id: String) -> void:
	current_page = id
	expanded_vehicle = -1
	_update_nav()
	_refresh_sidebar()
	_rebuild()


func _update_nav() -> void:
	for k in nav.keys():
		var b: Button = nav[k] as Button
		var active: bool = str(k) == current_page
		var sb := StyleBoxFlat.new()
		sb.bg_color = Data.C_ACCENT.darkened(0.55) if active else Color(0, 0, 0, 0)
		sb.set_corner_radius_all(8)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		if active:
			sb.border_color = Data.C_ACCENT
			sb.border_width_left = 3
		b.add_theme_stylebox_override("normal", sb)
		var hov := sb.duplicate()
		if not active:
			hov.bg_color = Color(1, 1, 1, 0.05)
		b.add_theme_stylebox_override("hover", hov)
		b.add_theme_stylebox_override("pressed", hov)
		b.add_theme_color_override("font_color", Data.C_TEXT if active else Data.C_DIM)


func _refresh_sidebar() -> void:
	_cash_label.text = "$%s" % _fmt(Game.cash)
	_job_label.text = "职业：%s" % Game.job_info().get("name", "无业")


func _rebuild() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	_refresh_sidebar()
	match current_page:
		"map": _page_map()
		"jobs": _page_jobs()
		"missions": _page_missions()
		"property": _page_property()
		"shops": _page_shops()
		"vehicles": _page_vehicles()
		"weapons": _page_weapons()
		"gang": _page_gang()
		"stats": _page_stats()


# ═══════════════ 通用控件 ═══════════════
func _title(t: String, sub_text := "") -> void:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 26)
	content.add_child(l)
	if sub_text != "":
		var s := Label.new()
		s.text = sub_text
		s.add_theme_font_size_override("font_size", 13)
		s.add_theme_color_override("font_color", Data.C_DIM)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(s)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	content.add_child(gap)


func _card(bg := Data.C_PANEL2) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(10)
	sb.border_color = Color(1, 1, 1, 0.06)
	sb.set_border_width_all(1)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	content.add_child(p)
	return p


func _label(t: String, size := 15, color := Data.C_TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(520, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _btn(text: String, cb: Callable, kind := "normal", min_w := 108) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 36)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	var bg := Color(0.15, 0.17, 0.21)
	var border := Color(1, 1, 1, 0.10)
	match kind:
		"primary":
			bg = Data.C_ACCENT.darkened(0.42)
			border = Data.C_ACCENT
		"danger":
			bg = Color(0.32, 0.11, 0.13)
			border = Data.C_RED
		"ok":
			bg = Color(0.08, 0.28, 0.22)
			border = Data.C_TEAL
		"gold":
			bg = Color(0.32, 0.25, 0.08)
			border = Data.C_GOLD
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(8)
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	b.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate()
	hov.bg_color = bg.lightened(0.14)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


func _row(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


# ═══════════════ 地图页 ═══════════════
func _page_map() -> void:
	_title("城市地图", "所有地点、待售房产与任务目标都在这张图上。")

	var h := _row(16)
	var mv := MapView.new()
	mv.custom_minimum_size = Vector2(600, 600)
	mv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(mv)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.custom_minimum_size = Vector2(240, 0)
	h.add_child(right)

	var loc := Label.new()
	loc.text = "当前位置"
	loc.add_theme_font_size_override("font_size", 13)
	loc.add_theme_color_override("font_color", Data.C_DIM)
	right.add_child(loc)

	var near := Label.new()
	near.text = _nearest_place()
	near.add_theme_font_size_override("font_size", 18)
	near.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(near)

	var sep := HSeparator.new()
	right.add_child(sep)

	var mt := Label.new()
	mt.text = "进行中的任务"
	mt.add_theme_font_size_override("font_size", 13)
	mt.add_theme_color_override("font_color", Data.C_DIM)
	right.add_child(mt)

	if Game.missions.is_empty():
		right.add_child(_label("暂无任务，去「任务」页接一个。", 13, Data.C_DIM))
	else:
		for m in Game.missions:
			var l := _label("• %s  %d m" % [m["title"], int(_dist_to(m["target"]))], 13)
			right.add_child(l)

	var sep2 := HSeparator.new()
	right.add_child(sep2)

	var tips := _label("提示：地图上的圆环就是任务目标，走进圆环按 E 完成。", 12, Data.C_DIM, true)
	tips.custom_minimum_size = Vector2(220, 0)
	right.add_child(tips)

	content.add_child(h)


func _nearest_place() -> String:
	if not is_instance_valid(Game.player):
		return "未知"
	var pp: Vector3 = Game.player.global_position
	var best := "郊区"
	var bd := 1e9
	for p in Data.PLACES:
		var c := Data.cell_center(p["cell"])
		var d := pp.distance_to(c)
		if d < bd:
			bd = d
			best = p["name"]
	if bd > 60.0:
		return "街区外 · 最近：%s" % best
	return best


func _dist_to(p: Vector3) -> float:
	if not is_instance_valid(Game.player):
		return 0.0
	var pp: Vector3 = Game.player.global_position
	return Vector2(pp.x - p.x, pp.z - p.z).length()


# ═══════════════ 职业页 ═══════════════
func _page_jobs() -> void:
	_title("职业中心", "选择一份工作。厨师与店长需要先拥有对应店铺的使用权。")

	var cur := Game.job_info()
	var c0 := _card(Color(0.09, 0.12, 0.18))
	var h0 := _row(14)
	var bar := ColorRect.new()
	bar.color = cur.get("color", Data.C_DIM)
	bar.custom_minimum_size = Vector2(5, 0)
	h0.add_child(bar)
	var v0 := VBoxContainer.new()
	v0.add_theme_constant_override("separation", 3)
	v0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h0.add_child(v0)
	v0.add_child(_label("当前职业", 12, Data.C_DIM))
	v0.add_child(_label(str(cur.get("name", "")), 20))
	var sal := int(cur.get("salary", 0))
	v0.add_child(_label("日薪 $%d" % sal if sal > 0 else "无固定日薪", 13, Data.C_GOLD))
	c0.add_child(h0)

	for jid in Data.JOB_ORDER:
		if jid == "unemployed":
			continue
		var j: Dictionary = Data.JOBS[jid]
		var card := _card()
		var h := _row(14)
		var stripe := ColorRect.new()
		stripe.color = j["color"]
		stripe.custom_minimum_size = Vector2(5, 0)
		h.add_child(stripe)

		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(_label(str(j["name"]), 18))
		var d := _label(str(j["desc"]), 13, Data.C_DIM, true)
		d.custom_minimum_size = Vector2(560, 0)
		v.add_child(d)
		var extra := ""
		if int(j["salary"]) > 0:
			extra += "日薪 $%d" % int(j["salary"])
		if j["need_shop"] != "":
			var ok := Game.job_has_shop(str(jid))
			extra += ("　·　店铺：%s" % ("已租" if ok else "未租"))
			v.add_child(_label(extra, 12, Data.C_TEAL if ok else Data.C_RED))
		elif extra != "":
			v.add_child(_label(extra, 12, Data.C_GOLD))

		var active: bool = (Game.job == str(jid))
		var b := _btn("在职" if active else "申请", Callable(), "ok" if active else "primary")
		b.disabled = active
		if not active:
			var id: String = jid
			b.pressed.connect(func():
				Game.set_job(id)
				_rebuild())
		h.add_child(b)
		card.add_child(h)


# ═══════════════ 任务页 ═══════════════
func _page_missions() -> void:
	_title("任务", "任务奖励即时结算。帮派任务会提升通缉度。")

	var head := _label("进行中", 14, Data.C_DIM)
	content.add_child(head)

	if Game.missions.is_empty():
		var c := _card()
		c.add_child(_label("暂无进行中的任务。", 14, Data.C_DIM))
	else:
		for m in Game.missions:
			var card := _card(Color(0.10, 0.13, 0.16))
			var h := _row(12)
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 5)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(v)
			v.add_child(_label(str(m["title"]), 17))
			var dist := int(_dist_to(m["target"]))
			v.add_child(_label("目标距离 %d 米　·　报酬 $%d" % [dist, int(m["reward"])], 12, Data.C_DIM))

			var pb := ProgressBar.new()
			pb.max_value = float(m["need"])
			pb.value = float(m["progress"])
			pb.show_percentage = false
			pb.custom_minimum_size = Vector2(420, 12)
			var bg := StyleBoxFlat.new()
			bg.bg_color = Color(0, 0, 0, 0.4)
			bg.set_corner_radius_all(4)
			var fg := StyleBoxFlat.new()
			fg.bg_color = Data.C_TEAL
			fg.set_corner_radius_all(4)
			pb.add_theme_stylebox_override("background", bg)
			pb.add_theme_stylebox_override("fill", fg)
			v.add_child(pb)

			var mid: int = int(m["id"])
			h.add_child(_btn("放弃", func():
				Game.abandon_mission(mid)
				_rebuild(), "danger", 88))
			card.add_child(h)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	content.add_child(gap)
	content.add_child(_label("可接取", 14, Data.C_DIM))

	var any := false
	for tid in Data.MISSION_ORDER:
		var t: Dictionary = Data.MISSION_TYPES[tid]
		if t["job"] != Game.job:
			continue
		any = true
		var card := _card()
		var h := _row(12)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(_label(str(t["name"]), 16))
		var d := _label(str(t["desc"]), 12, Data.C_DIM, true)
		d.custom_minimum_size = Vector2(560, 0)
		v.add_child(d)
		v.add_child(_label("报酬 $%d%s" % [int(t["reward"]), ("　·　通缉 +%.1f" % float(t["heat"])) if float(t["heat"]) > 0 else ""], 12, Data.C_GOLD))
		var id: String = tid
		var take_btn := _btn("接取", Callable(), "primary", 88)
		take_btn.pressed.connect(func():
			close()
			Game.accept_mission(id))
		h.add_child(take_btn)
		card.add_child(h)

	if not any:
		var c := _card()
		c.add_child(_label("当前职业没有可接的任务。去「职业中心」申请一份工作吧。", 13, Data.C_DIM))


# ═══════════════ 房产页 ═══════════════
func _page_property() -> void:
	_title("房产", "买下房子后，走进屋里按 B 进入装修模式。")

	var owned := Game.owned_property_list()
	content.add_child(_label("我的房产", 14, Data.C_DIM))
	if owned.is_empty():
		var c := _card()
		c.add_child(_label("还没有房产。攒钱买下第一套房吧。", 13, Data.C_DIM))
	else:
		for p in owned:
			var card := _card(Color(0.09, 0.15, 0.12))
			var h := _row(12)
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 4)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(v)
			v.add_child(_label(str(p["name"]), 17))
			var fc: int = Game.properties[p["id"]]["furniture"].size()
			v.add_child(_label("%s　·　已摆放 %d 件家具" % [p["rooms"], fc], 12, Data.C_DIM))
			var pid: String = p["id"]
			h.add_child(_btn("去装修", func():
				close()
				if Game.world and Game.world.has_method("enter_decorate"):
					Game.world.enter_decorate(pid), "ok", 96))
			card.add_child(h)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	content.add_child(gap)
	content.add_child(_label("在售房源", 14, Data.C_DIM))

	for p in Data.PROPERTIES:
		var has := Game.owns_property(p["id"])
		var card := _card()
		var h := _row(12)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(_label(str(p["name"]), 16))
		v.add_child(_label("%s　·　位于%s" % [p["rooms"], _cell_name(p["cell"])], 12, Data.C_DIM))
		v.add_child(_label("$%s" % _fmt(int(p["price"])), 17, Data.C_GOLD))
		var pid: String = p["id"]
		var price := int(p["price"])
		if has:
			h.add_child(_btn("已拥有", Callable(), "ok", 96))
			h.get_child(h.get_child_count() - 1).disabled = true
		else:
			var b := _btn("购买", func():
				Game.buy_property(pid)
				_rebuild(), "gold", 96)
			b.disabled = Game.cash < price
			h.add_child(b)
		card.add_child(h)


func _cell_name(cell: Vector2i) -> String:
	for p in Data.PLACES:
		if p["cell"] == cell:
			return p["name"]
	return "中城区"


# ═══════════════ 店铺页 ═══════════════
func _page_shops() -> void:
	_title("店铺使用权", "租下店铺才能从事厨师或便利店老板。租金按 7 天结算。")

	for s in Data.SHOPS:
		var has := Game.has_shop(s["id"])
		var card := _card(Color(0.09, 0.14, 0.12) if has else Data.C_PANEL2)
		var h := _row(12)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(_label(str(s["name"]), 17))
		var d := _label(str(s["desc"]), 12, Data.C_DIM, true)
		d.custom_minimum_size = Vector2(560, 0)
		v.add_child(d)
		var info := "租金 $%s / 7 天" % _fmt(int(s["rent"]))
		if has:
			info += "　·　到期：第 %d 天" % int(Game.shops[s["id"]])
		v.add_child(_label(info, 12, Data.C_TEAL if has else Data.C_GOLD))
		var sid: String = s["id"]
		if has:
			h.add_child(_btn("已租用", Callable(), "ok", 96))
			h.get_child(h.get_child_count() - 1).disabled = true
		else:
			var b := _btn("租下", func():
				Game.rent_shop(sid)
				_rebuild(), "primary", 96)
			b.disabled = Game.cash < int(s["rent"])
			h.add_child(b)
		card.add_child(h)


# ═══════════════ 车辆页 ═══════════════
func _page_vehicles() -> void:
	_title("车辆", "在车行购买车辆后，去车行停车场按 E 上车。改装会提升性能。")

	content.add_child(_label("我的车库", 14, Data.C_DIM))
	if Game.vehicles.is_empty():
		var c := _card()
		c.add_child(_label("车库是空的。下面挑一辆吧。", 13, Data.C_DIM))
	else:
		for v in Game.vehicles:
			var uid: int = int(v["uid"])
			var st := Game.vehicle_stats(v)
			var card := _card(Color(0.10, 0.11, 0.15))
			var h := _row(12)
			var sw := ColorRect.new()
			sw.color = v["paint"]
			sw.custom_minimum_size = Vector2(6, 0)
			h.add_child(sw)
			var vv := VBoxContainer.new()
			vv.add_theme_constant_override("separation", 4)
			vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(vv)
			vv.add_child(_label(str(v["name"]), 17))
			var eng: int = int(v.get("engine", 0))
			var tir: int = int(v.get("tires", 0))
			vv.add_child(_label("引擎 %s　·　轮胎 %s　·　极速 %.0f km/h" % [
				Data.UPGRADES["engine"]["levels"][eng]["name"],
				Data.UPGRADES["tires"]["levels"][tir]["name"],
				st["top"] * 3.6], 12, Data.C_DIM))
			h.add_child(_btn("收起" if expanded_vehicle == uid else "改装", func():
				expanded_vehicle = -1 if expanded_vehicle == uid else uid
				_rebuild(), "primary", 88))
			card.add_child(h)

			if expanded_vehicle == uid:
				_tuning_panel(v, uid)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	content.add_child(gap)
	content.add_child(_label("车行在售", 14, Data.C_DIM))

	for vd in Data.VEHICLES:
		var card := _card()
		var h := _row(12)
		var sw2 := ColorRect.new()
		sw2.color = vd["color"]
		sw2.custom_minimum_size = Vector2(6, 0)
		h.add_child(sw2)
		var vv := VBoxContainer.new()
		vv.add_theme_constant_override("separation", 4)
		vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(vv)
		vv.add_child(_label(str(vd["name"]), 16))
		vv.add_child(_label("极速 %.0f km/h　·　加速 %.0f　·　抓地 %.2f" % [float(vd["top"]) * 3.6, float(vd["accel"]), float(vd["grip"])], 12, Data.C_DIM))
		vv.add_child(_label("$%s" % _fmt(int(vd["price"])), 17, Data.C_GOLD))
		var tid: String = vd["id"]
		var price := int(vd["price"])
		var b := _btn("购买", func():
			Game.buy_vehicle(tid)
			_rebuild(), "gold", 88)
		b.disabled = Game.cash < price
		h.add_child(b)
		card.add_child(h)


func _tuning_panel(v: Dictionary, uid: int) -> void:
	var inner := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.065, 0.085)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	inner.add_theme_stylebox_override("panel", sb)
	content.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	inner.add_child(vbox)

	for part in ["engine", "tires"]:
		var tiers: Array = Data.UPGRADES[part]["levels"]
		var cur: int = int(v.get(part, 0))
		var row := _row(8)
		row.add_child(_label(str(Data.UPGRADES[part]["name"]), 13, Data.C_DIM))
		for i in range(tiers.size()):
			var t: Dictionary = tiers[i]
			var txt := "%s" % t["name"]
			if i > 0:
				txt += "  $%s" % _fmt(int(t["cost"]))
			var kind := "ok" if i == cur else ("normal" if i < cur else "primary")
			var b := _btn(txt, Callable(), kind, 130)
			if i <= cur:
				b.disabled = true
			else:
				var pi := i
				var pp: String = str(part)
				b.pressed.connect(func():
					Game.upgrade_vehicle(uid, pp)
					_rebuild())
			row.add_child(b)
		vbox.add_child(row)

	var prow := _row(8)
	prow.add_child(_label("喷漆", 13, Data.C_DIM))
	for i in range(Data.PAINTS.size()):
		var p: Dictionary = Data.PAINTS[i]
		var pb := Button.new()
		pb.custom_minimum_size = Vector2(34, 34)
		pb.focus_mode = Control.FOCUS_NONE
		pb.tooltip_text = "%s  $%d" % [p["name"], int(p["cost"])]
		var ps := StyleBoxFlat.new()
		ps.bg_color = p["color"]
		ps.set_corner_radius_all(6)
		ps.border_color = Color(1, 1, 1, 0.25)
		ps.set_border_width_all(1)
		pb.add_theme_stylebox_override("normal", ps)
		pb.add_theme_stylebox_override("hover", ps)
		pb.add_theme_stylebox_override("pressed", ps)
		var idx := i
		pb.pressed.connect(func():
			Game.paint_vehicle(uid, idx)
			_rebuild())
		prow.add_child(pb)
	vbox.add_child(prow)


# ═══════════════ 武器页 ═══════════════
func _page_weapons() -> void:
	_title("武器", "购枪前必须通过「购枪资格测验」（答对全部 3 题）。Glock 17 仅警察免费配发。")
	if Game.job == "police":
		var tip := _card(Color(0.07, 0.11, 0.13))
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 4)
		tip.add_child(tv)
		tv.add_child(_label("警察配发", 14, Data.C_TEAL))
		tv.add_child(_label("入职警察后自动获得 Glock 17；也可以自费购买 M4 / AK / MAC-10（同样需要答题）。", 12, Data.C_DIM, true))
	else:
		var tip2 := _card(Color(0.09, 0.08, 0.06))
		var tv2 := VBoxContainer.new()
		tv2.add_theme_constant_override("separation", 4)
		tip2.add_child(tv2)
		tv2.add_child(_label("购枪须知", 14, Data.C_GOLD))
		tv2.add_child(_label("任何人都可以购买 M4 / AK-47 / MAC-10，但必须先通过购枪资格测验。Glock 17 不对外出售。", 12, Data.C_DIM, true))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	content.add_child(gap)
	content.add_child(_label("柜台目录", 14, Data.C_DIM))

	for w in Data.WEAPONS:
		var wid: String = str(w["id"])
		var card := _card()
		var h := _row(12)
		var stripe := ColorRect.new()
		stripe.color = Color(0.85, 0.72, 0.38) if wid == "glock" else Color(0.42, 0.47, 0.52)
		stripe.custom_minimum_size = Vector2(6, 0)
		h.add_child(stripe)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 3)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(_label("%s　·　%s" % [str(w["name"]), str(w["kind"])], 17))
		v.add_child(_label("伤害 %.0f　射速 %.2fs　弹匣 %d%s" % [float(w["damage"]), float(w["rate"]), int(w["mag"]), "　全自动" if bool(w["auto"]) else "　半自动"], 12, Data.C_DIM))
		var d := _label(str(w["desc"]), 12, Data.C_DIM, true)
		d.custom_minimum_size = Vector2(480, 0)
		v.add_child(d)
		if bool(w["auto"]):
			v.add_child(_label("提示：装备后按住左键连续射击；R 换弹；1-4 快速切枪。", 11, Data.C_DIM))
		else:
			v.add_child(_label("提示：装备后左键射击；R 换弹；1-4 快速切枪。", 11, Data.C_DIM))

		# 状态 + 操作
		var right := VBoxContainer.new()
		right.add_theme_constant_override("separation", 4)
		right.custom_minimum_size = Vector2(150, 0)
		h.add_child(right)
		var owned := Game.owns_weapon(wid)
		var equipped := Game.weapon == wid
		var price := int(w["price"])
		if owned:
			right.add_child(_label("已持有", 13, Data.C_TEAL))
		elif wid == "glock":
			right.add_child(_label("警察配发", 13, Data.C_GOLD))
		else:
			right.add_child(_label("$%s" % _fmt(price), 17, Data.C_GOLD))
		var police_only := wid == "glock"
		if owned:
			var eb := _btn("收起" if equipped else "装备", func():
				if equipped:
					Game.holster_weapon()
				else:
					Game.equip_weapon(wid)
				_rebuild(), "ok", 96)
			right.add_child(eb)
		elif police_only:
			right.add_child(_label("仅警察配发", 12, Data.C_DIM))
		else:
			var buy := _btn("购枪（答题）", Callable(), "gold", 120)
			buy.disabled = Game.cash < price
			buy.pressed.connect(func(): _open_weapon_quiz(wid))
			right.add_child(buy)
		card.add_child(h)


func _open_weapon_quiz(wid: String, questions_override: Array = []) -> void:
	var w := Game.weapon_info(wid)
	if w.is_empty():
		return
	var quiz_script = load("res://scripts/core/weapon_quiz.gd")
	var panel_script = load("res://scripts/ui/quiz_panel.gd")
	if quiz_script == null or panel_script == null:
		Game.toast.emit("答题系统未就绪，无法购枪", "error")
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var questions: Array = questions_override
	if questions.is_empty():
		questions = quiz_script.pick(3, rng)
	var layer := CanvasLayer.new()
	layer.layer = 45
	add_child(layer)
	var qp = panel_script.new()
	layer.add_child(qp)
	qp.question_provider = func():
		var r := RandomNumberGenerator.new()
		r.randomize()
		return quiz_script.pick(3, r)
	qp.finished.connect(func(passed: bool):
		layer.queue_free()
		if passed:
			Game.buy_weapon(wid)
		else:
			Game.toast.emit("测验未通过，购枪取消", "error"))
	qp.closed.connect(func():
		if is_instance_valid(layer) and not layer.is_queued_for_deletion():
			layer.queue_free())
	qp.open(questions)


# ═══════════════ 帮派页 ═══════════════
func _page_gang() -> void:
	_title("帮派", "帮派任务报酬高，但会留下通缉记录。")

	if Game.gang == "":
		for g in Data.GANGS:
			var card := _card()
			var h := _row(12)
			var stripe := ColorRect.new()
			stripe.color = g["color"]
			stripe.custom_minimum_size = Vector2(5, 0)
			h.add_child(stripe)
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 4)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(v)
			v.add_child(_label(str(g["name"]), 18))
			var d := _label(str(g["desc"]), 12, Data.C_DIM, true)
			d.custom_minimum_size = Vector2(520, 0)
			v.add_child(d)
			var gid: String = g["id"]
			h.add_child(_btn("加入", func():
				Game.gang = gid
				Game.set_job("gangster")
				_rebuild(), "primary", 88))
			card.add_child(h)
	else:
		var gname := ""
		for g in Data.GANGS:
			if g["id"] == Game.gang:
				gname = g["name"]
		var c := _card(Color(0.13, 0.10, 0.18))
		c.add_child(_label("当前帮派：%s" % gname, 18, Data.C_PURPLE))
		c.add_child(_label("在城西仓库接活。任务目标会出现在地图上。", 12, Data.C_DIM))

		content.add_child(_label("帮派任务", 14, Data.C_DIM))
		for tid in ["capture", "deliver", "rob"]:
			var t: Dictionary = Data.MISSION_TYPES[tid]
			var card := _card()
			var h := _row(12)
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 4)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(v)
			v.add_child(_label(str(t["name"]), 16))
			var d := _label(str(t["desc"]), 12, Data.C_DIM, true)
			d.custom_minimum_size = Vector2(520, 0)
			v.add_child(d)
			v.add_child(_label("报酬 $%d　·　通缉 +%.1f" % [int(t["reward"]), float(t["heat"])], 12, Data.C_RED))
			var id: String = tid
			var take_btn := _btn("接取", Callable(), "primary", 88)
			take_btn.pressed.connect(func():
				close()
				Game.accept_mission(id))
			h.add_child(take_btn)
			card.add_child(h)


# ═══════════════ 档案页 ═══════════════
func _page_stats() -> void:
	_title("生涯档案", "你在 Sim Life 里留下的痕迹。")

	var s := Game.stats
	var rows := [
		["完成任务", str(s["missions_done"])],
		["累计收入", "$%s" % _fmt(int(s["earned"]))],
		["逮捕人数", str(s["arrests"])],
		["扑灭火灾", str(s["fires"])],
		["救治伤员", str(s["heals"])],
		["持有房产", "%d 套" % Game.owned_property_list().size()],
		["车辆", "%d 辆" % Game.vehicles.size()],
		["游戏天数", "第 %d 天" % Game.day],
		["当前通缉度", "%.1f" % Game.heat],
	]
	for r in rows:
		var card := _card()
		var h := _row(12)
		h.add_child(_label(str(r[0]), 14, Data.C_DIM))
		h.add_child(_spacer())
		h.add_child(_label(str(r[1]), 17))
		card.add_child(h)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	content.add_child(gap)
	var help := _card(Color(0.07, 0.09, 0.11))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 5)
	help.add_child(hv)
	hv.add_child(_label("操作说明", 15))
	hv.add_child(_label("WASD 移动　Shift 奔跑　Ctrl 蹲下　空格 跳跃", 12, Data.C_DIM, true))
	hv.add_child(_label("E 交互 / 上下车　TAB 打开平板　B 装修模式（在自家屋内）", 12, Data.C_DIM, true))
	hv.add_child(_label("驾驶：W/S 油门刹车　A/D 转向　E 下车", 12, Data.C_DIM, true))


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
