extends RefCounted


func run() -> Array:
	var failures: Array = []
	DataService.load_all_data()

	_run_combat_victory_test(failures)
	_run_event_resolution_test(failures)
	_run_utility_resolution_test(failures)
	_run_levelup_run_upgrade_test(failures)
	_run_combat_defeat_test(failures)
	_run_boss_gate_test(failures)
	_run_boss_relic_reward_test(failures)
	_run_special_run_upgrade_test(failures)
	_run_special_relic_test(failures)
	_run_meta_progression_test(failures)
	_run_finish_run_summary_test(failures)

	GameState.load_profile_state(GameState.make_default_profile())
	return failures


func _run_combat_victory_test(failures: Array) -> void:
	GameState.load_profile_state(GameState.make_default_profile(), _make_run_state("plains", _make_player()))
	var result: Dictionary = GameState.resolve_tile("1,0")

	if not result.get("ok", false):
		failures.append("Expected plains resolution to succeed.")
		return
	if String(result.get("kind", "")) != "combat":
		failures.append("Expected plains tile to resolve as combat.")
	if not GameState.has_pending_combat():
		failures.append("Expected plains combat to create a pending combat encounter.")
		return

	var completion: Dictionary = GameState.complete_pending_combat()
	if not completion.get("victory", false):
		failures.append("Expected default player to defeat the plains enemy.")
	if int(GameState.active_run.get("captured_tiles", 0)) != 1:
		failures.append("Expected combat victory to capture the plains tile.")


func _run_event_resolution_test(failures: Array) -> void:
	GameState.load_profile_state(GameState.make_default_profile(), _make_run_state("shrine", _make_player()))
	var preview: Dictionary = GameState.resolve_tile("1,0")
	if String(preview.get("kind", "")) != "event":
		failures.append("Expected shrine tile to open an event.")
		return

	var event_def: Dictionary = preview.get("event", {})
	var choices: Array = event_def.get("choices", [])
	if choices.is_empty():
		failures.append("Expected shrine event to provide at least one choice.")
		return

	var first_choice: Dictionary = choices[0]
	var choice_id := String(first_choice.get("id", ""))
	var result: Dictionary = GameState.choose_event("1,0", choice_id)
	if not result.get("ok", false):
		failures.append("Expected shrine event choice to resolve successfully.")
		return

	if int(GameState.active_run.get("captured_tiles", 0)) != 1:
		failures.append("Expected shrine event resolution to capture the tile.")
	if String(GameState.active_run.get("last_action", {}).get("kind", "")) != "event":
		failures.append("Expected shrine event to update last action as event.")


func _run_utility_resolution_test(failures: Array) -> void:
	var player := _make_player({
		"current_hp": 40,
		"max_hp": 100
	})
	GameState.load_profile_state(GameState.make_default_profile(), _make_run_state("market", player))
	var result: Dictionary = GameState.resolve_tile("1,0")

	if String(result.get("kind", "")) != "utility":
		failures.append("Expected market tile to resolve as utility.")
		return
	if int(GameState.active_run.get("player", {}).get("current_hp", 0)) <= 40:
		failures.append("Expected market tile to restore player HP.")
	if int(GameState.active_run.get("captured_tiles", 0)) != 1:
		failures.append("Expected utility tile to count as captured.")


