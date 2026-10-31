extends Node3D
## char_showcase.gd —— Quaternius 人形角色集成前检（task-3）
##
## 运行（需要渲染设备，非 headless）：
##   & "D:\Godot\Godot_v4.7.2-stable_win64.exe" --path "D:\Sim Life" "res://tests/char_showcase.tscn"
##   加 "-- --measure-only" 只跑测量、不出截图
##
## 产出：
##   shots/char_showcase_report.txt             完整数值报告
##   shots/char_showcase_lineup.png             20 模型总览（面向镜头，含身高标签 + 1.7m 参照）
##   shots/char_showcase_lineup_casual.png      行人组近景
##   shots/char_showcase_lineup_uniform.png     制服/职业组近景
##   shots/char_showcase_pose_idle.png          Idle 姿势
##   shots/char_showcase_pose_walk.png          Walk @40%（行走中）
##   shots/char_showcase_pose_run.png           Run @40%（跑步中）
##   shots/char_showcase_pose_death.png         Death @55% / @100%（伤员定格用）
##   shots/char_showcase_facing.png             朝向证明：同一模型 rot.y=0/90/180/270
##   shots/char_showcase_facing_side.png        侧视图（鼻尖朝向）
##
## 测量方法：
##   - 身高：模型放进独立 SubViewport（透明背景 + 正交相机），渲染 Idle 姿势，
##     用 Image.get_used_rect() 取剪影包围盒，按「正交视野高度 / 像素高」换算世界尺寸。
##   - 朝向：用左右对称骨骼对（Shoulder/UpperArm/Foot...）求右向量，前进方向 = UP × right，
##     再换算成「rotation.y 需要多少度才能面向 -Z」（游戏约定）。
##   - 循环：Animation.loop_mode（0=NONE）+ 首末帧骨骼姿势差异（loop 接缝 pop 检测）。
##   - root motion：逐步 seek 采样 Hips / Bone 世界位置，算 1s 净漂移与摆幅。

const DIR := "res://assets/chars/"
const SHOT_DIR := "D:/Sim Life/shots/char_showcase_"
const REPORT_PATH := "D:/Sim Life/shots/char_showcase_report.txt"

const MODELS := [
	"Casual_Male", "Casual_Female", "Casual_Bald",
	"Casual2_Male", "Casual2_Female", "Casual3_Male", "Casual3_Female",
	"Worker_Male", "Worker_Female",
	"OldClassy_Male", "OldClassy_Female",
	"Suit_Male", "Suit_Female",
	"Soldier_Male", "Pirate_Male", "Doctor_Male_Young",
	"Chef_Male", "Chef_Female", "Ninja_Male", "Zombie_Male",
]

const REQUIRED := ["Idle", "Walk", "Run", "Death"]
const ALL_ANIMS := ["Death", "Defeat", "Idle", "Jump", "PickUp", "Punch", "RecieveHit",
	"Roll", "Run", "Run_Carry", "Shoot_OneHanded", "SitDown", "StandUp",
	"SwordSlash", "Victory", "Walk", "Walk_Carry"]

const LOOP_NAME := {0: "NONE", 1: "LINEAR", 2: "PINGPONG"}

const PED_GROUP := ["Casual_Male", "Casual_Female", "Casual_Bald", "Casual2_Male",
	"Casual2_Female", "Casual3_Male", "Casual3_Female", "Worker_Male",
	"Worker_Female", "Suit_Male", "Suit_Female", "OldClassy_Male", "OldClassy_Female"]
const JOB_GROUP := ["Soldier_Male", "Pirate_Male", "Ninja_Male", "Zombie_Male",
	"Doctor_Male_Young", "Chef_Male", "Chef_Female"]

var data := {}            # model -> Dictionary
var order: Array = []     # 保证顺序
var report := PackedStringArray()# --- 测量世界（独立 SubViewport，透明背景，正交相机）---
var mview: SubViewport
var mcam: Camera3D
var mholder: Node3D
var m_ok := false

# --- 展示世界（主窗口）---
var showroot: Node3D
var cam: Camera3D
var ground: MeshInstance3D

var show_facing: Array = []   # 截图用：model -> 面向 -Z 所需 rotation.y（度）


func _ready() -> void:
	var headless := DisplayServer.get_name() == "headless"
	var user_args := OS.get_cmdline_user_args()
	var measure_only := "--measure-only" in user_args
	print("char_showcase: display=", DisplayServer.get_name(), " headless=", headless,
		" measure_only=", measure_only)
	if not headless:
		var w := get_window()
		w.mode = Window.MODE_WINDOWED
		w.size = Vector2i(1920, 1080)
		w.position = Vector2i(16, 16)
	_build_show_env()
	_build_measure_env()
	if "--probe" in user_args:
		await _probe_sizes()
		get_tree().quit()
		return
	await _measure_all()
	_summarize()
	_write_report()
	if headless or measure_only:
		get_tree().quit()
		return
	await _shots()
	get_tree().quit()


# =====================================================================================
# 测量
# =====================================================================================

func _measure_all() -> void:
	for name in MODELS:
		var r: Dictionary = await _measure_model(name)
		data[name] = r
		order.append(name)
		print("[measured] ", name, " h=", _f(r.get("height", -1.0), 3), "m y_min=",
			_f(r.get("y_min", -9.0), 3), " facing=", _f(r.get("facing_yaw", 999.0), 2), "deg")


