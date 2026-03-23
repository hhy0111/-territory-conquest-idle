extends Node

const MAX_RECORDED_EVENTS := 200

signal event_logged(entry)

var enabled := true
var recorded_events: Array = []


func log_event(event_name: String, payload: Dictionary = {}) -> void:
	if not enabled or event_name.is_empty():
		return

	var entry := {
		"name": event_name,
		"payload": payload.duplicate(true),
		"recorded_at_unix": int(Time.get_unix_time_from_system())
	}
	recorded_events.append(entry)
	if recorded_events.size() > MAX_RECORDED_EVENTS:
		recorded_events.remove_at(0)
	emit_signal("event_logged", entry)


func get_recorded_events() -> Array:
	return recorded_events.duplicate(true)


func set_enabled(is_enabled: bool) -> void:
	enabled = is_enabled


func reset_for_tests() -> void:
	enabled = true
	recorded_events.clear()

