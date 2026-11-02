extends Node
## Exercise actual input, physics, mission timing, UI suppression and driving.
var world: Node3D
var checks := 0
var failures := 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Game.reset_new_game()
	Game.set_process(false)
	world = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	for npc in world.npc_root.get_children():
		npc.set_physics_process(false)
		npc.collision_layer = 0
	await _ticks(3)
	for pair in [["police", "arrest"], ["firefighter", "fire"], ["doctor", "heal"], ["gangster", "capture"], ["gangster", "deliver"], ["gangster", "rob"], ["courier", "parcel"]]:
		Game.set_job(pair[0])
		var mission := Game.accept_mission(pair[1])
		var target: MissionTarget = world.missions_root.get_child(world.missions_root.get_child_count() - 1)
		if pair[1] != "parcel":
			target.global_position = Data.sidewalk_point(Vector2i(0, 0), 0)
		var cash_before: int = Game.cash
		world.player.teleport(target.global_position + Vector3(0, 0.2, 2))
		await _ticks(3)
		world.player.in_ui = true
		Input.action_press("interact")
		await _ticks(30)
		_expect(target.hold == 0 and target.stand == 0, pair[1] + " blocked by UI")
		Input.action_release("interact")
		world.player.in_ui = false
		if pair[1] == "fire":
			var wall := StaticBody3D.new()
			world.add_child(wall)
			wall.global_position = target.global_position + Vector3(0, 1, 1)
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(3, 3, 0.25)
			shape.shape = box
			wall.add_child(shape)
			await _ticks(2)
			Input.action_press("interact")
			await _ticks(30)
			_expect(target.hold == 0, "fire cannot be extinguished through wall")
			Input.action_release("interact")
			wall.queue_free()
			await _ticks(2)
		world.player.teleport(target.global_position + Vector3(0, 0.2, 2))
		await _ticks(2)
		Input.action_press("interact")
		await _ticks(ceili(maxf(target.hold_need, target.stand_need) * 60) + 8)
		Input.action_release("interact")
		if pair[1] == "parcel":
			_expect(Game.cash == cash_before and mission["progress"] == 1, "parcel pickup has no premature reward")
			world.player.teleport(mission["target"] + Vector3(0, 0.2, 2))
			await _ticks(3)
			Input.action_press("interact")
			await _ticks(100)
			Input.action_release("interact")
		await _ticks(3)
		_expect(Game.missions.is_empty() and Game.cash == cash_before + mission["reward"], pair[1] + " completes through actual input")
	Game.set_job("police")
	var patrol := Game.accept_mission("patrol")
	for point in patrol["targets"]:
		world.player.teleport(point + Vector3(0, 0.2, 1))
		await _ticks(5)
	_expect(Game.missions.is_empty(), "patrol completes by visiting actual waypoints")
	Game.cash = 100000
	Game.buy_vehicle("sedan")
	var vehicle: Vehicle = world.vehicles_root.get_child(0)
	vehicle.enter(world.player)
	var origin := vehicle.global_position
	Input.action_press("move_forward")
	await _ticks(90)
	Input.action_release("move_forward")
	_expect(vehicle.global_position.distance_to(origin) > 4, "driving input moves actual vehicle")
	world.tablet.open("vehicles")
	var speed_before := vehicle.speed
	Input.action_press("move_forward")
	await _ticks(30)
	Input.action_release("move_forward")
	_expect(vehicle.speed < speed_before, "vehicle coasts while tablet blocks throttle")
	world.tablet.close()
	vehicle.speed = 0
	vehicle.exit()
	await _ticks(3)
	_expect(not world.player.driving and world.player.cam.current, "driving flow exits with player camera")
	Game.cash = 100000
	Game.rent_shop("east_diner")
	Game.set_job("chef")
	world.player.teleport(Game.place_pos("east_diner"))
	await _ticks(3)
	var cash_before: int = Game.cash
	world._start_business("east_diner")
	await _ticks(500)
	_expect(not world._biz_active and Game.cash >= cash_before + 430, "new cafe completes valid business and pays")
	world._biz_cd = 0
	world._start_business("east_diner")
	cash_before = Game.cash
	Game.day = 8
	Game._decay_shop_rent()
	await _ticks(3)
	_expect(not world._biz_active and Game.cash == cash_before, "expired rent cancels active business without payment")
	for npc in world.npc_root.get_children():
		if npc.kind == "customer":
			npc.lifetime = 0.01
	await _ticks(3)
	var customers := 0
	for npc in world.npc_root.get_children():
		if npc.kind == "customer":
			customers += 1
	_expect(customers == 0, "business customers are reclaimed")
	print("GAMEPLAY_FLOW: ", checks, " checks, ", failures, " failures")
	await GameAudio.finish_shutdown()
	get_tree().quit(1 if failures else 0)

func _ticks(count: int) -> void:
	for i in range(count):
		await get_tree().physics_frame

func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: ", label)
