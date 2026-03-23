extends RefCounted

const TARGET_EVENT_COUNT := 12
const TARGET_RUN_UPGRADE_COUNT := 24
const TARGET_META_UPGRADE_COUNT := 18

const EVENT_COST_KEYS := {
	"current_hp_percent": true,
	"gold_flat": true,
	"curse": true
}

const EVENT_REWARD_KEYS := {
	"attack_flat": true,
	"attack_percent": true,
	"armor_flat": true,
	"attack_speed": true,
	"crit_rate": true,
	"territory_power": true,
	"luck": true,
	"max_hp_flat": true,
	"heal_flat": true,
	"heal_percent": true,
	"gold": true,
	"xp": true,
	"essence_on_run_end": true,
	"sigils_on_run_end": true,
	"grant_skill": true,
	"grant_trait": true
}

const RUN_UPGRADE_EFFECT_KEYS := {
	"attack_flat": true,
	"armor_flat": true,
	"attack_speed": true,
	"crit_rate": true,
	"territory_power": true,
	"luck": true,
	"max_hp_flat": true,
	"heal_flat": true,
	"gold_flat": true,
	"essence_on_run_end_flat": true,
	"sigils_on_run_end_flat": true,
	"grant_skill": true,
	"grant_trait": true
}

const META_EFFECT_KEYS := {
	"base_attack_flat": true,
	"base_hp_flat": true,
	"base_armor_flat": true,
	"base_crit_rate_flat": true,
	"starting_gold_flat": true,
	"starting_luck_flat": true,
	"essence_gain_percent": true,
	"heal_after_boss_percent": true,
	"boss_reward_essence_flat": true,
	"boss_reward_sigil_flat": true,
	"relic_offer_extra_choices": true,
	"run_upgrade_offer_extra_choices": true,
	"victory_sigils_flat": true
}

const SUPPORTED_SKILLS := {
	"ember_rounds": true,
	"breaker_strike": true,
	"shrapnel_burst": true,
	"bulwark_drive": true,
	"command_volley": true
}

const SUPPORTED_TRAITS := {
	"veteran_resolve": true,
	"execution_order": true,
	"unyielding_standard": true,
	"iron_reflexes": true,
	"march_supremacy": true
}

const META_TREE_TARGETS := {
	"command": 6,
	"logistics": 6,
	"legacy": 6
}


func run() -> Array:
	var failures: Array = []
	DataService.load_all_data()

	_run_event_data_checks(failures)
	_run_run_upgrade_checks(failures)
	_run_meta_upgrade_checks(failures)

	return failures


func _run_event_data_checks(failures: Array) -> void:
	var events: Array = DataService.get_data_set("events")
	if events.size() != TARGET_EVENT_COUNT:
		failures.append("Expected %s events, found %s." % [TARGET_EVENT_COUNT, events.size()])

	var seen_ids: Dictionary = {}
	for event_value in events:
		if not (event_value is Dictionary):
			failures.append("Expected every event entry to be a dictionary.")
			continue

		var event_def: Dictionary = event_value
		var event_id := String(event_def.get("id", ""))
		if event_id.is_empty():
			failures.append("Expected every event to have a non-empty id.")
			continue
		if seen_ids.has(event_id):
			failures.append("Duplicate event id found: %s." % event_id)
			continue
		seen_ids[event_id] = true

		var choices: Array = event_def.get("choices", [])
		if choices.size() < 2:
			failures.append("Expected event %s to have at least two choices." % event_id)

		for choice_value in choices:
			if not (choice_value is Dictionary):
				failures.append("Expected event %s choices to be dictionaries." % event_id)
				continue
			var choice: Dictionary = choice_value
			var choice_id := String(choice.get("id", ""))
			_validate_keys(choice.get("cost", {}), EVENT_COST_KEYS, "Unsupported cost key on %s:%s" % [event_id, choice_id], failures)
			_validate_keys(choice.get("reward", {}), EVENT_REWARD_KEYS, "Unsupported reward key on %s:%s" % [event_id, choice_id], failures)
			_validate_special_refs(choice.get("reward", {}), "event %s:%s" % [event_id, choice_id], failures)

	var tile_defs: Dictionary = DataService.get_tile_definitions()
	for tile_id in ["ruins", "shrine", "sanctum"]:
		var tile_def: Dictionary = tile_defs.get(tile_id, {})
		var event_pool: Array = tile_def.get("event_pool", [])
		if event_pool.size() < 4:
			failures.append("Expected tile %s to expose at least four event candidates." % tile_id)
		for event_id_value in event_pool:
			var event_id := String(event_id_value)
			if not seen_ids.has(event_id):
				failures.append("Expected tile %s event_pool entry %s to exist in events data." % [tile_id, event_id])


