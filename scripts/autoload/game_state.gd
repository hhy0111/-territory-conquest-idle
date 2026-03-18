extends Node

const SAVE_VERSION := 1
const RUN_CAPTURE_GOAL := 11
const MapGeneratorScript = preload("res://scripts/map/map_generator.gd")
const TileResolverScript = preload("res://scripts/map/tile_resolver.gd")
const EventResolverScript = preload("res://scripts/map/event_resolver.gd")
const CombatResolverScript = preload("res://scripts/combat/combat_resolver.gd")

signal profile_changed
signal run_changed
signal result_changed

var profile: Dictionary = {}
var active_run: Dictionary = {}
var last_result: Dictionary = {}


func _ready() -> void:
	if profile.is_empty():
		profile = make_default_profile()


func make_default_profile() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"essence": 0,
		"sigils": 0,
		"meta_upgrades": {},
		"unlocks": {},
		"best_run": {
			"captures": 0,
			"bosses_defeated": 0,
			"seed": 0
		}
	}


func make_default_player() -> Dictionary:
	return {
		"current_hp": 108,
		"max_hp": 108,
		"attack": 13,
		"attack_speed": 1.0,
		"armor": 6,
		"crit_rate": 0.05,
		"crit_damage": 0.5,
		"evade": 0.02,
		"lifesteal": 0.0,
		"range": 1.2,
		"move_speed": 80,
		"luck": 0,
		"territory_power": 0.0,
		"corruption_resist": 0.0,
		"skills": [],
		"traits": []
	}


func make_default_run_stats() -> Dictionary:
	return {
		"combat": {
			"encounters_started": 0,
			"victories": 0,
			"defeats": 0,
			"boss_encounters_started": 0,
			"boss_victories": 0,
			"damage_dealt": 0,
			"damage_taken": 0,
			"healing_received": 0,
			"enemy_healing": 0,
			"highest_hit": 0,
			"longest_battle_seconds": 0.0,
			"total_battle_seconds": 0.0,
			"phase_changes_seen": 0
		},
		"map": {
			"captured_by_type": {},
			"utilities_resolved": 0,
			"utility_by_type": {},
			"events_resolved": 0,
			"highest_danger": 0
		},
		"economy": {
			"gold_from_tiles": 0,
			"gold_from_events": 0,
			"gold_from_utilities": 0,
			"gold_from_upgrades": 0,
			"xp_from_tiles": 0,
			"xp_from_events": 0,
			"xp_from_utilities": 0,
			"essence_bonus_from_events": 0,
			"essence_bonus_from_upgrades": 0,
			"sigil_bonus_from_events": 0,
			"sigil_bonus_from_upgrades": 0,
			"hp_healed_from_utilities": 0,
			"hp_spent_on_events": 0
		},
		"build": {
			"relic_pick_order": [],
			"run_upgrade_pick_order": [],
			"skills_gained": [],
			"traits_gained": []
		}
	}


func load_profile_state(profile_data: Dictionary, run_data: Dictionary = {}) -> void:
	profile = _merge_profile(profile_data)
	active_run = _normalize_run_state(run_data.duplicate(true))
	last_result = {}
	emit_signal("profile_changed")
	emit_signal("run_changed")
	emit_signal("result_changed")


func has_active_run() -> bool:
	return not active_run.is_empty()


func has_pending_combat() -> bool:
	return not active_run.get("pending_combat", {}).is_empty()


func has_pending_relic_choice() -> bool:
	return not active_run.get("pending_relic_choice", {}).is_empty()


func has_pending_run_upgrade() -> bool:
	return not active_run.get("pending_run_upgrade", {}).is_empty()


func get_pending_combat() -> Dictionary:
	return active_run.get("pending_combat", {}).duplicate(true)


func get_pending_relic_choice() -> Dictionary:
	return active_run.get("pending_relic_choice", {}).duplicate(true)


func get_pending_run_upgrade() -> Dictionary:
	return active_run.get("pending_run_upgrade", {}).duplicate(true)


func get_run_capture_goal() -> int:
	return RUN_CAPTURE_GOAL


func is_run_clear_ready(run_data: Dictionary = {}) -> bool:
	var run_ref: Dictionary = active_run if run_data.is_empty() else run_data
	if run_ref.is_empty():
		return false
	return int(run_ref.get("captured_tiles", 0)) >= RUN_CAPTURE_GOAL


func level_for_xp(xp: int) -> int:
	var level := 1
	var remaining_xp := maxi(0, xp)
	var next_cost := 18

	while remaining_xp >= next_cost:
		remaining_xp -= next_cost
		level += 1
		next_cost += 12

	return level


func start_new_run(seed: int = 0) -> Dictionary:
	if seed == 0:
		seed = int(Time.get_unix_time_from_system())

	var player := _build_player_from_profile()
	active_run = {
		"seed": seed,
		"phase_index": 1,
		"captured_tiles": 0,
		"danger": 0,
		"gold": _starting_gold_from_profile(),
		"xp": 0,
		"level": 1,
		"started_at": int(Time.get_unix_time_from_system()),
		"player": player,
		"relics": [],
		"run_upgrades": {},
		"curses": [],
		"bosses_defeated": 0,
		"pending_essence_bonus": 0,
		"pending_sigil_bonus": 0,
		"pending_combat": {},
		"pending_relic_choice": {},
		"pending_run_upgrade": {},
		"last_action": {},
		"stats": make_default_run_stats(),
		"map": MapGeneratorScript.generate_initial_map(seed)
	}
	last_result = {}

	if RngService:
		RngService.seed_channels(seed)

	emit_signal("run_changed")
	emit_signal("result_changed")
	return active_run


func capture_tile(coord_key: String) -> Dictionary:
	if active_run.is_empty():
		return {}

	active_run = TileResolverScript.capture_tile(active_run, coord_key, DataService.get_tile_definitions())
	emit_signal("run_changed")
	return active_run


