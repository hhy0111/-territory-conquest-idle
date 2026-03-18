extends RefCounted
class_name CombatResolver

const CombatActorScript = preload("res://scripts/combat/combat_actor.gd")


static func attack_interval(attack_speed: float) -> float:
	return maxf(0.25, 1.0 / maxf(0.01, attack_speed))


static func compute_damage(attacker: Dictionary, defender: Dictionary, variance: float = 1.0, force_crit: bool = false, skill_multiplier: float = 1.0) -> int:
	var attack := float(attacker.get("attack", 0.0))
	var crit_damage := float(attacker.get("crit_damage", 0.0))
	var territory_power := float(attacker.get("territory_power", 0.0))
	var armor := float(defender.get("armor", 0.0))

	var crit_multiplier: float = 1.5 + crit_damage
	var armor_multiplier: float = 100.0 / (100.0 + maxf(-50.0, armor))
	var damage_before_armor: float = attack * skill_multiplier * (1.0 + territory_power)
	var critical_damage: float = damage_before_armor * (crit_multiplier if force_crit else 1.0)
	return maxi(1, int(floor(critical_damage * armor_multiplier * variance)))


static func simulate_basic_duel(player_stats: Dictionary, enemy_stats: Dictionary, tick: float = 0.1, max_seconds: float = 30.0) -> Dictionary:
	var detailed: Dictionary = simulate_battle_log(player_stats, enemy_stats, tick, max_seconds)
	return {
		"victory": detailed.get("victory", false),
		"player_hp": detailed.get("player_hp", 0),
		"enemy_hp": detailed.get("enemy_hp", 0),
		"elapsed": detailed.get("elapsed", 0.0)
	}


static func simulate_battle_log(player_stats: Dictionary, enemy_stats: Dictionary, tick: float = 0.1, max_seconds: float = 30.0) -> Dictionary:
	var player = CombatActorScript.new(player_stats)
	var enemy = CombatActorScript.new(enemy_stats)

	var elapsed: float = 0.0
	var player_cooldown: float = 0.0
	var enemy_cooldown: float = 0.0
	var events: Array = []

	while elapsed < max_seconds and player.is_alive() and enemy.is_alive():
		player_cooldown -= tick
		enemy_cooldown -= tick
		var event_start_index := events.size()
		_append_status_events(events, player.advance_statuses(tick), "player", "Commander", elapsed, player.current_hp, enemy.current_hp)
		_decorate_new_events(events, event_start_index, player, enemy)
		event_start_index = events.size()
		_append_status_events(events, enemy.advance_statuses(tick), "enemy", String(enemy.stats.get("display_name", "Enemy")), elapsed, player.current_hp, enemy.current_hp)
		_decorate_new_events(events, event_start_index, player, enemy)
		event_start_index = events.size()
		_process_boss_phase_transitions(enemy, events, elapsed, player.current_hp)
		_decorate_new_events(events, event_start_index, player, enemy)
		event_start_index = events.size()
		_process_combat_traits(player, enemy, "player", "Commander", events, elapsed)
		_decorate_new_events(events, event_start_index, player, enemy)
		event_start_index = events.size()
		_process_combat_traits(enemy, player, "enemy", String(enemy.stats.get("display_name", "Enemy")), events, elapsed)
		_decorate_new_events(events, event_start_index, player, enemy)

		if not player.is_alive() or not enemy.is_alive():
			break

		if player_cooldown <= 0.0:
			event_start_index = events.size()
			_resolve_attack(player, enemy, "player", "Commander", String(enemy.stats.get("display_name", "Enemy")), events, elapsed)
			_decorate_new_events(events, event_start_index, player, enemy)
			event_start_index = events.size()
			_process_boss_phase_transitions(enemy, events, elapsed, player.current_hp)
			_decorate_new_events(events, event_start_index, player, enemy)
			event_start_index = events.size()
			_process_combat_traits(player, enemy, "player", "Commander", events, elapsed)
			_decorate_new_events(events, event_start_index, player, enemy)
			event_start_index = events.size()
			_process_combat_traits(enemy, player, "enemy", String(enemy.stats.get("display_name", "Enemy")), events, elapsed)
			_decorate_new_events(events, event_start_index, player, enemy)
			player_cooldown = player.attack_interval()

		if enemy.is_alive() and enemy_cooldown <= 0.0:
			event_start_index = events.size()
			_resolve_attack(enemy, player, "enemy", String(enemy.stats.get("display_name", "Enemy")), "Commander", events, elapsed)
			_decorate_new_events(events, event_start_index, player, enemy)
			event_start_index = events.size()
			_process_combat_traits(player, enemy, "player", "Commander", events, elapsed)
			_decorate_new_events(events, event_start_index, player, enemy)
			event_start_index = events.size()
			_process_combat_traits(enemy, player, "enemy", String(enemy.stats.get("display_name", "Enemy")), events, elapsed)
			_decorate_new_events(events, event_start_index, player, enemy)
			enemy_cooldown = enemy.attack_interval()

		elapsed += tick

	return {
		"victory": player.is_alive() and not enemy.is_alive(),
		"player_hp": player.current_hp,
		"enemy_hp": enemy.current_hp,
		"elapsed": elapsed,
		"events": events,
		"initial_player_state": _actor_state_snapshot(player_stats),
		"initial_enemy_state": _actor_state_snapshot(enemy_stats),
		"final_player_state": player.export_state(),
		"final_enemy_state": enemy.export_state()
	}