func _run_run_upgrade_checks(failures: Array) -> void:
	var upgrades: Array = DataService.get_data_set("upgrades_run")
	if upgrades.size() != TARGET_RUN_UPGRADE_COUNT:
		failures.append("Expected %s run upgrades, found %s." % [TARGET_RUN_UPGRADE_COUNT, upgrades.size()])

	var seen_ids: Dictionary = {}
	for upgrade_value in upgrades:
		if not (upgrade_value is Dictionary):
			failures.append("Expected every run-upgrade entry to be a dictionary.")
			continue

		var upgrade_def: Dictionary = upgrade_value
		var upgrade_id := String(upgrade_def.get("id", ""))
		if upgrade_id.is_empty():
			failures.append("Expected every run upgrade to have a non-empty id.")
			continue
		if seen_ids.has(upgrade_id):
			failures.append("Duplicate run upgrade id found: %s." % upgrade_id)
			continue
		seen_ids[upgrade_id] = true

		var effect: Dictionary = upgrade_def.get("effect", {})
		_validate_keys(effect, RUN_UPGRADE_EFFECT_KEYS, "Unsupported run-upgrade effect key on %s" % upgrade_id, failures)
		_validate_special_refs(effect, "run upgrade %s" % upgrade_id, failures)


func _run_meta_upgrade_checks(failures: Array) -> void:
	var upgrades: Array = DataService.get_data_set("upgrades_meta")
	if upgrades.size() != TARGET_META_UPGRADE_COUNT:
		failures.append("Expected %s meta upgrades, found %s." % [TARGET_META_UPGRADE_COUNT, upgrades.size()])

	var seen_ids: Dictionary = {}
	var tree_counts := {
		"command": 0,
		"logistics": 0,
		"legacy": 0
	}

	for upgrade_value in upgrades:
		if not (upgrade_value is Dictionary):
			failures.append("Expected every meta-upgrade entry to be a dictionary.")
			continue

		var upgrade_def: Dictionary = upgrade_value
		var upgrade_id := String(upgrade_def.get("id", ""))
		if upgrade_id.is_empty():
			failures.append("Expected every meta upgrade to have a non-empty id.")
			continue
		if seen_ids.has(upgrade_id):
			failures.append("Duplicate meta upgrade id found: %s." % upgrade_id)
			continue
		seen_ids[upgrade_id] = true

		var tree_id := String(upgrade_def.get("tree", ""))
		if not tree_counts.has(tree_id):
			failures.append("Expected meta upgrade %s to use a supported tree id." % upgrade_id)
		else:
			tree_counts[tree_id] = int(tree_counts[tree_id]) + 1

		var effect: Dictionary = upgrade_def.get("effect", {})
		_validate_keys(effect, META_EFFECT_KEYS, "Unsupported meta-upgrade effect key on %s" % upgrade_id, failures)

	for tree_id in META_TREE_TARGETS.keys():
		var expected_count := int(META_TREE_TARGETS[tree_id])
		var actual_count := int(tree_counts.get(tree_id, 0))
		if actual_count != expected_count:
			failures.append("Expected %s meta upgrades in tree %s, found %s." % [expected_count, tree_id, actual_count])


func _validate_keys(effect: Dictionary, allowed_keys: Dictionary, failure_prefix: String, failures: Array) -> void:
	for key_value in effect.keys():
		var effect_key := String(key_value)
		if not allowed_keys.has(effect_key):
			failures.append("%s: %s." % [failure_prefix, effect_key])


func _validate_special_refs(effect: Dictionary, source_label: String, failures: Array) -> void:
	if effect.has("grant_skill"):
		_validate_special_values(effect["grant_skill"], SUPPORTED_SKILLS, "%s references an unknown skill" % source_label, failures)
	if effect.has("grant_trait"):
		_validate_special_values(effect["grant_trait"], SUPPORTED_TRAITS, "%s references an unknown trait" % source_label, failures)


func _validate_special_values(values: Variant, allowed_values: Dictionary, failure_prefix: String, failures: Array) -> void:
	if values is Array:
		for value in values:
			var item := String(value)
			if not allowed_values.has(item):
				failures.append("%s: %s." % [failure_prefix, item])
		return

	var item := String(values)
	if not allowed_values.has(item):
		failures.append("%s: %s." % [failure_prefix, item])
