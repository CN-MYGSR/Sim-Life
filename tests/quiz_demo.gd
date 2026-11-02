extends Node3D
## 临时测试场景：购枪资格测验（WeaponQuiz + QuizPanel）
## - 验证题库结构 / pick() / is_passed() / count_correct()
## - 自动走「全对 → 测验通过」与「答错 → 测验未通过」两条路径，并验证按钮语义：
##     结果页出现时发 result_shown()；点「完成」/「关闭」关闭结果页时才发 finished()
## - 截图：shots/quiz_question.png / shots/quiz_feedback.png /
##          shots/quiz_feedback_wrong.png / shots/quiz_result_pass.png /
##          shots/quiz_result_fail.png
## 运行：D:\Godot\Godot_v4.7.2-stable_win64.exe --path "D:\Sim Life" "res://tests/quiz_demo.tscn"

const OUT := "res://shots/quiz/"
const SEED := 20261101

var panel: QuizPanel
var finished_events: Array = []
var result_events: Array = []
var fail_count := 0


func _ready() -> void:
	_setup_env()

	print("=== WeaponQuiz 验证 ===")
	_validate_bank()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var questions: Array = WeaponQuiz.pick(3, rng)
	_validate_pick(questions)
	_validate_is_passed(questions)

	# ── UI 装配（加入 CanvasLayer，与游戏内一致）──
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	panel = QuizPanel.new()
	layer.add_child(panel)
	panel.finished.connect(func(passed: bool) -> void: finished_events.append(passed))
	panel.result_shown.connect(func(passed: bool) -> void: result_events.append(passed))
	_validate_panel_api()
	await _wait(0.30)

	# ══ 路径 1：全对 → 通过 ══
	panel.open(questions)
	await _wait(0.55)
	await _shot("quiz_question.png")

	for i in range(questions.size()):
		var q: Dictionary = questions[i]
		panel.choose_option(int(q.get("answer", 0)))
		if i == 0:
			await _wait(0.40)
			await _shot("quiz_feedback.png")
		await _wait(0.12)
		panel.advance()
		await _wait(0.20)
	await _wait(0.45)
	await _shot("quiz_result_pass.png")

	_expect(result_events.size() == 1 and bool(result_events[0]), "结果页出现时发出 result_shown(true)")
	_expect(finished_events.is_empty(), "结果页出现时 finished 尚未发出（待玩家点「完成」）")
	var done := _find_button("DoneBtn")
	_expect(done != null and done.visible, "通过结果页显示「完成」按钮")
	if done != null:
		done.pressed.emit()
	await _wait(0.15)
	_expect(finished_events.size() == 1 and bool(finished_events[0]), "点「完成」→ finished(true)")
	_expect(not panel.is_open(), "点「完成」后面板隐藏")

	# ══ 路径 2：答错一题 → 未通过 ══
	rng.seed = SEED + 1
	var questions2: Array = WeaponQuiz.pick(3, rng)
	panel.open(questions2)
	await _wait(0.35)
	for i in range(questions2.size()):
		var q2: Dictionary = questions2[i]
		var ans: int = int(q2.get("answer", 0))
		if i == 1:
			ans = (ans + 1) % 4   # 故意答错一题
		panel.choose_option(ans)
		if i == 1:
			await _wait(0.40)
			await _shot("quiz_feedback_wrong.png")
		await _wait(0.10)
		panel.advance()
		await _wait(0.15)
	await _wait(0.45)
	await _shot("quiz_result_fail.png")

	_expect(result_events.size() == 2 and not bool(result_events[1]), "答错 → result_shown(false)")
	_expect(finished_events.size() == 1, "失败结果页出现时 finished 尚未发出")

	var retry := _find_button("RetryBtn")
	_expect(retry != null and retry.visible, "失败结果页显示「重新答题」按钮")
	if retry != null:
		retry.pressed.emit()
	await _wait(0.30)
	_expect(panel.is_open() and panel.current_index() == 0, "「重新答题」回到第 1 题")
	_expect(panel.answers().is_empty(), "「重新答题」清空作答记录")
	_expect(finished_events.size() == 1, "「重新答题」不发出 finished")

	# 再答一次（全错）→ 失败页 → 点「关闭」
	for i in range(questions2.size()):
		var q3: Dictionary = questions2[i]
		panel.choose_option((int(q3.get("answer", 0)) + 1) % 4)
		await _wait(0.08)
		panel.advance()
		await _wait(0.10)
	await _wait(0.35)
	var close_btn := _find_button("CloseBtn")
	_expect(close_btn != null and close_btn.visible, "失败结果页显示「关闭」按钮")
	if close_btn != null:
		close_btn.pressed.emit()
	await _wait(0.15)
	_expect(finished_events.size() == 2 and not bool(finished_events[1]), "点「关闭」→ finished(false)")
	_expect(not panel.is_open(), "点「关闭」后面板隐藏")

	# ══ 未答完直接 ESC / close()：视为放弃，不发 finished ══
	panel.open(questions)
	await _wait(0.25)
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _wait(0.25)
	_expect(not panel.is_open(), "测验中途 ESC → 面板关闭")
	_expect(finished_events.size() == 2, "测验中途 ESC → 不发出 finished（视为放弃购买）")

	panel.open(questions)
	await _wait(0.25)
	panel.close()
	await _wait(0.10)
	_expect(finished_events.size() == 2, "测验中途 close() 不发出 finished（视为放弃购买）")

	# ══ 集成契约：按 tablet.gd 的方式装配（load().new() + finished 里释放层并购买）══
	var wq_script: Script = load("res://scripts/core/weapon_quiz.gd")
	_expect(wq_script != null, "load(weapon_quiz.gd) 成功（tablet.gd 装配方式）")
	var picked: Variant = wq_script.pick(3, rng)
	_expect(picked is Array and (picked as Array).size() == 3, "脚本对象直接调用 pick(3, rng) 可用")

	var layer2 := CanvasLayer.new()
	layer2.layer = 45
	add_child(layer2)
	var panel_script: Script = load("res://scripts/ui/quiz_panel.gd")
	_expect(panel_script != null, "load(quiz_panel.gd) 成功（tablet.gd 装配方式）")
	var qp2: QuizPanel = panel_script.new()
	layer2.add_child(qp2)
	var bought: Array = [false]
	qp2.finished.connect(func(passed: bool) -> void:
		layer2.queue_free()
		bought[0] = passed)
	qp2.open(picked)
	await _wait(0.35)
	for i in range(picked.size()):
		qp2.choose_option(int(picked[i].get("answer", 0)))
		qp2.advance()
		await _wait(0.08)
	await _wait(0.30)
	var done2: Button = qp2.find_child("DoneBtn", true, false) as Button
	if done2 != null:
		done2.pressed.emit()
	await _wait(0.30)
	_expect(bool(bought[0]), "集成契约：finished(true) 后执行购枪回调")
	_expect(not is_instance_valid(layer2), "集成契约：finished 里 queue_free 所在 CanvasLayer 正常释放")

	# ── 汇总 ──
	print("=== 验证汇总 ===")
	print("失败项: ", fail_count)
	print("QUIZ_DEMO_DONE fail=", fail_count)
	get_tree().quit(1 if fail_count > 0 else 0)


