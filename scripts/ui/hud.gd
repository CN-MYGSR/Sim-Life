extends CanvasLayer
class_name HUD
## 抬头显示：准星 / 现金 / 职业 / 时钟 / 体力 / 通缉度 / 交互提示 / 通知

var root: Control
var cross: Control
var money_label: Label
var job_label: Label
var time_label: Label
var heat_label: Label
var mission_label: Label
var prompt_panel: PanelContainer
var prompt_label: Label
var hold_panel: PanelContainer
var hold_label: Label
var hold_bar: ProgressBar
var stamina_bar: ProgressBar
var health_bar: ProgressBar
var toast_box: VBoxContainer
var _prompt_text: String = ""
var _t: float = 0.0


func _ready() -> void:
	layer = 10
	Game.hud = self
	_build()
	Game.toast.connect(_on_toast)
	Game.cash_changed.connect(_refresh_money)
	Game.job_changed.connect(_refresh_job)
	Game.heat_changed.connect(_refresh_heat)
	_refresh_money()
	_refresh_job()
	_refresh_heat()
	_update_time()


func _build() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ── 准星 ──
	cross = Control.new()
	cross.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.draw.connect(_draw_cross)
	root.add_child(cross)

	# ── 左上：职业 + 现金 ──
	var left := VBoxContainer.new()
	left.position = Vector2(26, 22)
	left.add_theme_constant_override("separation", 6)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)

	var tag := Label.new()
	tag.text = "SIM LIFE"
	tag.add_theme_font_size_override("font_size", 11)
	tag.add_theme_color_override("font_color", Data.C_DIM)
	left.add_child(tag)

	job_label = Label.new()
	job_label.add_theme_font_size_override("font_size", 19)
	left.add_child(job_label)

	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 30)
	money_label.add_theme_color_override("font_color", Data.C_GOLD)
	left.add_child(money_label)

	heat_label = Label.new()
	heat_label.add_theme_font_size_override("font_size", 15)
	heat_label.add_theme_color_override("font_color", Data.C_RED)
	left.add_child(heat_label)

	mission_label = Label.new()
	mission_label.add_theme_font_size_override("font_size", 14)
	mission_label.add_theme_color_override("font_color", Data.C_TEAL)
	left.add_child(mission_label)

	# ── 右上：时间 ──
	var tr := VBoxContainer.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-280, 22)
	tr.custom_minimum_size = Vector2(250, 0)
	tr.alignment = BoxContainer.ALIGNMENT_BEGIN
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)

	time_label = Label.new()
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time_label.add_theme_font_size_override("font_size", 20)
	time_label.custom_minimum_size = Vector2(250, 0)
	tr.add_child(time_label)

	toast_box = VBoxContainer.new()
	toast_box.custom_minimum_size = Vector2(250, 0)
	toast_box.add_theme_constant_override("separation", 6)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.add_child(toast_box)

	# ── 左下：状态条 ──
	var bl := VBoxContainer.new()
	bl.anchor_left = 0.0
	bl.anchor_top = 1.0
	bl.anchor_right = 0.0
	bl.anchor_bottom = 1.0
	bl.offset_left = 26
	bl.offset_right = 246
	bl.offset_top = -104
	bl.offset_bottom = -26
	bl.add_theme_constant_override("separation", 6)
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bl)

	health_bar = _make_bar(Color(0.90, 0.30, 0.32), "生命")
	bl.add_child(health_bar)
	stamina_bar = _make_bar(Color(0.35, 0.82, 0.62), "体力")
	bl.add_child(stamina_bar)

	# ── 底部中央：交互提示 ──
	prompt_panel = PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.05, 0.07, 0.82)
	ps.set_corner_radius_all(10)
	ps.content_margin_left = 20
	ps.content_margin_right = 20
	ps.content_margin_top = 10
	ps.content_margin_bottom = 10
	ps.border_color = Color(0.35, 0.65, 1.0, 0.55)
	ps.set_border_width_all(1)
	prompt_panel.add_theme_stylebox_override("panel", ps)
	prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_panel.visible = false
	root.add_child(prompt_panel)

	prompt_label = Label.new()
	prompt_label.add_theme_font_size_override("font_size", 17)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_panel.add_child(prompt_label)

	# ── 准星下方：长按进度 ──
	hold_panel = PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(0.04, 0.05, 0.07, 0.85)
	hs.set_corner_radius_all(10)
	hs.content_margin_left = 18
	hs.content_margin_right = 18
	hs.content_margin_top = 9
	hs.content_margin_bottom = 9
	hs.border_color = Color(0.30, 0.85, 1.0, 0.5)
	hs.set_border_width_all(1)
	hold_panel.add_theme_stylebox_override("panel", hs)
	hold_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hold_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hold_panel.visible = false
	root.add_child(hold_panel)

	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 6)
	hold_panel.add_child(hv)

	hold_label = Label.new()
	hold_label.add_theme_font_size_override("font_size", 15)
	hold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hold_label.custom_minimum_size = Vector2(220, 0)
	hv.add_child(hold_label)

	hold_bar = ProgressBar.new()
	hold_bar.max_value = 1.0
	hold_bar.value = 0.0
	hold_bar.show_percentage = false
	hold_bar.custom_minimum_size = Vector2(220, 10)
	var hbg := StyleBoxFlat.new()
	hbg.bg_color = Color(0, 0, 0, 0.5)
	hbg.set_corner_radius_all(4)
	var hfg := StyleBoxFlat.new()
	hfg.bg_color = Color(0.30, 0.85, 1.0)
	hfg.set_corner_radius_all(4)
	hold_bar.add_theme_stylebox_override("background", hbg)
	hold_bar.add_theme_stylebox_override("fill", hfg)
	hv.add_child(hold_bar)


