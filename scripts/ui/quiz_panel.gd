class_name QuizPanel
extends Control
## 购枪资格测验：自包含的模态测验面板（纯代码构建，无场景依赖）
##
## 典型用法（加入 CanvasLayer）：
##   var panel := QuizPanel.new()
##   layer.add_child(panel)                       # 面板铺满屏幕，背景变暗并拦截鼠标
##   panel.finished.connect(func(passed: bool): ...)
##   panel.open(WeaponQuiz.pick(3, rng))
##   panel.close()                                # 关闭后节点保留，可再次 open() 复用
##
## 行为约定：
## - 最后一题作答后点「下一题/查看结果」进入结果页；结果页出现时发出
##   result_shown(passed) 一次，用于提前得知结果。
## - finished(passed) 在结果页被「完成/关闭」关闭时（或结果页上按 ESC 关闭时）
##   发出一次——此时再执行购枪/扣款等业务动作，玩家能完整看到结果页。
##   未答完直接 close()（如 ESC 中途退出）不会发出 finished。
## - 答错后点「重新答题」默认重答同一套题；若调用方给 question_provider 赋一个
##   返回 Array 的 Callable，则会重新取新题再开始。
## - 由调用方负责释放节点（通常 connected finished/closed 时 queue_free 所在层）。
##   面板可见时会拦截鼠标，并吞掉 ESC / TAB 键，避免误关平板或暂停菜单。
## - 除字体外不依赖任何游戏脚本：字体优先取 /root/Game.get_font()，
##   不可用时回退到 ThemeDB.fallback_font（再不行就用主题默认字体）。
## - choose_option() / advance() / retry() 是公开的自动化辅助接口
##   （测试、键盘操作或演示脚本可直接驱动面板）。
## - 关闭面板不会自动释放节点；调用方可按需 queue_free()。

signal finished(passed: bool)       ## 结果页被关闭时发出一次（购枪时机）
signal result_shown(passed: bool)   ## 结果页出现时发出一次
signal closed                       ## 面板被 close() 隐藏时发出

const TITLE := "购枪资格测验"
const SUBTITLE_FMT := "答对全部 %d 题才能购买"
const PANEL_SIZE := Vector2(820, 640)

# ── 配色（与 Data.C_* 保持一致，但本组件不依赖 Data 自动加载）──
const C_TEXT := Color(0.902, 0.929, 0.953)
const C_DIM := Color(0.545, 0.580, 0.620)
const C_TEAL := Color(0.208, 0.816, 0.729)
const C_GOLD := Color(1.0, 0.820, 0.400)
const C_RED := Color(0.949, 0.357, 0.376)
const C_GREEN := Color(0.290, 0.780, 0.470)

const OPTION_BG := Color(0.10, 0.125, 0.16)
const OPTION_BORDER := Color(1, 1, 1, 0.08)
const OPTION_CORRECT_BG := Color(0.06, 0.26, 0.17)
const OPTION_REVEAL_BG := Color(0.05, 0.20, 0.15)
const OPTION_WRONG_BG := Color(0.30, 0.10, 0.13)
const OPTION_OTHER_BG := Color(0.09, 0.11, 0.14)

## 可选：重新答题时用于取新题的 Callable（返回 Array）；为空则重答同一套题。
var question_provider: Callable = Callable()

var _questions: Array = []
var _answers: Array = []
var _index: int = 0
var _answered: bool = false
var _finished: bool = false
var _emitted: bool = false
var _result_announced: bool = false
var _passed: bool = false
var _font: Font = null
var _built: bool = false
var _tween: Tween = null

var _dim: ColorRect
var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _progress: Label
var _quiz_view: VBoxContainer
var _question: Label
var _options: Array[Button] = []
var _feedback: Label
var _explain: Label
var _next_btn: Button
var _result_view: VBoxContainer
var _result_title: Label
var _result_score: Label
var _result_hint: Label
var _done_btn: Button
var _retry_btn: Button
var _close_btn: Button


func _ready() -> void:
	# 即使调用方把游戏树暂停（平板类 UI 常见做法），面板仍要能显示和响应输入
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_built()
	hide()


func _input(event: InputEvent) -> void:
	# 用 _input 而不是 _unhandled_input：保证先于 main.gd / tablet.gd 的
	# `_unhandled_input`（TAB 开合平板、ESC 关平板/暂停菜单）拿到按键。
	if not visible:
		return
	if _is_dismiss_event(event):
		get_viewport().set_input_as_handled()
		close()


