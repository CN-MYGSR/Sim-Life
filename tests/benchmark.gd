extends Node
## Fixed-seed, fixed-camera benchmark using engine Performance monitors.
## Run with --scene res://tests/benchmark.tscn -- --output=res://.artifacts/baseline.json

var samples: Array[float] = []
var process_ms: Array[float] = []
var physics_ms: Array[float] = []
var frames := 0
var last_tick := 0
var startup_ms := 0.0
var game_scene: Node
var output := "res://.artifacts/benchmark.json"
var warmup_end := 0

func _ready() -> void:
	if Game.get("persistence_enabled") != null:
		Game.set("persistence_enabled", false)
	Game.reset_new_game()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			output = arg.substr(9)
	seed(20261102)
	var start := Time.get_ticks_usec()
	game_scene = load("res://scenes/main.tscn").instantiate()
	add_child(game_scene)
	seed(20261102)
	Game.clock = Data.START_HOUR / 24.0 * Data.DAY_LENGTH
	Game.set_process(false)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280, 720))
	startup_ms = (Time.get_ticks_usec() - start) / 1000.0
	print("BENCHMARK_READY startup_ms=", startup_ms, " output=", output)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	last_tick = Time.get_ticks_usec()
	warmup_end = last_tick + 3000000

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	frames += 1
	if frames > 120 and now >= warmup_end:
		samples.append((now - last_tick) / 1000.0)
		process_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	last_tick = now
	if samples.size() == 600:
		var active_npcs := 0
		for npc in game_scene.npc_root.get_children():
			if npc.is_physics_processing():
				active_npcs += 1
		var sorted := samples.duplicate()
		sorted.sort()
		var result := {
			"engine": Engine.get_version_info().string,
			"renderer": RenderingServer.get_current_rendering_method(),
			"viewport": str(get_viewport().get_visible_rect().size),
			"display": DisplayServer.get_name(),
			"grid": Data.GRID, "warmup_frames": frames - samples.size(), "warmup_min_seconds": 3, "sample_frames": samples.size(),
			"startup_ms": startup_ms, "frame_mean_ms": _mean(samples),
			"frame_p50_ms": sorted[sorted.size() / 2], "frame_p95_ms": sorted[int(sorted.size() * 0.95)],
			"process_mean_ms": _mean(process_ms), "physics_mean_ms": _mean(physics_ms),
			"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
			"memory_static_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
			"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
			"gpu": RenderingServer.get_video_adapter_name(),
			"ssao_enabled": game_scene.env.ssao_enabled,
			"npc_physics_active": active_npcs,
			"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"rendered_objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
			"rendered_primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		}
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			push_error("Cannot write benchmark: " + output)
			get_tree().quit(1)
			return
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
		print("BENCHMARK ", JSON.stringify(result))
		set_process(false)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(output.get_basename() + ".png")
		var game_audio := get_node_or_null("/root/GameAudio")
		if game_audio != null and game_audio.has_method("shutdown"):
			game_audio.shutdown()
			await get_tree().create_timer(0.12, true).timeout
		get_tree().quit()

func _mean(values: Array[float]) -> float:
	var total := 0.0
	for value in values:
		total += value
	return total / max(1, values.size())