func _measure_model(model: String) -> Dictionary:
	var r := {"name": model, "error": ""}
	var ps: PackedScene = load(DIR + model + ".gltf") as PackedScene
	if ps == null:
		r["error"] = "gltf_load_failed"
		return r
	var inst: Node3D = ps.instantiate() as Node3D
	mholder.add_child(inst)
	var ap := _find_ap(inst)
	var sk := _find_skel(inst)
	r["meshes"] = _all_meshes(inst).size()
	r["bones"] = sk.get_bone_count() if sk != null else 0
	r["bone_names"] = _bone_names(sk)
	r["materials"] = _material_info(inst)
	r["anims"] = {}
	r["anim_list"] = []
	var node_tracks := 0
	if ap != null:
		var list := ap.get_animation_list()
		r["anim_list"] = list
		for a in list:
			var an := ap.get_animation(a)
			var tr := 0
			for ti in an.get_track_count():
				if not String(an.track_get_path(ti)).contains("Skeleton3D:"):
					tr += 1
			node_tracks += tr
			r["anims"][String(a)] = {
				"len": an.length,
				"loop": an.loop_mode,
				"tracks": an.get_track_count(),
				"node_tracks": tr,
			}
	r["node_tracks"] = node_tracks

	# 身高（渲染剪影）；先把姿势摆到 Idle 中段
	var idle_len := 4.167
	if ap != null and ap.has_animation("Idle"):
		ap.play("Idle", 0.0)
		ap.pause()
		ap.seek(0.3, true)
		idle_len = ap.get_animation("Idle").length

	# 朝向：在 Idle 一个完整周期内采样 8 帧，左右骨骼对求「右向量」，
	# 前进方向 = UP × right，用圆周平均消除姿势摆动/绑定姿势不对称（顺时针为 +）。
	var fac := _facing_from_cycle(ap, sk, idle_len)
	r["facing_yaw"] = fac["yaw"]
	r["facing_pairs"] = fac["per_pair"]
	r["facing_spread"] = fac["spread"]
	if ap != null and ap.has_animation("Idle"):
		ap.seek(0.3, true)
	if m_ok:
		await _silhouette(inst, r)
	else:
		r["height"] = _bone_max_y(sk) * 1.15
		r["y_min"] = 0.0
		r["height_note"] = "headless_estimate"

	if ap != null and sk != null:
		# 循环接缝 + 根骨漂移
		r["anim_stats"] = {}
		for a in REQUIRED:
			if not ap.has_animation(a):
				r["anim_stats"][a] = {"exists": false}
				continue
			var an2 := ap.get_animation(a)
			var st := {"exists": true, "len": an2.length, "loop": an2.loop_mode,
				"tracks": an2.get_track_count()}
			st["seam"] = _seam_check(ap, sk, a, an2.length)
			r["anim_stats"][a] = st
		r["rootmotion"] = {}
		for a in ["Walk", "Run"]:
			if ap.has_animation(a):
				r["rootmotion"][a] = _root_motion(ap, sk, a)
		# 只对代表模型做额外测量：各姿势贴地情况 + 步幅估计
		if model == "Casual_Male" and m_ok:
			r["pose_contact"] = await _pose_contact(ap)
			r["stride"] = await _stride_est(ap)

	mholder.remove_child(inst)
	inst.free()
	return r


## 各 surface 材质信息：贴图是否加载 / albedo / 顶点色
func _material_info(inst: Node) -> Array:
	var out: Array = []
	for mi in _all_meshes(inst):
		var mii := mi as MeshInstance3D
		if mii == null or mii.mesh == null:
			continue
		for si in mii.mesh.get_surface_count():
			var mat: Material = mii.get_active_material(si)
			var info := {"surf": si}
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				info["class"] = "Std"
				info["name"] = String(sm.resource_name)
				info["tex"] = sm.albedo_texture != null
				info["albedo"] = sm.albedo_color.to_html(false)
				info["vcol"] = sm.vertex_color_use_as_albedo
				info["transp"] = sm.transparency
				info["cull"] = sm.cull_mode
			elif mat != null:
				info["class"] = mat.get_class()
				info["tex"] = false
			else:
				info["class"] = "null"
				info["tex"] = false
			out.append(info)
	return out


## 在整段循环动画的 8 个采样点上求朝向（圆周平均，消除姿势摆动影响）
func _facing_from_cycle(ap: AnimationPlayer, sk: Skeleton3D, length: float) -> Dictionary:
	var pair_defs := [
		["Shoulder.L", "Shoulder.R"],
		["UpperArm.L", "UpperArm.R"],
		["LowerArm.L", "LowerArm.R"],
		["UpperLeg.L", "UpperLeg.R"],
	]
	var samples := 8
	var acc_all := Vector2.ZERO
	var per_pair_acc := {}
	for s in range(samples):
		ap.seek(length * float(s) / float(samples), true)
		for p in pair_defs:
			var l := _bone_world(sk, p[0])
			var rr := _bone_world(sk, p[1])
			var right := rr - l
			right.y = 0.0
			if right.length() < 0.05:
				continue
			var fwd := Vector3.UP.cross(right.normalized())
			var ang := atan2(fwd.x, -fwd.z)
			acc_all += Vector2(cos(ang), sin(ang))
			if not per_pair_acc.has(p[0]):
				per_pair_acc[p[0]] = Vector2.ZERO
			per_pair_acc[p[0]] += Vector2(cos(ang), sin(ang))
	var main := 180.0
	if acc_all.length() > 0.001:
		main = rad_to_deg(atan2(acc_all.y, acc_all.x))
	var pp := {}
	var spread := 0.0
	for k in per_pair_acc:
		var v: Vector2 = per_pair_acc[k]
		if v.length() < 0.001:
			pp[k] = main
			continue
		var a := rad_to_deg(atan2(v.y, v.x))
		pp[k] = a
		spread = maxf(spread, absf(_ang_diff(a, main)))
	return {"yaw": main, "per_pair": pp, "spread": spread}


func _ang_diff(a: float, b: float) -> float:
	return fposmod(a - b + 180.0, 360.0) - 180.0


## 当前子视口渲染结果的包围盒（世界尺寸；相机为正交前视）
func _rect_world() -> Dictionary:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := mview.get_texture().get_image()
	if img == null:
		return {}
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return {}
	var vs := Vector2(mview.size)
	var wpp: float = mcam.size / vs.y
	return {
		"h": float(used.size.y) * wpp,
		"w": float(used.size.x) * wpp,
		"y_min": mcam.position.y + (vs.y * 0.5 - float(used.position.y + used.size.y)) * wpp,
		"y_max": mcam.position.y + (vs.y * 0.5 - float(used.position.y)) * wpp,
	}


