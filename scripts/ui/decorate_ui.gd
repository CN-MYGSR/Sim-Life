extends CanvasLayer
class_name DecorateUI
## 装修模式界面：左侧家具目录，右侧已摆放列表

signal closed

var main: Node
var prop_id: String = ""
var _owned_box: VBoxContainer


func setup(p_prop: String, p_main: Node) -> void:
	prop_id = p_prop
	main = p_main
	_build()


func _build() -> void:
	layer = 22
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = Game.get_theme_res()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# 顶部条
	var top := PanelContainer.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.04, 0.05, 0.07, 0.92)
	ts.set_corner_radius_all(12)
	ts.content_margin_left = 18
	ts.content_margin_right = 18
	ts.content_margin_top = 10
	ts.content_margin_bottom = 10
	top.add_theme_stylebox_override("panel", ts)
	top.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-260, 20)
	top.custom_minimum_size = Vector2(520, 0)
	root.add_child(top)

	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 14)
	top.add_child(th)
	var name := ""
	for p in Data.PROPERTIES:
		if p["id"] == prop_id:
			name = p["name"]
	var title := Label.new()
	title.text = "装修模式 · %s" % name
	title.add_theme_font_size_override("font_size", 18)
	th.add_child(title)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(sp)
	var hint := Label.new()
	hint.text = "家具会放在你正前方"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Data.C_DIM)
	th.add_child(hint)
	var exit_btn := Button.new()
	exit_btn.text = "退出 (B)"
	exit_btn.custom_minimum_size = Vector2(96, 34)
	exit_btn.pressed.connect(func(): closed.emit())
	th.add_child(exit_btn)

	# 左侧目录
	var left := PanelContainer.new()
	var ls := StyleBoxFlat.new()
	ls.bg_color = Color(0.04, 0.05, 0.07, 0.92)
	ls.set_corner_radius_all(12)
	ls.content_margin_left = 12
	ls.content_margin_right = 12
	ls.content_margin_top = 12
	ls.content_margin_bottom = 12
	left.add_theme_stylebox_override("panel", ls)
	left.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	left.position = Vector2(20, -280)
	left.custom_minimum_size = Vector2(268, 560)
	root.add_child(left)

	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	left.add_child(lv)

	var lt := Label.new()
	lt.text = "家具目录"
	lt.add_theme_font_size_override("font_size", 16)
	lv.add_child(lt)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(240, 500)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(scroll)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	for f in Data.FURNITURE:
		var b := Button.new()
		b.text = "%s    $%d" % [f["name"], int(f["price"])]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(228, 34)
		b.add_theme_font_size_override("font_size", 13)
		var fid: String = f["id"]
		b.pressed.connect(func():
			if main and main.has_method("place_furniture"):
				main.call("place_furniture", fid)
			_refresh_owned())
		list.add_child(b)

	# 右侧已摆放
	var right := PanelContainer.new()
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0.04, 0.05, 0.07, 0.92)
	rs.set_corner_radius_all(12)
	rs.content_margin_left = 12
	rs.content_margin_right = 12
	rs.content_margin_top = 12
	rs.content_margin_bottom = 12
	right.add_theme_stylebox_override("panel", rs)
	right.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	right.position = Vector2(-268, -280)
	right.custom_minimum_size = Vector2(248, 560)
	root.add_child(right)

	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	right.add_child(rv)

	var rt := Label.new()
	rt.text = "已摆放"
	rt.add_theme_font_size_override("font_size", 16)
	rv.add_child(rt)

	var scroll2 := ScrollContainer.new()
	scroll2.custom_minimum_size = Vector2(220, 500)
	scroll2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rv.add_child(scroll2)

	_owned_box = VBoxContainer.new()
	_owned_box.add_theme_constant_override("separation", 4)
	_owned_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll2.add_child(_owned_box)

	_refresh_owned()


func _refresh_owned() -> void:
	if not is_instance_valid(_owned_box):
		return
	for c in _owned_box.get_children():
		_owned_box.remove_child(c)
		c.queue_free()
	if not Game.properties.has(prop_id):
		return
	var arr: Array = Game.properties[prop_id]["furniture"]
	if arr.is_empty():
		var l := Label.new()
		l.text = "还没有家具"
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Data.C_DIM)
		_owned_box.add_child(l)
		return
	for i in range(arr.size()):
		var f: Dictionary = arr[i]
		var fname := str(f["id"])
		for d in Data.FURNITURE:
			if d["id"] == f["id"]:
				fname = d["name"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var l2 := Label.new()
		l2.text = "%d. %s" % [i + 1, fname]
		l2.add_theme_font_size_override("font_size", 12)
		l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l2)
		var idx := i
		var b := Button.new()
		b.text = "回收"
		b.custom_minimum_size = Vector2(52, 26)
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(func():
			if main and main.has_method("remove_furniture_at"):
				main.call("remove_furniture_at", idx)
			_refresh_owned())
		row.add_child(b)
		_owned_box.add_child(row)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("decorate") or event.is_action_pressed("cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
