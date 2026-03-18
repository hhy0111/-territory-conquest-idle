extends RefCounted

const MapGeneratorScript = preload("res://scripts/map/map_generator.gd")
const TileResolverScript = preload("res://scripts/map/tile_resolver.gd")


func run() -> Array:
	var failures: Array = []
	var map_data: Dictionary = MapGeneratorScript.generate_initial_map(12345, 2)
	var tiles: Dictionary = map_data.get("tiles", {})

	if tiles.size() != 25:
		failures.append("Expected 25 tiles for radius 2, got %s" % tiles.size())

	var center_key := MapGeneratorScript.coord_key(0, 0)
	if String(tiles.get(center_key, {}).get("state", "")) != "captured":
		failures.append("Expected center tile to be captured.")

	var selectable_count := 0
	for tile in tiles.values():
		if String(tile.get("state", "")) == "selectable":
			selectable_count += 1

	if selectable_count != 4:
		failures.append("Expected 4 starting selectable tiles, got %s" % selectable_count)

	var dummy_run := {
		"captured_tiles": 0,
		"danger": 0,
		"gold": 0,
		"xp": 0,
		"level": 1,
		"map": map_data
	}

	var tile_defs := {
		"plains": {
			"base_reward": { "gold": [8, 10], "xp": [10, 12] },
			"risk_delta": 2
		}
	}
	var result := TileResolverScript.capture_tile(dummy_run, MapGeneratorScript.coord_key(1, 0), tile_defs)
	if int(result.get("captured_tiles", 0)) != 1:
		failures.append("Expected one captured tile after capture.")

	return failures