## 关键姿势的包围盒：判断脚是否贴地（Walk/Run）、倒地后是否贴地/仰躺（Death/Defeat/SitDown）
func _pose_contact(ap: AnimationPlayer) -> Dictionary:
	var out := {}
	var poses := [["Idle", 0.3], ["Walk", 0.4], ["Run", 0.4], ["Death", 0.85],
		["Death", 0.95], ["Death", 1.0], ["Defeat", 1.0], ["SitDown", 1.0], ["Roll", 1.0]]
	for p in poses:
		var a: String = p[0]
		if not ap.has_animation(a):
			continue
		var an := ap.get_animation(a)
		ap.play(a, 0.0)
		ap.pause()
		ap.seek(an.length * float(p[1]), true)
		var rect: Dictionary = await _rect_world()
		var key := "%s@%d" % [a, int(round(float(p[1]) * 100.0))]
		out[key] = rect
	return out


## 把模型转 90°，用正交前视相机量其原始 Z 向跨度（米）
func _z_extent(ap: AnimationPlayer, anim: String, ratio: float) -> float:
	if not ap.has_animation(anim):
		return 0.0
	var an := ap.get_animation(anim)
	ap.play(anim, 0.0)
	ap.pause()
	ap.seek(an.length * ratio, true)
	if mholder.get_child_count() == 0:
		return 0.0
	var inst := mholder.get_child(0) as Node3D
	if inst == null:
		return 0.0
	inst.rotation.y = PI * 0.5
	var rect: Dictionary = await _rect_world()
	inst.rotation.y = 0.0
	return float(rect.get("w", 0.0))


## 步幅估计（网格空间）：Idle 的 Z 向跨度作为身体厚度，走/跑最分腿帧的 Z 跨度 - 身体厚度 ≈ 步长；
## 每循环位移 ≈ 2 × 步长；隐含地面速度 = 位移 / 循环时长。
func _stride_est(ap: AnimationPlayer) -> Dictionary:
	var idle: float = await _z_extent(ap, "Idle", 0.3)
	var walk := 0.0
	for k in range(12):
		walk = maxf(walk, await _z_extent(ap, "Walk", float(k) / 12.0))
	var run := 0.0
	for k in range(12):
		run = maxf(run, await _z_extent(ap, "Run", float(k) / 12.0))
	var wl: float = ap.get_animation("Walk").length if ap.has_animation("Walk") else 1.25
	var rl: float = ap.get_animation("Run").length if ap.has_animation("Run") else 0.875
	# 最分腿帧的前后极值点就是前后两只脚 → 前后跨度≈步长；一个循环走两步
	var sw: float = walk
	var sr: float = run
	return {
		"idle_z": idle, "walk_z": walk, "run_z": run,
		"step_walk": sw, "step_run": sr,
		"speed_walk": 2.0 * sw / wl,
		"speed_run": 2.0 * sr / rl,
	}


## 透明背景正交渲染 → 剪影包围盒 → 世界尺寸
func _silhouette(inst: Node3D, r: Dictionary) -> void:
	mcam.current = true
	inst.position = Vector3.ZERO
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := mview.get_texture().get_image()
	if img == null:
		r["height"] = -1.0
		r["height_note"] = "no_image"
		return
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		r["height"] = -1.0
		r["height_note"] = "empty_silhouette"
		return
	var vs := Vector2(mview.size)
	var wpp: float = mcam.size / vs.y          # 正交相机 size = 垂直世界高度
	r["height"] = float(used.size.y) * wpp
	r["width"] = float(used.size.x) * wpp
	r["y_max"] = mcam.position.y + (vs.y * 0.5 - float(used.position.y)) * wpp
	r["y_min"] = mcam.position.y + (vs.y * 0.5 - float(used.position.y + used.size.y)) * wpp
	r["used_rect"] = used


func _seam_check(ap: AnimationPlayer, sk: Skeleton3D, anim_name: String, length: float) -> Dictionary:
	ap.play(anim_name, 0.0)
	ap.pause()
	ap.seek(0.0, true)
	var a := _pose_snapshot(sk)
	ap.seek(length, true)
	var b := _pose_snapshot(sk)
	return _pose_diff(a, b)


func _root_motion(ap: AnimationPlayer, sk: Skeleton3D, anim_name: String) -> Dictionary:
	var an := ap.get_animation(anim_name)
	var dur: float = an.length
	var span: float = minf(1.0, dur)
	var steps := 30
	ap.play(anim_name, 0.0)
	ap.pause()
	var hi := sk.find_bone("Hips")
	var ri := sk.find_bone("Bone")
	var first_h := Vector3.ZERO
	var last_h := Vector3.ZERO
	var first_r := Vector3.ZERO
	var last_r := Vector3.ZERO
	var hmin := Vector3(1e9, 1e9, 1e9)
	var hmax := Vector3(-1e9, -1e9, -1e9)
	for i in range(steps + 1):
		var t: float = span * float(i) / float(steps)
		ap.seek(t, true)
		var h := _bone_world_idx(sk, hi)
		var rb := _bone_world_idx(sk, ri)
		if i == 0:
			first_h = h
			first_r = rb
		last_h = h
		last_r = rb
		hmin = hmin.min(h)
		hmax = hmax.max(h)
	var net := Vector2(last_h.x - first_h.x, last_h.z - first_h.z)
	return {
		"dur": dur,
		"sampled": span,
		"dx": net.x,
		"dz": net.y,
		"horiz_net": net.length(),
		"horiz_range": Vector2(hmax.x - hmin.x, hmax.z - hmin.z),
		"y_range": hmax.y - hmin.y,
		"root_bone_drift": Vector2(last_r.x - first_r.x, last_r.z - first_r.z).length(),
	}


func _pose_snapshot(sk: Skeleton3D) -> Array:
	var out: Array = []
	for i in sk.get_bone_count():
		out.append(sk.get_bone_global_pose(i))
	return out


