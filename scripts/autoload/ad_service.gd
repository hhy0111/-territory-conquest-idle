extends Node

const REWARDED_RECENCY_WINDOW_SECONDS := 90.0
const DEFAULT_APP_OPEN_SLOT := "app_open_launch"
const DEFAULT_INTERSTITIAL_SLOT := "interstitial_run_end"
const DEFAULT_QA_CONFIG := {
	"enabled": false,
	"consent": {
		"status": "",
		"detail": ""
	},
	"slot_outcomes": {}
}
const DEFAULT_RUNTIME_CONFIG := {
	"platforms": {
		"default": {
			"app_id": "",
			"package_name": "",
			"consent_enabled": false,
			"bridge_singleton": "",
			"app_open_resume_threshold_seconds": 180
		}
	},
	"slots": {},
	"analytics_events": {
		"ad_bridge_bound": "ad_bridge_bound",
		"ad_consent_status": "ad_consent_status",
		"ad_show_attempt": "ad_show_attempt",
		"ad_show_completed": "ad_show_completed",
		"ad_show_failed": "ad_show_failed"
	},
	"qa": DEFAULT_QA_CONFIG
}

signal consent_status_changed(status)
signal bridge_state_changed(active, bridge_name)
signal rewarded_started(slot_key)
signal rewarded_completed(slot_key)
signal rewarded_failed(slot_key, reason)
signal app_open_started(slot_key)
signal app_open_closed(slot_key)
signal app_open_failed(slot_key, reason)
signal interstitial_started(slot_key)
signal interstitial_closed(slot_key)
signal interstitial_failed(slot_key, reason)

var rewarded_ready: bool = true
var app_open_ready: bool = true
var interstitial_ready: bool = true
var last_app_open_slot_id := ""
var last_app_open_at_unix := 0
var last_rewarded_slot_id := ""
var last_rewarded_at_unix := 0
var last_interstitial_at_unix := 0
var app_open_show_count := 0
var rewarded_watch_count := 0
var interstitial_show_count := 0
var active_app_open_slot_id := ""
var active_rewarded_slot_id := ""
var active_interstitial_slot_id := ""
var runtime_config: Dictionary = DEFAULT_RUNTIME_CONFIG.duplicate(true)
var qa_config: Dictionary = DEFAULT_QA_CONFIG.duplicate(true)
var consent_status := "unknown"
var bridge_singleton_name := ""
var bridge_singleton: Variant = null
var pending_qa_callbacks: Array = []


func _ready() -> void:
	reset_mock_state()
	refresh_runtime_config()
	request_consent_if_needed()


func reset_mock_state() -> void:
	_disconnect_bridge_signals()
	rewarded_ready = true
	app_open_ready = true
	interstitial_ready = true
	last_app_open_slot_id = ""
	last_app_open_at_unix = 0
	last_rewarded_slot_id = ""
	last_rewarded_at_unix = 0
	last_interstitial_at_unix = 0
	app_open_show_count = 0
	rewarded_watch_count = 0
	interstitial_show_count = 0
	active_app_open_slot_id = ""
	active_rewarded_slot_id = ""
	active_interstitial_slot_id = ""
	runtime_config = DEFAULT_RUNTIME_CONFIG.duplicate(true)
	qa_config = DEFAULT_QA_CONFIG.duplicate(true)
	consent_status = "unknown"
	bridge_singleton_name = ""
	bridge_singleton = null
	pending_qa_callbacks.clear()


func refresh_runtime_config() -> void:
	var config_data := {}
	if DataService:
		config_data = DataService.get_ad_runtime_config()
	runtime_config = _normalize_runtime_config(config_data)
	qa_config = _normalize_qa_config(runtime_config.get("qa", {}))
	_bind_runtime_bridge()
	_refresh_readiness_flags()


func get_runtime_config() -> Dictionary:
	return runtime_config.duplicate(true)


func get_qa_config() -> Dictionary:
	return qa_config.duplicate(true)


