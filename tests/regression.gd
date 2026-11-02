extends Node
## Real state transitions and scene integration. Any failed check exits nonzero.

var failures := 0
var checks := 0
var world: Node3D

func _ready() -> void:
	_run.call_deferred()

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: ", description)

func _run() -> void:
	Game.set_process(false)
	Game.reset_new_game()
	var cash_before: int = Game.cash
	expect(not Game.try_spend(-100), "negative spending rejected")
	expect(Game.cash == cash_before, "negative spending cannot mint money")
	Game.heat = 2.0
	Game.clear_heat()
	expect(Game.cash == cash_before - 440 and Game.heat == 0.0, "fine actually charges cash")
	Game.cash = 0
	Game.heat = 5.0
	Game.clear_heat()
	expect(Game.heat == 5.0 and Game.cash == 0, "unaffordable fine preserves heat")
	Game.cash = 100000
	expect(Game.rent_shop("shopfront") and Game.set_job("clerk"), "clerk may operate rented shopfront")
	expect(Game.shops["shopfront"] == 7, "seven-day rent includes purchase day")
	Game.clock = Data.DAY_LENGTH - 0.01
	Game._process(Data.DAY_LENGTH * 7 + 0.02)
	expect(Game.day == 9 and not Game.has_shop("shopfront") and Game.job == "unemployed", "multi-day advancement expires rent and dependent job")
	Game.reset_new_game()
	Game.cash = 100000
	expect(Game.buy_vehicle("sedan"), "vehicle purchase")
	expect(not Game.upgrade_vehicle(1, "bogus"), "invalid upgrade rejected")
	expect(not Game.paint_vehicle(1, -1) and not Game.paint_vehicle(1, 999), "invalid paint indices rejected")
	expect(Game.buy_property("apt201"), "property purchase")
	var prop: Dictionary = Data.PROPERTIES[0]
	var center: Vector3 = Data.cell_center(prop["cell"]) + prop["offset"]
	cash_before = Game.cash
	expect(not Game.add_furniture("apt201", "sofa", Vector3(10000, 0, 0), 0), "furniture outside property rejected")
	expect(Game.cash == cash_before, "failed placement does not charge")
	expect(Game.add_furniture("apt201", "sofa", center, 0), "valid furniture purchased and placed")
	cash_before = Game.cash
	expect(not Game.add_furniture("apt201", "sofa", center, 0) and Game.cash == cash_before, "overlapping furniture does not charge")
	Game.remove_furniture("apt201", 0)
	var refund_cash: int = Game.cash
	Game.remove_furniture("apt201", 0)
	expect(Game.cash == refund_cash, "furniture refund cannot repeat")
	Game.set_job("police")
	var mission: Dictionary = Game.accept_mission("patrol")
	expect(not mission.is_empty() and Game.accept_mission("patrol").is_empty(), "duplicate missions rejected")
	Game.set_job("doctor")
	expect(Game.missions.is_empty(), "changing career cancels incompatible mission")
	Game.reset_new_game()
	world = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	expect(world.builder.kit_buildings.size() >= 12, "public buildings generated")
	expect(world.builder.kit_buildings[0].batched_boxes > 0, "static furniture batching is active")
	var occupied := {}
	for place in Data.PLACES:
		occupied[place["cell"]] = true
	for property in Data.PROPERTIES:
		occupied[property["cell"]] = true
	expect(Data.GRID >= 6 and occupied.size() == Data.GRID * Data.GRID, "all 36 city blocks have usable places or homes")
	expect(Game.places.has("post") and Game.places.has("east_park"), "new building and park destinations registered")
	var pedestrian: NPC = world.npc_root.get_child(0)
	var original_player: Vector3 = world.player.global_position
	pedestrian.global_position = Data.sidewalk_point(Vector2i(5, 5), 2)
	world._update_ambient_lod()
	expect(not pedestrian.is_physics_processing(), "distant ambient pedestrian sleeps without deletion")
	world.player.teleport(pedestrian.global_position + Vector3(0, 0.2, 3))
	world._update_ambient_lod()
	expect(pedestrian.is_physics_processing() and pedestrian.alive, "ambient pedestrian wakes before player arrives")
	world.player.teleport(original_player)
	expect(GameAudio.sounds["shot"].data.size() > 1000 and GameAudio.voices.size() == 12, "synthesized audio and bounded voice pool initialized")
	expect(KitLib.mesh_of("Brick_Window_Trim_Single") != null, "missing kit has visible mesh")
	var actor := CharacterModel.create("__missing_test_character")
	add_child(actor)
	expect(actor.anim_player != null and actor.anim_player.has_animation("Walk"), "missing character has animated fallback")
	actor.queue_free()
	Game.set_process(true)
	world._toggle_pause()
	var clock_before: float = Game.clock
	await get_tree().create_timer(0.15, true).timeout
	expect(get_tree().paused and Game.clock == clock_before, "pause freezes simulation")
	world._close_pause()
	expect(not get_tree().paused and not world.player.in_ui, "resume restores controls")
	await get_tree().process_frame
	await get_tree().process_frame
	expect(Game.clock > clock_before, "resumed simulation clock advances")
	Game.set_process(false)
	Game.cash = 100000
	Game.buy_vehicle("sedan")
	var vehicle: Vehicle = world.vehicles_root.get_child(0)
	vehicle.global_position += Vector3(0, 0, -3)
	var parked := vehicle.global_position
	Game.upgrade_vehicle(vehicle.uid, "engine")
	expect(world.vehicles_root.get_child(0) == vehicle and vehicle.global_position == parked, "upgrade retains vehicle node and location")
	vehicle.enter(world.player)
	await get_tree().physics_frame
	await get_tree().physics_frame
	expect(world.player.driving and world.player.shape.disabled, "driver collision disabled inside vehicle")
	world.tablet.open("vehicles")
	world.tablet.close()
	expect(not world.player.in_ui, "closing tablet while driving releases UI lock")
	vehicle.exit()
	await get_tree().physics_frame
	await get_tree().physics_frame
	expect(not world.player.driving and not world.player.shape.disabled and world.player.cam.current, "exit restores collision and camera")
	Game.set_job("police")
	mission = Game.accept_mission("patrol")
	var patrols: Array[Node] = world.missions_root.get_children()
	patrols[0]._finish()
	expect(mission["progress"] == 1.0 and mission["meta"]["visited"].size() == 1, "patrol records completed waypoint")
	expect(mission["target"] == mission["targets"][1], "patrol HUD and map advance to the next unfinished waypoint")
	patrols[1]._finish()
	patrols[2]._finish()
	expect(Game.missions.is_empty() and Game.stats["missions_done"] == 1, "patrol pays exactly once after three points")
	cash_before = Game.cash
	Game.complete_mission(int(mission["id"]))
	expect(Game.cash == cash_before, "completed mission cannot pay twice")
	mission = Game.accept_mission("arrest")
	var arrest: MissionTarget = world.missions_root.get_child(world.missions_root.get_child_count() - 1)
	arrest._npc.global_position += Vector3(10, 0, 0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	expect(mission["target"].distance_to(arrest._npc.global_position) < 1, "arrest map target tracks fleeing NPC")
	cash_before = Game.cash
	arrest._npc.take_damage(1000)
	expect(Game.missions.is_empty() and Game.cash == cash_before, "killing target cannot award arrest payment")
	Game.set_job("police")
	Game.player.weapon_sys.mag = 3
	Game.holster_weapon()
	Game.equip_weapon("glock")
	expect(Game.player.weapon_sys.mag == 3, "holstering and equipping does not refill magazine")
	Game.player.weapon_sys.mag = 2
	Game.equip_weapon("glock")
	expect(Game.player.weapon_sys.mag == 2, "equipping same weapon does not refill magazine")
	var weapon_system: WeaponSystem = Game.player.weapon_sys
	expect(weapon_system.muzzle.position.z < 0 and weapon_system.model_root.get_child(0).rotation.is_zero_approx(), "baked weapon orientation and muzzle face camera forward")
	var range_origin := Data.sidewalk_point(Vector2i(0, 0), 0) + Vector3(0, 0.2, 0)
	world.player.teleport(range_origin)
	world.player.rotation = Vector3.ZERO
	var target := NPC.spawn(world.npc_root, range_origin + Vector3(0, 0, -6), "pedestrian", Color.WHITE)
	target.set_physics_process(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	world.player.cam.look_at(target.global_position + Vector3(0, 0.9, 0))
	weapon_system._fire()
	expect(target.health < 100 and weapon_system.mag == 1, "real weapon ray damages NPC and consumes round")
	target.queue_free()
	for id in ["m4", "ak", "mac10"]:
		Game.give_weapon(id)
		Game.equip_weapon(id)
		expect(weapon_system.weapon_id == id and weapon_system.model_root.get_child_count() == 1 and weapon_system.muzzle.position.z < 0, id + " model equips with forward-facing muzzle")
	Game.save_path = "res://.artifacts/regression.save"
	expect(Game.save_game(false), "save writes and verifies snapshot")
	var saved_cash: int = Game.cash
	Game.cash += 100
	expect(Game.save_game(false), "second save replaces primary and retains backup")
	Game.cash = 0
	expect(Game.load_game(false) and Game.cash == saved_cash + 100, "save roundtrip restores economy")
	var invalid := Game.snapshot()
	invalid["health"] = NAN
	expect(not SaveValidation.valid(invalid), "non-finite state rejected")
	invalid = Game.snapshot()
	invalid["vehicles"][0]["engine"] = 99
	expect(not SaveValidation.valid(invalid), "out-of-range saved upgrade rejected")
	var corrupt := FileAccess.open(Game.save_path, FileAccess.WRITE)
	corrupt.store_string("corrupted")
	corrupt.close()
	expect(Game.load_game(false) and Game.cash == saved_cash, "corrupt primary recovers last valid backup")
	corrupt = FileAccess.open(Game.save_path + ".bak", FileAccess.WRITE)
	corrupt.store_string("corrupted")
	corrupt.close()
	Game.cash = 777
	expect(not Game.load_game(false) and Game.cash == 777, "unreadable saves never reset current game")
	Game.save_path = "user://saves/city.save"
	Game.health = 80
	world._last_sky_day_f = -1
	world._update_sky()
	var sky_update: float = world._last_sky_day_f
	world._update_sky()
	expect(world._last_sky_day_f == sky_update, "unchanged daylight does not rebuild sky radiance")
	Game.cash = 100000
	Game.buy_property("apt201")
	expect(Game.add_furniture("apt201", "sofa", center, 0), "furniture ready for scene restoration")
	Game.set_job("courier")
	mission = Game.accept_mission("parcel")
	expect(not mission.is_empty() and mission["target"].is_equal_approx(Game.place_pos("post")), "courier starts at post office")
	var parcel: MissionTarget = world.missions_root.get_child(world.missions_root.get_child_count() - 1)
	cash_before = Game.cash
	parcel._finish()
	expect(mission["progress"] == 1.0 and Game.cash == cash_before and not parcel.done, "pickup advances stage without paying")
	Game.save_path = "res://.artifacts/city-restore.save"
	expect(Game.save_game(false), "mid-delivery state saved")
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	expect(Game.world == null and Game.player == null, "scene teardown clears global references")
	expect(Game.load_game(false), "mid-delivery save loads")
	world = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	expect(world.decor_root.get_child_count() == 1 and world.vehicles_root.get_child_count() == 1, "scene reconstructs furniture and vehicles")
	expect(world.missions_root.get_child_count() == 1, "scene reconstructs in-progress delivery")
	parcel = world.missions_root.get_child(0)
	expect(parcel.prompt_text.contains("交付"), "loaded parcel resumes delivery rather than pickup")
	cash_before = Game.cash
	parcel._finish()
	expect(Game.missions.is_empty() and Game.cash == cash_before + 420, "delivered parcel pays exactly once")
	cash_before = Game.cash
	world.discover_place("museum")
	world.discover_place("museum")
	expect(Game.cash == cash_before + 75, "landmark discovery only rewards first visit")
	world.player.teleport(center)
	world.on_property_door("apt201")
	expect(Game.health == 100 and Game.stamina == 100, "owned home provides rest interaction")
	Game.save_path = "user://saves/city.save"
	world.queue_free()
	await get_tree().process_frame
	print("REGRESSION: ", checks, " checks, ", failures, " failures")
	await GameAudio.finish_shutdown()
	get_tree().quit(1 if failures else 0)
