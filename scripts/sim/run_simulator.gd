extends RefCounted
class_name RunSimulator

const DEFAULT_MAX_STEPS := 256


func simulate_many(seeds: Array, profile_data: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	var runs: Array = []
	var failures: Array = []
	var aggregate := {
		"requested_runs": seeds.size(),
		"ended_runs": 0,
		"victories": 0,
		"defeats": 0,
		"finish_reason_counts": {},
		"total_bosses_defeated": 0,
		"max_captures": 0,
		"total_captures": 0,
		"tile_type_counts": {},
		"event_counts": {},
		"event_choice_counts": {},
		"relic_pick_counts": {},
		"run_upgrade_pick_counts": {},
		"tile_types_seen": {},
		"events_seen": {},
		"relics_picked": {},
		"run_upgrades_picked": {}
	}

	for seed_value in seeds:
		var run_result: Dictionary = simulate_run(int(seed_value), profile_data, options)
		runs.append(run_result)

		if not bool(run_result.get("ok", false)):
			failures.append(run_result)
			continue

		aggregate["ended_runs"] = int(aggregate.get("ended_runs", 0)) + 1
		if bool(run_result.get("victory", false)):
			aggregate["victories"] = int(aggregate.get("victories", 0)) + 1
		else:
			aggregate["defeats"] = int(aggregate.get("defeats", 0)) + 1
		_increment_count(aggregate["finish_reason_counts"], String(run_result.get("finish_reason", "ended")))

		var captures := int(run_result.get("captures", 0))
		aggregate["total_bosses_defeated"] = int(aggregate.get("total_bosses_defeated", 0)) + int(run_result.get("bosses_defeated", 0))
		aggregate["total_captures"] = int(aggregate.get("total_captures", 0)) + captures
		aggregate["max_captures"] = maxi(int(aggregate.get("max_captures", 0)), captures)

		_merge_count_sets(aggregate["tile_type_counts"], run_result.get("tile_type_counts", {}))
		_merge_count_sets(aggregate["event_counts"], run_result.get("event_counts", {}))
		_merge_count_sets(aggregate["event_choice_counts"], run_result.get("event_choice_counts", {}))
		_merge_count_sets(aggregate["relic_pick_counts"], run_result.get("relic_pick_counts", {}))
		_merge_count_sets(aggregate["run_upgrade_pick_counts"], run_result.get("run_upgrade_pick_counts", {}))
		_merge_flag_sets(aggregate["tile_types_seen"], run_result.get("tile_types_seen", {}))
		_merge_flag_sets(aggregate["events_seen"], run_result.get("events_seen", {}))
		_merge_flag_sets(aggregate["relics_picked"], run_result.get("relics_picked", {}))
		_merge_flag_sets(aggregate["run_upgrades_picked"], run_result.get("run_upgrades_picked", {}))

	aggregate["average_captures"] = (
		float(aggregate.get("total_captures", 0)) / float(maxi(1, int(aggregate.get("ended_runs", 0))))
	)
	aggregate["average_bosses_defeated"] = (
		float(aggregate.get("total_bosses_defeated", 0)) / float(maxi(1, int(aggregate.get("ended_runs", 0))))
	)

	return {
		"ok": failures.is_empty(),
		"runs": runs,
		"failures": failures,
		"aggregate": aggregate
	}


func simulate_run(seed: int, profile_data: Dictionary = {}, options: Dictionary = {}) -> Dictionary:
	DataService.load_all_data()
	var initial_profile: Dictionary = GameState.make_default_profile()
	if not profile_data.is_empty():
		initial_profile = profile_data.duplicate(true)
	GameState.load_profile_state(initial_profile)
	GameState.start_new_run(seed)

	var metrics := {
		"tile_type_counts": {},
		"event_counts": {},
		"event_choice_counts": {},
		"relic_pick_counts": {},
		"run_upgrade_pick_counts": {},
		"tile_types_seen": {},
		"events_seen": {},
		"relics_picked": {},
		"run_upgrades_picked": {}
	}
	var max_steps := maxi(1, int(options.get("max_steps", DEFAULT_MAX_STEPS)))

	for step in range(max_steps):
		var validation := _validate_run_state(step)
		if not bool(validation.get("ok", false)):
			return _failed_result(seed, step, String(validation.get("reason", "invalid_state")), metrics)

		var pending_result := _resolve_pending_states(seed, step, metrics)
		if not bool(pending_result.get("ok", false)):
			return _failed_result(seed, step, String(pending_result.get("reason", "pending_resolution_failed")), metrics)
		if bool(pending_result.get("finished", false)):
			return _finished_result(seed, step + 1, String(pending_result.get("finish_reason", "ended")), metrics, pending_result.get("result", {}))

		if GameState.is_run_clear_ready():
			var victory_result := GameState.finish_run(true)
			return _finished_result(seed, step + 1, "victory", metrics, victory_result)

		var selectable_coord_keys := _selectable_coord_keys(GameState.active_run)
		if selectable_coord_keys.is_empty():
			if int(GameState.active_run.get("player", {}).get("current_hp", 0)) <= 0:
				var defeat_result := GameState.finish_run(false)
				return _finished_result(seed, step + 1, "defeat", metrics, defeat_result)
			return _failed_result(seed, step, "softlock_no_selectable_tiles", metrics)

		var coord_key := _choose_tile_coord(selectable_coord_keys, metrics)
		var tiles: Dictionary = GameState.active_run.get("map", {}).get("tiles", {})
		var tile: Dictionary = tiles.get(coord_key, {})
		if tile.is_empty():
			return _failed_result(seed, step, "selected_tile_missing", metrics)

		var tile_type := String(tile.get("type", "plains"))
		_increment_count(metrics["tile_type_counts"], tile_type)
		metrics["tile_types_seen"][tile_type] = true

		var preview: Dictionary = GameState.resolve_tile(coord_key)
		if not bool(preview.get("ok", false)):
			return _failed_result(
				seed,
				step,
				"resolve_tile_failed:%s" % String(preview.get("message", "unknown")),
				metrics
			)

		if String(preview.get("kind", "")) == "event":
			var event_id := String(preview.get("event", {}).get("id", ""))
			if not event_id.is_empty():
				_increment_count(metrics["event_counts"], event_id)
				metrics["events_seen"][event_id] = true

	return _failed_result(seed, max_steps, "max_steps_exceeded", metrics)


func _resolve_pending_states(seed: int, step: int, metrics: Dictionary) -> Dictionary:
	while GameState.has_active_run():
		if GameState.has_pending_combat():
			var combat_result: Dictionary = GameState.complete_pending_combat()
			if not bool(combat_result.get("ok", false)):
				return { "ok": false, "reason": "complete_pending_combat_failed" }
			if not bool(combat_result.get("victory", false)):
				var defeat_result := GameState.finish_run(false)
				return {
					"ok": true,
					"finished": true,
					"finish_reason": "defeat",
					"result": defeat_result
				}
			continue

		if GameState.has_pending_event():
			var pending_event: Dictionary = GameState.get_pending_event()
			var event_def: Dictionary = pending_event.get("event", {})
			var event_id := String(event_def.get("id", ""))
			if not event_id.is_empty():
				_increment_count(metrics["event_counts"], event_id)
				metrics["events_seen"][event_id] = true
			var choice_id := _choose_event_choice_id(seed, step, pending_event)
			if choice_id.is_empty():
				return { "ok": false, "reason": "no_affordable_event_choice" }
			var event_choice_key := "%s:%s" % [event_id, choice_id]
			_increment_count(metrics["event_choice_counts"], event_choice_key)
			var event_result: Dictionary = GameState.choose_event(String(pending_event.get("coord_key", "")), choice_id)
			if not bool(event_result.get("ok", false)):
				return { "ok": false, "reason": "choose_event_failed:%s" % String(event_result.get("message", "unknown")) }
			continue

		if GameState.has_pending_relic_choice():
			var relic_id := _choose_relic_id(seed, step, GameState.get_pending_relic_choice())
			if relic_id.is_empty():
				return { "ok": false, "reason": "no_relic_choice_available" }
			var relic_result: Dictionary = GameState.choose_relic(relic_id)
			if not bool(relic_result.get("ok", false)):
				return { "ok": false, "reason": "choose_relic_failed:%s" % String(relic_result.get("message", "unknown")) }
			_increment_count(metrics["relic_pick_counts"], relic_id)
			metrics["relics_picked"][relic_id] = true
			continue

		if GameState.has_pending_run_upgrade():
			var upgrade_id := _choose_run_upgrade_id(seed, step, GameState.get_pending_run_upgrade())
			if upgrade_id.is_empty():
				return { "ok": false, "reason": "no_run_upgrade_choice_available" }
			var upgrade_result: Dictionary = GameState.choose_run_upgrade(upgrade_id)
			if not bool(upgrade_result.get("ok", false)):
				return { "ok": false, "reason": "choose_run_upgrade_failed:%s" % String(upgrade_result.get("message", "unknown")) }
			_increment_count(metrics["run_upgrade_pick_counts"], upgrade_id)
			metrics["run_upgrades_picked"][upgrade_id] = true
			continue

		break

	return { "ok": true, "finished": false }


func _validate_run_state(step: int) -> Dictionary:
	if int(GameState.profile.get("essence", 0)) < 0:
		return { "ok": false, "reason": "negative_profile_essence_step_%s" % step }
	if int(GameState.profile.get("sigils", 0)) < 0:
		return { "ok": false, "reason": "negative_profile_sigils_step_%s" % step }
	if not GameState.has_active_run():
		return { "ok": true }

	var run: Dictionary = GameState.active_run
	var player: Dictionary = run.get("player", {})
	var current_hp := int(player.get("current_hp", 0))
	var max_hp := int(player.get("max_hp", 0))
	if int(run.get("gold", 0)) < 0:
		return { "ok": false, "reason": "negative_run_gold_step_%s" % step }
	if max_hp <= 0:
		return { "ok": false, "reason": "non_positive_max_hp_step_%s" % step }
	if current_hp < 0 or current_hp > max_hp:
		return { "ok": false, "reason": "invalid_hp_bounds_step_%s" % step }

	var danger := int(run.get("danger", 0))
	if danger < 0 or danger > 100:
		return { "ok": false, "reason": "danger_out_of_bounds_step_%s" % step }

	if current_hp > 0 and not GameState.is_run_clear_ready(run):
		var has_pending := (
			GameState.has_pending_combat()
			or GameState.has_pending_event()
			or GameState.has_pending_relic_choice()
			or GameState.has_pending_run_upgrade()
		)
		if not has_pending and _selectable_coord_keys(run).is_empty():
			return { "ok": false, "reason": "softlock_state_detected_step_%s" % step }

	return { "ok": true }


func _selectable_coord_keys(run_data: Dictionary) -> Array:
	var selectable: Array = []
	var tiles: Dictionary = run_data.get("map", {}).get("tiles", {})
	for coord_key in tiles.keys():
		if String(tiles[coord_key].get("state", "")) == "selectable":
			selectable.append(String(coord_key))
	selectable.sort()
	return selectable


func _choose_tile_coord(selectable_coord_keys: Array, metrics: Dictionary) -> String:
	var run: Dictionary = GameState.active_run
	var tiles: Dictionary = run.get("map", {}).get("tiles", {})
	var tile_defs: Dictionary = DataService.get_tile_definitions()
	var best_coord := ""
	var best_score := -INF

	for coord_value in selectable_coord_keys:
		var coord_key := String(coord_value)
		var tile: Dictionary = tiles.get(coord_key, {})
		var tile_type := String(tile.get("type", "plains"))
		var tile_def: Dictionary = tile_defs.get(tile_type, {})
		var resolver_mode := String(tile_def.get("resolver_mode", "combat"))
		var hp_ratio := float(run.get("player", {}).get("current_hp", 0)) / maxf(1.0, float(run.get("player", {}).get("max_hp", 1)))
		var captures := int(run.get("captured_tiles", 0))
		var risk_delta := int(tile_def.get("risk_delta", 0))
		var score := float(tile.get("ring", 0)) * 8.0

		match resolver_mode:
			"utility":
				score += 24.0 if hp_ratio < 0.55 else 7.0
			"event":
				score += 12.0
			_:
				score += 9.0

		if tile_type == "sanctum":
			score += 8.0
		elif tile_type == "shrine" or tile_type == "ruins":
			score += 4.0

		if hp_ratio < 0.4 and resolver_mode == "combat":
			score -= 18.0
		elif hp_ratio < 0.55 and resolver_mode == "event":
			score -= 6.0

		if captures + 2 >= GameState.get_run_capture_goal():
			score += 5.0

		if metrics.get("tile_types_seen", {}).has(tile_type):
			score -= 1.5

		score -= float(maxi(0, risk_delta)) * (1.8 if hp_ratio < 0.55 else 0.9)
		score += float(_stable_hash("%s:%s:%s" % [int(run.get("seed", 0)), captures, coord_key]) % 17) * 0.01

		if score > best_score:
			best_score = score
			best_coord = coord_key

	return best_coord


func _choose_event_choice_id(seed: int, step: int, pending_event: Dictionary) -> String:
	var event_def: Dictionary = pending_event.get("event", {})
	var choices: Array = event_def.get("choices", [])
	var best_choice_id := ""
	var best_score := -INF
	var run: Dictionary = GameState.active_run
	var predicted_gold := int(run.get("gold", 0))
	var tile_type := String(pending_event.get("tile_type", "event"))
	var tile_capture_reward: Dictionary = GameState._tile_capture_reward_for_type(tile_type)
	predicted_gold += int(tile_capture_reward.get("gold", 0))

	for choice_value in choices:
		if not (choice_value is Dictionary):
			continue
		var choice: Dictionary = choice_value
		var choice_id := String(choice.get("id", ""))
		var cost: Dictionary = choice.get("cost", {})
		if cost.has("gold_flat") and predicted_gold < int(cost.get("gold_flat", 0)):
			continue

		var score := _effect_score(choice.get("reward", {}), run)
		score -= float(maxi(0, int(choice.get("danger_delta", 0)))) * 1.8
		score -= float(int(cost.get("gold_flat", 0))) * 0.75
		score -= float(int(round(float(cost.get("current_hp_percent", 0.0)) * 100.0))) * 0.8
		if cost.has("curse"):
			score -= 24.0
		score += float(_stable_hash("%s:%s:%s" % [seed, step, choice_id]) % 13) * 0.01

		if score > best_score:
			best_score = score
			best_choice_id = choice_id

	return best_choice_id


func _choose_relic_id(seed: int, step: int, pending_relic_choice: Dictionary) -> String:
	var defs: Dictionary = DataService.get_relic_definitions()
	return _choose_effect_choice_id(seed, step, pending_relic_choice.get("choices", []), defs)


func _choose_run_upgrade_id(seed: int, step: int, pending_run_upgrade: Dictionary) -> String:
	var defs: Dictionary = DataService.get_run_upgrade_definitions()
	return _choose_effect_choice_id(seed, step, pending_run_upgrade.get("choices", []), defs)


func _choose_effect_choice_id(seed: int, step: int, choice_ids: Array, definitions: Dictionary) -> String:
	var best_id := ""
	var best_score := -INF
	var run: Dictionary = GameState.active_run

	for choice_value in choice_ids:
		var choice_id := String(choice_value)
		var definition: Dictionary = definitions.get(choice_id, {})
		if definition.is_empty():
			continue

		var score := _effect_score(definition.get("effect", {}), run)
		score += float(_stable_hash("%s:%s:%s" % [seed, step, choice_id]) % 11) * 0.01
		if score > best_score:
			best_score = score
			best_id = choice_id

	return best_id


func _effect_score(effect: Dictionary, run: Dictionary) -> float:
	var player: Dictionary = run.get("player", {})
	var hp_ratio := float(player.get("current_hp", 0)) / maxf(1.0, float(player.get("max_hp", 1)))
	var score := 0.0

	score += float(effect.get("attack_flat", 0)) * 5.0
	score += float(effect.get("attack_percent", 0.0)) * 54.0
	score += float(effect.get("armor_flat", 0)) * (6.0 if hp_ratio < 0.65 else 4.5)
	score += float(effect.get("attack_speed", 0.0)) * 60.0
	score += float(effect.get("crit_rate", 0.0)) * 52.0
	score += float(effect.get("territory_power", 0.0)) * 60.0
	score += float(effect.get("max_hp_flat", 0)) * (2.1 if hp_ratio < 0.6 else 1.6)
	score += float(effect.get("heal_flat", 0)) * (1.8 if hp_ratio < 0.6 else 1.0)
	score += float(effect.get("heal_percent", 0.0)) * (120.0 if hp_ratio < 0.6 else 70.0)
	score += float(effect.get("luck", 0)) * 4.0
	score += float(effect.get("gold", 0)) * 0.55
	score += float(effect.get("gold_flat", 0)) * 0.55
	score += float(effect.get("xp", 0)) * 0.55
	score += float(effect.get("essence_on_run_end", 0)) * 0.8
	score += float(effect.get("essence_on_run_end_flat", 0)) * 0.8
	score += float(effect.get("sigils_on_run_end", 0)) * 6.0
	score += float(effect.get("sigils_on_run_end_flat", 0)) * 6.0
	score += float(effect.get("base_attack_flat", 0)) * 5.0
	score += float(effect.get("base_hp_flat", 0)) * 1.8
	score += float(effect.get("base_armor_flat", 0)) * 4.5
	score += float(effect.get("base_crit_rate_flat", 0.0)) * 52.0
	score += float(effect.get("starting_gold_flat", 0)) * 0.55
	score += float(effect.get("starting_luck_flat", 0)) * 4.0
	score += float(effect.get("essence_gain_percent", 0.0)) * 60.0
	score += float(effect.get("heal_after_boss_percent", 0.0)) * 65.0
	score += float(effect.get("boss_reward_essence_flat", 0)) * 2.2
	score += float(effect.get("boss_reward_sigil_flat", 0)) * 10.0
	score += float(effect.get("relic_offer_extra_choices", 0)) * 18.0
	score += float(effect.get("run_upgrade_offer_extra_choices", 0)) * 16.0
	score += float(effect.get("victory_sigils_flat", 0)) * 10.0

	if effect.has("grant_skill"):
		score += 16.0
	if effect.has("grant_trait"):
		score += 14.0

	return score


func _finished_result(seed: int, steps_taken: int, finish_reason: String, metrics: Dictionary, result: Dictionary) -> Dictionary:
	return {
		"ok": true,
		"seed": seed,
		"steps_taken": steps_taken,
		"finish_reason": finish_reason,
		"victory": bool(result.get("victory", false)),
		"captures": int(result.get("captures", 0)),
		"bosses_defeated": int(result.get("bosses_defeated", 0)),
		"tile_type_counts": metrics.get("tile_type_counts", {}).duplicate(true),
		"event_counts": metrics.get("event_counts", {}).duplicate(true),
		"event_choice_counts": metrics.get("event_choice_counts", {}).duplicate(true),
		"relic_pick_counts": metrics.get("relic_pick_counts", {}).duplicate(true),
		"run_upgrade_pick_counts": metrics.get("run_upgrade_pick_counts", {}).duplicate(true),
		"tile_types_seen": metrics.get("tile_types_seen", {}).duplicate(true),
		"events_seen": metrics.get("events_seen", {}).duplicate(true),
		"relics_picked": metrics.get("relics_picked", {}).duplicate(true),
		"run_upgrades_picked": metrics.get("run_upgrades_picked", {}).duplicate(true),
		"result": result.duplicate(true)
	}


func _failed_result(seed: int, step: int, reason: String, metrics: Dictionary) -> Dictionary:
	return {
		"ok": false,
		"seed": seed,
		"step": step,
		"reason": reason,
		"captures": int(GameState.active_run.get("captured_tiles", 0)),
		"tile_type_counts": metrics.get("tile_type_counts", {}).duplicate(true),
		"event_counts": metrics.get("event_counts", {}).duplicate(true),
		"event_choice_counts": metrics.get("event_choice_counts", {}).duplicate(true),
		"relic_pick_counts": metrics.get("relic_pick_counts", {}).duplicate(true),
		"run_upgrade_pick_counts": metrics.get("run_upgrade_pick_counts", {}).duplicate(true),
		"tile_types_seen": metrics.get("tile_types_seen", {}).duplicate(true),
		"events_seen": metrics.get("events_seen", {}).duplicate(true),
		"relics_picked": metrics.get("relics_picked", {}).duplicate(true),
		"run_upgrades_picked": metrics.get("run_upgrades_picked", {}).duplicate(true)
	}


func _merge_flag_sets(target: Dictionary, source: Dictionary) -> void:
	for key_value in source.keys():
		target[String(key_value)] = true


func _merge_count_sets(target: Dictionary, source: Dictionary) -> void:
	for key_value in source.keys():
		var key := String(key_value)
		target[key] = int(target.get(key, 0)) + int(source.get(key_value, 0))


func _increment_count(target: Dictionary, key: String) -> void:
	target[key] = int(target.get(key, 0)) + 1


func _stable_hash(text: String) -> int:
	var total := 0
	for value in text.to_ascii_buffer():
		total = (total * 33) + int(value)
	return abs(total)