func configure_qa_overrides(config_data: Dictionary) -> void:
	qa_config = _normalize_qa_config(config_data)


func clear_qa_overrides() -> void:
	qa_config = DEFAULT_QA_CONFIG.duplicate(true)
	pending_qa_callbacks.clear()


func get_platform_config(platform_name: String = "") -> Dictionary:
	var platforms: Dictionary = runtime_config.get("platforms", {})
	var resolved_platform := platform_name.strip_edges().to_lower()
	if resolved_platform.is_empty():
		resolved_platform = _runtime_platform_name()

	if platforms.has(resolved_platform):
		return platforms[resolved_platform].duplicate(true)
	return platforms.get("default", {}).duplicate(true)


func get_slot_config(slot_key: String) -> Dictionary:
	return runtime_config.get("slots", {}).get(slot_key, {}).duplicate(true)


func get_slot_unit_id(slot_key: String) -> String:
	return String(get_slot_config(slot_key).get("unit_id", ""))


func get_consent_status() -> String:
	return consent_status


func request_consent_if_needed() -> String:
	var qa_consent_override := _get_qa_consent_override()
	if not qa_consent_override.is_empty():
		_set_consent_status(
			String(qa_consent_override.get("status", "unknown")),
			String(qa_consent_override.get("detail", "qa_override"))
		)
		return consent_status

	var platform_config := get_platform_config()
	if not bool(platform_config.get("consent_enabled", false)):
		_set_consent_status("not_required", "Consent disabled in runtime config.")
		return consent_status

	if not is_bridge_active():
		_set_consent_status("granted", "Mock consent granted for non-Android runtime.")
		return consent_status

	var requested := false
	if _bridge_has_method("request_consent"):
		requested = bool(_bridge_call("request_consent", []))
	elif _bridge_has_method("request_consent_info"):
		requested = bool(_bridge_call("request_consent_info", []))

	if requested:
		_set_consent_status("pending", "Consent request started through Android bridge.")
	else:
		_set_consent_status("unknown", "Android bridge does not expose a consent request method.")
	return consent_status


func mark_consent_result(status: String, detail: String = "") -> void:
	_set_consent_status(status.strip_edges().to_lower(), detail)


func is_rewarded_ready() -> bool:
	return rewarded_ready and active_rewarded_slot_id.is_empty()


func is_app_open_ready() -> bool:
	return app_open_ready and active_app_open_slot_id.is_empty()


func show_app_open(ad_slot_id: String = DEFAULT_APP_OPEN_SLOT) -> bool:
	var slot_config := get_slot_config(ad_slot_id)
	if not _can_show_slot(ad_slot_id, slot_config, app_open_ready):
		return false
	if not active_app_open_slot_id.is_empty():
		_log_ad_event("ad_show_failed", {
			"slot_key": ad_slot_id,
			"reason": "busy",
			"mode": _runtime_mode()
		})
		return false

	_log_ad_event("ad_show_attempt", {
		"slot_key": ad_slot_id,
		"format": String(slot_config.get("format", "")),
		"unit_id": get_slot_unit_id(ad_slot_id),
		"mode": _runtime_mode()
	})

	active_app_open_slot_id = ad_slot_id
	var qa_outcome := _get_qa_slot_outcome(ad_slot_id, "app_open")
	if not qa_outcome.is_empty():
		return _begin_qa_slot_request(ad_slot_id, "app_open", qa_outcome)
	var shown := false
	if is_bridge_active():
		shown = _bridge_show("show_app_open", ad_slot_id)
	else:
		shown = true

	if not shown:
		active_app_open_slot_id = ""
		_log_ad_event("ad_show_failed", {
			"slot_key": ad_slot_id,
			"reason": "bridge_rejected",
			"mode": _runtime_mode()
		})
		return false

	if active_app_open_slot_id == ad_slot_id:
		emit_signal("app_open_started", ad_slot_id)
	if not is_bridge_active():
		call_deferred("_complete_mock_app_open", ad_slot_id)
	return true


