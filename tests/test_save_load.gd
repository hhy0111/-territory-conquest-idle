extends RefCounted

const SaveServiceScript = preload("res://scripts/autoload/save_service.gd")


func run() -> Array:
	var failures: Array = []
	var service = SaveServiceScript.new()
	var serialized := service.serialize_payload(
		{
			"version": 1,
			"essence": 22,
			"sigils": 1,
			"meta_upgrades": { "cmd_attack_1": 2 }
		},
		{
			"seed": 99,
			"captured_tiles": 3
		}
	)

	var parsed: Dictionary = service.deserialize_payload(serialized)
	if int(parsed.get("profile", {}).get("essence", 0)) != 22:
		failures.append("Expected serialized profile essence to round-trip.")
	if int(parsed.get("active_run", {}).get("captured_tiles", 0)) != 3:
		failures.append("Expected serialized active run to round-trip.")
	service.free()

	return failures