# ═══════════════ 公开 API ═══════════════
func open(questions: Array) -> void:
	_ensure_built()
	if questions.is_empty():
		push_warning("QuizPanel.open(): 题目列表为空，未打开")
		return
	_questions = questions.duplicate()
	_start_quiz()
	show()
	modulate.a = 1.0
	if is_inside_tree():
		if _tween != null and _tween.is_valid():
			_tween.kill()
		modulate.a = 0.0
		_tween = create_tween()
		_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tween.tween_property(self, "modulate:a", 1.0, 0.16)


func close() -> void:
	if not visible:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	modulate.a = 1.0
	hide()
	# 先发结果（调用方在此购枪/扣款/释放层），再发关闭生命周期
	if _finished and not _emitted:
		_emitted = true
		finished.emit(_passed)
	closed.emit()


func is_open() -> bool:
	return visible


func current_index() -> int:
	return _index


func result_passed() -> bool:
	return _passed


func answers() -> Array:
	return _answers.duplicate()


# ═══════════════ 自动化辅助接口 ═══════════════
## 选择第 index 个选项（0-3）。仅在当前题尚未作答时生效。
func choose_option(index: int) -> void:
	if not _built or _finished or _answered:
		return
	if _index < 0 or _index >= _questions.size():
		return
	var q: Dictionary = _questions[_index]
	var opts: Array = q.get("options", [])
	if index < 0 or index >= opts.size():
		return
	_answered = true
	_answers.append(index)
	var correct: int = int(q.get("answer", -1))
	var good: bool = index == correct
	for k in range(_options.size()):
		var b: Button = _options[k]
		b.disabled = true
		if k == correct and good:
			_apply_option_style(b, OPTION_CORRECT_BG, C_GREEN, C_TEXT)
		elif k == correct:
			_apply_option_style(b, OPTION_REVEAL_BG, C_GREEN, Color(0.80, 0.97, 0.88))
		elif k == index:
			_apply_option_style(b, OPTION_WRONG_BG, C_RED, C_TEXT)
		else:
			_apply_option_style(b, OPTION_OTHER_BG, Color(1, 1, 1, 0.05), C_DIM)
	if good:
		_feedback.text = "回答正确"
		_feedback.add_theme_color_override("font_color", C_GREEN)
	else:
		var letter: String = "?"
		if correct >= 0 and correct < 4:
			letter = "ABCD"[correct]
		_feedback.text = "回答错误 · 正确答案是 %s" % letter
		_feedback.add_theme_color_override("font_color", C_RED)
	var ex: String = str(q.get("explain", ""))
	_explain.text = ("解析：" + ex) if ex != "" else ""
	_next_btn.disabled = false


## 进入下一题；已是最后一题时进入结果页。仅在本轮题已作答后生效。
func advance() -> void:
	if not _built:
		return
	if _finished:
		confirm_result()
		return
	if not _answered:
		return
	if _index + 1 < _questions.size():
		_index += 1
		_refresh_question()
	else:
		_show_result()


## 自动化/键盘辅助：在结果页确认（通过→完成购买；未通过→关闭）
func confirm_result() -> void:
	if not _finished:
		return
	if _passed:
		if _done_btn != null:
			_done_btn.pressed.emit()
	else:
		if _close_btn != null:
			_close_btn.pressed.emit()


## 重新开始一轮测验：优先用 question_provider 取新题，否则重答同一套题。
func retry() -> void:
	if not _built or _questions.is_empty():
		return
	if _finished and question_provider.is_valid():
		var fresh: Variant = question_provider.call()
		if fresh is Array and not (fresh as Array).is_empty():
			_questions = (fresh as Array).duplicate()
	_start_quiz()