func show_rewarded(ad_slot_id: String) -> bool:
	var slot_config := get_slot_config(ad_slot_id)
	if not _can_show_slot(ad_slot_id, slot_config, rewarded_ready):
		return false
	if not active_rewarded_slot_id.is_empty():
		_log_ad_event("ad_show_failed", {
			"slot_key": ad_slot_id,
			"reason": "busy",
			"mode": _runtime_mode()
		})
		return false

	_log_ad_event("ad_show_attempt", {
		"slot_key": ad_slot_id,
		"format": String(slot_config.get("format", "")),
		"unit_id": get_slot_unit_id(ad_slot_id),
		"mode": _runtime_mode()
	})

	active_rewarded_slot_id = ad_slot_id
	var qa_outcome := _get_qa_slot_outcome(ad_slot_id, "rewarded")
	if not qa_outcome.is_empty():
		return _begin_qa_slot_request(ad_slot_id, "rewarded", qa_outcome)
	var shown := false
	if is_bridge_active():
		shown = _bridge_show("show_rewarded", ad_slot_id)
	else:
		shown = true

	if not shown:
		active_rewarded_slot_id = ""
		_log_ad_event("ad_show_failed", {
			"slot_key": ad_slot_id,
			"reason": "bridge_rejected",
			"mode": _runtime_mode()
		})
		return false

	if active_rewarded_slot_id == ad_slot_id:
		emit_signal("rewarded_started", ad_slot_id)
	if not is_bridge_active():
		call_deferred("_complete_mock_rewarded", ad_slot_id)
	return true


func is_interstitial_ready() -> bool:
	return interstitial_ready and active_interstitial_slot_id.is_empty()


func show_interstitial(ad_slot_id: String = DEFAULT_INTERSTITIAL_SLOT) -> bool:
	var slot_config := get_slot_config(ad_slot_id)
	if not _can_show_slot(ad_slot_id, slot_config, interstitial_ready):
		return false
	if not active_interstitial_slot_id.is_empty():
		_log_ad_event("ad_show_failed", {
			"slot_key": ad_slot_id,
			"reason": "busy",
			"mode": _runtime_mode()
		})
		return false

	_log_ad_event("ad_show_attempt", {
		"slot_key": ad_slot_id,
		"format": String(slot_config.get("format", "")),
		"unit_id": get_slot_unit_id(ad_slot_id),
		"mode": _runtime_mode()
	})

	active_interstitial_slot_id = ad_slot_id
	var qa_outcome := _get_qa_slot_outcome(ad_slot_id, "interstitial")
	if not qa_outcome.is_empty():
		return _begin_qa_slot_request(ad_slot_id, "interstitial", qa_outcome)
	var shown := false
	if is_bridge_active():
		shown = _bridge_show("show_interstitial", ad_slot_id)
	else:
		shown = true

	if not shown:
		active_interstitial_slot_id = ""
		_log_ad_event("ad_show_failed", {
			"slot_key": ad_slot_id,
			"reason": "bridge_rejected",
			"mode": _runtime_mode()
		})
		return false

	if active_interstitial_slot_id == ad_slot_id:
		emit_signal("interstitial_started", ad_slot_id)
	if not is_bridge_active():
		call_deferred("_complete_mock_interstitial", ad_slot_id)
	return true


func has_recent_rewarded_watch(window_seconds: float = REWARDED_RECENCY_WINDOW_SECONDS) -> bool:
	if last_rewarded_at_unix <= 0:
		return false
	return float(Time.get_unix_time_from_system() - last_rewarded_at_unix) < window_seconds


func is_bridge_active() -> bool:
	return bridge_singleton != null


func get_bridge_name() -> String:
	return bridge_singleton_name