func _make_bar(color: Color, title: String) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = 100.0
	b.value = 100.0
	b.show_percentage = false
	b.custom_minimum_size = Vector2(210, 16)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(4)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.tooltip_text = title
	return b


func _draw_cross() -> void:
	var c := cross.size * 0.5
	var col := Color(1, 1, 1, 0.82)
	var gap := 5.0
	var ln := 8.0
	var w := 2.0
	cross.draw_line(c + Vector2(-gap - ln, 0), c + Vector2(-gap, 0), col, w)
	cross.draw_line(c + Vector2(gap, 0), c + Vector2(gap + ln, 0), col, w)
	cross.draw_line(c + Vector2(0, -gap - ln), c + Vector2(0, -gap), col, w)
	cross.draw_line(c + Vector2(0, gap), c + Vector2(0, gap + ln), col, w)
	cross.draw_circle(c, 1.6, col)


func _process(delta: float) -> void:
	_t += delta
	if _t > 0.15:
		_t = 0.0
		_update_time()
		_update_mission()
		if is_instance_valid(Game.player):
			health_bar.value = lerpf(health_bar.value, Game.health, 0.2)
			stamina_bar.value = lerpf(stamina_bar.value, Game.stamina, 0.2)


func _update_mission() -> void:
	if Game.missions.is_empty():
		mission_label.text = ""
		return
	var m: Dictionary = Game.missions[0]
	var tp: Vector3 = m["target"]
	var d := 0.0
	if is_instance_valid(Game.player):
		var pp: Vector3 = Game.player.global_position
		d = Vector2(pp.x - tp.x, pp.z - tp.z).length()
	mission_label.text = "▸ %s   %d m" % [m["title"], int(d)]


func _update_time() -> void:
	time_label.text = Game.get_time_string()
	if Game.is_night():
		time_label.add_theme_color_override("font_color", Color(0.62, 0.72, 1.0))
	else:
		time_label.add_theme_color_override("font_color", Data.C_TEXT)


func _refresh_money() -> void:
	money_label.text = "$%s" % _fmt(Game.cash)


func _refresh_job() -> void:
	var info := Game.job_info()
	job_label.text = str(info.get("name", "无业"))
	job_label.add_theme_color_override("font_color", info.get("color", Data.C_TEXT))


func _refresh_heat() -> void:
	var stars := int(ceil(Game.heat))
	if stars <= 0:
		heat_label.text = ""
		return
	var s := ""
	for i in range(5):
		s += "●" if i < stars else "○"
	heat_label.text = "通缉  " + s


func set_prompt(text: String) -> void:
	if text == _prompt_text:
		return
	_prompt_text = text
	if text == "":
		prompt_panel.visible = false
		return
	prompt_label.text = "[E]  " + text
	prompt_panel.visible = true
	prompt_panel.reset_size()
	var vp := root.size
	prompt_panel.position = Vector2(vp.x * 0.5 - prompt_panel.size.x * 0.5, vp.y - 130)


func set_hold(active: bool, progress: float, text: String) -> void:
	if not active:
		hold_panel.visible = false
		return
	hold_panel.visible = true
	hold_label.text = text
	hold_bar.value = progress
	hold_panel.reset_size()
	var vp := root.size
	hold_panel.position = Vector2(vp.x * 0.5 - hold_panel.size.x * 0.5, vp.y * 0.5 + 54)


func _on_toast(text: String, kind: String) -> void:
	var col := Data.C_TEXT
	match kind:
		"money": col = Data.C_GOLD
		"ok": col = Data.C_TEAL
		"warn": col = Color(1.0, 0.70, 0.35)
		"error": col = Data.C_RED
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.08, 0.86)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.border_color = col
	sb.border_width_left = 3
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_SHRINK_END
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(230, 0)
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", col)
	p.add_child(l)

	toast_box.add_child(p)
	p.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	tw.tween_interval(2.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.45)
	tw.tween_callback(p.queue_free)
	# 最多保留 5 条
	while toast_box.get_child_count() > 5:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()


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
