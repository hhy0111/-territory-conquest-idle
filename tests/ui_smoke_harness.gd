extends Node

const HOME_SCENE = preload("res://scenes/ui/home_screen.tscn")
const RUN_SCENE = preload("res://scenes/map/run_scene.tscn")
const COMBAT_SCENE = preload("res://scenes/combat/combat_scene.tscn")
const META_SCENE = preload("res://scenes/meta/meta_screen.tscn")
const RELIC_SCENE = preload("res://scenes/ui/relic_choice_scene.tscn")
const RUN_UPGRADE_SCENE = preload("res://scenes/ui/run_upgrade_scene.tscn")
const RESULT_SCENE = preload("res://scenes/ui/result_screen.tscn")


func _ready() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	var failures: Array = []
	var profile_backup: Dictionary = GameState.profile.duplicate(true)
	var run_backup: Dictionary = GameState.active_run.duplicate(true)
	var result_backup: Dictionary = GameState.last_result.duplicate(true)

	var smoke_steps := [
		{ "name": "home", "scene": HOME_SCENE, "setup": Callable(self, "_setup_home") },
		{ "name": "run", "scene": RUN_SCENE, "setup": Callable(self, "_setup_run") },
		{ "name": "meta", "scene": META_SCENE, "setup": Callable(self, "_setup_meta") },
		{ "name": "result", "scene": RESULT_SCENE, "setup": Callable(self, "_setup_result") },
		{ "name": "relic", "scene": RELIC_SCENE, "setup": Callable(self, "_setup_relic") },
		{ "name": "run_upgrade", "scene": RUN_UPGRADE_SCENE, "setup": Callable(self, "_setup_run_upgrade") },
		{ "name": "combat", "scene": COMBAT_SCENE, "setup": Callable(self, "_setup_combat") }
	]

	for step_value in smoke_steps:
		var step: Dictionary = step_value
		GameState.load_profile_state(profile_backup.duplicate(true), {})
		GameState.last_result = {}
		var setup_error := String(step["setup"].call())
		if not setup_error.is_empty():
			failures.append("[%s] %s" % [step["name"], setup_error])
			continue

		var instance = step["scene"].instantiate()
		if instance == null:
			failures.append("[%s] Failed to instantiate scene." % step["name"])
			continue
		get_tree().root.add_child(instance)
		await get_tree().process_frame
		instance.queue_free()
		await get_tree().process_frame

	GameState.load_profile_state(profile_backup, run_backup)
	GameState.last_result = result_backup

	if failures.is_empty():
		print("UI smoke passed.")
		get_tree().quit(0)
		return

	for failure in failures:
		push_error(failure)
	get_tree().quit(1)


func _setup_home() -> String:
	GameState.load_profile_state(GameState.make_default_profile(), {})
	return ""


func _setup_run() -> String:
	GameState.start_new_run(123)
	return ""


func _setup_meta() -> String:
	GameState.load_profile_state(GameState.make_default_profile(), {})
	return ""


func _setup_result() -> String:
	GameState.start_new_run(123)
	GameState.finish_run(false)
	return "" if not GameState.last_result.is_empty() else "Missing result state."


func _setup_relic() -> String:
	GameState.start_new_run(123)
	GameState.active_run["pending_relic_choice"] = {
		"picks_remaining": 1,
		"choices": ["relic_sharp_edge", "relic_field_plate", "relic_storm_dial"]
	}
	return ""


func _setup_run_upgrade() -> String:
	GameState.start_new_run(123)
	GameState.active_run["pending_run_upgrade"] = {
		"picks_remaining": 1,
		"choices": ["run_blade_drill", "run_guard_stance", "run_quick_orders"]
	}
	return ""


func _setup_combat() -> String:
	GameState.start_new_run(123)
	var tiles: Dictionary = GameState.active_run.get("map", {}).get("tiles", {})
	var tile_defs: Dictionary = DataService.get_tile_definitions()
	var selectable_keys: Array = []
	for key in tiles.keys():
		if String(tiles[key].get("state", "")) == "selectable":
			selectable_keys.append(String(key))
	selectable_keys.sort()

	for key_value in selectable_keys:
		var coord_key := String(key_value)
		var tile_type := String(tiles[coord_key].get("type", "plains"))
		var tile_def: Dictionary = tile_defs.get(tile_type, {})
		if String(tile_def.get("resolver_mode", "combat")) != "combat":
			continue
		var result: Dictionary = GameState.resolve_tile(coord_key)
		if result.get("ok", false) and String(result.get("kind", "")) == "combat":
			return ""
	return "Could not prepare pending combat."