func flush_mock_callbacks_for_tests() -> void:
	_flush_pending_qa_callbacks()
	if is_bridge_active():
		return
	if not active_app_open_slot_id.is_empty():
		notify_app_open_closed(active_app_open_slot_id, "test_flush")
	if not active_rewarded_slot_id.is_empty():
		notify_rewarded_completed(active_rewarded_slot_id, "test_flush")
	if not active_interstitial_slot_id.is_empty():
		notify_interstitial_closed(active_interstitial_slot_id, "test_flush")


func notify_app_open_closed(slot_key: String = "", detail: String = "") -> void:
	var resolved_slot := _resolve_active_slot(slot_key, active_app_open_slot_id)
	if resolved_slot.is_empty():
		return

	active_app_open_slot_id = ""
	last_app_open_slot_id = resolved_slot
	last_app_open_at_unix = int(Time.get_unix_time_from_system())
	app_open_show_count += 1

	var slot_config := get_slot_config(resolved_slot)
	_log_ad_event("ad_show_completed", {
		"slot_key": resolved_slot,
		"format": String(slot_config.get("format", "")),
		"unit_id": get_slot_unit_id(resolved_slot),
		"mode": _runtime_mode(),
		"detail": detail
	})
	emit_signal("app_open_closed", resolved_slot)


func notify_app_open_failed(slot_key: String = "", reason: String = "failed") -> void:
	var resolved_slot := _resolve_active_slot(slot_key, active_app_open_slot_id)
	if resolved_slot.is_empty():
		return

	if resolved_slot == active_app_open_slot_id:
		active_app_open_slot_id = ""
	_log_ad_event("ad_show_failed", {
		"slot_key": resolved_slot,
		"reason": reason,
		"mode": _runtime_mode()
	})
	emit_signal("app_open_failed", resolved_slot, reason)


func notify_rewarded_completed(slot_key: String = "", detail: String = "") -> void:
	var resolved_slot := _resolve_active_slot(slot_key, active_rewarded_slot_id)
	if resolved_slot.is_empty():
		return

	active_rewarded_slot_id = ""
	last_rewarded_slot_id = resolved_slot
	last_rewarded_at_unix = int(Time.get_unix_time_from_system())
	rewarded_watch_count += 1

	var slot_config := get_slot_config(resolved_slot)
	_log_ad_event("ad_show_completed", {
		"slot_key": resolved_slot,
		"format": String(slot_config.get("format", "")),
		"unit_id": get_slot_unit_id(resolved_slot),
		"mode": _runtime_mode(),
		"detail": detail
	})
	emit_signal("rewarded_completed", resolved_slot)


func notify_rewarded_failed(slot_key: String = "", reason: String = "failed") -> void:
	var resolved_slot := _resolve_active_slot(slot_key, active_rewarded_slot_id)
	if resolved_slot.is_empty():
		return

	if resolved_slot == active_rewarded_slot_id:
		active_rewarded_slot_id = ""
	_log_ad_event("ad_show_failed", {
		"slot_key": resolved_slot,
		"reason": reason,
		"mode": _runtime_mode()
	})
	emit_signal("rewarded_failed", resolved_slot, reason)


func notify_interstitial_closed(slot_key: String = "", detail: String = "") -> void:
	var resolved_slot := _resolve_active_slot(slot_key, active_interstitial_slot_id)
	if resolved_slot.is_empty():
		return

	active_interstitial_slot_id = ""
	last_interstitial_at_unix = int(Time.get_unix_time_from_system())
	interstitial_show_count += 1

	var slot_config := get_slot_config(resolved_slot)
	_log_ad_event("ad_show_completed", {
		"slot_key": resolved_slot,
		"format": String(slot_config.get("format", "")),
		"unit_id": get_slot_unit_id(resolved_slot),
		"mode": _runtime_mode(),
		"detail": detail
	})
	emit_signal("interstitial_closed", resolved_slot)


