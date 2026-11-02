extends Node
## Walk real collision geometry through every public door and staircase.

var checks := 0
var failures := 0

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	Game.reset_new_game()
	Game.set_process(false)
	var world = load("res://scenes/main.tscn").instantiate()
	add_child(world)
	var player: Player = world.player
	await get_tree().physics_frame
	await get_tree().physics_frame
	for building in world.builder.kit_buildings:
		var base: Vector3 = building.global_position
		player.teleport(base + Vector3(0, 0.3, building.d * 0.5 + 2.4))
		player.rotation.y = 0
		await _walk(90)
		_expect(player.global_position.z < base.z + building.d * 0.5 - 1.0, str(building.place["id"]) + " door")
		for floor_index in range(building.floors - 1):
			var negative: bool = floor_index % 2 == 0
			var x: float = building.stair_x0 + (1.0 if negative else 3.0)
			var z: float = building.stair_z0 + (4.7 if negative else -0.7)
			player.teleport(base + Vector3(x, floor_index * 3.0 + 0.3, z))
			player.rotation.y = 0 if negative else PI
			await _walk(150)
			_expect(player.global_position.y > (floor_index + 1) * 3.0 - 0.25, "%s stairs %d y=%.2f" % [building.place["id"], floor_index + 1, player.global_position.y])
	print("WORLD_ROUTES: ", checks, " checks, ", failures, " failures")
	get_tree().quit(1 if failures else 0)

func _walk(ticks: int) -> void:
	Input.action_press("move_forward")
	for i in range(ticks):
		await get_tree().physics_frame
	Input.action_release("move_forward")
	await get_tree().physics_frame

func _expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: ", label)