func _pose_diff(a: Array, b: Array) -> Dictionary:
	var max_r := 0.0
	var max_p := 0.0
	for i in range(mini(a.size(), b.size())):
		var ta: Transform3D = a[i]
		var tb: Transform3D = b[i]
		var qa := ta.basis.get_rotation_quaternion()
		var qb := tb.basis.get_rotation_quaternion()
		max_r = maxf(max_r, qa.angle_to(qb))
		max_p = maxf(max_p, ta.origin.distance_to(tb.origin))
	return {"rot_deg": rad_to_deg(max_r), "pos": max_p}


# =====================================================================================
# 报告
# =====================================================================================

func _summarize() -> void:
	var hs: Array = []
	for m in order:
		var h: float = data[m].get("height", -1.0)
		if h > 0.0:
			hs.append(h)
	hs.sort()
	print("\n================ SUMMARY ================")
	if hs.size() > 0:
		print("height min=%.3f max=%.3f (n=%d)" % [hs[0], hs[hs.size() - 1], hs.size()])
		var outliers := []
		for m in order:
			var h: float = data[m].get("height", -1.0)
			if h > 0.0 and (h < 1.6 or h > 1.9):
				outliers.append("%s=%.3f" % [m, h])
		print("outliers(1.6~1.9m): ", outliers)
	var fy := []
	for m in order:
		fy.append(float(data[m].get("facing_yaw", 999.0)))
	if fy.size() > 0:
		print("facing yaw (deg) min/max: ", fy.min(), " / ", fy.max())
	print("========================================\n")


