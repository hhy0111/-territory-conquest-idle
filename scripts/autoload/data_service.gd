extends Node

const DATA_FILES := {
	"tiles": "res://data/tiles.json",
	"enemies": "res://data/enemies.json",
	"events": "res://data/events.json",
	"bosses": "res://data/bosses.json",
	"relics": "res://data/relics.json",
	"upgrades_run": "res://data/upgrades_run.json",
	"upgrades_meta": "res://data/upgrades_meta.json",
	"ad_runtime": "res://data/ad_runtime.json"
}

var data_sets: Dictionary = {}
var indexed_sets: Dictionary = {}


func _ready() -> void:
	load_all_data()


func load_all_data() -> void:
	data_sets.clear()
	indexed_sets.clear()
	for key in DATA_FILES.keys():
		var raw_data: Variant = _load_json_file(DATA_FILES[key])
		data_sets[key] = raw_data
		indexed_sets[key] = _index_by_id(raw_data)


func get_data_set(name: String) -> Variant:
	if not data_sets.has(name):
		load_all_data()
	return data_sets.get(name, [])


func get_indexed_data_set(name: String) -> Dictionary:
	if not indexed_sets.has(name):
		load_all_data()
	return indexed_sets.get(name, {})


func get_tile_definitions() -> Dictionary:
	return get_indexed_data_set("tiles")


func get_enemy_definitions() -> Dictionary:
	return get_indexed_data_set("enemies")


func get_event_definitions() -> Dictionary:
	return get_indexed_data_set("events")


func get_boss_definitions() -> Dictionary:
	return get_indexed_data_set("bosses")


func get_relic_definitions() -> Dictionary:
	return get_indexed_data_set("relics")


func get_meta_upgrade_definitions() -> Dictionary:
	return get_indexed_data_set("upgrades_meta")


func get_run_upgrade_definitions() -> Dictionary:
	return get_indexed_data_set("upgrades_run")


func get_ad_runtime_config() -> Dictionary:
	return get_data_set("ad_runtime")


func _load_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Missing data file: %s" % path)
		return []

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open data file: %s" % path)
		return []

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null:
		push_error("Failed to parse JSON file: %s" % path)
		return []

	return parsed


func _index_by_id(raw_data: Variant) -> Dictionary:
	var indexed: Dictionary = {}
	if raw_data is Array:
		for entry in raw_data:
			if entry is Dictionary and entry.has("id"):
				indexed[String(entry["id"])] = entry
	elif raw_data is Dictionary:
		indexed = raw_data.duplicate(true)
	return indexed