func resolve_tile(coord_key: String) -> Dictionary:
	if active_run.is_empty():
		return { "ok": false, "message": "No active run." }
	if has_pending_combat():
		return { "ok": false, "message": "Resolve the active combat first." }
	if has_pending_run_upgrade():
		return { "ok": false, "message": "Choose a run upgrade first." }

	var tiles: Dictionary = active_run.get("map", {}).get("tiles", {})
	if not tiles.has(coord_key):
		return { "ok": false, "message": "Unknown tile." }

	var tile: Dictionary = tiles[coord_key]
	var tile_type := String(tile.get("type", "plains"))
	var tile_def: Dictionary = DataService.get_tile_definitions().get(tile_type, {})
	var resolver_mode := String(tile_def.get("resolver_mode", "combat"))

	match resolver_mode:
		"event":
			return _prepare_event_tile(coord_key, tile, tile_def)
		"utility":
			return _resolve_utility_tile(coord_key, tile, tile_def)
		_:
			return _prepare_combat_tile(coord_key, tile, tile_def)


func choose_event(coord_key: String, choice_id: String) -> Dictionary:
	if active_run.is_empty():
		return { "ok": false, "message": "No active run." }
	if has_pending_combat():
		return { "ok": false, "message": "Resolve the active combat first." }
	if has_pending_run_upgrade():
		return { "ok": false, "message": "Choose a run upgrade first." }

	var tiles: Dictionary = active_run.get("map", {}).get("tiles", {})
	if not tiles.has(coord_key):
		return { "ok": false, "message": "Unknown tile." }

	var tile: Dictionary = tiles[coord_key]
	var tile_type := String(tile.get("type", "plains"))
	var tile_def: Dictionary = DataService.get_tile_definitions().get(tile_type, {})
	var event_def := EventResolverScript.event_for_tile(active_run, coord_key, tile_def, DataService.get_event_definitions())
	var chosen_choice := _event_choice_by_id(event_def, choice_id)
	var previous_level := int(active_run.get("level", 1))
	var previous_run: Dictionary = active_run.duplicate(true)
	var result := EventResolverScript.apply_choice(active_run, coord_key, DataService.get_tile_definitions(), event_def, choice_id)
	if not result.get("ok", false):
		return result

	active_run = result.get("run", {}).duplicate(true)
	_record_tile_capture(tile_type)
	_record_event_resolution(event_def, chosen_choice, previous_run)
	_queue_run_upgrade_if_needed(previous_level)
	emit_signal("run_changed")
	return {
		"ok": true,
		"kind": "event_resolution",
		"message": result.get("message", "Event resolved.")
	}


func choose_relic(relic_id: String) -> Dictionary:
	if active_run.is_empty():
		return { "ok": false, "message": "No active run." }
	if not has_pending_relic_choice():
		return { "ok": false, "message": "No pending relic choice." }

	var relic_defs: Dictionary = DataService.get_relic_definitions()
	if not relic_defs.has(relic_id):
		return { "ok": false, "message": "Unknown relic." }

	var relic_choice: Dictionary = active_run.get("pending_relic_choice", {})
	var choice_ids: Array = relic_choice.get("choices", [])
	if not choice_ids.has(relic_id):
		return { "ok": false, "message": "Relic is not in the current offer." }

	var relic_def: Dictionary = relic_defs[relic_id]
	var relics: Array = active_run.get("relics", []).duplicate()
	if not relics.has(relic_id):
		relics.append(relic_id)
	active_run["relics"] = relics

	var player: Dictionary = active_run.get("player", {}).duplicate(true)
	_apply_relic_effect(player, relic_def.get("effect", {}))
	active_run["player"] = player

	var remaining_picks := maxi(0, int(relic_choice.get("picks_remaining", 1)) - 1)
	if remaining_picks > 0:
		active_run["pending_relic_choice"] = _build_relic_offer(remaining_picks)
	else:
		active_run["pending_relic_choice"] = {}

	active_run["last_action"] = {
		"kind": "relic",
		"relic_id": relic_id
	}
	_record_relic_choice(relic_id, relic_def)
	emit_signal("run_changed")

	return {
		"ok": true,
		"has_more": remaining_picks > 0,
		"relic": relic_def.duplicate(true),
		"message": "Acquired %s." % String(relic_def.get("name", relic_id))
	}


func choose_run_upgrade(upgrade_id: String) -> Dictionary:
	if active_run.is_empty():
		return { "ok": false, "message": "No active run." }
	if not has_pending_run_upgrade():
		return { "ok": false, "message": "No pending run upgrade." }

	var upgrade_defs: Dictionary = DataService.get_run_upgrade_definitions()
	if not upgrade_defs.has(upgrade_id):
		return { "ok": false, "message": "Unknown run upgrade." }

	var pending_upgrade: Dictionary = active_run.get("pending_run_upgrade", {})
	var choice_ids: Array = pending_upgrade.get("choices", [])
	if not choice_ids.has(upgrade_id):
		return { "ok": false, "message": "Upgrade is not in the current offer." }

	var upgrade_def: Dictionary = upgrade_defs[upgrade_id]
	var run_upgrades: Dictionary = active_run.get("run_upgrades", {}).duplicate(true)
	var current_rank := int(run_upgrades.get(upgrade_id, 0))
	var max_rank := int(upgrade_def.get("max_rank", 1))
	if current_rank >= max_rank:
		return { "ok": false, "message": "Upgrade is already maxed." }

	run_upgrades[upgrade_id] = current_rank + 1
	active_run["run_upgrades"] = run_upgrades
	_apply_run_upgrade_effect(upgrade_def.get("effect", {}))

	var remaining_picks := maxi(0, int(pending_upgrade.get("picks_remaining", 1)) - 1)
	if remaining_picks > 0:
		active_run["pending_run_upgrade"] = _build_run_upgrade_offer(remaining_picks)
	else:
		active_run["pending_run_upgrade"] = {}

	active_run["last_action"] = {
		"kind": "run_upgrade",
		"upgrade_id": upgrade_id
	}
	_record_run_upgrade_choice(upgrade_id, upgrade_def)
	emit_signal("run_changed")

	return {
		"ok": true,
		"has_more": remaining_picks > 0,
		"upgrade": upgrade_def.duplicate(true),
		"message": "Applied %s." % String(upgrade_def.get("name", upgrade_id))
	}


