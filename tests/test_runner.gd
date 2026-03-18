extends SceneTree

const TestCombatMath = preload("res://tests/test_combat_math.gd")
const TestEventResolution = preload("res://tests/test_event_resolution.gd")
const TestGameStateResolution = preload("res://tests/test_game_state_resolution.gd")
const TestMapGeneration = preload("res://tests/test_map_generation.gd")
const TestSaveLoad = preload("res://tests/test_save_load.gd")


func _init() -> void:
	var suites := [
		{ "name": "combat_math", "suite": TestCombatMath.new() },
		{ "name": "event_resolution", "suite": TestEventResolution.new() },
		{ "name": "game_state_resolution", "suite": TestGameStateResolution.new() },
		{ "name": "map_generation", "suite": TestMapGeneration.new() },
		{ "name": "save_load", "suite": TestSaveLoad.new() }
	]

	var failures: Array = []
	for suite_data in suites:
		var suite_failures: Array = suite_data["suite"].run()
		for failure in suite_failures:
			failures.append("[%s] %s" % [suite_data["name"], failure])

	if failures.is_empty():
		print("All tests passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)