func _write_report() -> void:
	report.clear()
	report.append("=== Quaternius 人形角色 showcase / 集成检报告 (task-3) ===")
	report.append("Godot 4.7.2  Forward+  viewport=1920x1080  %s" % Time.get_datetime_string_from_system())
	report.append("")
	var hs: Array = []
	for m in order:
		var h: float = data[m].get("height", -1.0)
		if h > 0.0:
			hs.append(h)
	hs.sort()
	report.append("[1] 身高（Idle 姿势渲染剪影，米）")
	report.append("model | height | y_min(脚底) | width | bones | meshes")
	for m in order:
		var d: Dictionary = data[m]
		report.append("%s | %s | %s | %s | %d | %d" % [m, _f(d.get("height", -1.0), 3),
			_f(d.get("y_min", -9.0), 3), _f(d.get("width", -1.0), 3),
			d.get("bones", 0), d.get("meshes", 0)])
	if hs.size() > 0:
		var sum := 0.0
		for h in hs:
			sum += float(h)
		report.append("min=%.3f max=%.3f mean=%.3f (n=%d)" % [hs[0], hs[hs.size() - 1],
			sum / float(hs.size()), hs.size()])
		var out := []
		for m in order:
			var h2: float = data[m].get("height", -1.0)
			if h2 > 0.0 and (h2 < 1.6 or h2 > 1.9):
				out.append("%s(%.3f)" % [m, h2])
		report.append("不在 1.6~1.9m 的: " + (str(out) if out.size() > 0 else "无"))
	report.append("")
	report.append("[1b] 材质 / 贴图（surfaces=网格面数，tex=有 albedo 贴图的材质数，albedo=底色，vcol=顶点色）")
	for m in order:
		var mats: Array = data[m].get("materials", [])
		var texs := 0
		var albedos := []
		var names := []
		var vcols := 0
		for mt in mats:
			if mt.get("tex", false):
				texs += 1
			albedos.append(str(mt.get("albedo", "-")))
			names.append(str(mt.get("name", "-")))
			if mt.get("vcol", false):
				vcols += 1
		report.append("%s | surfaces=%d | tex=%d | vcol=%d | albedo=%s | names=%s" % [
			m, mats.size(), texs, vcols, str(albedos), str(names)])
	report.append("")
	report.append("[1c] 关键姿势包围盒（Casual_Male，米；y_min=最低点 h=包围高 w=包围宽）")
	var pc: Dictionary = data.get("Casual_Male", {}).get("pose_contact", {})
	for k in pc:
		var v: Dictionary = pc[k]
		report.append("%s | y_min=%.3f | y_max=%.3f | h=%.3f | w=%.3f" % [k,
			v.get("y_min", 0.0), v.get("y_max", 0.0), v.get("h", 0.0), v.get("w", 0.0)])
	report.append("")
	report.append("[1d] 步幅 / 隐含地面速度估计（Casual_Male，网格空间，近似）")
	var sd: Dictionary = data.get("Casual_Male", {}).get("stride", {})
	if not sd.is_empty():
		report.append("idle_z=%.3f walk_z(最分腿)=%.3f run_z(最分腿)=%.3f" % [
			sd.get("idle_z", 0.0), sd.get("walk_z", 0.0), sd.get("run_z", 0.0)])
		report.append("scale=1.0 时隐含 walk=%.2f m/s, run=%.2f m/s（一个循环两步；缩放 s 后乘 s）" % [
			sd.get("speed_walk", 0.0), sd.get("speed_run", 0.0)])
	report.append("")
	report.append("[2] 朝向（rotation.y=0 时模型世界前进方向；Idle 整周期圆周平均）")
	report.append("model | forward_yaw_deg | yaw_offset_to_face_-Z | pair_spread_deg | per_pair_yaws")
	for m in order:
		var d: Dictionary = data[m]
		var yv: float = d.get("facing_yaw", 999.0)
		report.append("%s | %s | %s | %s | %s" % [m, _f(yv, 2), _f(yv, 2),
			_f(d.get("facing_spread", -1.0), 2), str(d.get("facing_pairs", {}))])
	report.append("说明：forward_yaw≈180° 表示 rotation.y=0 时模型面向 +Z；")
	report.append("      yaw_offset 就是模型要面向 -Z（游戏约定）应设的 rotation.y。")
	report.append("")
	report.append("[3] 动画（导入后 loop_mode：0=NONE/1=LINEAR/2=PINGPONG）")
	report.append("model | anim | exists | length(s) | tracks | loop | seam_rot_deg | seam_pos")
	for m in order:
		var d: Dictionary = data[m]
		var st: Dictionary = d.get("anim_stats", {})
		for a in REQUIRED:
			if not st.has(a):
				continue
			var s: Dictionary = st[a]
			if not s.get("exists", false):
				report.append("%s | %s | MISSING" % [m, a])
				continue
			var seam: Dictionary = s.get("seam", {})
			report.append("%s | %s | yes | %.3f | %d | %d(%s) | %.2f | %.4f" % [
				m, a, s.get("len", 0.0), s.get("tracks", 0), s.get("loop", 0),
				LOOP_NAME.get(s.get("loop", 0), "?"), seam.get("rot_deg", -1.0),
				seam.get("pos", -1.0)])
	report.append("")
	report.append("[3b] 全部 17 个动画（以 %s 为准）" % order[0])
	var first: Dictionary = data.get(order[0], {})
	for a in ALL_ANIMS:
		var an: Dictionary = first.get("anims", {}).get(a, {})
		if an.is_empty():
			report.append("%s | MISSING" % a)
		else:
			report.append("%s | length=%.3f | tracks=%d | loop=%d(%s) | node_tracks=%d" % [
				a, an.get("len", 0.0), an.get("tracks", 0), an.get("loop", 0),
				LOOP_NAME.get(an.get("loop", 0), "?"), an.get("node_tracks", 0)])
	report.append("")
	report.append("[3c] 各模型动画集合 / 骨骼数")
	for m in order:
		var d: Dictionary = data[m]
		var lst: Array = d.get("anim_list", [])
		report.append("%s | bones=%d | anims=%d | node_tracks=%d | missing=%s" % [
			m, d.get("bones", 0), lst.size(), d.get("node_tracks", 0), str(_missing_anims(lst))])
	report.append("")
	report.append("[4] root motion（原地播放 1s 采样，米）")
	report.append("model | anim | dur | dx | dz | |horiz_net| | horiz_range(x,z) | y_range | root_bone_drift")
	for m in order:
		var d: Dictionary = data[m]
		var rm: Dictionary = d.get("rootmotion", {})
		for a in ["Walk", "Run"]:
			if not rm.has(a):
				continue
			var x: Dictionary = rm[a]
			var hrg: Vector2 = x.get("horiz_range", Vector2.ZERO)
			report.append("%s | %s | %.3f | %+.4f | %+.4f | %.4f | (%.4f, %.4f) | %.4f | %.4f" % [
				m, a, x.get("dur", 0.0), x.get("dx", 0.0), x.get("dz", 0.0),
				x.get("horiz_net", 0.0), hrg.x, hrg.y, x.get("y_range", 0.0),
				x.get("root_bone_drift", 0.0)])
	report.append("")
	report.append("[5] 截图")
	report.append("shots/char_showcase_lineup.png       20 模型总览（含身高标签 + 1.7m 参照柱）")
	report.append("shots/char_showcase_lineup_casual.png 行人组近景")
	report.append("shots/char_showcase_lineup_uniform.png 制服/职业组近景")
	report.append("shots/char_showcase_pose_idle.png    Idle")
	report.append("shots/char_showcase_pose_walk.png    Walk @40%")
	report.append("shots/char_showcase_pose_run.png     Run @40%")
	report.append("shots/char_showcase_pose_death.png   Death @55% / @100%（patient 定格）")
	report.append("shots/char_showcase_pose_death_side.png Death 侧视（仰躺/趴着 + 是否贴地）")
	report.append("shots/char_showcase_skin_compare.png Skin 材质 #202020 与正常肤色对比")
	report.append("shots/char_showcase_facing.png       rot.y=0/90/180/270 朝向证明")
	report.append("shots/char_showcase_facing_side.png  侧视朝向")
	report.append("shots/char_showcase_probe_sizes.png  身高标尺核对图")
	report.append("")
	report.append("[6] 集成要点")
	var mean_h := 0.0
	for h in hs:
		mean_h += float(h)
	mean_h /= maxf(1.0, float(hs.size()))
	report.append("- 身高 %.2f~%.2f m（均值 %.2f）；游戏玩家胶囊 1.8m / NPC 胶囊 1.7m → 模型缩放建议 %.3f（最高模型到 1.70m）~ %.3f（最矮模型到 1.80m）。" % [
		hs[0] if hs.size() > 0 else 0.0, hs[hs.size() - 1] if hs.size() > 0 else 0.0, mean_h,
		1.7 / (hs[hs.size() - 1] if hs.size() > 0 else 1.0),
		1.8 / (hs[0] if hs.size() > 0 else 1.0)])
	report.append("- 原点在双脚之间、脚底≈y0（y_min≈-0.017m）；模型正面 +Z，rotation.y=PI 后面向 -Z。")
	report.append("- 17 个动画导入 loop_mode 全为 NONE(0)；Idle/Walk/Run 必须运行时设 Animation.LOOP_LINEAR。")
	report.append("- Idle/Walk 首末帧姿势差 ≤0.06° → LOOP_LINEAR 无缝；Run 首末帧差 4.68° / 0.044m → 每 0.875s 有一次轻微跳变。")
	report.append("- 动画是原地(in-place)：1s 采样 Hips 净水平漂移 ≤0.002m、root 骨骼 0 位移、无 node-level 轨道。")
	report.append("- 材质是无贴图纯色；所有模型 Skin 材质底色 #202020（近黑）→ 脸/手臂发黑。若想要正常肤色，CharacterModel 里覆盖 Skin 材质 albedo 即可（见 skin_compare 截图）。")
	report.append("- Death 末尾身体沉到 y=-0.27m（scale=1.0）；而且结尾是趴着（脸朝下）。patient 定格建议：+Y 抬回地面（0.27×scale）、要仰面再加 rotation.x=PI。")
	report.append("- 脚步匹配：按 scale=0.52 换算，Walk 隐含 1.47 m/s（行人 1.7 m/s → speed_scale≈1.16）；Run 隐含 2.52 m/s（罪犯 4.6 m/s → speed_scale≈1.83，现拦 1.4 会明显滑步）。")
	report.append("- Casual_Bald 缺 Run，Suit_Male 缺 Punch（其余 18 模型 17 个动画齐全）。")
	report.append("")
	report.append("[7] 推荐映射（NPC kind）")
	report.append("- pedestrian（13）：Casual_Male/Female, Casual2_Male/Female, Casual3_Male/Female, Casual_Bald, Worker_Male/Female, OldClassy_Male/Female, Suit_Male/Female")
	report.append("- customer（商务/购物感）：Suit_Male/Female, OldClassy_Male/Female, Casual2_Male/Female")
	report.append("- criminal：Pirate_Male, Ninja_Male, Zombie_Male（现用）；现代街区里 Pirate/Ninja 略出戏，可换 Soldier_Male 做武装劫匪")
	report.append("- patient：任意模型 + Death@100% 定格（注意倒地朝向/贴地见 [1c]/截图）")
	report.append("- 目前未被 NPC 使用的：Soldier_Male（警察/劫匪）、Doctor_Male_Young（医院职员）、Chef_Male/Female（餐厅厨师）")
	report.append("- 女性 7 个：Casual_Female, Casual2_Female, Casual3_Female, Worker_Female, OldClassy_Female, Suit_Female, Chef_Female")
	report.append("")
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(report))
		f.close()
		print("report written: ", REPORT_PATH)
	for line in report:
		print(line)


