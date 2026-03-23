extends RefCounted
class_name EventResolver

const TileResolverScript = preload("res://scripts/map/tile_resolver.gd")


static func event_candidates_for_tile(run: Dictionary, tile_def: Dictionary, event_defs: Dictionary) -> Array:
	var event_pool: Array = tile_def.get("event_pool", [])
	if event_pool.is_empty():
		var fallback_ids: Array = event_defs.keys()
		fallback_ids.sort()
		event_pool = fallback_ids

	if event_pool.is_empty():
		return []

	var phase_tag := _phase_tag_for_run(run)
	var filtered_pool: Array = []
	for event_value in event_pool:
		var event_id := String(event_value)
		var definition: Dictionary = event_defs.get(event_id, {})
		var phase_tags: Array = definition.get("phase_tags", [])
		if phase_tags.is_empty() or phase_tags.has(phase_tag):
			filtered_pool.append(event_id)

	if filtered_pool.is_empty():
		return event_pool.duplicate()

	return filtered_pool


static func event_for_tile(run: Dictionary, coord_key: String, tile_def: Dictionary, event_defs: Dictionary, reroll_count: int = 0) -> Dictionary:
	var filtered_pool: Array = event_candidates_for_tile(run, tile_def, event_defs)
	if filtered_pool.is_empty():
		return {}
	var phase_tag := _phase_tag_for_run(run)

	var index: int = abs(_coord_hash("%s:%s:%s" % [int(run.get("seed", 0)), coord_key, phase_tag])) % filtered_pool.size()
	if filtered_pool.size() > 1:
		index = (index + maxi(0, reroll_count)) % filtered_pool.size()
	var event_id := String(filtered_pool[index])
	if event_defs.has(event_id):
		return event_defs[event_id].duplicate(true)
	return {}


static func apply_choice(run: Dictionary, coord_key: String, tile_defs: Dictionary, event_def: Dictionary, choice_id: String) -> Dictionary:
	var choice: Dictionary = {}
	for candidate in event_def.get("choices", []):
		if String(candidate.get("id", "")) == choice_id:
			choice = candidate
			break

	if choice.is_empty():
		return {
			"ok": false,
			"message": "Invalid event choice."
		}

	var next_run: Dictionary = TileResolverScript.capture_tile(run, coord_key, tile_defs)
	var player: Dictionary = next_run.get("player", {}).duplicate(true)
	var cost: Dictionary = choice.get("cost", {})
	var reward: Dictionary = choice.get("reward", {})

	if cost.has("gold_flat") and int(next_run.get("gold", 0)) < int(cost["gold_flat"]):
		return {
			"ok": false,
			"message": "Not enough gold for that choice."
		}

	if cost.has("current_hp_percent"):
		var hp_cost_percent := float(cost["current_hp_percent"])
		player["current_hp"] = max(1, int(round(float(player.get("current_hp", 1)) * (1.0 - hp_cost_percent))))
	if cost.has("gold_flat"):
		next_run["gold"] = maxi(0, int(next_run.get("gold", 0)) - int(cost["gold_flat"]))
	if cost.has("curse"):
		var curses: Array = next_run.get("curses", []).duplicate()
		curses.append(String(cost["curse"]))
		next_run["curses"] = curses

	_apply_reward_to_run(next_run, player, reward)
	next_run["danger"] = clampi(int(next_run.get("danger", 0)) + int(choice.get("danger_delta", 0)), 0, 100)
	next_run["player"] = player
	next_run["level"] = GameState.level_for_xp(int(next_run.get("xp", 0)))
	next_run["last_action"] = {
		"kind": "event",
		"event_id": String(event_def.get("id", "")),
		"choice_id": choice_id
	}

	return {
		"ok": true,
		"run": next_run,
		"event_id": String(event_def.get("id", "")),
		"choice_id": choice_id,
		"message": "%s -> %s" % [String(event_def.get("title", "Event")), String(choice.get("label", "Choice"))]
	}


static func _apply_reward_to_run(run: Dictionary, player: Dictionary, reward: Dictionary) -> void:
	if reward.has("attack_flat"):
		player["attack"] = int(player.get("attack", 0)) + int(reward["attack_flat"])
	if reward.has("attack_percent"):
		player["attack"] = int(round(float(player.get("attack", 0)) * (1.0 + float(reward["attack_percent"]))))
	if reward.has("armor_flat"):
		player["armor"] = int(player.get("armor", 0)) + int(reward["armor_flat"])
	if reward.has("attack_speed"):
		player["attack_speed"] = float(player.get("attack_speed", 1.0)) + float(reward["attack_speed"])
	if reward.has("crit_rate"):
		player["crit_rate"] = float(player.get("crit_rate", 0.0)) + float(reward["crit_rate"])
	if reward.has("territory_power"):
		player["territory_power"] = float(player.get("territory_power", 0.0)) + float(reward["territory_power"])
	if reward.has("luck"):
		player["luck"] = int(player.get("luck", 0)) + int(reward["luck"])
	if reward.has("max_hp_flat"):
		var hp_gain := int(reward["max_hp_flat"])
		player["max_hp"] = int(player.get("max_hp", 0)) + hp_gain
		player["current_hp"] = int(player.get("current_hp", 0)) + hp_gain
	if reward.has("heal_flat"):
		player["current_hp"] = mini(int(player.get("max_hp", 0)), int(player.get("current_hp", 0)) + int(reward["heal_flat"]))
	if reward.has("heal_percent"):
		var heal_amount := int(round(float(player.get("max_hp", 0)) * float(reward["heal_percent"])))
		player["current_hp"] = mini(int(player.get("max_hp", 0)), int(player.get("current_hp", 0)) + heal_amount)
	if reward.has("gold"):
		run["gold"] = int(run.get("gold", 0)) + int(reward["gold"])
	if reward.has("xp"):
		run["xp"] = int(run.get("xp", 0)) + int(reward["xp"])
	if reward.has("essence_on_run_end"):
		run["pending_essence_bonus"] = int(run.get("pending_essence_bonus", 0)) + int(reward["essence_on_run_end"])
	if reward.has("sigils_on_run_end"):
		run["pending_sigil_bonus"] = int(run.get("pending_sigil_bonus", 0)) + int(reward["sigils_on_run_end"])

	_apply_special_progression_effects(player, reward)


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


static func _phase_tag_for_run(run: Dictionary) -> String:
	var captures := int(run.get("captured_tiles", 0))
	if captures < 4:
		return "early"
	if captures < 8:
		return "mid"
	return "late"


static func _coord_hash(text: String) -> int:
	var total := 0
	for value in text.to_ascii_buffer():
		total = (total * 33) + int(value)
	return total