func notify_interstitial_failed(slot_key: String = "", reason: String = "failed") -> void:
	var resolved_slot := _resolve_active_slot(slot_key, active_interstitial_slot_id)
	if resolved_slot.is_empty():
		return

	if resolved_slot == active_interstitial_slot_id:
		active_interstitial_slot_id = ""
	_log_ad_event("ad_show_failed", {
		"slot_key": resolved_slot,
		"reason": reason,
		"mode": _runtime_mode()
	})
	emit_signal("interstitial_failed", resolved_slot, reason)


func _normalize_runtime_config(config_data: Variant) -> Dictionary:
	var normalized := DEFAULT_RUNTIME_CONFIG.duplicate(true)
	if not (config_data is Dictionary):
		return normalized

	for key in config_data.keys():
		normalized[key] = config_data[key]

	if not (normalized.get("platforms", {}) is Dictionary):
		normalized["platforms"] = DEFAULT_RUNTIME_CONFIG["platforms"].duplicate(true)
	if not (normalized.get("slots", {}) is Dictionary):
		normalized["slots"] = {}
	if not (normalized.get("analytics_events", {}) is Dictionary):
		normalized["analytics_events"] = DEFAULT_RUNTIME_CONFIG["analytics_events"].duplicate(true)
	if not (normalized.get("qa", {}) is Dictionary):
		normalized["qa"] = DEFAULT_QA_CONFIG.duplicate(true)
	return normalized


func _normalize_qa_config(config_data: Variant) -> Dictionary:
	var normalized := DEFAULT_QA_CONFIG.duplicate(true)
	if not (config_data is Dictionary):
		return normalized

	for key in config_data.keys():
		normalized[key] = config_data[key]

	if not (normalized.get("consent", {}) is Dictionary):
		normalized["consent"] = DEFAULT_QA_CONFIG["consent"].duplicate(true)
	if not (normalized.get("slot_outcomes", {}) is Dictionary):
		normalized["slot_outcomes"] = {}
	return normalized


func _refresh_readiness_flags() -> void:
	rewarded_ready = _has_enabled_slot_format("rewarded")
	app_open_ready = bool(get_slot_config(DEFAULT_APP_OPEN_SLOT).get("enabled", false))
	interstitial_ready = bool(get_slot_config(DEFAULT_INTERSTITIAL_SLOT).get("enabled", false))


func _bind_runtime_bridge() -> void:
	_disconnect_bridge_signals()
	bridge_singleton = null
	bridge_singleton_name = ""

	if not OS.has_feature("android"):
		emit_signal("bridge_state_changed", false, bridge_singleton_name)
		return

	var platform_config := get_platform_config("android")
	var singleton_name := String(platform_config.get("bridge_singleton", "")).strip_edges()
	if singleton_name.is_empty():
		emit_signal("bridge_state_changed", false, bridge_singleton_name)
		return
	if not Engine.has_singleton(singleton_name):
		emit_signal("bridge_state_changed", false, bridge_singleton_name)
		return

	bridge_singleton = Engine.get_singleton(singleton_name)
	bridge_singleton_name = singleton_name
	_connect_bridge_signals()
	_bridge_configure_runtime()
	_log_ad_event("ad_bridge_bound", {
		"bridge_name": bridge_singleton_name,
		"platform": "android"
	})
	emit_signal("bridge_state_changed", true, bridge_singleton_name)


func _bridge_configure_runtime() -> void:
	if not is_bridge_active():
		return

	if _bridge_has_method("configure_runtime"):
		_bridge_call("configure_runtime", [JSON.stringify(runtime_config)])


func _bridge_show(method_name: String, slot_key: String) -> bool:
	if not is_bridge_active() or not _bridge_has_method(method_name):
		return false
	return bool(_bridge_call(method_name, [slot_key, get_slot_unit_id(slot_key)]))


func _bridge_has_method(method_name: String) -> bool:
	return bridge_singleton != null and bridge_singleton.has_method(method_name)