static func _resolve_attack(attacker, defender, attacker_side: String, attacker_name: String, target_name: String, events: Array, elapsed: float) -> void:
	var attack_index: int = int(attacker.attack_count) + 1
	var actions: Array = _skill_actions_for_attack(attacker.stats, attack_index)
	var target_side := "enemy" if attacker_side == "player" else "player"

	for action_value in actions:
		if not defender.is_alive():
			break
		if not (action_value is Dictionary):
			continue

		var action: Dictionary = action_value
		var attacker_stats: Dictionary = attacker.effective_stats()
		var defender_stats: Dictionary = defender.effective_stats()
		var damage: int = compute_damage(
			attacker_stats,
			defender_stats,
			1.0,
			bool(action.get("force_crit", false)),
			float(action.get("skill_multiplier", 1.0))
		)
		defender.apply_damage(damage)

		var applied_statuses: Array = []
		for status_value in action.get("target_statuses", []):
			if not (status_value is Dictionary):
				continue
			var status_payload: Dictionary = status_value.duplicate(true)
			status_payload["source_side"] = attacker_side
			status_payload["source_name"] = attacker_name
			var status: Dictionary = defender.add_status(status_payload)
			applied_statuses.append(_status_display_name(String(status.get("id", "status"))))

		for self_status_value in action.get("self_statuses", []):
			if self_status_value is Dictionary:
				var self_status: Dictionary = self_status_value.duplicate(true)
				self_status["source_side"] = attacker_side
				self_status["source_name"] = attacker_name
				attacker.add_status(self_status)

		var lifesteal_amount := int(floor(float(damage) * float(attacker_stats.get("lifesteal", 0.0))))
		var heal_amount := int(action.get("heal_flat", 0)) + lifesteal_amount
		if heal_amount > 0:
			attacker.heal(heal_amount)

		events.append({
			"kind": "attack",
			"attacker": attacker_side,
			"attacker_name": attacker_name,
			"target_side": target_side,
			"target_name": target_name,
			"damage": damage,
			"player_hp": attacker.current_hp if attacker_side == "player" else defender.current_hp,
			"enemy_hp": defender.current_hp if attacker_side == "player" else attacker.current_hp,
			"elapsed": _round_elapsed(elapsed),
			"skill_label": String(action.get("label", "Attack")),
			"status_text": ", ".join(applied_statuses),
			"heal_amount": heal_amount
		})

	attacker.attack_count = attack_index