# ═══════════════ 校验 ═══════════════
func _validate_bank() -> void:
	var bank: Array = WeaponQuiz.BANK
	print("题库总数: ", bank.size())
	_expect(bank.size() >= 14 and bank.size() <= 18, "题库数量在 14-18 之间")
	var bad := 0
	var answers_used := {}
	for i in range(bank.size()):
		var q: Variant = bank[i]
		var ok: bool = typeof(q) == TYPE_DICTIONARY
		if ok:
			var d: Dictionary = q
			ok = not str(d.get("q", "")).is_empty()
			var opts: Array = d.get("options", [])
			ok = ok and opts.size() == 4
			var seen := {}
			for o in opts:
				var s := str(o)
				ok = ok and not s.is_empty()
				seen[s] = true
			ok = ok and seen.size() == opts.size()
			var ans: int = int(d.get("answer", -1))
			ok = ok and ans >= 0 and ans <= 3
			ok = ok and not str(d.get("explain", "")).is_empty()
			if ans >= 0 and ans <= 3:
				answers_used[ans] = true
		if not ok:
			bad += 1
			print("  [BAD] 第 ", i + 1, " 题结构不合法")
	_expect(bad == 0, "每题都有非空题干 + 4 个不重复选项 + 合法 answer + explain")
	_expect(answers_used.size() == 4, "正确答案分布覆盖 A/B/C/D 四个位置")


func _validate_pick(sample: Array) -> void:
	_expect(sample.size() == 3, "pick(3) 返回 3 题")
	var seen := {}
	for q in sample:
		seen[str(q.get("q", ""))] = true
	_expect(seen.size() == sample.size(), "pick(3) 题目不重复")

	var r1 := RandomNumberGenerator.new()
	var r2 := RandomNumberGenerator.new()
	r1.seed = 42
	r2.seed = 42
	var a: Array = WeaponQuiz.pick(5, r1)
	var b: Array = WeaponQuiz.pick(5, r2)
	_expect(_q_texts(a) == _q_texts(b), "相同 seed 的 pick() 结果一致（可复现）")

	var big: Array = WeaponQuiz.pick(999, r1)
	_expect(big.size() == WeaponQuiz.BANK.size(), "pick(999) 截断到题库总数")
	var zero: Array = WeaponQuiz.pick(0, r1)
	_expect(zero.is_empty(), "pick(0) 返回空数组")
	var one: Array = WeaponQuiz.pick(1, r1)
	_expect(one.size() == 1, "pick(1) 返回 1 题")


