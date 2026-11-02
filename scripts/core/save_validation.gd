extends RefCounted
class_name SaveValidation
## Reject malformed snapshots before changing any live state.

static func valid(state: Dictionary) -> bool:
	if state.has("city_grid") and state["city_grid"] != Data.GRID:
		return false
	var explored = state.get("explored_places", [])
	if not explored is Array or explored.size() > Data.PLACES.size():
		return false
	var unique_places := []
	for place_id in explored:
		if not place_id is String or Game._find(Data.PLACES, place_id).is_empty() or place_id in unique_places:
			return false
		unique_places.append(place_id)
	for key in ["cash", "bank", "day"]:
		if not _number(state.get(key), 0 if key != "day" else 1, 1000000000):
			return false
	for key in ["health", "stamina", "heat", "clock"]:
		if not _number(state.get(key), 0, 100 if key in ["health", "stamina"] else (5 if key == "heat" else Data.DAY_LENGTH - 0.0001)):
			return false
	if not Data.JOBS.has(state.get("job", "")) or not state.get("gang") is String:
		return false
	for key in ["properties", "shops", "weapons_owned", "stats", "weapon_ammo", "player_state"]:
		if not state.get(key) is Dictionary:
			return false
	if not state.get("vehicles") is Array or not state.get("missions") is Array:
		return false
	if not state.get("weapon", "") is String or not _number(state.get("mission_seq"), 0, 1000000000):
		return false
	var player: Dictionary = state["player_state"]
	if not _position(player.get("position")) or not _number(player.get("yaw"), -100000, 100000) or not _number(player.get("pitch"), -1.5, 1.5):
		return false
	for key in ["missions_done", "earned", "arrests", "fires", "heals"]:
		if not _number(state["stats"].get(key), 0, 1000000000):
			return false
	for id in state["shops"]:
		if Game._find(Data.SHOPS, id).is_empty() or not _number(state["shops"][id], 1, 1000000000):
			return false
	for id in state["weapons_owned"]:
		if Game.weapon_info(id).is_empty() or state["weapons_owned"][id] != true:
			return false
	if state["weapon"] != "" and not state["weapons_owned"].has(state["weapon"]):
		return false
	for id in state["weapon_ammo"]:
		var info := Game.weapon_info(id)
		if info.is_empty() or not _number(state["weapon_ammo"][id], 0, info["mag"]):
			return false
	for id in state["properties"]:
		var prop := Game._find(Data.PROPERTIES, id)
		var entry = state["properties"][id]
		if prop.is_empty() or not entry is Dictionary or entry.get("owned") != true or not entry.get("furniture") is Array:
			return false
		if entry["furniture"].size() > 128:
			return false
		for furniture in entry["furniture"]:
			if not furniture is Dictionary or Game._find(Data.FURNITURE, furniture.get("id", "")).is_empty() or not _position(furniture.get("pos")) or not _number(furniture.get("rot"), -100000, 100000):
				return false
			var center: Vector3 = Data.cell_center(prop["cell"]) + prop["offset"]
			if absf(furniture["pos"].x - center.x) > prop["size"].x * 0.5 or absf(furniture["pos"].z - center.z) > prop["size"].y * 0.5:
				return false
	if state["vehicles"].size() > 12:
		return false
	var uids := []
	for vehicle in state["vehicles"]:
		if not vehicle is Dictionary or Game._find(Data.VEHICLES, vehicle.get("type", "")).is_empty() or not vehicle.get("paint") is Color:
			return false
		if not _number(vehicle.get("uid"), 1, 1000000000) or int(vehicle["uid"]) in uids:
			return false
		uids.append(int(vehicle["uid"]))
		for part in ["engine", "tires"]:
			if not _number(vehicle.get(part), 0, 3):
				return false
		if vehicle.has("position") and not _position(vehicle["position"]):
			return false
		if vehicle.has("rotation") and not _number(vehicle["rotation"], -100000, 100000):
			return false
	if state["missions"].size() > Data.MISSION_TYPES.size():
		return false
	var mission_ids := []
	var mission_types := []
	for mission in state["missions"]:
		if not mission is Dictionary or not Data.MISSION_TYPES.has(mission.get("type", "")):
			return false
		var template: Dictionary = Data.MISSION_TYPES[mission["type"]]
		var need := 3 if mission["type"] == "patrol" else (2 if mission["type"] == "parcel" else 1)
		if mission.get("reward") != template["reward"] or mission.get("need") != need or mission.get("heat") != template["heat"] or template["job"] != state["job"]:
			return false
		if not _position(mission.get("target")) or not _number(mission.get("progress"), 0, need - 0.00001) or not mission.get("meta") is Dictionary:
			return false
		if not _number(mission.get("id"), 1, state["mission_seq"]) or int(mission["id"]) in mission_ids or mission["type"] in mission_types:
			return false
		mission_ids.append(int(mission["id"]))
		mission_types.append(mission["type"])
		if mission["type"] == "parcel" and not _position(mission.get("delivery_target")):
			return false
		if mission["type"] == "patrol":
			if not mission.get("targets") is Array or mission["targets"].size() != 3:
				return false
			for target in mission["targets"]:
				if not _position(target):
					return false
			var visited = mission["meta"].get("visited", [])
			if not visited is Array or visited.size() != int(mission["progress"]):
				return false
			var unique := []
			for point in visited:
				if not point is int or point < 0 or point > 2 or point in unique:
					return false
				unique.append(point)
	return true

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func _position(value: Variant) -> bool:
	return value is Vector3 and value.is_finite() and absf(value.x) <= Data.CITY_HALF + 10 and absf(value.z) <= Data.CITY_HALF + 10 and value.y >= -2 and value.y < 80
