extends RefCounted

const CombatResolverScript = preload("res://scripts/combat/combat_resolver.gd")


func run() -> Array:
	var failures: Array = []
	var attacker := {
		"attack": 12,
		"crit_damage": 0.5,
		"territory_power": 0.1
	}
	var defender := {
		"armor": 5
	}

	var non_crit := CombatResolverScript.compute_damage(attacker, defender, 1.0, false, 1.0)
	if non_crit != 12:
		failures.append("Expected non-crit damage 12, got %s" % non_crit)

	var crit := CombatResolverScript.compute_damage(attacker, defender, 1.0, true, 1.0)
	if crit != 25:
		failures.append("Expected crit damage 25, got %s" % crit)

	var fast_interval := CombatResolverScript.attack_interval(10.0)
	if abs(fast_interval - 0.25) > 0.001:
		failures.append("Expected fast interval clamp to 0.25, got %s" % fast_interval)

	var battle_log: Dictionary = CombatResolverScript.simulate_battle_log(
		{
			"current_hp": 60,
			"max_hp": 60,
			"attack": 10,
			"attack_speed": 1.0,
			"armor": 2
		},
		{
			"current_hp": 30,
			"max_hp": 30,
			"attack": 4,
			"attack_speed": 0.8,
			"armor": 1
		}
	)
	if battle_log.get("events", []).is_empty():
		failures.append("Expected battle log simulation to produce at least one combat event.")

	var skill_battle_log: Dictionary = CombatResolverScript.simulate_battle_log(
		{
			"current_hp": 80,
			"max_hp": 80,
			"attack": 9,
			"attack_speed": 1.0,
			"armor": 3
		},
		{
			"display_name": "Hex Shaman",
			"current_hp": 40,
			"max_hp": 40,
			"attack": 7,
			"attack_speed": 1.2,
			"armor": 1,
			"skills": ["hex_bolt"]
		},
		0.1,
		8.0
	)
	var saw_hex_bolt := false
	var saw_status_tick := false
	var saw_state_snapshot := false
	var saw_player_burn_or_weaken := false
	for event_value in skill_battle_log.get("events", []):
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		if String(event.get("skill_label", "")) == "Hex Bolt":
			saw_hex_bolt = true
		if String(event.get("kind", "")) == "status_tick":
			saw_status_tick = true
		if event.has("player_state") and event.has("enemy_state"):
			saw_state_snapshot = true
			if _state_has_status(event.get("player_state", {}), "burn") or _state_has_status(event.get("player_state", {}), "weaken"):
				saw_player_burn_or_weaken = true
	if not saw_hex_bolt:
		failures.append("Expected skilled combat log to include Hex Bolt attack events.")
	if not saw_status_tick:
		failures.append("Expected skilled combat log to include status tick events.")
	if not saw_state_snapshot:
		failures.append("Expected combat log events to include actor state snapshots for UI playback.")
	if not saw_player_burn_or_weaken:
		failures.append("Expected actor state snapshots to expose applied burn or weaken statuses.")

	var phase_battle_log: Dictionary = CombatResolverScript.simulate_battle_log(
		{
			"current_hp": 150,
			"max_hp": 150,
			"attack": 14,
			"attack_speed": 1.0,
			"armor": 5
		},
		{
			"display_name": "Phase Warden",
			"current_hp": 110,
			"max_hp": 110,
			"attack": 7,
			"attack_speed": 0.9,
			"armor": 4,
			"skills": ["fortified_march"],
			"phases": [
				{
					"id": "shield_rush",
					"name": "Shield Rush",
					"trigger_hp_percent": 0.75,
					"description": "The warden enters phase two.",
					"bonuses": { "speed_bonus": 0.08 },
					"add_skills": ["slam"]
				}
			]
		},
		0.1,
		12.0
	)
	var saw_phase_change := false
	var saw_phase_skill := false
	for event_value in phase_battle_log.get("events", []):
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		if String(event.get("kind", "")) == "phase_change":
			saw_phase_change = true
		if String(event.get("skill_label", "")) == "Slam":
			saw_phase_skill = true
	if not saw_phase_change:
		failures.append("Expected boss battle log to include a phase change event.")
	if not saw_phase_skill:
		failures.append("Expected boss phase transition to unlock and use the Slam skill.")

	var player_feature_log: Dictionary = CombatResolverScript.simulate_battle_log(
		{
			"current_hp": 60,
			"max_hp": 60,
			"attack": 11,
			"attack_speed": 1.0,
			"armor": 2,
			"skills": ["ember_rounds"],
			"traits": ["veteran_resolve"]
		},
		{
			"display_name": "Raider Captain",
			"current_hp": 75,
			"max_hp": 75,
			"attack": 12,
			"attack_speed": 1.1,
			"armor": 1
		},
		0.1,
		10.0
	)
	var saw_player_skill := false
	var saw_player_trait := false
	for event_value in player_feature_log.get("events", []):
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		if String(event.get("skill_label", "")) == "Ember Rounds":
			saw_player_skill = true
		if String(event.get("kind", "")) == "trait_trigger" and String(event.get("trait_name", "")) == "Veteran Resolve":
			saw_player_trait = true
	if not saw_player_skill:
		failures.append("Expected player feature combat log to include Ember Rounds attacks.")
	if not saw_player_trait:
		failures.append("Expected player feature combat log to include Veteran Resolve trait triggers.")

	var expansion_feature_log: Dictionary = CombatResolverScript.simulate_battle_log(
		{
			"current_hp": 72,
			"max_hp": 72,
			"attack": 11,
			"attack_speed": 1.0,
			"armor": 3,
			"skills": ["shrapnel_burst"],
			"traits": ["iron_reflexes"]
		},
		{
			"display_name": "Bombardier",
			"current_hp": 82,
			"max_hp": 82,
			"attack": 10,
			"attack_speed": 0.9,
			"armor": 2
		},
		0.1,
		12.0
	)
	var saw_shrapnel_burst := false
	var saw_iron_reflexes := false
	for event_value in expansion_feature_log.get("events", []):
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		if String(event.get("skill_label", "")) == "Shrapnel Burst":
			saw_shrapnel_burst = true
		if String(event.get("kind", "")) == "trait_trigger" and String(event.get("trait_name", "")) == "Iron Reflexes":
			saw_iron_reflexes = true
	if not saw_shrapnel_burst:
		failures.append("Expected expansion combat log to include Shrapnel Burst attacks.")
	if not saw_iron_reflexes:
		failures.append("Expected expansion combat log to include Iron Reflexes trait triggers.")

	return failures


func _state_has_status(state: Dictionary, status_id: String) -> bool:
	for status_value in state.get("statuses", []):
		if not (status_value is Dictionary):
			continue
		if String(status_value.get("id", "")) == status_id:
			return true
	return false
