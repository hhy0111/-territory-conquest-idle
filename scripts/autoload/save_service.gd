extends Node

const SAVE_PATH := "user://territory_conquest_idle_save.json"
const ACTIVE_RUN_MAX_AGE_SECONDS := 1800


func load_all() -> void:
	var payload := load_payload()
	var profile_data: Dictionary = payload.get("profile", GameState.make_default_profile())
	var run_data: Dictionary = _sanitize_run(payload.get("active_run", {}))
	GameState.load_profile_state(profile_data, run_data)


func load_payload() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return {}

	return deserialize_payload(file.get_as_text())


func persist() -> bool:
	var run_data: Dictionary = GameState.active_run.duplicate(true)
	if not run_data.is_empty():
		run_data["saved_at"] = int(Time.get_unix_time_from_system())

	var payload := {
		"version": GameState.SAVE_VERSION,
		"profile": GameState.profile.duplicate(true),
		"active_run": run_data,
		"saved_at": int(Time.get_unix_time_from_system())
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false

	file.store_string(JSON.stringify(payload, "\t"))
	return true


func serialize_payload(profile_data: Dictionary, run_data: Dictionary) -> String:
	return JSON.stringify({
		"version": GameState.SAVE_VERSION,
		"profile": profile_data,
		"active_run": run_data
	}, "\t")


func deserialize_payload(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


func _sanitize_run(run_data: Dictionary) -> Dictionary:
	if run_data.is_empty():
		return {}

	var saved_at := int(run_data.get("saved_at", run_data.get("started_at", 0)))
	if saved_at > 0 and int(Time.get_unix_time_from_system()) - saved_at > ACTIVE_RUN_MAX_AGE_SECONDS:
		return {}

	return run_data.duplicate(true)