func complete_pending_combat() -> Dictionary:
	if active_run.is_empty():
		return { "ok": false, "message": "No active run." }
	if not has_pending_combat():
		return { "ok": false, "message": "No pending combat." }

	var pending: Dictionary = active_run.get("pending_combat", {})
	var coord_key := String(pending.get("coord_key", ""))
	var tile_type := String(pending.get("tile_type", "tile"))
	var enemy_stats: Dictionary = pending.get("enemy", {})
	var battle_result: Dictionary = pending.get("battle_result", {})
	var previous_level := int(active_run.get("level", 1))
	var player_state: Dictionary = active_run.get("player", {}).duplicate(true)
	player_state["current_hp"] = int(battle_result.get("player_hp", player_state.get("current_hp", 0)))
	active_run["player"] = player_state
	active_run["pending_combat"] = {}

	if battle_result.get("victory", false):
		_record_combat_resolution(pending, battle_result, true)
		active_run = TileResolverScript.capture_tile(active_run, coord_key, DataService.get_tile_definitions())
		_record_tile_capture(String(pending.get("tile_type", tile_type)))
		active_run["player"]["current_hp"] = player_state["current_hp"]
		active_run["last_action"] = {
			"kind": "combat",
			"victory": true,
			"enemy_id": String(enemy_stats.get("id", "enemy")),
			"is_boss": bool(pending.get("is_boss", false))
		}

		if pending.get("is_boss", false):
			var meta_boss_essence := int(round(_meta_effect_total("boss_reward_essence_flat")))
			var meta_boss_sigils := int(round(_meta_effect_total("boss_reward_sigil_flat")))
			active_run["bosses_defeated"] = int(active_run.get("bosses_defeated", 0)) + 1
			active_run["pending_essence_bonus"] = int(active_run.get("pending_essence_bonus", 0)) + int(pending.get("boss_reward_essence", 0)) + meta_boss_essence
			active_run["pending_sigil_bonus"] = int(active_run.get("pending_sigil_bonus", 0)) + int(pending.get("boss_reward_sigils", 0)) + meta_boss_sigils
			var boss_heal_percent := float(_meta_effect_total("heal_after_boss_percent"))
			if boss_heal_percent > 0.0:
				var healed_player: Dictionary = active_run.get("player", {}).duplicate(true)
				var boss_heal_amount := int(round(float(healed_player.get("max_hp", 0)) * boss_heal_percent))
				healed_player["current_hp"] = mini(int(healed_player.get("max_hp", 0)), int(healed_player.get("current_hp", 0)) + boss_heal_amount)
				active_run["player"] = healed_player
			if int(pending.get("boss_reward_relics", 0)) > 0:
				active_run["pending_relic_choice"] = _build_relic_offer(int(pending.get("boss_reward_relics", 0)))
		_queue_run_upgrade_if_needed(previous_level)

		emit_signal("run_changed")
		return {
			"ok": true,
			"kind": "combat_resolution",
			"victory": true,
			"is_boss": bool(pending.get("is_boss", false)),
			"message": "Defeated %s on %s." % [
				String(enemy_stats.get("display_name", enemy_stats.get("id", "enemy"))),
				tile_type.capitalize()
			]
		}

	active_run["player"]["current_hp"] = 0
	_record_combat_resolution(pending, battle_result, false)
	active_run["last_action"] = {
		"kind": "combat",
		"victory": false,
		"enemy_id": String(enemy_stats.get("id", "enemy")),
		"is_boss": bool(pending.get("is_boss", false))
	}
	emit_signal("run_changed")
	return {
		"ok": true,
		"kind": "combat_resolution",
		"victory": false,
		"is_boss": bool(pending.get("is_boss", false)),
		"message": "Defeated by %s." % String(enemy_stats.get("display_name", enemy_stats.get("id", "enemy")))
	}


func finish_run(victory: bool) -> Dictionary:
	if active_run.is_empty():
		return last_result

	var run_snapshot: Dictionary = active_run.duplicate(true)
	var captures := int(active_run.get("captured_tiles", 0))
	var bosses := int(active_run.get("bosses_defeated", 0))
	var started_at := int(active_run.get("started_at", int(Time.get_unix_time_from_system())))
	var duration_seconds: int = maxi(1, int(Time.get_unix_time_from_system()) - started_at)
	var pending_essence_bonus := int(active_run.get("pending_essence_bonus", 0))
	var pending_sigil_bonus := int(active_run.get("pending_sigil_bonus", 0))

	var essence_gain := captures * 4 + bosses * 10 + pending_essence_bonus + (20 if victory else 0)
	var essence_multiplier := 1.0 + _meta_effect_total("essence_gain_percent")
	essence_gain = int(round(float(essence_gain) * essence_multiplier))

	var sigil_gain := pending_sigil_bonus + (1 if victory and captures >= 4 else 0)
	if victory:
		sigil_gain += int(round(_meta_effect_total("victory_sigils_flat")))

	profile["essence"] = int(profile.get("essence", 0)) + essence_gain
	profile["sigils"] = int(profile.get("sigils", 0)) + sigil_gain

	var best_run: Dictionary = profile.get("best_run", {})
	if captures > int(best_run.get("captures", 0)):
		profile["best_run"] = {
			"captures": captures,
			"bosses_defeated": bosses,
			"seed": int(active_run.get("seed", 0))
		}

	var result_stats := _normalize_run_stats(run_snapshot.get("stats", {}))
	_update_highest_danger(result_stats)
	last_result = {
		"victory": victory,
		"captures": captures,
		"bosses_defeated": bosses,
		"essence_gain": essence_gain,
		"bonus_essence": pending_essence_bonus,
		"bonus_sigils": pending_sigil_bonus,
		"sigil_gain": sigil_gain,
		"duration_seconds": duration_seconds,
		"gold_earned": int(active_run.get("gold", 0)),
		"seed": int(active_run.get("seed", 0)),
		"final_level": int(run_snapshot.get("level", 1)),
		"final_danger": int(run_snapshot.get("danger", 0)),
		"final_player": run_snapshot.get("player", {}).duplicate(true),
		"relic_ids": run_snapshot.get("relics", []).duplicate(true),
		"run_upgrades": run_snapshot.get("run_upgrades", {}).duplicate(true),
		"curses": run_snapshot.get("curses", []).duplicate(true),
		"stats": result_stats
	}

	active_run = {}
	emit_signal("profile_changed")
	emit_signal("run_changed")
	emit_signal("result_changed")
	return last_result