static func _process_boss_phase_transitions(enemy, events: Array, elapsed: float, player_hp: int) -> void:
	var phases: Array = enemy.stats.get("phases", [])
	if phases.is_empty() or not enemy.is_alive():
		return

	var phase_index: int = int(enemy.stats.get("phase_index", 0))
	while phase_index < phases.size() and enemy.is_alive():
		var phase_data: Dictionary = phases[phase_index]
		var trigger_hp_percent: float = float(phase_data.get("trigger_hp_percent", 0.0))
		if _hp_ratio(enemy) > trigger_hp_percent:
			break

		var phase_result: Dictionary = _apply_phase(enemy, phase_data)
		events.append({
			"kind": "phase_change",
			"attacker": "enemy",
			"attacker_name": String(enemy.stats.get("display_name", "Enemy")),
			"phase_name": String(phase_data.get("name", "Phase Shift")),
			"phase_description": String(phase_data.get("description", "")),
			"buff_summary": String(phase_result.get("summary", "")),
			"status_text": String(phase_result.get("status_text", "")),
			"heal_amount": int(phase_result.get("heal_amount", 0)),
			"player_hp": player_hp,
			"enemy_hp": enemy.current_hp,
			"elapsed": _round_elapsed(elapsed)
		})

		phase_index += 1
		enemy.stats["phase_index"] = phase_index


static func _apply_phase(enemy, phase_data: Dictionary) -> Dictionary:
	var bonuses: Dictionary = phase_data.get("bonuses", {})
	var summary_segments: Array = []

	if bonuses.has("attack_multiplier"):
		enemy.stats["attack"] = int(round(float(enemy.stats.get("attack", 0)) * float(bonuses["attack_multiplier"])))
		summary_segments.append("Attack Up")
	if bonuses.has("armor_bonus"):
		enemy.stats["armor"] = int(enemy.stats.get("armor", 0)) + int(bonuses["armor_bonus"])
		summary_segments.append("Armor Up")
	if bonuses.has("speed_bonus"):
		enemy.stats["attack_speed"] = maxf(0.4, float(enemy.stats.get("attack_speed", 1.0)) + float(bonuses["speed_bonus"]))
		summary_segments.append("Faster Attacks")
	if bonuses.has("territory_power_bonus"):
		enemy.stats["territory_power"] = float(enemy.stats.get("territory_power", 0.0)) + float(bonuses["territory_power_bonus"])
		summary_segments.append("Territory Power Up")
	if bonuses.has("crit_damage_bonus"):
		enemy.stats["crit_damage"] = float(enemy.stats.get("crit_damage", 0.0)) + float(bonuses["crit_damage_bonus"])
		summary_segments.append("Crit Damage Up")

	var skills: Array = enemy.stats.get("skills", []).duplicate(true)
	for skill_value in phase_data.get("add_skills", []):
		var skill_id := String(skill_value)
		if not skills.has(skill_id):
			skills.append(skill_id)
			summary_segments.append("Unlocked %s" % _skill_display_name(skill_id))
	enemy.stats["skills"] = skills

	var applied_statuses: Array = []
	for status_value in phase_data.get("self_statuses", []):
		if not (status_value is Dictionary):
			continue
		var status_payload: Dictionary = status_value.duplicate(true)
		status_payload["source_side"] = "enemy"
		status_payload["source_name"] = String(enemy.stats.get("display_name", "Enemy"))
		var status: Dictionary = enemy.add_status(status_payload)
		applied_statuses.append(_status_display_name(String(status.get("id", "status"))))

	var heal_amount := 0
	if phase_data.has("heal_percent"):
		heal_amount = int(round(float(enemy.max_hp()) * float(phase_data.get("heal_percent", 0.0))))
		if heal_amount > 0:
			enemy.heal(heal_amount)
			summary_segments.append("Recovered HP")

	return {
		"summary": ", ".join(summary_segments),
		"status_text": ", ".join(applied_statuses),
		"heal_amount": heal_amount
	}