# ═══════════════ 构建 ═══════════════
func _ensure_built() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_resolve_font()

	# 变暗遮罩
	_dim = ColorRect.new()
	_dim.color = Color(0.01, 0.015, 0.02, 0.72)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	# 主面板
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = PANEL_SIZE
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.06, 0.08, 0.95)
	ps.set_corner_radius_all(14)
	ps.border_color = Color(0.28, 0.32, 0.38)
	ps.set_border_width_all(2)
	ps.shadow_color = Color(0, 0, 0, 0.55)
	ps.shadow_size = 30
	ps.content_margin_left = 30
	ps.content_margin_right = 30
	ps.content_margin_top = 24
	ps.content_margin_bottom = 24
	_panel.add_theme_stylebox_override("panel", ps)
	center.add_child(_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	_panel.add_child(root)

	# ── 头部 ──
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	root.add_child(head)

	_title = _label(TITLE, 26, C_GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)

	_progress = _label("", 15, C_TEAL)
	_progress.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_progress)

	_subtitle = _label(SUBTITLE_FMT % 3, 13, C_DIM)
	root.add_child(_subtitle)

	var line := ColorRect.new()
	line.color = Color(C_TEAL.r, C_TEAL.g, C_TEAL.b, 0.30)
	line.custom_minimum_size = Vector2(0, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(line)

	# ── 答题视图 ──
	_quiz_view = VBoxContainer.new()
	_quiz_view.add_theme_constant_override("separation", 12)
	_quiz_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_quiz_view)

	_question = _label("", 20, C_TEXT)
	_question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question.custom_minimum_size = Vector2(0, 64)
	_quiz_view.add_child(_question)

	var opt_box := VBoxContainer.new()
	opt_box.add_theme_constant_override("separation", 10)
	_quiz_view.add_child(opt_box)
	for i in range(4):
		var b := Button.new()
		b.name = "Option%d" % i
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 52)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_on_option_pressed.bind(i))
		_font_override(b)
		opt_box.add_child(b)
		_options.append(b)

	_feedback = _label("", 16, C_GREEN)
	_feedback.custom_minimum_size = Vector2(0, 22)
	_quiz_view.add_child(_feedback)

	_explain = _label("", 14, C_DIM)
	_explain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_explain.custom_minimum_size = Vector2(0, 42)
	_quiz_view.add_child(_explain)

	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quiz_view.add_child(grow)

	var next_row := HBoxContainer.new()
	next_row.alignment = BoxContainer.ALIGNMENT_END
	_quiz_view.add_child(next_row)
	_next_btn = _action_button("下一题", _accent_color(), 150, 44)
	_next_btn.name = "NextBtn"
	_next_btn.pressed.connect(advance)
	next_row.add_child(_next_btn)

	# ── 结果视图 ──
	_result_view = VBoxContainer.new()
	_result_view.add_theme_constant_override("separation", 14)
	_result_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_view.visible = false
	root.add_child(_result_view)

	var top_gap := Control.new()
	top_gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_view.add_child(top_gap)

	_result_title = _label("", 36, C_GOLD)
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_title.custom_minimum_size = Vector2(0, 56)
	_result_view.add_child(_result_title)

	_result_score = _label("", 16, C_TEXT)
	_result_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_view.add_child(_result_score)

	_result_hint = _label("", 15, C_DIM)
	_result_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_hint.custom_minimum_size = Vector2(0, 48)
	_result_view.add_child(_result_hint)

	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_view.add_child(gap)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	_result_view.add_child(btn_row)

	_retry_btn = _action_button("重新答题", _accent_color(), 150, 46)
	_retry_btn.name = "RetryBtn"
	_retry_btn.pressed.connect(retry)
	btn_row.add_child(_retry_btn)

	_done_btn = _action_button("完成", Color(0.10, 0.36, 0.30), 150, 46)
	_done_btn.name = "DoneBtn"
	_done_btn.pressed.connect(close)
	btn_row.add_child(_done_btn)

	_close_btn = _action_button("关闭", Color(0.15, 0.17, 0.21), 150, 46)
	_close_btn.name = "CloseBtn"
	_close_btn.pressed.connect(close)
	btn_row.add_child(_close_btn)

	_reset_option_styles()


# ═══════════════ 流程 ═══════════════
func _start_quiz() -> void:
	_index = 0
	_answers.clear()
	_answered = false
	_finished = false
	_emitted = false
	_result_announced = false
	_passed = false
	_quiz_view.visible = true
	_result_view.visible = false
	_progress.visible = true
	_subtitle.text = SUBTITLE_FMT % _questions.size()
	_refresh_question()