func purchase_meta_upgrade(upgrade_id: String) -> Dictionary:
	var definitions: Dictionary = DataService.get_meta_upgrade_definitions()
	if not definitions.has(upgrade_id):
		return { "ok": false, "message": "Unknown upgrade." }

	var definition: Dictionary = definitions[upgrade_id]
	var purchased: Dictionary = profile.get("meta_upgrades", {})
	var current_rank := int(purchased.get(upgrade_id, 0))
	var max_rank := int(definition.get("max_rank", 1))

	if current_rank >= max_rank:
		return { "ok": false, "message": "Already at max rank." }

	var essence_cost := int(definition.get("cost_essence", 0)) * (current_rank + 1)
	var sigils_cost := int(definition.get("cost_sigils", 0))

	if int(profile.get("essence", 0)) < essence_cost or int(profile.get("sigils", 0)) < sigils_cost:
		return { "ok": false, "message": "Not enough currency." }

	profile["essence"] = int(profile.get("essence", 0)) - essence_cost
	profile["sigils"] = int(profile.get("sigils", 0)) - sigils_cost
	purchased[upgrade_id] = current_rank + 1
	profile["meta_upgrades"] = purchased
	emit_signal("profile_changed")
	return { "ok": true, "message": "Purchased %s." % String(definition.get("name", upgrade_id)) }


func _merge_profile(profile_data: Dictionary) -> Dictionary:
	var merged := make_default_profile()
	for key in profile_data.keys():
		merged[key] = profile_data[key]

	if not (merged.get("meta_upgrades", {}) is Dictionary):
		merged["meta_upgrades"] = {}
	if not (merged.get("unlocks", {}) is Dictionary):
		merged["unlocks"] = {}
	if not (merged.get("best_run", {}) is Dictionary):
		merged["best_run"] = make_default_profile()["best_run"]
	merged["version"] = SAVE_VERSION
	return merged


func _normalize_run_state(run_data: Dictionary) -> Dictionary:
	if run_data.is_empty():
		return {}

	if not run_data.has("bosses_defeated"):
		run_data["bosses_defeated"] = 0
	if not run_data.has("pending_essence_bonus"):
		run_data["pending_essence_bonus"] = 0
	if not run_data.has("pending_sigil_bonus"):
		run_data["pending_sigil_bonus"] = 0
	if not (run_data.get("pending_combat", {}) is Dictionary):
		run_data["pending_combat"] = {}
	if not (run_data.get("pending_relic_choice", {}) is Dictionary):
		run_data["pending_relic_choice"] = {}
	if not (run_data.get("pending_run_upgrade", {}) is Dictionary):
		run_data["pending_run_upgrade"] = {}
	if not (run_data.get("run_upgrades", {}) is Dictionary):
		run_data["run_upgrades"] = {}
	run_data["stats"] = _normalize_run_stats(run_data.get("stats", {}))
	return run_data


func _normalize_run_stats(stats_data: Variant) -> Dictionary:
	var normalized := make_default_run_stats()
	if not (stats_data is Dictionary):
		return normalized

	for group_key in normalized.keys():
		var default_group: Dictionary = normalized[group_key]
		var incoming_group: Variant = stats_data.get(group_key, {})
		if not (incoming_group is Dictionary):
			normalized[group_key] = default_group
			continue

		var group_copy := default_group.duplicate(true)
		for entry_key in incoming_group.keys():
			group_copy[entry_key] = incoming_group[entry_key]
		normalized[group_key] = group_copy

	var map_stats: Dictionary = normalized.get("map", {})
	if not (map_stats.get("captured_by_type", {}) is Dictionary):
		map_stats["captured_by_type"] = {}
	if not (map_stats.get("utility_by_type", {}) is Dictionary):
		map_stats["utility_by_type"] = {}
	normalized["map"] = map_stats

	var build_stats: Dictionary = normalized.get("build", {})
	for key in ["relic_pick_order", "run_upgrade_pick_order", "skills_gained", "traits_gained"]:
		if not (build_stats.get(key, []) is Array):
			build_stats[key] = []
	normalized["build"] = build_stats
	return normalized


func _record_tile_capture(tile_type: String) -> void:
	if active_run.is_empty():
		return

	var stats := _normalize_run_stats(active_run.get("stats", {}))
	var map_stats: Dictionary = stats.get("map", {}).duplicate(true)
	var captured_by_type: Dictionary = map_stats.get("captured_by_type", {}).duplicate(true)
	captured_by_type[tile_type] = int(captured_by_type.get(tile_type, 0)) + 1
	map_stats["captured_by_type"] = captured_by_type
	stats["map"] = map_stats

	var tile_reward := _tile_capture_reward_for_type(tile_type)
	var economy_stats: Dictionary = stats.get("economy", {}).duplicate(true)
	economy_stats["gold_from_tiles"] = int(economy_stats.get("gold_from_tiles", 0)) + int(tile_reward.get("gold", 0))
	economy_stats["xp_from_tiles"] = int(economy_stats.get("xp_from_tiles", 0)) + int(tile_reward.get("xp", 0))
	stats["economy"] = economy_stats

	_update_highest_danger(stats)
	active_run["stats"] = stats


func _record_utility_resolution(tile_type: String, previous_run: Dictionary) -> void:
	if active_run.is_empty():
		return

	var stats := _normalize_run_stats(active_run.get("stats", {}))
	var map_stats: Dictionary = stats.get("map", {}).duplicate(true)
	map_stats["utilities_resolved"] = int(map_stats.get("utilities_resolved", 0)) + 1
	var utility_by_type: Dictionary = map_stats.get("utility_by_type", {}).duplicate(true)
	utility_by_type[tile_type] = int(utility_by_type.get(tile_type, 0)) + 1
	map_stats["utility_by_type"] = utility_by_type
	stats["map"] = map_stats

	var previous_hp := int(previous_run.get("player", {}).get("current_hp", 0))
	var current_hp := int(active_run.get("player", {}).get("current_hp", 0))
	var economy_stats: Dictionary = stats.get("economy", {}).duplicate(true)
	var tile_reward := _tile_capture_reward_for_type(tile_type)
	var utility_gold_gain := maxi(0, int(active_run.get("gold", 0)) - int(previous_run.get("gold", 0)) - int(tile_reward.get("gold", 0)))
	var utility_xp_gain := maxi(0, int(active_run.get("xp", 0)) - int(previous_run.get("xp", 0)) - int(tile_reward.get("xp", 0)))
	economy_stats["gold_from_utilities"] = int(economy_stats.get("gold_from_utilities", 0)) + utility_gold_gain
	economy_stats["xp_from_utilities"] = int(economy_stats.get("xp_from_utilities", 0)) + utility_xp_gain
	economy_stats["hp_healed_from_utilities"] = int(economy_stats.get("hp_healed_from_utilities", 0)) + maxi(0, current_hp - previous_hp)
	stats["economy"] = economy_stats

	_update_highest_danger(stats)
	active_run["stats"] = stats