func _run_levelup_run_upgrade_test(failures: Array) -> void:
	var player := _make_player({
		"current_hp": 52,
		"max_hp": 80
	})
	var run_state: Dictionary = _make_run_state("market", player)
	run_state["xp"] = 24
	run_state["level"] = 1
	GameState.load_profile_state(GameState.make_default_profile(), run_state)

	var result: Dictionary = GameState.resolve_tile("1,0")
	if String(result.get("kind", "")) != "utility":
		failures.append("Expected market tile to still resolve as utility during level-up test.")
		return
	if not GameState.has_pending_run_upgrade():
		failures.append("Expected level-up utility capture to create a pending run upgrade.")
		return

	var pending_upgrade: Dictionary = GameState.get_pending_run_upgrade()
	var upgrade_ids: Array = pending_upgrade.get("choices", [])
	if upgrade_ids.is_empty():
		failures.append("Expected run upgrade offer to include at least one choice.")
		return

	var upgrade_id := String(upgrade_ids[0])
	var upgrade_def: Dictionary = DataService.get_run_upgrade_definitions().get(upgrade_id, {})
	var before_player: Dictionary = GameState.active_run.get("player", {}).duplicate(true)
	var before_gold := int(GameState.active_run.get("gold", 0))
	var choose_result: Dictionary = GameState.choose_run_upgrade(upgrade_id)
	if not choose_result.get("ok", false):
		failures.append("Expected run upgrade selection to succeed.")
		return
	if not GameState.active_run.get("run_upgrades", {}).has(upgrade_id):
		failures.append("Expected chosen run upgrade to be tracked on the active run.")
	if GameState.has_pending_run_upgrade():
		failures.append("Expected single level-up to consume the only pending run upgrade pick.")

	var effect: Dictionary = upgrade_def.get("effect", {})
	var after_player: Dictionary = GameState.active_run.get("player", {})
	if effect.has("attack_flat") and int(after_player.get("attack", 0)) <= int(before_player.get("attack", 0)):
		failures.append("Expected attack run upgrade to increase player attack.")
	if effect.has("armor_flat") and int(after_player.get("armor", 0)) <= int(before_player.get("armor", 0)):
		failures.append("Expected armor run upgrade to increase player armor.")
	if effect.has("attack_speed") and float(after_player.get("attack_speed", 0.0)) <= float(before_player.get("attack_speed", 0.0)):
		failures.append("Expected speed run upgrade to increase player attack speed.")
	if effect.has("crit_rate") and float(after_player.get("crit_rate", 0.0)) <= float(before_player.get("crit_rate", 0.0)):
		failures.append("Expected crit run upgrade to increase crit rate.")
	if effect.has("max_hp_flat") and int(after_player.get("max_hp", 0)) <= int(before_player.get("max_hp", 0)):
		failures.append("Expected vitality run upgrade to increase max HP.")
	if effect.has("territory_power") and float(after_player.get("territory_power", 0.0)) <= float(before_player.get("territory_power", 0.0)):
		failures.append("Expected territory run upgrade to increase territory power.")
	if effect.has("luck") and int(after_player.get("luck", 0)) <= int(before_player.get("luck", 0)):
		failures.append("Expected luck run upgrade to increase player luck.")
	if effect.has("gold_flat") and int(GameState.active_run.get("gold", 0)) <= before_gold:
		failures.append("Expected economy run upgrade to increase current gold.")


func _run_combat_defeat_test(failures: Array) -> void:
	var player := _make_player({
		"current_hp": 1,
		"max_hp": 1,
		"attack": 1,
		"armor": 0
	})
	GameState.load_profile_state(GameState.make_default_profile(), _make_run_state("fortress", player, 3))
	var result: Dictionary = GameState.resolve_tile("1,0")

	if String(result.get("kind", "")) != "combat":
		failures.append("Expected fortress tile to resolve as combat.")
		return

	var completion: Dictionary = GameState.complete_pending_combat()
	if completion.get("victory", true):
		failures.append("Expected fragile player to lose against the fortress encounter.")
	if int(GameState.active_run.get("player", {}).get("current_hp", -1)) != 0:
		failures.append("Expected defeat to set player HP to zero.")


func _run_boss_gate_test(failures: Array) -> void:
	var player := _make_player({
		"attack": 40,
		"max_hp": 180,
		"current_hp": 180,
		"armor": 12
	})
	var run_state: Dictionary = _make_run_state("plains", player)
	run_state["captured_tiles"] = 3
	GameState.load_profile_state(GameState.make_default_profile(), run_state)

	var result: Dictionary = GameState.resolve_tile("1,0")
	var encounter: Dictionary = result.get("encounter", {})
	if not bool(encounter.get("is_boss", false)):
		failures.append("Expected combat after three captures to become a boss encounter.")
		return
	if String(encounter.get("boss_id", "")) != "border_warden":
		failures.append("Expected first prototype boss to be border_warden.")