static func _append_status_events(events: Array, status_events: Array, owner_side: String, owner_name: String, elapsed: float, player_hp: int, enemy_hp: int) -> void:
	for event_value in status_events:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value
		events.append({
			"kind": "status_tick",
			"attacker": String(event.get("source_side", owner_side)),
			"attacker_name": String(event.get("source_name", owner_name)),
			"target_side": owner_side,
			"target_name": owner_name,
			"status_id": String(event.get("status_id", "status")),
			"damage": int(event.get("damage", 0)),
			"player_hp": player_hp if owner_side == "enemy" else int(event.get("current_hp", player_hp)),
			"enemy_hp": int(event.get("current_hp", enemy_hp)) if owner_side == "enemy" else enemy_hp,
			"elapsed": _round_elapsed(elapsed)
		})


static func _skill_actions_for_attack(stats: Dictionary, attack_index: int) -> Array:
	var skills: Array = stats.get("skills", [])
	for skill_value in skills:
		var skill_id := String(skill_value)
		var skill_actions: Array = _actions_for_skill(skill_id, attack_index)
		if not skill_actions.is_empty():
			return skill_actions
	return [{ "label": "Attack", "skill_multiplier": 1.0 }]


static func _actions_for_skill(skill_id: String, attack_index: int) -> Array:
	match skill_id:
		"ember_rounds":
			if attack_index % 3 == 0:
				return [{
					"label": "Ember Rounds",
					"skill_multiplier": 1.05,
					"target_statuses": [{ "id": "burn", "duration": 2.5, "tick_damage": 4, "tick_interval": 1.0 }]
				}]
		"breaker_strike":
			if attack_index % 4 == 0:
				return [{
					"label": "Breaker Strike",
					"skill_multiplier": 1.2,
					"target_statuses": [{ "id": "sunder", "duration": 3.0, "armor_delta": -4 }]
				}]
		"shrapnel_burst":
			if attack_index % 4 == 0:
				return [
					{
						"label": "Shrapnel Burst",
						"skill_multiplier": 0.7,
						"target_statuses": [{ "id": "burn", "duration": 2.0, "tick_damage": 3, "tick_interval": 1.0 }]
					},
					{
						"label": "Shrapnel Burst",
						"skill_multiplier": 0.7,
						"target_statuses": [{ "id": "sunder", "duration": 2.5, "armor_delta": -2 }]
					}
				]
		"bulwark_drive":
			if attack_index % 4 == 0:
				return [{
					"label": "Bulwark Drive",
					"skill_multiplier": 1.15,
					"self_statuses": [{ "id": "guard", "duration": 3.0, "armor_delta": 5 }]
				}]
		"command_volley":
			if attack_index % 5 == 0:
				return [
					{ "label": "Command Volley", "skill_multiplier": 0.75 },
					{
						"label": "Command Volley",
						"skill_multiplier": 0.75,
						"target_statuses": [{ "id": "weaken", "duration": 2.5, "attack_multiplier": 0.85 }]
					}
				]
		"gap_close_light":
			if attack_index == 1:
				return [{ "label": "Gap Close", "skill_multiplier": 1.2 }]
		"volley_light":
			if attack_index % 3 == 0:
				return [
					{ "label": "Volley", "skill_multiplier": 0.7 },
					{ "label": "Volley", "skill_multiplier": 0.7 }
				]
		"slam":
			if attack_index % 2 == 0:
				return [{
					"label": "Slam",
					"skill_multiplier": 1.35,
					"target_statuses": [{ "id": "sunder", "duration": 3.0, "armor_delta": -3 }]
				}]
		"hex_bolt":
			if attack_index % 2 == 0:
				return [{
					"label": "Hex Bolt",
					"skill_multiplier": 1.0,
					"target_statuses": [
						{ "id": "burn", "duration": 3.0, "tick_damage": 3, "tick_interval": 1.0 },
						{ "id": "weaken", "duration": 3.0, "attack_multiplier": 0.85 }
					]
				}]
		"brace_counter":
			if attack_index == 1:
				return [{
					"label": "Brace Counter",
					"skill_multiplier": 1.0,
					"self_statuses": [{ "id": "guard", "duration": 3.0, "armor_delta": 4 }]
				}]
			if attack_index % 3 == 0:
				return [{
					"label": "Brace Counter",
					"skill_multiplier": 1.15,
					"self_statuses": [{ "id": "guard", "duration": 2.5, "armor_delta": 3 }],
					"target_statuses": [{ "id": "sunder", "duration": 2.5, "armor_delta": -2 }]
				}]
		"harrier_step":
			if attack_index % 2 == 0:
				return [
					{ "label": "Harrier Step", "skill_multiplier": 0.68 },
					{
						"label": "Harrier Step",
						"skill_multiplier": 0.68,
						"target_statuses": [{ "id": "weaken", "duration": 2.0, "attack_multiplier": 0.88 }]
					}
				]
		"fanatic_surge":
			if attack_index == 1 or attack_index % 3 == 0:
				return [{
					"label": "Fanatic Surge",
					"skill_multiplier": 1.18,
					"self_statuses": [{ "id": "fury", "duration": 3.5, "attack_multiplier": 1.14, "crit_damage_delta": 0.1 }]
				}]
		"mortar_barrage":
			if attack_index % 3 == 0:
				return [
					{
						"label": "Mortar Barrage",
						"skill_multiplier": 0.8,
						"target_statuses": [{ "id": "burn", "duration": 2.0, "tick_damage": 3, "tick_interval": 1.0 }]
					},
					{ "label": "Mortar Barrage", "skill_multiplier": 0.8 }
				]
		"fortified_march":
			if attack_index == 1 or attack_index % 3 == 0:
				return [{
					"label": "Fortified March",
					"skill_multiplier": 1.05,
					"self_statuses": [{ "id": "guard", "duration": 2.5, "armor_delta": 6 }]
				}]
		"ancient_bark":
			if attack_index == 1:
				return [{
					"label": "Ancient Bark",
					"skill_multiplier": 1.0,
					"self_statuses": [{ "id": "guard", "duration": 4.0, "armor_delta": 8 }]
				}]
			if attack_index % 4 == 0:
				return [{
					"label": "Crushing Limb",
					"skill_multiplier": 1.15,
					"heal_flat": 8
				}]
		"overheat_arsenal":
			if attack_index % 3 == 0:
				return [{
					"label": "Overheat Arsenal",
					"skill_multiplier": 1.4,
					"target_statuses": [{ "id": "burn", "duration": 2.0, "tick_damage": 4, "tick_interval": 1.0 }]
				}]
		"void_liturgy":
			if attack_index % 3 == 0:
				return [{
					"label": "Void Liturgy",
					"skill_multiplier": 1.1,
					"target_statuses": [
						{ "id": "burn", "duration": 2.0, "tick_damage": 3, "tick_interval": 1.0 },
						{ "id": "weaken", "duration": 2.5, "attack_multiplier": 0.8 }
					]
				}]
		"last_dominion":
			if attack_index % 4 == 0:
				return [
					{ "label": "Royal Strike", "skill_multiplier": 1.05 },
					{
						"label": "Royal Decree",
						"skill_multiplier": 0.95,
						"force_crit": true,
						"target_statuses": [{ "id": "sunder", "duration": 3.0, "armor_delta": -4 }]
					}
				]
	return []


