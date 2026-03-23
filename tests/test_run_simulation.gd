extends RefCounted

const RunSimulatorScript = preload("res://scripts/sim/run_simulator.gd")

const DEFAULT_BATCH_COUNT := 25
const META_BATCH_COUNT := 25


func run() -> Array:
	var failures: Array = []
	var simulator = RunSimulatorScript.new()

	_run_batch(
		failures,
		simulator,
		"default",
		1001,
		DEFAULT_BATCH_COUNT,
		GameState.make_default_profile()
	)
	_run_batch(
		failures,
		simulator,
		"meta",
		2001,
		META_BATCH_COUNT,
		_make_progressed_profile()
	)

	GameState.load_profile_state(GameState.make_default_profile())
	return failures


func _run_batch(
	failures: Array,
	simulator,
	label: String,
	start_seed: int,
	count: int,
	profile_data: Dictionary
) -> void:
	var seeds: Array = []
	for offset in range(count):
		seeds.append(start_seed + offset)

	var result: Dictionary = simulator.simulate_many(seeds, profile_data, { "max_steps": 256 })
	if not bool(result.get("ok", false)):
		var first_failure: Dictionary = result.get("failures", [])[0]
		failures.append("%s simulation batch failed on seed %s: %s." % [
			label,
			int(first_failure.get("seed", 0)),
			String(first_failure.get("reason", "unknown"))
		])
		return

	var aggregate: Dictionary = result.get("aggregate", {})
	var average_captures := float(aggregate.get("average_captures", 0.0))
	var max_captures := int(aggregate.get("max_captures", 0))
	var min_average_captures := 6.0 if label == "default" else 6.5
	if int(aggregate.get("ended_runs", 0)) != count:
		failures.append("Expected %s %s simulations to end cleanly, got %s." % [
			count,
			label,
			int(aggregate.get("ended_runs", 0))
		])
	if average_captures <= 0.0:
		failures.append("Expected %s simulation batch to capture at least one tile on average." % label)
	if max_captures < 3:
		failures.append("Expected %s simulation batch to reach at least three captures in one run." % label)
	if average_captures < min_average_captures:
		failures.append(
			"Expected %s simulation batch to average at least %.1f captures, got %.2f." % [
				label,
				min_average_captures,
				average_captures
			]
		)
	if max_captures < 10:
		failures.append("Expected %s simulation batch to reach at least ten captures in one run, got %s." % [
			label,
			max_captures
		])
	if result.get("aggregate", {}).get("tile_types_seen", {}).is_empty():
		failures.append("Expected %s simulation batch to encounter at least one tile type." % label)


func _make_progressed_profile() -> Dictionary:
	var profile := GameState.make_default_profile()
	profile["meta_upgrades"] = {
		"cmd_attack_1": 2,
		"cmd_hp_1": 2,
		"cmd_armor_1": 1,
		"logistics_gold_1": 2,
		"logistics_luck_1": 1,
		"logistics_salvage_1": 1,
		"command_recovery_1": 1,
		"legacy_relic_choice_1": 1,
		"legacy_tactics_1": 1,
		"command_recovery_2": 1,
		"logistics_gold_2": 1,
		"legacy_bounty_2": 1
	}
	return profile