func _record_event_resolution(_event_def: Dictionary, choice: Dictionary, previous_run: Dictionary) -> void:
	if active_run.is_empty():
		return

	var stats := _normalize_run_stats(active_run.get("stats", {}))
	var map_stats: Dictionary = stats.get("map", {}).duplicate(true)
	map_stats["events_resolved"] = int(map_stats.get("events_resolved", 0)) + 1
	stats["map"] = map_stats

	var reward: Dictionary = choice.get("reward", {})
	var economy_stats: Dictionary = stats.get("economy", {}).duplicate(true)
	economy_stats["gold_from_events"] = int(economy_stats.get("gold_from_events", 0)) + int(reward.get("gold", 0))
	economy_stats["xp_from_events"] = int(economy_stats.get("xp_from_events", 0)) + int(reward.get("xp", 0))
	economy_stats["essence_bonus_from_events"] = int(economy_stats.get("essence_bonus_from_events", 0)) + int(reward.get("essence_on_run_end", 0))
	economy_stats["sigil_bonus_from_events"] = int(economy_stats.get("sigil_bonus_from_events", 0)) + int(reward.get("sigils_on_run_end", 0))
	var previous_hp := int(previous_run.get("player", {}).get("current_hp", 0))
	var current_hp := int(active_run.get("player", {}).get("current_hp", 0))
	economy_stats["hp_spent_on_events"] = int(economy_stats.get("hp_spent_on_events", 0)) + maxi(0, previous_hp - current_hp)
	stats["economy"] = economy_stats

	_update_highest_danger(stats)
	active_run["stats"] = stats


func _record_relic_choice(relic_id: String, relic_def: Dictionary) -> void:
	if active_run.is_empty():
		return

	var stats := _normalize_run_stats(active_run.get("stats", {}))
	var build_stats: Dictionary = stats.get("build", {}).duplicate(true)
	var relic_pick_order: Array = build_stats.get("relic_pick_order", []).duplicate(true)
	relic_pick_order.append(relic_id)
	build_stats["relic_pick_order"] = relic_pick_order
	_record_build_effects(build_stats, relic_def.get("effect", {}))
	stats["build"] = build_stats
	active_run["stats"] = stats


func _record_run_upgrade_choice(upgrade_id: String, upgrade_def: Dictionary) -> void:
	if active_run.is_empty():
		return

	var stats := _normalize_run_stats(active_run.get("stats", {}))
	var build_stats: Dictionary = stats.get("build", {}).duplicate(true)
	var run_upgrade_pick_order: Array = build_stats.get("run_upgrade_pick_order", []).duplicate(true)
	run_upgrade_pick_order.append(upgrade_id)
	build_stats["run_upgrade_pick_order"] = run_upgrade_pick_order
	_record_build_effects(build_stats, upgrade_def.get("effect", {}))
	stats["build"] = build_stats

	var economy_stats: Dictionary = stats.get("economy", {}).duplicate(true)
	economy_stats["gold_from_upgrades"] = int(economy_stats.get("gold_from_upgrades", 0)) + int(upgrade_def.get("effect", {}).get("gold_flat", 0))
	economy_stats["essence_bonus_from_upgrades"] = int(economy_stats.get("essence_bonus_from_upgrades", 0)) + int(upgrade_def.get("effect", {}).get("essence_on_run_end_flat", 0))
	economy_stats["sigil_bonus_from_upgrades"] = int(economy_stats.get("sigil_bonus_from_upgrades", 0)) + int(upgrade_def.get("effect", {}).get("sigils_on_run_end_flat", 0))
	stats["economy"] = economy_stats
	active_run["stats"] = stats


func _record_build_effects(build_stats: Dictionary, effect: Dictionary) -> void:
	if effect.has("grant_skill"):
		_append_unique_strings(build_stats, "skills_gained", effect["grant_skill"])
	if effect.has("grant_trait"):
		_append_unique_strings(build_stats, "traits_gained", effect["grant_trait"])


func _record_combat_prepared(pending_combat: Dictionary) -> void:
	if active_run.is_empty():
		return

	var stats := _normalize_run_stats(active_run.get("stats", {}))
	var combat_stats: Dictionary = stats.get("combat", {}).duplicate(true)
	combat_stats["encounters_started"] = int(combat_stats.get("encounters_started", 0)) + 1
	if bool(pending_combat.get("is_boss", false)):
		combat_stats["boss_encounters_started"] = int(combat_stats.get("boss_encounters_started", 0)) + 1
	stats["combat"] = combat_stats
	active_run["stats"] = stats