func _run_boss_relic_reward_test(failures: Array) -> void:
	var player := _make_player({
		"attack": 40,
		"max_hp": 180,
		"current_hp": 180,
		"armor": 12
	})
	var run_state: Dictionary = _make_run_state("plains", player)
	run_state["captured_tiles"] = 3
	GameState.load_profile_state(GameState.make_default_profile(), run_state)

	var preview: Dictionary = GameState.resolve_tile("1,0")
	if not bool(preview.get("encounter", {}).get("is_boss", false)):
		failures.append("Expected boss reward test to begin with a boss encounter.")
		return

	var completion: Dictionary = GameState.complete_pending_combat()
	if not completion.get("victory", false):
		failures.append("Expected boosted player to defeat the first boss.")
		return
	if not GameState.has_pending_relic_choice():
		failures.append("Expected boss victory to create a pending relic choice.")
		return

	var relic_choice: Dictionary = GameState.get_pending_relic_choice()
	var relic_ids: Array = relic_choice.get("choices", [])
	if relic_ids.is_empty():
		failures.append("Expected relic choice screen to offer at least one relic.")
		return

	var relic_id := String(relic_ids[0])
	var before_attack := int(GameState.active_run.get("player", {}).get("attack", 0))
	var before_armor := int(GameState.active_run.get("player", {}).get("armor", 0))
	var relic_result: Dictionary = GameState.choose_relic(relic_id)
	if not relic_result.get("ok", false):
		failures.append("Expected relic selection to succeed after boss victory.")
		return
	if GameState.has_pending_relic_choice():
		failures.append("Expected first boss reward to consume the only relic pick.")
	if not GameState.active_run.get("relics", []).has(relic_id):
		failures.append("Expected selected relic to be stored in the run relic list.")

	var effect: Dictionary = DataService.get_relic_definitions().get(relic_id, {}).get("effect", {})
	if effect.has("attack_flat") and int(GameState.active_run.get("player", {}).get("attack", 0)) <= before_attack:
		failures.append("Expected attack relic to increase player attack.")
	if effect.has("armor_flat") and int(GameState.active_run.get("player", {}).get("armor", 0)) <= before_armor:
		failures.append("Expected armor relic to increase player armor.")


func _run_special_run_upgrade_test(failures: Array) -> void:
	var run_state: Dictionary = _make_run_state("plains", _make_player())
	run_state["pending_run_upgrade"] = {
		"picks_remaining": 1,
		"choices": ["run_veteran_resolve"]
	}
	GameState.load_profile_state(GameState.make_default_profile(), run_state)

	var result: Dictionary = GameState.choose_run_upgrade("run_veteran_resolve")
	if not result.get("ok", false):
		failures.append("Expected trait-granting run upgrade to resolve successfully.")
		return
	if not GameState.active_run.get("player", {}).get("traits", []).has("veteran_resolve"):
		failures.append("Expected run upgrade to add veteran_resolve to player traits.")


func _run_special_relic_test(failures: Array) -> void:
	var run_state: Dictionary = _make_run_state("plains", _make_player())
	run_state["pending_relic_choice"] = {
		"picks_remaining": 1,
		"choices": ["relic_war_horn"]
	}
	GameState.load_profile_state(GameState.make_default_profile(), run_state)

	var result: Dictionary = GameState.choose_relic("relic_war_horn")
	if not result.get("ok", false):
		failures.append("Expected skill-granting relic to resolve successfully.")
		return
	if not GameState.active_run.get("player", {}).get("skills", []).has("command_volley"):
		failures.append("Expected relic to add command_volley to player skills.")


func _run_meta_progression_test(failures: Array) -> void:
	var profile := GameState.make_default_profile()
	profile["meta_upgrades"] = {
		"cmd_armor_1": 1,
		"logistics_luck_1": 1,
		"legacy_relic_choice_1": 1
	}
	GameState.load_profile_state(profile)
	GameState.start_new_run(123)

	var player: Dictionary = GameState.active_run.get("player", {})
	if int(player.get("armor", 0)) <= int(GameState.make_default_player().get("armor", 0)):
		failures.append("Expected meta armor upgrade to increase starting armor.")
	if int(player.get("luck", 0)) <= 0:
		failures.append("Expected meta luck upgrade to increase starting luck.")

	var boss_run_state: Dictionary = _make_run_state("plains", _make_player({
		"attack": 42,
		"max_hp": 190,
		"current_hp": 190,
		"armor": 12
	}))
	boss_run_state["captured_tiles"] = 3
	GameState.load_profile_state(profile, boss_run_state)
	var preview: Dictionary = GameState.resolve_tile("1,0")
	if not bool(preview.get("encounter", {}).get("is_boss", false)):
		failures.append("Expected meta progression test to reach a boss encounter.")
		return
	var completion: Dictionary = GameState.complete_pending_combat()
	if not completion.get("victory", false):
		failures.append("Expected meta progression test player to defeat the first boss.")
		return
	var relic_choice: Dictionary = GameState.get_pending_relic_choice()
	if int(relic_choice.get("choices", []).size()) < 4:
		failures.append("Expected relic-choice meta upgrade to add one extra relic option.")