static func _process_combat_traits(actor, opponent, actor_side: String, actor_name: String, events: Array, elapsed: float) -> void:
	var traits: Array = actor.stats.get("traits", [])
	for trait_value in traits:
		var trait_id := String(trait_value)
		if actor.trait_triggered(trait_id):
			continue

		var trait_result: Dictionary = _trait_result(trait_id, actor, opponent)
		if trait_result.is_empty():
			continue

		actor.mark_trait_triggered(trait_id)

		var applied_statuses: Array = []
		for status_value in trait_result.get("self_statuses", []):
			if not (status_value is Dictionary):
				continue
			var status_payload: Dictionary = status_value.duplicate(true)
			status_payload["source_side"] = actor_side
			status_payload["source_name"] = actor_name
			var status: Dictionary = actor.add_status(status_payload)
			applied_statuses.append(_status_display_name(String(status.get("id", "status"))))

		var heal_amount := int(trait_result.get("heal_amount", 0))
		if heal_amount > 0:
			actor.heal(heal_amount)

		events.append({
			"kind": "trait_trigger",
			"attacker": actor_side,
			"attacker_name": actor_name,
			"trait_name": String(trait_result.get("name", _special_display_name(trait_id))),
			"summary": String(trait_result.get("summary", "")),
			"status_text": ", ".join(applied_statuses),
			"heal_amount": heal_amount,
			"player_hp": actor.current_hp if actor_side == "player" else opponent.current_hp,
			"enemy_hp": opponent.current_hp if actor_side == "player" else actor.current_hp,
			"elapsed": _round_elapsed(elapsed)
		})