func _record_combat_resolution(pending_combat: Dictionary, battle_result: Dictionary, victory: bool) -> void:
	if active_run.is_empty():
		return

	var stats := _normalize_run_stats(active_run.get("stats", {}))
	var combat_stats: Dictionary = stats.get("combat", {}).duplicate(true)
	if victory:
		combat_stats["victories"] = int(combat_stats.get("victories", 0)) + 1
		if bool(pending_combat.get("is_boss", false)):
			combat_stats["boss_victories"] = int(combat_stats.get("boss_victories", 0)) + 1
	else:
		combat_stats["defeats"] = int(combat_stats.get("defeats", 0)) + 1

	var elapsed := float(battle_result.get("elapsed", 0.0))
	combat_stats["total_battle_seconds"] = float(combat_stats.get("total_battle_seconds", 0.0)) + elapsed
	combat_stats["longest_battle_seconds"] = maxf(float(combat_stats.get("longest_battle_seconds", 0.0)), elapsed)

	for event_value in battle_result.get("events", []):
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value
		var damage := int(event.get("damage", 0))
		if damage > 0:
			combat_stats["highest_hit"] = maxi(int(combat_stats.get("highest_hit", 0)), damage)

		match String(event.get("kind", "")):
			"attack":
				var attacker_side := String(event.get("attacker", "player"))
				var target_side := String(event.get("target_side", "enemy" if attacker_side == "player" else "player"))
				if target_side == "enemy":
					combat_stats["damage_dealt"] = int(combat_stats.get("damage_dealt", 0)) + damage
				else:
					combat_stats["damage_taken"] = int(combat_stats.get("damage_taken", 0)) + damage

				var heal_amount := int(event.get("heal_amount", 0))
				if heal_amount > 0:
					if attacker_side == "player":
						combat_stats["healing_received"] = int(combat_stats.get("healing_received", 0)) + heal_amount
					else:
						combat_stats["enemy_healing"] = int(combat_stats.get("enemy_healing", 0)) + heal_amount
			"status_tick":
				var tick_target_side := String(event.get("target_side", "enemy"))
				if tick_target_side == "enemy":
					combat_stats["damage_dealt"] = int(combat_stats.get("damage_dealt", 0)) + damage
				else:
					combat_stats["damage_taken"] = int(combat_stats.get("damage_taken", 0)) + damage
			"phase_change":
				combat_stats["phase_changes_seen"] = int(combat_stats.get("phase_changes_seen", 0)) + 1
				combat_stats["enemy_healing"] = int(combat_stats.get("enemy_healing", 0)) + int(event.get("heal_amount", 0))
			"trait_trigger":
				var trait_actor_side := String(event.get("attacker", "player"))
				var trait_heal := int(event.get("heal_amount", 0))
				if trait_heal > 0:
					if trait_actor_side == "player":
						combat_stats["healing_received"] = int(combat_stats.get("healing_received", 0)) + trait_heal
					else:
						combat_stats["enemy_healing"] = int(combat_stats.get("enemy_healing", 0)) + trait_heal

	stats["combat"] = combat_stats
	active_run["stats"] = stats


func _tile_capture_reward_for_type(tile_type: String) -> Dictionary:
	var tile_defs: Dictionary = DataService.get_tile_definitions()
	var tile_def: Dictionary = tile_defs.get(tile_type, {})
	var reward_data: Dictionary = tile_def.get("base_reward", {})
	var gold_gain := _mid_reward_value(reward_data.get("gold", [8, 10]))
	var xp_gain := _mid_reward_value(reward_data.get("xp", [10, 12]))
	var capture_bonus: Dictionary = tile_def.get("capture_bonus", {})
	gold_gain += int(capture_bonus.get("gold_flat", 0))
	gold_gain += int(capture_bonus.get("gold", 0))
	xp_gain += int(capture_bonus.get("xp_flat", 0))
	xp_gain += int(capture_bonus.get("xp", 0))

	return {
		"gold": gold_gain,
		"xp": xp_gain
	}


func _update_highest_danger(stats: Dictionary) -> void:
	var map_stats: Dictionary = stats.get("map", {}).duplicate(true)
	map_stats["highest_danger"] = maxi(int(map_stats.get("highest_danger", 0)), int(active_run.get("danger", 0)))
	stats["map"] = map_stats


func _event_choice_by_id(event_def: Dictionary, choice_id: String) -> Dictionary:
	for choice_value in event_def.get("choices", []):
		if not (choice_value is Dictionary):
			continue
		var choice: Dictionary = choice_value
		if String(choice.get("id", "")) == choice_id:
			return choice
	return {}


func _mid_reward_value(values: Variant) -> int:
	if values is Array and values.size() >= 2:
		return int(round((float(values[0]) + float(values[1])) * 0.5))
	return int(values)


func _build_player_from_profile() -> Dictionary:
	var player := make_default_player()
	player["attack"] = int(player.get("attack", 0)) + int(_meta_effect_total("base_attack_flat"))
	player["max_hp"] = int(player.get("max_hp", 0)) + int(_meta_effect_total("base_hp_flat"))
	player["armor"] = int(player.get("armor", 0)) + int(_meta_effect_total("base_armor_flat"))
	player["crit_rate"] = float(player.get("crit_rate", 0.0)) + float(_meta_effect_total("base_crit_rate_flat"))
	player["luck"] = int(player.get("luck", 0)) + int(_meta_effect_total("starting_luck_flat"))
	player["current_hp"] = int(player["max_hp"])
	return player


func _starting_gold_from_profile() -> int:
	return 10 + int(_meta_effect_total("starting_gold_flat"))


func _meta_effect_total(effect_key: String) -> float:
	var total := 0.0
	var purchased: Dictionary = profile.get("meta_upgrades", {})
	var definitions: Dictionary = DataService.get_meta_upgrade_definitions()

	for upgrade_id in purchased.keys():
		if not definitions.has(upgrade_id):
			continue
		var rank := int(purchased[upgrade_id])
		var effect: Dictionary = definitions[upgrade_id].get("effect", {})
		total += float(effect.get(effect_key, 0.0)) * rank

	return total


func _prepare_event_tile(coord_key: String, tile: Dictionary, tile_def: Dictionary) -> Dictionary:
	var event_def := EventResolverScript.event_for_tile(active_run, coord_key, tile_def, DataService.get_event_definitions())
	if event_def.is_empty():
		return { "ok": false, "message": "No event data available." }

	return {
		"ok": true,
		"kind": "event",
		"coord_key": coord_key,
		"tile_type": String(tile.get("type", "shrine")),
		"event": event_def,
		"message": "Choose how to resolve %s." % String(event_def.get("title", "the event"))
	}


func _resolve_utility_tile(coord_key: String, tile: Dictionary, tile_def: Dictionary) -> Dictionary:
	var previous_level := int(active_run.get("level", 1))
	var previous_run: Dictionary = active_run.duplicate(true)
	active_run = TileResolverScript.resolve_utility_tile(active_run, coord_key, DataService.get_tile_definitions())
	_record_tile_capture(String(tile.get("type", tile_def.get("id", "utility"))))
	_record_utility_resolution(String(tile.get("type", tile_def.get("id", "utility"))), previous_run)
	_queue_run_upgrade_if_needed(previous_level)
	emit_signal("run_changed")
	return {
		"ok": true,
		"kind": "utility",
		"message": "%s restored supplies and stabilized the frontier." % String(tile.get("type", tile_def.get("id", "Utility"))).capitalize()
	}