func _bridge_call(method_name: String, arguments: Array) -> Variant:
	if not _bridge_has_method(method_name):
		return null
	return bridge_singleton.callv(method_name, arguments)


func _connect_bridge_signals() -> void:
	_bridge_connect_signal("consent_result", Callable(self, "_on_bridge_consent_result"))
	_bridge_connect_signal("consent_status_changed", Callable(self, "_on_bridge_consent_status_changed"))
	_bridge_connect_signal("app_open_closed", Callable(self, "_on_bridge_app_open_closed"))
	_bridge_connect_signal("app_open_failed", Callable(self, "_on_bridge_app_open_failed"))
	_bridge_connect_signal("rewarded_completed", Callable(self, "_on_bridge_rewarded_completed"))
	_bridge_connect_signal("rewarded_failed", Callable(self, "_on_bridge_rewarded_failed"))
	_bridge_connect_signal("interstitial_closed", Callable(self, "_on_bridge_interstitial_closed"))
	_bridge_connect_signal("interstitial_failed", Callable(self, "_on_bridge_interstitial_failed"))


func _disconnect_bridge_signals() -> void:
	if bridge_singleton == null:
		return
	_bridge_disconnect_signal("consent_result", Callable(self, "_on_bridge_consent_result"))
	_bridge_disconnect_signal("consent_status_changed", Callable(self, "_on_bridge_consent_status_changed"))
	_bridge_disconnect_signal("app_open_closed", Callable(self, "_on_bridge_app_open_closed"))
	_bridge_disconnect_signal("app_open_failed", Callable(self, "_on_bridge_app_open_failed"))
	_bridge_disconnect_signal("rewarded_completed", Callable(self, "_on_bridge_rewarded_completed"))
	_bridge_disconnect_signal("rewarded_failed", Callable(self, "_on_bridge_rewarded_failed"))
	_bridge_disconnect_signal("interstitial_closed", Callable(self, "_on_bridge_interstitial_closed"))
	_bridge_disconnect_signal("interstitial_failed", Callable(self, "_on_bridge_interstitial_failed"))


func _bridge_connect_signal(signal_name: String, callable: Callable) -> void:
	if bridge_singleton == null:
		return
	if not bridge_singleton.has_signal(signal_name):
		return
	if bridge_singleton.is_connected(signal_name, callable):
		return
	bridge_singleton.connect(signal_name, callable)


func _bridge_disconnect_signal(signal_name: String, callable: Callable) -> void:
	if bridge_singleton == null:
		return
	if not bridge_singleton.has_signal(signal_name):
		return
	if not bridge_singleton.is_connected(signal_name, callable):
		return
	bridge_singleton.disconnect(signal_name, callable)


func _has_enabled_slot_format(format_name: String) -> bool:
	var slots: Dictionary = runtime_config.get("slots", {})
	for slot_key in slots.keys():
		var slot_config: Dictionary = slots[slot_key]
		if not bool(slot_config.get("enabled", false)):
			continue
		if String(slot_config.get("format", "")).to_lower() == format_name:
			return true
	return false


func _can_show_slot(slot_key: String, slot_config: Dictionary, ready_flag: bool) -> bool:
	if slot_key.is_empty():
		return false
	if slot_config.is_empty():
		_log_ad_event("ad_show_failed", {
			"slot_key": slot_key,
			"reason": "missing_slot_config",
			"mode": _runtime_mode()
		})
		return false
	if not bool(slot_config.get("enabled", false)):
		_log_ad_event("ad_show_failed", {
			"slot_key": slot_key,
			"reason": "slot_disabled",
			"mode": _runtime_mode()
		})
		return false
	if not ready_flag:
		_log_ad_event("ad_show_failed", {
			"slot_key": slot_key,
			"reason": "not_ready",
			"mode": _runtime_mode()
		})
		return false
	if _consent_blocks_ads():
		_log_ad_event("ad_show_failed", {
			"slot_key": slot_key,
			"reason": "consent_blocked",
			"mode": _runtime_mode()
		})
		return false
	return true