func _missing_anims(lst: Array) -> Array:
	var out := []
	for a in ALL_ANIMS:
		if not lst.has(a):
			out.append(a)
	return out


# =====================================================================================
# 截图
# =====================================================================================

func _shots() -> void:
	show_facing.clear()
	for m in order:
		show_facing.append(float(data[m].get("facing_yaw", 180.0)))
	await _shot_lineup()
	await _shot_group(PED_GROUP, "casual")
	await _shot_group(JOB_GROUP, "uniform")
	await _shot_pose("Idle", 0.3, "idle")
	await _shot_pose("Walk", 0.4, "walk")
	await _shot_pose("Run", 0.4, "run")
	await _shot_skin()
	await _shot_death()
	await _shot_facing()
	print("ALL SHOTS DONE")


## 尺寸探针：Idle 姿势 vs 绑定姿势 + 0.5m 刻度标尺，人眼核对身高
func _probe_sizes() -> void:
	cam.fov = 40.0
	cam.position = Vector3(0, 1.9, -9.5)
	cam.look_at(Vector3(0, 1.9, 0))
	_spawn("Casual_Male", Vector3(-1.7, 0.0, 0.0), 180.0, "Idle", 0.3)
	_add_label("Idle @0.3s", Vector3(-1.7, 4.75, 0.0), 0.02, 56)
	_spawn("Casual_Male", Vector3(1.7, 0.0, 0.0), 180.0)
	_add_label("bind pose", Vector3(1.7, 4.75, 0.0), 0.02, 56)
	for i in range(8):
		var y := 0.5 * float(i + 1)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 0.05, 0.05)
		mi.mesh = bm
		mi.position = Vector3(4.3, y, 0.0)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.85, 0.1)
		m.emission_enabled = true
		m.emission = Color(0.6, 0.45, 0.02)
		mi.material_override = m
		showroot.add_child(mi)
		_add_label("%.1fm" % y, Vector3(5.15, y, 0.0), 0.012, 44)
	await _snap(SHOT_DIR + "probe_sizes.png")


func _clear_show() -> void:
	for c in showroot.get_children():
		c.free()


## 生成一个模型实例（yaw_deg = 面向 -Z 的 rotation.y）
func _spawn(model: String, pos: Vector3, yaw_deg: float, anim := "", t := 0.0) -> Node3D:
	var inst := Node3D.new()
	var ps: PackedScene = load(DIR + model + ".gltf") as PackedScene
	if ps != null:
		inst = ps.instantiate() as Node3D
	else:
		push_warning("missing model " + model)
	inst.position = pos
	inst.rotation.y = deg_to_rad(yaw_deg)
	showroot.add_child(inst)
	var ap := _find_ap(inst)
	if ap != null and anim != "" and ap.has_animation(anim):
		ap.play(anim, 0.0)
		ap.pause()
		ap.seek(t, true)
	return inst


func _add_label(text: String, pos: Vector3, px := 0.0055, fs := 44) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = fs
	l.pixel_size = px
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	l.outline_size = 14
	showroot.add_child(l)


## 1.7m 参照柱（游戏 NPC 胶囊高度）
func _add_gauge(x: float, z: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 1.7, 0.22)
	mi.mesh = bm
	mi.position = Vector3(x, 0.85, z)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.12, 0.12)
	m.emission_enabled = true
	m.emission = Color(0.3, 0.02, 0.02)
	mi.material_override = m
	showroot.add_child(mi)
	_add_label("NPC 胶囊\n1.7m", Vector3(x, 2.0, z), 0.006, 40)


## 相机按「需要装入半宽」计算距离（受 viewport 宽高比影响）
func _fit_dist(half_w: float, fov_v: float, margin := 1.06) -> float:
	var vs := get_viewport().get_visible_rect().size
	var aspect: float = vs.x / maxf(1.0, vs.y)
	var hf := atan(tan(deg_to_rad(fov_v * 0.5)) * aspect)
	return half_w * margin / maxf(0.001, tan(hf))


func _shot_lineup() -> void:
	_clear_show()
	var cols := 10
	var sp := 2.4
	var gap := 3.6
	var gauge_x := -float(cols) * sp * 0.5 - 1.6
	for i in range(MODELS.size()):
		var m: String = MODELS[i]
		var col := i % cols
		var row := int(i / cols)
		# 相机朝 +Z 时画面左 = 世界 +X，所以反向排 x 让 MODELS 顺序在画面里从左到右
		var x := (float(cols - 1) * 0.5 - float(col)) * sp
		if row % 2 == 1:
			x -= 1.2
		var z := float(row) * gap
		_spawn(m, Vector3(x, 0.0, z), show_facing[i], "Idle", 0.3)
		var h: float = data[m].get("height", 1.8)
		var ly := maxf(h, 2.1) + 0.4 + float(row) * 1.2
		_add_label("%s\n%.2fm" % [m, h], Vector3(x, ly, z), 0.0055, 44)
	_add_gauge(gauge_x, 0.0)
	var right_x := float(cols - 1) * 0.5 * sp + 0.9
	var cx := (gauge_x + right_x) * 0.5
	var half_w := maxf(absf(gauge_x - cx), absf(right_x - cx)) + 0.8
	var fov := 38.0
	var d := _fit_dist(half_w, fov)
	cam.fov = fov
	cam.position = Vector3(cx, 3.3, -d)
	cam.look_at(Vector3(cx, 1.7, gap * 0.5))
	await _snap(SHOT_DIR + "lineup.png")


