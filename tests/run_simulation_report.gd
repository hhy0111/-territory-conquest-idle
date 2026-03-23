extends Node

const RunSimulatorScript = preload("res://scripts/sim/run_simulator.gd")

const DEFAULT_BATCH_COUNT := 50
const DEFAULT_MAX_STEPS := 256


func _ready() -> void:
	call_deferred("_run_report")


func _run_report() -> void:
	var default_batch_count := _env_int("SIM_DEFAULT_BATCH_COUNT", DEFAULT_BATCH_COUNT)
	var meta_batch_count := _env_int("SIM_META_BATCH_COUNT", DEFAULT_BATCH_COUNT)
	var max_steps := _env_int("SIM_MAX_STEPS", DEFAULT_MAX_STEPS)

	var report := {
		"generated_at_unix": int(Time.get_unix_time_from_system()),
		"config": {
			"default_batch_count": default_batch_count,
			"meta_batch_count": meta_batch_count,
			"max_steps": max_steps
		},
		"batches": {}
	}

	var simulator = RunSimulatorScript.new()
	var default_result: Dictionary = simulator.simulate_many(
		_seed_range(1001, default_batch_count),
		GameState.make_default_profile(),
		{ "max_steps": max_steps }
	)
	var meta_result: Dictionary = simulator.simulate_many(
		_seed_range(2001, meta_batch_count),
		_make_progressed_profile(),
		{ "max_steps": max_steps }
	)

	report["batches"]["default"] = _summarize_batch("default", default_result)
	report["batches"]["meta"] = _summarize_batch("meta", meta_result)
	report["ok"] = bool(default_result.get("ok", false)) and bool(meta_result.get("ok", false))

	_print_batch_summary("default", report["batches"]["default"])
	_print_batch_summary("meta", report["batches"]["meta"])
	print("SIM_REPORT_JSON=%s" % JSON.stringify(report))

	if not bool(report.get("ok", false)):
		get_tree().quit(1)
		return

	get_tree().quit(0)


func _summarize_batch(label: String, result: Dictionary) -> Dictionary:
	var summary := {
		"label": label,
		"ok": bool(result.get("ok", false)),
		"aggregate": result.get("aggregate", {}).duplicate(true)
	}

	var failures: Array = result.get("failures", [])
	if not failures.is_empty():
		summary["first_failure"] = failures[0]

	return summary


func _print_batch_summary(label: String, batch_summary: Dictionary) -> void:
	var aggregate: Dictionary = batch_summary.get("aggregate", {})
	if not bool(batch_summary.get("ok", false)):
		var failure: Dictionary = batch_summary.get("first_failure", {})
		print("[%s] failed on seed %s: %s" % [
			label,
			int(failure.get("seed", 0)),
			String(failure.get("reason", "unknown"))
		])
		return

	print("[%s] runs=%s victories=%s defeats=%s avg_captures=%.2f max_captures=%s avg_bosses=%.2f" % [
		label,
		int(aggregate.get("ended_runs", 0)),
		int(aggregate.get("victories", 0)),
		int(aggregate.get("defeats", 0)),
		float(aggregate.get("average_captures", 0.0)),
		int(aggregate.get("max_captures", 0)),
		float(aggregate.get("average_bosses_defeated", 0.0))
	])


func _seed_range(start_seed: int, count: int) -> Array:
	var seeds: Array = []
	for offset in range(maxi(0, count)):
		seeds.append(start_seed + offset)
	return seeds


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


func _env_int(name: String, fallback: int) -> int:
	var raw := OS.get_environment(name).strip_edges()
	if raw.is_empty():
		return fallback
	if not raw.is_valid_int():
		return fallback
	return int(raw)
