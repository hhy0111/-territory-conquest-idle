extends RefCounted
class_name TileResolver

const MapGeneratorScript = preload("res://scripts/map/map_generator.gd")


static func capture_tile(run: Dictionary, coord_key: String, tile_defs: Dictionary) -> Dictionary:
	var next_run: Dictionary = run.duplicate(true)
	var map_data: Dictionary = next_run.get("map", {})
	var tiles: Dictionary = map_data.get("tiles", {})

	if not tiles.has(coord_key):
		return next_run

	var tile: Dictionary = tiles[coord_key]
	if tile.get("state", "") != "selectable":
		return next_run

	var tile_def: Dictionary = _tile_definition(String(tile.get("type", "plains")), tile_defs)
	var reward_data: Dictionary = tile_def.get("base_reward", {})
	var gold_gain := _mid_value(reward_data.get("gold", [8, 10]))
	var xp_gain := _mid_value(reward_data.get("xp", [10, 12]))

	tile["state"] = "captured"
	tiles[coord_key] = tile

	next_run["captured_tiles"] = int(next_run.get("captured_tiles", 0)) + 1
	next_run["gold"] = int(next_run.get("gold", 0)) + gold_gain
	next_run["xp"] = int(next_run.get("xp", 0)) + xp_gain
	next_run["danger"] = clampi(int(next_run.get("danger", 0)) + int(tile_def.get("risk_delta", 2)), 0, 100)
	_apply_effect_to_run(next_run, tile_def.get("capture_bonus", {}))
	next_run["level"] = GameState.level_for_xp(int(next_run.get("xp", 0)))

	_reveal_neighbors(tiles, int(tile.get("x", 0)), int(tile.get("y", 0)))
	_refresh_selectables(tiles)

	map_data["selected_tile"] = coord_key
	map_data["tiles"] = tiles
	next_run["map"] = map_data
	return next_run


static func resolve_utility_tile(run: Dictionary, coord_key: String, tile_defs: Dictionary) -> Dictionary:
	var next_run: Dictionary = capture_tile(run, coord_key, tile_defs)
	var map_tiles: Dictionary = next_run.get("map", {}).get("tiles", {})
	var tile_type: String = "utility"
	if map_tiles.has(coord_key):
		tile_type = String(map_tiles[coord_key].get("type", "utility"))

	var tile_def: Dictionary = _tile_definition(tile_type, tile_defs)
	_apply_effect_to_run(next_run, tile_def.get("utility_effect", {}))
	next_run["last_action"] = {
		"kind": "utility",
		"tile_type": tile_type
	}
	return next_run


static func _tile_definition(tile_id: String, tile_defs: Dictionary) -> Dictionary:
	if tile_defs.has(tile_id):
		return tile_defs[tile_id]
	return {
		"id": "fallback",
		"base_reward": { "gold": [8, 10], "xp": [10, 12] },
		"risk_delta": 2
	}


static func _mid_value(values: Variant) -> int:
	if values is Array and values.size() >= 2:
		return int(round((float(values[0]) + float(values[1])) * 0.5))
	return int(values)


static func _apply_effect_to_run(run: Dictionary, effect: Dictionary) -> void:
	if effect.is_empty():
		return

	var player: Dictionary = run.get("player", {}).duplicate(true)
	var current_hp := int(player.get("current_hp", 0))
	var max_hp := int(player.get("max_hp", 0))

	if effect.has("attack_flat"):
		player["attack"] = int(player.get("attack", 0)) + int(effect["attack_flat"])
	if effect.has("attack_percent"):
		player["attack"] = int(round(float(player.get("attack", 0)) * (1.0 + float(effect["attack_percent"]))))
	if effect.has("armor_flat"):
		player["armor"] = int(player.get("armor", 0)) + int(effect["armor_flat"])
	if effect.has("attack_speed"):
		player["attack_speed"] = float(player.get("attack_speed", 1.0)) + float(effect["attack_speed"])
	if effect.has("crit_rate"):
		player["crit_rate"] = float(player.get("crit_rate", 0.0)) + float(effect["crit_rate"])
	if effect.has("territory_power"):
		player["territory_power"] = float(player.get("territory_power", 0.0)) + float(effect["territory_power"])
	if effect.has("luck"):
		player["luck"] = int(player.get("luck", 0)) + int(effect["luck"])
	if effect.has("max_hp_flat"):
		var hp_gain := int(effect["max_hp_flat"])
		player["max_hp"] = max_hp + hp_gain
		player["current_hp"] = current_hp + hp_gain
		max_hp = int(player["max_hp"])
	if effect.has("heal_flat"):
		player["current_hp"] = mini(max_hp, int(player.get("current_hp", current_hp)) + int(effect["heal_flat"]))
	if effect.has("heal_percent"):
		player["current_hp"] = mini(max_hp, int(player.get("current_hp", current_hp)) + int(round(float(max_hp) * float(effect["heal_percent"]))))
	if effect.has("gold_flat"):
		run["gold"] = int(run.get("gold", 0)) + int(effect["gold_flat"])
	if effect.has("xp_flat"):
		run["xp"] = int(run.get("xp", 0)) + int(effect["xp_flat"])
	if effect.has("danger_delta"):
		run["danger"] = clampi(int(run.get("danger", 0)) + int(effect["danger_delta"]), 0, 100)
	if effect.has("essence_on_run_end"):
		run["pending_essence_bonus"] = int(run.get("pending_essence_bonus", 0)) + int(effect["essence_on_run_end"])
	if effect.has("sigils_on_run_end"):
		run["pending_sigil_bonus"] = int(run.get("pending_sigil_bonus", 0)) + int(effect["sigils_on_run_end"])

	_apply_special_progression_effects(player, effect)

	run["player"] = player
	run["level"] = GameState.level_for_xp(int(run.get("xp", 0)))


static func _apply_special_progression_effects(player: Dictionary, effect: Dictionary) -> void:
	if effect.has("grant_skill"):
		_append_unique_strings(player, "skills", effect["grant_skill"])
	if effect.has("grant_trait"):
		_append_unique_strings(player, "traits", effect["grant_trait"])


static func _append_unique_strings(target: Dictionary, key: String, values: Variant) -> void:
	var items: Array = target.get(key, []).duplicate()
	if values is Array:
		for value in values:
			var item := String(value)
			if not items.has(item):
				items.append(item)
	else:
		var item := String(values)
		if not items.has(item):
			items.append(item)
	target[key] = items


static func _reveal_neighbors(tiles: Dictionary, x: int, y: int) -> void:
	for offset in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		var key: String = MapGeneratorScript.coord_key(x + int(offset[0]), y + int(offset[1]))
		if tiles.has(key):
			var tile: Dictionary = tiles[key]
			if tile.get("state", "") == "hidden":
				tile["state"] = "revealed"
				tiles[key] = tile


static func _refresh_selectables(tiles: Dictionary) -> void:
	for key in tiles.keys():
		var tile: Dictionary = tiles[key]
		var state := String(tile.get("state", "hidden"))
		if state == "captured" or state == "hidden":
			continue

		tile["state"] = "revealed"
		if _has_captured_neighbor(tiles, int(tile.get("x", 0)), int(tile.get("y", 0))):
			tile["state"] = "selectable"
		tiles[key] = tile


static func _has_captured_neighbor(tiles: Dictionary, x: int, y: int) -> bool:
	for offset in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
		var key: String = MapGeneratorScript.coord_key(x + int(offset[0]), y + int(offset[1]))
		if tiles.has(key) and String(tiles[key].get("state", "")) == "captured":
			return true
	return false