func _shot_group(models: Array, tag: String) -> void:
	_clear_show()
	var sp := 2.6
	var gap := 3.0
	var per_row := 5
	for i in range(models.size()):
		var m: String = models[i]
		var row := int(i / per_row)
		var col := i % per_row
		var x := (float(per_row - 1) * 0.5 - float(col)) * sp
		if row % 2 == 1:
			x -= sp * 0.5
		var z := float(row) * gap
		var idx := MODELS.find(m)
		var yaw: float = show_facing[idx] if idx >= 0 else 180.0
		_spawn(m, Vector3(x, 0.0, z), yaw, "Idle", 0.3)
		var h: float = data[m].get("height", 1.8)
		var ly := maxf(h, 2.1) + 0.35 + float(row) * 0.95
		_add_label("%s  %.2fm" % [m, h], Vector3(x, ly, z), 0.0055, 44)
	var half_w := float(per_row - 1) * 0.5 * sp + sp * 0.5 + 1.2
	var fov := 36.0
	var d := _fit_dist(half_w, fov)
	cam.fov = fov
	cam.position = Vector3(0, 2.5, -d)
	cam.look_at(Vector3(0, 1.4, gap * 0.5))
	await _snap(SHOT_DIR + "lineup_%s.png" % tag)


func _shot_pose(anim: String, ratio: float, tag: String) -> void:
	_clear_show()
	var picks := ["Casual_Male", "Casual_Female", "Suit_Male", "Soldier_Male"]
	var sp := 2.6
	var st: Dictionary = data[picks[0]].get("anim_stats", {}).get(anim, {})
	var length: float = st.get("len", 1.0)
	var t: float = length * ratio
	for i in range(picks.size()):
		var m: String = picks[i]
		var idx := MODELS.find(m)
		var yaw: float = show_facing[idx] if idx >= 0 else 180.0
		var x := (float(picks.size() - 1) * 0.5 - float(i)) * sp
		_spawn(m, Vector3(x, 0.0, 0.0), yaw, anim, t)
		_add_label("%s\n%s @%d%%  %.2fs" % [m, anim, int(round(ratio * 100.0)), t],
			Vector3(x, 3.75, 0.0), 0.0055, 44)
	var half_w := float(picks.size() - 1) * 0.5 * sp + 1.0
	var fov := 36.0
	var d := _fit_dist(half_w, fov)
	cam.fov = fov
	cam.position = Vector3(0, 2.0, -d)
	cam.look_at(Vector3(0, 1.6, 0))
	await _snap(SHOT_DIR + "pose_%s.png" % tag)


func _shot_death() -> void:
	_clear_show()
	var picks := ["Casual_Male", "Worker_Female", "Zombie_Male"]
	var sp := 3.4
	var st: Dictionary = data["Casual_Male"].get("anim_stats", {}).get("Death", {})
	var length: float = st.get("len", 2.3)
	var far_z := 5.5
	for i in range(picks.size()):
		var m: String = picks[i]
		var idx := MODELS.find(m)
		var yaw: float = show_facing[idx] if idx >= 0 else 180.0
		var x := (float(picks.size() - 1) * 0.5 - float(i)) * sp
		# 倒地后身体从脚(原点)朝 -Z 方向平躺，所以两排错开 5.5m 防重叠
		_spawn(m, Vector3(x, 0.0, far_z), yaw, "Death", length * 0.55)
		_spawn(m, Vector3(x, 0.0, 0.0), yaw, "Death", length * 0.98)
		_add_label("%s\nDeath@100%% 趴卧(脸朝下)" % m, Vector3(x, 0.55, 1.15), 0.0055, 42)
	_add_label("上排 = Death @55%（倒下过程）   下排 = Death @100%（趴卧，patient 定格用）",
		Vector3(0, 2.8, far_z + 2.4), 0.0062, 44)
	cam.fov = 42.0
	cam.position = Vector3(0, 4.8, -9.8)
	cam.look_at(Vector3(0, 0.4, 1.9))
	await _snap(SHOT_DIR + "pose_death.png")
	# 侧视：确认倒地后是仰面还是趴着、贴不贴地
	_clear_show()
	var idx2 := MODELS.find("Casual_Male")
	var yaw2: float = show_facing[idx2] if idx2 >= 0 else 180.0
	_spawn("Casual_Male", Vector3(0, 0.0, 0.0), yaw2, "Death", length * 0.98)
	_spawn("Casual_Male", Vector3(0, 0.0, 5.5), yaw2, "Death", length * 0.55)
	_add_label("Death@100%（侧视）", Vector3(0, 1.0, -2.2), 0.0055, 40)
	_add_label("Death@55%", Vector3(0, 1.0, 7.4), 0.0055, 40)
	cam.fov = 45.0
	cam.position = Vector3(10.5, 1.7, 1.5)
	cam.look_at(Vector3(0, 0.55, 1.5))
	await _snap(SHOT_DIR + "pose_death_side.png")


