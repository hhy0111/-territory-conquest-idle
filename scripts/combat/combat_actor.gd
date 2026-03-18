extends RefCounted
class_name CombatActor

var stats: Dictionary = {}
var current_hp: int = 1
var statuses: Array = []
var attack_count: int = 0
var trait_states: Dictionary = {}


func _init(initial_stats: Dictionary = {}) -> void:
	stats = initial_stats.duplicate(true)
	current_hp = int(stats.get("current_hp", stats.get("max_hp", 1)))


func is_alive() -> bool:
	return current_hp > 0


func max_hp() -> int:
	return int(stats.get("max_hp", 1))


func trait_triggered(trait_id: String) -> bool:
	return bool(trait_states.get(trait_id, false))


func mark_trait_triggered(trait_id: String) -> void:
	trait_states[trait_id] = true


func attack_interval() -> float:
	return maxf(0.25, 1.0 / maxf(0.01, float(stats.get("attack_speed", 1.0))))


func apply_damage(amount: int) -> void:
	current_hp = maxi(0, current_hp - maxi(0, amount))


func heal(amount: int) -> void:
	current_hp = mini(max_hp(), current_hp + maxi(0, amount))


func export_state() -> Dictionary:
	return {
		"current_hp": current_hp,
		"max_hp": max_hp(),
		"attack_count": attack_count,
		"effective_stats": effective_stats(),
		"statuses": status_snapshot(),
		"skills": stats.get("skills", []).duplicate(true),
		"traits": stats.get("traits", []).duplicate(true)
	}


func status_snapshot() -> Array:
	var snapshot: Array = []
	for status_value in statuses:
		if not (status_value is Dictionary):
			continue
		var status: Dictionary = status_value
		snapshot.append({
			"id": String(status.get("id", "")),
			"duration": float(status.get("duration", 0.0)),
			"tick_damage": int(status.get("tick_damage", 0)),
			"tick_interval": float(status.get("tick_interval", 0.0)),
			"attack_multiplier": float(status.get("attack_multiplier", 1.0)),
			"armor_delta": int(status.get("armor_delta", 0)),
			"territory_power_delta": float(status.get("territory_power_delta", 0.0)),
			"crit_damage_delta": float(status.get("crit_damage_delta", 0.0)),
			"source_side": String(status.get("source_side", "")),
			"source_name": String(status.get("source_name", ""))
		})
	return snapshot


func effective_stats() -> Dictionary:
	var effective: Dictionary = stats.duplicate(true)
	var attack_multiplier := 1.0
	var armor_delta := 0
	var territory_power_delta := 0.0
	var crit_damage_delta := 0.0

	for status_value in statuses:
		if not (status_value is Dictionary):
			continue
		var status: Dictionary = status_value
		attack_multiplier *= float(status.get("attack_multiplier", 1.0))
		armor_delta += int(status.get("armor_delta", 0))
		territory_power_delta += float(status.get("territory_power_delta", 0.0))
		crit_damage_delta += float(status.get("crit_damage_delta", 0.0))

	effective["attack"] = int(round(float(effective.get("attack", 0)) * attack_multiplier))
	effective["armor"] = int(effective.get("armor", 0)) + armor_delta
	effective["territory_power"] = float(effective.get("territory_power", 0.0)) + territory_power_delta
	effective["crit_damage"] = float(effective.get("crit_damage", 0.0)) + crit_damage_delta
	return effective


func add_status(status: Dictionary) -> Dictionary:
	var status_id := String(status.get("id", ""))
	var next_status: Dictionary = status.duplicate(true)
	next_status["duration"] = maxf(0.0, float(next_status.get("duration", 0.0)))
	if next_status.has("tick_interval"):
		next_status["tick_timer"] = float(next_status.get("tick_interval", 1.0))

	for index in range(statuses.size()):
		var existing: Dictionary = statuses[index]
		if String(existing.get("id", "")) != status_id:
			continue
		existing["duration"] = maxf(float(existing.get("duration", 0.0)), float(next_status.get("duration", 0.0)))
		if next_status.has("tick_damage"):
			existing["tick_damage"] = maxi(int(existing.get("tick_damage", 0)), int(next_status.get("tick_damage", 0)))
			existing["tick_interval"] = minf(float(existing.get("tick_interval", 1.0)), float(next_status.get("tick_interval", 1.0)))
			existing["tick_timer"] = float(existing.get("tick_interval", 1.0))
		if next_status.has("attack_multiplier"):
			existing["attack_multiplier"] = minf(float(existing.get("attack_multiplier", 1.0)), float(next_status.get("attack_multiplier", 1.0)))
		if next_status.has("armor_delta"):
			var existing_armor_delta := int(existing.get("armor_delta", 0))
			var next_armor_delta := int(next_status.get("armor_delta", 0))
			existing["armor_delta"] = mini(existing_armor_delta, next_armor_delta) if next_armor_delta < 0 else maxi(existing_armor_delta, next_armor_delta)
		if next_status.has("source_side"):
			existing["source_side"] = String(next_status.get("source_side", existing.get("source_side", "")))
		if next_status.has("source_name"):
			existing["source_name"] = String(next_status.get("source_name", existing.get("source_name", "")))
		statuses[index] = existing
		return existing

	statuses.append(next_status)
	return next_status


func advance_statuses(delta: float) -> Array:
	var events: Array = []

	for index in range(statuses.size() - 1, -1, -1):
		var status: Dictionary = statuses[index]
		status["duration"] = maxf(0.0, float(status.get("duration", 0.0)) - delta)

		if status.has("tick_damage"):
			status["tick_timer"] = float(status.get("tick_timer", status.get("tick_interval", 1.0))) - delta
			while float(status.get("tick_timer", 0.0)) <= 0.0 and float(status.get("duration", 0.0)) > 0.0 and is_alive():
				var tick_damage := int(status.get("tick_damage", 0))
				apply_damage(tick_damage)
				events.append({
					"kind": "status_tick",
					"status_id": String(status.get("id", "status")),
					"source_side": String(status.get("source_side", "")),
					"source_name": String(status.get("source_name", "")),
					"damage": tick_damage,
					"remaining_duration": float(status.get("duration", 0.0)),
					"current_hp": current_hp
				})
				status["tick_timer"] = float(status.get("tick_timer", 0.0)) + float(status.get("tick_interval", 1.0))

		if float(status.get("duration", 0.0)) <= 0.0:
			statuses.remove_at(index)
		else:
			statuses[index] = status

	return events