func _prepare_combat_tile(coord_key: String, tile: Dictionary, tile_def: Dictionary) -> Dictionary:
	var enemy_stats: Dictionary = {}
	var is_boss := false
	var boss_def: Dictionary = {}

	if _should_spawn_boss():
		boss_def = _boss_definition_for_run()
		enemy_stats = _build_boss_for_run(boss_def, tile)
		is_boss = not boss_def.is_empty()
	else:
		enemy_stats = _build_enemy_for_tile(coord_key, tile, tile_def)

	var battle_result: Dictionary = CombatResolverScript.simulate_battle_log(active_run.get("player", {}), enemy_stats)
	active_run["pending_combat"] = {
		"coord_key": coord_key,
		"tile_type": String(tile.get("type", tile_def.get("id", "tile"))),
		"is_boss": is_boss,
		"enemy": enemy_stats,
		"boss_id": String(boss_def.get("id", "")),
		"boss_reward_essence": int(boss_def.get("reward_essence", 0)),
		"boss_reward_sigils": int(boss_def.get("reward_sigils", 0)),
		"boss_reward_relics": int(boss_def.get("reward_relics", 0)),
		"battle_result": battle_result
	}
	_record_combat_prepared(active_run.get("pending_combat", {}))
	emit_signal("run_changed")

	return {
		"ok": true,
		"kind": "combat",
		"requires_scene": true,
		"encounter": active_run.get("pending_combat", {}).duplicate(true),
		"message": "Engage %s." % String(enemy_stats.get("display_name", enemy_stats.get("id", "enemy")))
	}


func _build_enemy_for_tile(coord_key: String, tile: Dictionary, tile_def: Dictionary) -> Dictionary:
	var enemy_defs: Dictionary = DataService.get_enemy_definitions()
	var enemy_pool: Array = tile_def.get("enemy_pool", [])
	if enemy_pool.is_empty():
		enemy_pool = ["raider"]

	var index: int = abs(_coord_hash("%s:%s" % [int(active_run.get("seed", 0)), coord_key])) % enemy_pool.size()
	var enemy_id := String(enemy_pool[index])
	var enemy_def: Dictionary = enemy_defs.get(enemy_id, {})
	var ring := int(tile.get("ring", 0))
	var danger_tier := int(floor(float(active_run.get("danger", 0)) / 25.0))

	var hp_multiplier := 1.0 + (ring * 0.16) + (danger_tier * 0.05)
	var attack_multiplier := 1.0 + (ring * 0.14) + (danger_tier * 0.06)
	var speed_multiplier := 1.0 + (ring * 0.04)

	if String(tile_def.get("id", "")) == "fortress":
		hp_multiplier += 0.2
		attack_multiplier += 0.12

	return {
		"id": enemy_id,
		"display_name": _title_case_id(enemy_id),
		"current_hp": int(round(float(enemy_def.get("base_hp", 20)) * hp_multiplier)),
		"max_hp": int(round(float(enemy_def.get("base_hp", 20)) * hp_multiplier)),
		"attack": int(round(float(enemy_def.get("base_attack", 5)) * attack_multiplier)),
		"attack_speed": float(enemy_def.get("base_attack_speed", 1.0)) * speed_multiplier,
		"armor": int(enemy_def.get("armor", 0)),
		"territory_power": 0.0,
		"crit_damage": 0.0,
		"skills": enemy_def.get("skills", []).duplicate(true)
	}


func _should_spawn_boss() -> bool:
	var boss_defs: Array = DataService.get_data_set("bosses")
	if boss_defs.is_empty():
		return false

	var bosses_defeated := int(active_run.get("bosses_defeated", 0))
	if bosses_defeated >= boss_defs.size():
		return false

	var next_boss: Dictionary = boss_defs[bosses_defeated]
	var prototype_gate := int(next_boss.get("prototype_gate", 3 + (bosses_defeated * 2)))
	return int(active_run.get("captured_tiles", 0)) >= prototype_gate


func _boss_definition_for_run() -> Dictionary:
	var boss_defs: Array = DataService.get_data_set("bosses")
	if boss_defs.is_empty():
		return {}

	var boss_index := mini(int(active_run.get("bosses_defeated", 0)), boss_defs.size() - 1)
	return boss_defs[boss_index]


func _build_boss_for_run(boss_def: Dictionary, tile: Dictionary) -> Dictionary:
	var boss_index := int(active_run.get("bosses_defeated", 0))
	var ring := int(tile.get("ring", 0))
	var danger_tier := int(floor(float(active_run.get("danger", 0)) / 25.0))
	var boss_id := String(boss_def.get("id", "boss"))
	var profile: Dictionary = boss_def.get("stat_profile", {})
	var hp_base := 124 + (boss_index * 36) + (ring * 22) + (danger_tier * 14)
	var attack_base := 13 + (boss_index * 4) + (ring * 2) + (danger_tier * 2)
	var armor_base := 7 + (boss_index * 2) + danger_tier
	var attack_speed_base := 0.85 + (boss_index * 0.05)
	var hp := int(round(float(hp_base) * float(profile.get("hp_multiplier", 1.0))))
	var attack := int(round(float(attack_base) * float(profile.get("attack_multiplier", 1.0))))
	var armor := armor_base + int(profile.get("armor_bonus", 0))
	var attack_speed := maxf(0.4, attack_speed_base + float(profile.get("speed_bonus", 0.0)))

	return {
		"id": boss_id,
		"display_name": String(boss_def.get("name", _title_case_id(boss_id))),
		"description": String(boss_def.get("description", "")),
		"trait_name": String(boss_def.get("trait_name", "")),
		"trait_summary": String(boss_def.get("trait_summary", "")),
		"current_hp": hp,
		"max_hp": hp,
		"attack": attack,
		"attack_speed": attack_speed,
		"armor": armor,
		"territory_power": 0.12 + (boss_index * 0.03) + float(profile.get("territory_power_bonus", 0.0)),
		"crit_damage": 0.25 + float(profile.get("crit_damage_bonus", 0.0)),
		"is_boss": true,
		"skills": boss_def.get("skills", []).duplicate(true),
		"phases": boss_def.get("phases", []).duplicate(true)
	}


