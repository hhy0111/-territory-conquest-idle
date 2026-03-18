extends RefCounted
class_name MapGenerator

const DEFAULT_RADIUS := 3
const FALLBACK_TILE_ORDER := ["plains", "forest", "mine", "shrine", "fortress", "market"]


static func generate_initial_map(seed: int, radius: int = DEFAULT_RADIUS) -> Dictionary:
	var tiles: Dictionary = {}

	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var key: String = coord_key(x, y)
			var ring: int = abs(x) + abs(y)
			var state: String = "hidden"
			if x == 0 and y == 0:
				state = "captured"
			elif ring == 1:
				state = "selectable"
			tiles[key] = {
				"x": x,
				"y": y,
				"type": _pick_tile_type(seed, x, y, ring),
				"state": state,
				"ring": ring
			}

	return {
		"radius": radius,
		"selected_tile": "",
		"tiles": tiles
	}


static func coord_key(x: int, y: int) -> String:
	return "%s,%s" % [x, y]


static func _pick_tile_type(seed: int, x: int, y: int, ring: int) -> String:
	if x == 0 and y == 0:
		return "plains"

	var candidates: Array = _eligible_tile_candidates(ring)
	if candidates.is_empty():
		var rng_fallback: RandomNumberGenerator = RandomNumberGenerator.new()
		rng_fallback.seed = int(seed + (x * 73856093) + (y * 19349663))
		return FALLBACK_TILE_ORDER[rng_fallback.randi_range(0, FALLBACK_TILE_ORDER.size() - 1)]

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(seed + (x * 73856093) + (y * 19349663))
	var total_weight: int = 0
	for candidate_value in candidates:
		if candidate_value is Dictionary:
			total_weight += int(candidate_value.get("weight", 1))

	if total_weight <= 0:
		return String(candidates[0].get("id", "plains"))

	var roll: int = rng.randi_range(1, total_weight)
	var running_total: int = 0
	for candidate_value in candidates:
		if not (candidate_value is Dictionary):
			continue
		var candidate: Dictionary = candidate_value
		running_total += int(candidate.get("weight", 1))
		if roll <= running_total:
			return String(candidate.get("id", "plains"))

	return String(candidates[0].get("id", "plains"))


static func _eligible_tile_candidates(ring: int) -> Array:
	var tile_defs: Array = []
	if DataService:
		tile_defs = DataService.get_data_set("tiles")

	var candidates: Array = []
	for tile_value in tile_defs:
		if not (tile_value is Dictionary):
			continue
		var tile_def: Dictionary = tile_value
		var min_ring := int(tile_def.get("min_ring", 0))
		var max_ring := int(tile_def.get("max_ring", 99))
		if ring < min_ring or ring > max_ring:
			continue

		var weight := int(tile_def.get("spawn_weight", 1))
		if weight <= 0:
			continue

		candidates.append({
			"id": String(tile_def.get("id", "plains")),
			"weight": weight
		})

	return candidates