func _consent_blocks_ads() -> bool:
	var platform_config := get_platform_config()
	if not bool(platform_config.get("consent_enabled", false)):
		return false
	return not ["granted", "not_required"].has(consent_status)


func _runtime_platform_name() -> String:
	if OS.has_feature("android"):
		return "android"
	return "default"


func _runtime_mode() -> String:
	if _is_qa_mode_active():
		return "qa"
	return "bridge" if is_bridge_active() else "mock"


func _set_consent_status(status: String, detail: String) -> void:
	var normalized_status := status.strip_edges().to_lower()
	if normalized_status.is_empty():
		normalized_status = "unknown"
	consent_status = normalized_status
	_log_ad_event("ad_consent_status", {
		"status": consent_status,
		"detail": detail,
		"mode": _runtime_mode()
	})
	emit_signal("consent_status_changed", consent_status)


func _complete_mock_rewarded(slot_key: String) -> void:
	if _is_qa_mode_active():
		return
	if is_bridge_active():
		return
	if slot_key != active_rewarded_slot_id:
		return
	notify_rewarded_completed(slot_key, "mock_completed")


func _complete_mock_app_open(slot_key: String) -> void:
	if _is_qa_mode_active():
		return
	if is_bridge_active():
		return
	if slot_key != active_app_open_slot_id:
		return
	notify_app_open_closed(slot_key, "mock_completed")


func _complete_mock_interstitial(slot_key: String) -> void:
	if _is_qa_mode_active():
		return
	if is_bridge_active():
		return
	if slot_key != active_interstitial_slot_id:
		return
	notify_interstitial_closed(slot_key, "mock_completed")


func _resolve_active_slot(slot_key: String, active_slot: String) -> String:
	var normalized_slot := slot_key.strip_edges()
	if normalized_slot.is_empty():
		return active_slot
	return normalized_slot


func _is_qa_mode_active() -> bool:
	return bool(qa_config.get("enabled", false))


func _get_qa_consent_override() -> Dictionary:
	if not _is_qa_mode_active():
		return {}
	var consent_override: Variant = qa_config.get("consent", {})
	if not (consent_override is Dictionary):
		return {}
	var status := String(consent_override.get("status", "")).strip_edges().to_lower()
	if status.is_empty():
		return {}
	return {
		"status": status,
		"detail": String(consent_override.get("detail", "qa_override"))
	}


func _get_qa_slot_outcome(slot_key: String, expected_format: String) -> Dictionary:
	if not _is_qa_mode_active():
		return {}

	var slot_outcomes: Variant = qa_config.get("slot_outcomes", {})
	if not (slot_outcomes is Dictionary):
		return {}

	var slot_override: Variant = slot_outcomes.get(slot_key, {})
	if not (slot_override is Dictionary):
		return {}
	if slot_override.has("enabled") and not bool(slot_override.get("enabled", true)):
		return {}

	var normalized_outcome := _normalize_qa_outcome_name(
		String(slot_override.get("outcome", "")),
		expected_format
	)
	if normalized_outcome.is_empty():
		return {}

	return {
		"outcome": normalized_outcome,
		"reason": String(slot_override.get("reason", "qa_forced")),
		"detail": String(slot_override.get("detail", "qa_forced")),
		"show_returns": bool(slot_override.get("show_returns", true))
	}


func _normalize_qa_outcome_name(raw_outcome: String, expected_format: String) -> String:
	var normalized := raw_outcome.strip_edges().to_lower()
	if normalized.is_empty():
		if expected_format == "rewarded":
			return "completed"
		return "closed"

	if ["success", "succeeded", "complete", "completed", "close", "closed"].has(normalized):
		if expected_format == "rewarded":
			return "completed"
		return "closed"
	if ["fail", "failed", "error"].has(normalized):
		return "failed"
	return ""


