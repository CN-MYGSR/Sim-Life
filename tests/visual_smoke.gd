extends Node
## Real renderer capture of city, map, interiors, weapon and night lighting.

var world: Node3D

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual smoke requires a rendering display")
		get_tree().quit(1)
		return
	Game.reset_new_game()
	Game.set_process(false)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	world = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	world.player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _shot("city_day")
	world.tablet.open("map")
	await _shot("city_map")
	world.tablet.close()
	var overview := Camera3D.new()
	world.add_child(overview)
	overview.global_position = Vector3(0, 320, 220)
	overview.look_at(Vector3.ZERO)
	overview.far = 1000
	overview.current = true
	await _shot("city_overview")
	overview.queue_free()
	world.player.cam.current = true
	Game.set_job("police")
	var police: Vector3 = Data.cell_center(Vector2i(0, 0))
	world.player.teleport(police + Vector3(0, 0.1, 3))
	world.player.rotation.y = 0
	await _shot("interior_weapon")
	Game.clock = 21.0 / 24.0 * Data.DAY_LENGTH
	world._last_sky_day_f = -1
	world._update_sky()
	world.player.teleport(police + Vector3(0, 0.1, 18))
	world.player.rotation.y = PI
	await _shot("city_night")
	print("VISUAL_SMOKE_DONE")
	get_tree().quit()

func _shot(label: String) -> void:
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.artifacts/visual")
	var error := get_viewport().get_texture().get_image().save_png("res://.artifacts/visual/" + label + ".png")
	if error != OK:
		push_error("Screenshot failed: " + label)
	print("VISUAL_SHOT ", label, " error=", error)