static func _trait_result(trait_id: String, actor, opponent) -> Dictionary:
	match trait_id:
		"veteran_resolve":
			if actor.is_alive() and _hp_ratio(actor) <= 0.5:
				return {
					"name": "Veteran Resolve",
					"summary": "Recovers and braces under pressure.",
					"heal_amount": int(round(float(actor.max_hp()) * 0.12)),
					"self_statuses": [{ "id": "guard", "duration": 3.0, "armor_delta": 4 }]
				}
		"execution_order":
			if opponent.is_alive() and _hp_ratio(opponent) <= 0.35:
				return {
					"name": "Execution Order",
					"summary": "Sees weakness and pushes for the finish.",
					"self_statuses": [{ "id": "fury", "duration": 4.0, "attack_multiplier": 1.18, "crit_damage_delta": 0.15 }]
				}
		"unyielding_standard":
			if int(actor.attack_count) >= 3:
				return {
					"name": "Unyielding Standard",
					"summary": "Battle rhythm turns into a frontline surge.",
					"self_statuses": [{ "id": "fervor", "duration": 5.0, "attack_multiplier": 1.1, "territory_power_delta": 0.04 }]
				}
		"iron_reflexes":
			if actor.is_alive() and _hp_ratio(actor) <= 0.75:
				return {
					"name": "Iron Reflexes",
					"summary": "Braces and steadies the line once the pressure begins.",
					"self_statuses": [{ "id": "guard", "duration": 4.0, "armor_delta": 5 }]
				}
		"march_supremacy":
			if int(actor.attack_count) >= 2 and opponent.is_alive() and _hp_ratio(opponent) <= 0.7:
				return {
					"name": "March Supremacy",
					"summary": "The offensive line surges once control is established.",
					"self_statuses": [{ "id": "fury", "duration": 4.0, "attack_multiplier": 1.12, "crit_damage_delta": 0.1 }]
				}
	return {}


static func _special_display_name(value: String) -> String:
	var parts := String(value).split("_")
	var title_parts: Array = []
	for part in parts:
		title_parts.append(String(part).capitalize())
	return " ".join(title_parts)


static func _skill_display_name(skill_id: String) -> String:
	return _special_display_name(skill_id)


static func _status_display_name(status_id: String) -> String:
	match status_id:
		"burn":
			return "Burn"
		"weaken":
			return "Weaken"
		"sunder":
			return "Sunder"
		"guard":
			return "Guard"
		"fury":
			return "Fury"
		"fervor":
			return "Fervor"
		_:
			return status_id.capitalize()


static func _hp_ratio(actor) -> float:
	return float(actor.current_hp) / maxf(1.0, float(actor.max_hp()))


static func _round_elapsed(value: float) -> float:
	return round(value * 100.0) / 100.0


static func _decorate_new_events(events: Array, start_index: int, player, enemy) -> void:
	if start_index >= events.size():
		return

	var player_state: Dictionary = player.export_state()
	var enemy_state: Dictionary = enemy.export_state()
	for index in range(start_index, events.size()):
		var event: Dictionary = events[index]
		event["player_state"] = player_state.duplicate(true)
		event["enemy_state"] = enemy_state.duplicate(true)
		events[index] = event


static func _actor_state_snapshot(stats: Dictionary) -> Dictionary:
	var actor = CombatActorScript.new(stats)
	return actor.export_state()