func _begin_qa_slot_request(slot_key: String, format_name: String, qa_outcome: Dictionary) -> bool:
	if not bool(qa_outcome.get("show_returns", true)):
		_clear_active_slot(format_name, slot_key)
		_log_ad_event("ad_show_failed", {
			"slot_key": slot_key,
			"reason": String(qa_outcome.get("reason", "qa_rejected")),
			"mode": _runtime_mode()
		})
		return false

	_emit_started_signal(format_name, slot_key)
	pending_qa_callbacks.append({
		"slot_key": slot_key,
		"format": format_name,
		"outcome": String(qa_outcome.get("outcome", "")),
		"reason": String(qa_outcome.get("reason", "qa_forced")),
		"detail": String(qa_outcome.get("detail", "qa_forced"))
	})
	call_deferred("_flush_pending_qa_callbacks")
	return true


func _flush_pending_qa_callbacks() -> void:
	while not pending_qa_callbacks.is_empty():
		var pending_value: Variant = pending_qa_callbacks.pop_front()
		if not (pending_value is Dictionary):
			continue

		var pending: Dictionary = pending_value
		var slot_key := String(pending.get("slot_key", ""))
		var format_name := String(pending.get("format", ""))
		var outcome := String(pending.get("outcome", ""))
		var detail := String(pending.get("detail", "qa_forced"))
		var reason := String(pending.get("reason", "qa_forced"))

		match format_name:
			"app_open":
				if outcome == "failed":
					notify_app_open_failed(slot_key, reason)
				else:
					notify_app_open_closed(slot_key, detail)
			"rewarded":
				if outcome == "failed":
					notify_rewarded_failed(slot_key, reason)
				else:
					notify_rewarded_completed(slot_key, detail)
			"interstitial":
				if outcome == "failed":
					notify_interstitial_failed(slot_key, reason)
				else:
					notify_interstitial_closed(slot_key, detail)


func _emit_started_signal(format_name: String, slot_key: String) -> void:
	match format_name:
		"app_open":
			emit_signal("app_open_started", slot_key)
		"rewarded":
			emit_signal("rewarded_started", slot_key)
		"interstitial":
			emit_signal("interstitial_started", slot_key)


func _clear_active_slot(format_name: String, slot_key: String) -> void:
	match format_name:
		"app_open":
			if active_app_open_slot_id == slot_key:
				active_app_open_slot_id = ""
		"rewarded":
			if active_rewarded_slot_id == slot_key:
				active_rewarded_slot_id = ""
		"interstitial":
			if active_interstitial_slot_id == slot_key:
				active_interstitial_slot_id = ""


func _on_bridge_consent_result(status: String, detail: String = "") -> void:
	mark_consent_result(status, detail)


func _on_bridge_consent_status_changed(status: String) -> void:
	mark_consent_result(status)


func _on_bridge_app_open_closed(slot_key: String) -> void:
	notify_app_open_closed(slot_key, "bridge_closed")


func _on_bridge_app_open_failed(slot_key: String, reason: String = "bridge_failed") -> void:
	notify_app_open_failed(slot_key, reason)


func _on_bridge_rewarded_completed(slot_key: String) -> void:
	notify_rewarded_completed(slot_key, "bridge_completed")


func _on_bridge_rewarded_failed(slot_key: String, reason: String = "bridge_failed") -> void:
	notify_rewarded_failed(slot_key, reason)


func _on_bridge_interstitial_closed(slot_key: String) -> void:
	notify_interstitial_closed(slot_key, "bridge_closed")


func _on_bridge_interstitial_failed(slot_key: String, reason: String = "bridge_failed") -> void:
	notify_interstitial_failed(slot_key, reason)


func _log_ad_event(event_key: String, payload: Dictionary) -> void:
	if not AnalyticsService:
		return
	var analytics_events: Dictionary = runtime_config.get("analytics_events", {})
	var event_name := String(analytics_events.get(event_key, event_key))
	AnalyticsService.log_event(event_name, payload)