func _run_finish_run_summary_test(failures: Array) -> void:
	var player := _make_player({
		"attack": 28,
		"max_hp": 140,
		"current_hp": 140,
		"armor": 10
	})
	var run_state: Dictionary = _make_run_state("plains", player)
	run_state["started_at"] = int(Time.get_unix_time_from_system()) - 90
	GameState.load_profile_state(GameState.make_default_profile(), run_state)

	var preview: Dictionary = GameState.resolve_tile("1,0")
	if String(preview.get("kind", "")) != "combat":
		failures.append("Expected finish-run summary test to begin with a combat tile.")
		return

	var completion: Dictionary = GameState.complete_pending_combat()
	if not completion.get("victory", false):
		failures.append("Expected finish-run summary test player to win the opening combat.")
		return

	GameState.active_run["pending_relic_choice"] = {
		"picks_remaining": 1,
		"choices": ["relic_war_horn"]
	}
	var relic_result: Dictionary = GameState.choose_relic("relic_war_horn")
	if not relic_result.get("ok", false):
		failures.append("Expected finish-run summary test relic choice to succeed.")
		return

	GameState.active_run["pending_run_upgrade"] = {
		"picks_remaining": 1,
		"choices": ["run_veteran_resolve"]
	}
	var upgrade_result: Dictionary = GameState.choose_run_upgrade("run_veteran_resolve")
	if not upgrade_result.get("ok", false):
		failures.append("Expected finish-run summary test run upgrade choice to succeed.")
		return

	var result: Dictionary = GameState.finish_run(true)
	var stats: Dictionary = result.get("stats", {})
	var combat_stats: Dictionary = stats.get("combat", {})
	var map_stats: Dictionary = stats.get("map", {})
	var economy_stats: Dictionary = stats.get("economy", {})
	var build_stats: Dictionary = stats.get("build", {})

	if int(combat_stats.get("victories", 0)) != 1:
		failures.append("Expected finish-run summary to record one combat victory.")
	if int(combat_stats.get("damage_dealt", 0)) <= 0:
		failures.append("Expected finish-run summary to record dealt combat damage.")
	if int(map_stats.get("captured_by_type", {}).get("plains", 0)) != 1:
		failures.append("Expected finish-run summary to count one captured plains tile.")
	if int(economy_stats.get("gold_from_tiles", 0)) <= 0:
		failures.append("Expected finish-run summary to track gold earned from tile capture.")
	if not result.get("relic_ids", []).has("relic_war_horn"):
		failures.append("Expected finish-run summary to persist chosen relic ids.")
	if not result.get("final_player", {}).get("skills", []).has("command_volley"):
		failures.append("Expected finish-run summary to include final player skill grants.")
	if not build_stats.get("relic_pick_order", []).has("relic_war_horn"):
		failures.append("Expected finish-run summary to keep relic pick order.")
	if not build_stats.get("run_upgrade_pick_order", []).has("run_veteran_resolve"):
		failures.append("Expected finish-run summary to keep run upgrade pick order.")


func _make_run_state(tile_type: String, player: Dictionary, ring: int = 1) -> Dictionary:
	return {
		"seed": 321,
		"phase_index": 1,
		"captured_tiles": 0,
		"danger": 0,
		"gold": 10,
		"xp": 0,
		"level": 1,
		"started_at": 0,
		"player": player,
		"relics": [],
		"curses": [],
		"bosses_defeated": 0,
		"pending_essence_bonus": 0,
		"pending_sigil_bonus": 0,
		"pending_combat": {},
		"pending_relic_choice": {},
		"pending_run_upgrade": {},
		"run_upgrades": {},
		"last_action": {},
		"map": {
			"radius": 1,
			"selected_tile": "",
			"tiles": {
				"0,0": { "x": 0, "y": 0, "type": "plains", "state": "captured", "ring": 0 },
				"1,0": { "x": 1, "y": 0, "type": tile_type, "state": "selectable", "ring": ring }
			}
		}
	}


func _make_player(overrides: Dictionary = {}) -> Dictionary:
	var player := GameState.make_default_player()
	for key in overrides.keys():
		player[key] = overrides[key]
	return player