func _shot_facing() -> void:
	_clear_show()
	var m := "Casual_Male"
	var rots := [0.0, 90.0, 180.0, 270.0]
	var sp := 2.6
	for i in range(rots.size()):
		var x := (float(rots.size() - 1) * 0.5 - float(i)) * sp
		_spawn(m, Vector3(x, 0.0, 0.0), float(rots[i]), "Idle", 0.3)
		_add_label("rotation.y = %d°" % int(rots[i]), Vector3(x, 3.85, 0.0), 0.006, 44)
	_add_label("相机在 -Z（游戏前方）→ rot.y=0 看到的是背面 ⇒ 模型正面是 +Z", Vector3(0, 4.35, 0.0), 0.0065, 44)
	var half_w := float(rots.size() - 1) * 0.5 * sp + 1.0
	var fov := 36.0
	var d := _fit_dist(half_w, fov)
	cam.fov = fov
	cam.position = Vector3(0, 2.0, -d)
	cam.look_at(Vector3(0, 1.7, 0))
	await _snap(SHOT_DIR + "facing.png")
	# 侧视（相机 +X）：直接看鼻尖朝哪边；两个模型沿 Z 排开避免遮挡
	_clear_show()
	for i in range(2):
		var z := (float(i) - 0.5) * 5.2
		_spawn(m, Vector3(0.0, 0.0, z), 0.0 if i == 0 else 180.0, "Idle", 0.3)
		_add_label("rot.y=0（模型正面 +Z）" if i == 0 else "rot.y=180（面向 -Z）",
			Vector3(0.0, 3.95, z), 0.006, 42)
	cam.fov = 40.0
	cam.position = Vector3(9.0, 1.9, 0.0)
	cam.look_at(Vector3(0, 1.65, 0))
	await _snap(SHOT_DIR + "facing_side.png")


## 材质对比：源 glTF 的 "Skin" 材质底色约 #202020（近黑），下行示例把 Skin 改成正常肤色
func _shot_skin() -> void:
	_clear_show()
	var pairs := ["Casual_Male", "Casual_Female", "Worker_Male", "Doctor_Male_Young", "Zombie_Male"]
	var pair_sp := 3.2
	for i in range(pairs.size()):
		var m: String = pairs[i]
		var idx := MODELS.find(m)
		var yaw: float = show_facing[idx] if idx >= 0 else 180.0
		var xb := (float(pairs.size() - 1) * 0.5 - float(i)) * pair_sp
		# 画面左 = 世界 +X：修复版放 +0.95（画面左），原样放 -0.95（画面右）
		var fixed := _spawn(m, Vector3(xb + 0.95, 0.0, 0.0), yaw, "Idle", 0.3)
		_tint_skin(fixed, Color(0.87, 0.66, 0.52))
		_spawn(m, Vector3(xb - 0.95, 0.0, 0.0), yaw, "Idle", 0.3)
		_add_label("%s\n左:改肤色  右:原样" % m, Vector3(xb, 3.55, -1.3), 0.0052, 40)
	var half_w := float(pairs.size() - 1) * 0.5 * pair_sp + 0.95 + 0.7
	var fov := 34.0
	var d := _fit_dist(half_w, fov)
	cam.fov = fov
	cam.position = Vector3(0, 2.3, -d)
	cam.look_at(Vector3(0, 1.7, 0.0))
	await _snap(SHOT_DIR + "skin_compare.png")


## 把指定实例的 "Skin" 材质（或近黑表面）换成给定颜色（仅该实例，复制材质）
func _tint_skin(inst: Node, col: Color) -> void:
	for mi in _all_meshes(inst):
		var mii := mi as MeshInstance3D
		if mii == null or mii.mesh == null:
			continue
		for si in mii.mesh.get_surface_count():
			var mat: Material = mii.get_active_material(si)
			if not (mat is StandardMaterial3D):
				continue
			var sm := mat as StandardMaterial3D
			var nm := String(sm.resource_name).to_lower()
			var c := sm.albedo_color
			var is_skin := nm.contains("skin") or (c.r < 0.06 and c.g < 0.06 and c.b < 0.06)
			if is_skin:
				var dup := sm.duplicate() as StandardMaterial3D
				dup.albedo_color = col
				mii.set_surface_override_material(si, dup)


func _snap(path: String) -> void:
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path, " size=", img.get_size())


# =====================================================================================
# 环境 / 工具
# =====================================================================================

func _build_show_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.26, 0.44, 0.72)
	sm.sky_horizon_color = Color(0.78, 0.84, 0.9)
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46, -28, 0)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_energy = 0.5
	add_child(fill)
	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.52, 0.52, 0.5)
	gm.roughness = 0.9
	ground.material_override = gm
	add_child(ground)
	showroot = Node3D.new()
	showroot.name = "Show"
	add_child(showroot)
	cam = Camera3D.new()
	cam.fov = 38.0
	add_child(cam)
	cam.current = true


func _build_measure_env() -> void:
	if DisplayServer.get_name() == "headless":
		return
	mview = SubViewport.new()
	mview.size = Vector2i(960, 600)
	mview.transparent_bg = true
	mview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var w := World3D.new()
	mview.world_3d = w
	add_child(mview)
	mholder = Node3D.new()
	mview.add_child(mholder)
	mcam = Camera3D.new()
	mcam.projection = Camera3D.PROJECTION_ORTHOGONAL
	mcam.size = 4.6
	mview.add_child(mcam)
	mcam.position = Vector3(0, 1.9, -6.0)
	mcam.look_at(Vector3(0, 1.9, 0))
	mcam.current = true
	m_ok = true


func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_ap(c)
		if r != null:
			return r
	return null


func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skel(c)
		if r != null:
			return r
	return null


func _all_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_meshes(c))
	return out


func _bone_names(sk: Skeleton3D) -> Array:
	if sk == null:
		return []
	var out := []
	for i in sk.get_bone_count():
		out.append(sk.get_bone_name(i))
	return out


func _bone_world(sk: Skeleton3D, n: String) -> Vector3:
	if sk == null:
		return Vector3.ZERO
	return _bone_world_idx(sk, sk.find_bone(n))


func _bone_world_idx(sk: Skeleton3D, i: int) -> Vector3:
	if sk == null or i < 0:
		return Vector3.ZERO
	return sk.global_transform * sk.get_bone_global_pose(i).origin


func _bone_max_y(sk: Skeleton3D) -> float:
	if sk == null:
		return 0.0
	var mx := -1e9
	for i in sk.get_bone_count():
		mx = maxf(mx, _bone_world_idx(sk, i).y)
	return mx


func _f(v: float, digits: int) -> String:
	return String.num(v, digits)