func _build_run_upgrade_offer(picks_remaining: int) -> Dictionary:
	var upgrade_pool: Array = DataService.get_data_set("upgrades_run")
	var run_upgrades: Dictionary = active_run.get("run_upgrades", {})
	var candidates: Array = []

	for upgrade_data in upgrade_pool:
		if not (upgrade_data is Dictionary):
			continue
		var upgrade: Dictionary = upgrade_data
		var upgrade_id := String(upgrade.get("id", ""))
		var current_rank := int(run_upgrades.get(upgrade_id, 0))
		var max_rank := int(upgrade.get("max_rank", 1))
		if current_rank < max_rank:
			candidates.append(upgrade_id)

	if candidates.is_empty():
		return {}

	var bonus_choices := maxi(0, int(round(_meta_effect_total("run_upgrade_offer_extra_choices"))))
	var choice_count := mini(3 + bonus_choices, candidates.size())
	var choice_ids: Array = []
	var offer_salt := "%s:%s:%s:%s" % [
		int(active_run.get("seed", 0)),
		int(active_run.get("captured_tiles", 0)),
		int(active_run.get("level", 1)),
		picks_remaining
	]

	while choice_ids.size() < choice_count and not candidates.is_empty():
		var index: int = abs(_coord_hash("%s:%s" % [offer_salt, choice_ids.size()])) % candidates.size()
		choice_ids.append(String(candidates[index]))
		candidates.remove_at(index)

	return {
		"picks_remaining": picks_remaining,
		"choices": choice_ids
	}


func _queue_run_upgrade_if_needed(previous_level: int) -> void:
	if active_run.is_empty():
		return

	var current_level := int(active_run.get("level", 1))
	if current_level <= previous_level:
		return

	var pending_upgrade: Dictionary = active_run.get("pending_run_upgrade", {})
	var total_picks := int(pending_upgrade.get("picks_remaining", 0)) + (current_level - previous_level)
	active_run["pending_run_upgrade"] = _build_run_upgrade_offer(total_picks)


func _apply_run_upgrade_effect(effect: Dictionary) -> void:
	var player: Dictionary = active_run.get("player", {}).duplicate(true)
	var current_hp := int(player.get("current_hp", 0))
	var max_hp := int(player.get("max_hp", 0))

	if effect.has("attack_flat"):
		player["attack"] = int(player.get("attack", 0)) + int(effect["attack_flat"])
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
		current_hp = int(player["current_hp"])
	if effect.has("heal_flat"):
		player["current_hp"] = mini(max_hp, int(player.get("current_hp", current_hp)) + int(effect["heal_flat"]))
	if effect.has("gold_flat"):
		active_run["gold"] = int(active_run.get("gold", 0)) + int(effect["gold_flat"])
	if effect.has("essence_on_run_end_flat"):
		active_run["pending_essence_bonus"] = int(active_run.get("pending_essence_bonus", 0)) + int(effect["essence_on_run_end_flat"])
	if effect.has("sigils_on_run_end_flat"):
		active_run["pending_sigil_bonus"] = int(active_run.get("pending_sigil_bonus", 0)) + int(effect["sigils_on_run_end_flat"])
	_apply_player_special_effects(player, effect)

	active_run["player"] = player


func _build_relic_offer(picks_remaining: int) -> Dictionary:
	var relic_pool: Array = DataService.get_data_set("relics")
	var owned_relics: Array = active_run.get("relics", [])
	var candidates: Array = []

	for relic_data in relic_pool:
		if not (relic_data is Dictionary):
			continue
		var relic: Dictionary = relic_data
		var relic_id := String(relic.get("id", ""))
		if not owned_relics.has(relic_id):
			candidates.append(relic_id)

	if candidates.is_empty():
		for relic_data in relic_pool:
			if relic_data is Dictionary:
				candidates.append(String(relic_data.get("id", "")))

	var bonus_choices := maxi(0, int(round(_meta_effect_total("relic_offer_extra_choices"))))
	var choice_count := mini(3 + bonus_choices, candidates.size())
	var choice_ids: Array = []
	var offer_salt := "%s:%s:%s:%s" % [
		int(active_run.get("seed", 0)),
		int(active_run.get("bosses_defeated", 0)),
		int(active_run.get("captured_tiles", 0)),
		picks_remaining
	]

	while choice_ids.size() < choice_count and not candidates.is_empty():
		var index: int = abs(_coord_hash("%s:%s" % [offer_salt, choice_ids.size()])) % candidates.size()
		choice_ids.append(String(candidates[index]))
		candidates.remove_at(index)

	return {
		"picks_remaining": picks_remaining,
		"choices": choice_ids
	}


func _apply_relic_effect(player: Dictionary, effect: Dictionary) -> void:
	if effect.has("attack_flat"):
		player["attack"] = int(player.get("attack", 0)) + int(effect["attack_flat"])
	if effect.has("armor_flat"):
		player["armor"] = int(player.get("armor", 0)) + int(effect["armor_flat"])
	if effect.has("attack_speed"):
		player["attack_speed"] = float(player.get("attack_speed", 1.0)) + float(effect["attack_speed"])
	if effect.has("crit_rate"):
		player["crit_rate"] = float(player.get("crit_rate", 0.0)) + float(effect["crit_rate"])
	if effect.has("lifesteal"):
		player["lifesteal"] = float(player.get("lifesteal", 0.0)) + float(effect["lifesteal"])
	if effect.has("territory_power"):
		player["territory_power"] = float(player.get("territory_power", 0.0)) + float(effect["territory_power"])
	if effect.has("luck"):
		player["luck"] = int(player.get("luck", 0)) + int(effect["luck"])
	_apply_player_special_effects(player, effect)


func _apply_player_special_effects(player: Dictionary, effect: Dictionary) -> void:
	if effect.has("grant_skill"):
		_append_unique_strings(player, "skills", effect["grant_skill"])
	if effect.has("grant_trait"):
		_append_unique_strings(player, "traits", effect["grant_trait"])


func _append_unique_strings(target: Dictionary, key: String, values: Variant) -> void:
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


func _title_case_id(value: String) -> String:
	var parts := value.split("_")
	var title_parts: Array = []
	for part in parts:
		title_parts.append(String(part).capitalize())
	return " ".join(title_parts)


func _coord_hash(text: String) -> int:
	var total := 0
	for value in text.to_ascii_buffer():
		total = (total * 33) + int(value)
	return total