func _validate_is_passed(questions: Array) -> void:
	var all_right: Array = []
	for q in questions:
		all_right.append(int(q.get("answer", 0)))
	_expect(WeaponQuiz.is_passed(questions, all_right), "is_passed 全对 → true")
	_expect(WeaponQuiz.count_correct(questions, all_right) == questions.size(), "count_correct 全对 == 题数")

	var one_wrong: Array = all_right.duplicate()
	one_wrong[1] = (int(one_wrong[1]) + 1) % 4
	_expect(not WeaponQuiz.is_passed(questions, one_wrong), "is_passed 错一题 → false")
	_expect(WeaponQuiz.count_correct(questions, one_wrong) == questions.size() - 1, "count_correct 错一题 == 题数-1")

	_expect(not WeaponQuiz.is_passed(questions, [int(all_right[0])]), "is_passed 答案数量不符 → false")
	_expect(not WeaponQuiz.is_passed([], []), "is_passed 空题组 → false")
	_expect(not WeaponQuiz.is_passed(questions, []), "is_passed 空答案 → false")


func _validate_panel_api() -> void:
	_expect(panel.has_signal("finished"), "QuizPanel 有 finished(passed) 信号")
	_expect(panel.has_signal("result_shown"), "QuizPanel 有 result_shown(passed) 信号")
	_expect(panel.has_method("open") and panel.has_method("close"), "QuizPanel 有 open()/close() 方法")
	_expect(panel.mouse_filter == Control.MOUSE_FILTER_STOP, "QuizPanel 铺满屏幕并拦截鼠标")
	_expect(not panel.is_open(), "QuizPanel 默认隐藏")


func _q_texts(arr: Array) -> Array:
	var out: Array = []
	for q in arr:
		out.append(str(q.get("q", "")))
	return out


func _expect(cond: bool, label: String) -> void:
	if cond:
		print("  [OK] ", label)
	else:
		fail_count += 1
		print("  [FAIL] ", label)


func _find_button(node_name: String) -> Button:
	if panel == null:
		return null
	return panel.find_child(node_name, true, false) as Button


# ═══════════════ 场景 ═══════════════
func _setup_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.09, 0.13, 0.22)
	sm.sky_horizon_color = Color(0.42, 0.36, 0.37)
	sm.ground_bottom_color = Color(0.03, 0.035, 0.04)
	sm.ground_horizon_color = Color(0.16, 0.15, 0.16)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.45
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-40, 140, 0)
	moon.light_color = Color(0.62, 0.72, 1.0)
	moon.light_energy = 1.1
	moon.shadow_enabled = true
	add_child(moon)

	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(240, 240)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.13, 0.14, 0.15)
	gm.roughness = 0.95
	ground.material_override = gm
	add_child(ground)

	# 街景楼群（仅作暗色背景）
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(14):
		var h: float = rng.randf_range(6.0, 22.0)
		var w: float = rng.randf_range(4.0, 9.0)
		var d: float = rng.randf_range(4.0, 9.0)
		var bx: float = rng.randf_range(-34.0, 34.0)
		var bz: float = rng.randf_range(-40.0, -12.0)
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(w, h, d)
		box.mesh = bm
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.20, 0.21, 0.25).lerp(Color(0.28, 0.25, 0.22), rng.randf())
		mat.roughness = 0.9
		box.material_override = mat
		box.position = Vector3(bx, h * 0.5, bz)
		add_child(box)

		var win := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(w * 0.55, h * 0.05, 0.10)
		win.mesh = wm
		var wmat := StandardMaterial3D.new()
		wmat.albedo_color = Color(1.0, 0.84, 0.55)
		wmat.emission_enabled = true
		wmat.emission = Color(1.0, 0.78, 0.42)
		wmat.emission_energy_multiplier = 2.2
		win.material_override = wmat
		win.position = Vector3(bx, h * 0.45, bz + d * 0.5 + 0.06)
		add_child(win)

	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 4.5, 17)
	cam.look_at(Vector3(0, 3.5, -8))
	cam.fov = 66.0
	cam.current = true


# ═══════════════ 工具 ═══════════════
func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := OUT + name
	var err := img.save_png(path)
	print("SHOT ", name, " err=", err, " size=", img.get_size())