func _refresh_question() -> void:
	_answered = false
	_feedback.text = ""
	_explain.text = ""
	_next_btn.disabled = true
	_next_btn.text = "下一题" if _index < _questions.size() - 1 else "查看结果"
	_progress.text = "第 %d/%d 题" % [_index + 1, _questions.size()]
	var q: Dictionary = _questions[_index]
	_question.text = str(q.get("q", ""))
	var opts: Array = q.get("options", [])
	_reset_option_styles()
	for i in range(_options.size()):
		var b: Button = _options[i]
		b.disabled = false
		if i < opts.size():
			b.text = "%s. %s" % ["ABCD"[i], str(opts[i])]
		else:
			b.text = ""


func _reset_option_styles() -> void:
	for i in range(_options.size()):
		_apply_option_style(_options[i], OPTION_BG, OPTION_BORDER, C_TEXT)


func _on_option_pressed(index: int) -> void:
	choose_option(index)


func _show_result() -> void:
	var total: int = _questions.size()
	var correct: int = 0
	for i in range(total):
		if int(_answers[i]) == int(_questions[i].get("answer", -1)):
			correct += 1
	_passed = correct == total
	_finished = true
	_quiz_view.visible = false
	_result_view.visible = true
	_progress.visible = false
	_subtitle.text = "本卷共 %d 题 · 全部答对才算通过" % total
	_result_score.text = "正确 %d/%d 题" % [correct, total]
	if _passed:
		_result_title.text = "测验通过"
		_result_title.add_theme_color_override("font_color", C_GOLD)
		_result_hint.text = "你已具备购枪资格，点击「完成」继续购买。"
		_retry_btn.visible = false
		_done_btn.visible = true
		_close_btn.visible = false
	else:
		_result_title.text = "测验未通过，请重新答题"
		_result_title.add_theme_color_override("font_color", C_RED)
		_result_hint.text = "答对全部 %d 题才能购买，请仔细阅读解析后再试一次。" % total
		_retry_btn.visible = true
		_done_btn.visible = false
		_close_btn.visible = true
	_emitted = false
	if not _result_announced:
		_result_announced = true
		result_shown.emit(_passed)


# ═══════════════ 视觉辅助 ═══════════════
## 面板可见时吞掉 ESC / TAB：避免测验途中误关平板或打开暂停菜单。
func _is_dismiss_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE:
			return true
	if InputMap.has_action("cancel") and event.is_action_pressed("cancel"):
		return true
	if InputMap.has_action("tablet") and event.is_action_pressed("tablet"):
		return true
	return false


func _resolve_font() -> void:
	if _font != null:
		return
	var g := get_node_or_null("/root/Game")
	if g != null and g.has_method("get_font"):
		var f: Variant = g.get_font()
		if f is Font:
			_font = f
	if _font == null:
		_font = ThemeDB.fallback_font


func _font_override(ctrl: Control) -> void:
	if _font != null:
		ctrl.add_theme_font_override("font", _font)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	_font_override(l)
	return l


func _accent_color() -> Color:
	return Color(0.20, 0.38, 0.62)


func _style_button_states(b: Button, base: Color, border: Color, radius: int, margins: Vector2) -> void:
	var states := {
		"normal": base,
		"hover": base.lightened(0.13),
		"pressed": base.darkened(0.12),
		"disabled": base.darkened(0.32)
	}
	for key in states.keys():
		var sb := StyleBoxFlat.new()
		sb.bg_color = states[key]
		sb.set_corner_radius_all(radius)
		sb.border_color = border if key != "disabled" else Color(1, 1, 1, 0.06)
		sb.set_border_width_all(2)
		sb.content_margin_left = margins.x
		sb.content_margin_right = margins.x
		sb.content_margin_top = margins.y
		sb.content_margin_bottom = margins.y
		b.add_theme_stylebox_override(key, sb)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _apply_option_style(b: Button, bg: Color, border: Color, text_color: Color) -> void:
	_style_button_states(b, bg, border, 10, Vector2(20, 12))
	b.add_theme_color_override("font_color", text_color)
	b.add_theme_color_override("font_hover_color", text_color)
	b.add_theme_color_override("font_pressed_color", text_color)
	b.add_theme_color_override("font_disabled_color", text_color)


func _action_button(text: String, base: Color, min_w: int, min_h: int) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, min_h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 16)
	_style_button_states(b, base, base.lightened(0.35), 10, Vector2(18, 12))
	_font_override(b)
	return b
