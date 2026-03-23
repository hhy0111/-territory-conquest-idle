extends Control

const HOME_SCENE = preload("res://scenes/ui/home_screen.tscn")
const RUN_SCENE = preload("res://scenes/map/run_scene.tscn")
const COMBAT_SCENE = preload("res://scenes/combat/combat_scene.tscn")
const META_SCENE = preload("res://scenes/meta/meta_screen.tscn")
const RELIC_SCENE = preload("res://scenes/ui/relic_choice_scene.tscn")
const RUN_UPGRADE_SCENE = preload("res://scenes/ui/run_upgrade_scene.tscn")
const RESULT_SCENE = preload("res://scenes/ui/result_screen.tscn")
const RUN_RESUME_MAX_AGE_SECONDS := 1800
const DEFAULT_APP_OPEN_RESUME_THRESHOLD_SECONDS := 180

var screen_host: Control
var transition_overlay: ColorRect
var app_open_gate_overlay: ColorRect
var app_open_gate_label: Label
var launch_app_open_attempted := false
var queued_app_open_context := ""
var active_app_open_context := ""
var last_app_paused_at_unix := 0


func _ready() -> void:
	_build_shell()
	if not AdService.consent_status_changed.is_connected(_on_ad_consent_status_changed):
		AdService.consent_status_changed.connect(_on_ad_consent_status_changed)
	if not AdService.app_open_closed.is_connected(_on_app_open_settled):
		AdService.app_open_closed.connect(_on_app_open_settled)
	if not AdService.app_open_failed.is_connected(_on_app_open_failed):
		AdService.app_open_failed.connect(_on_app_open_failed)
	SaveService.load_all()
	if GameState.begin_session():
		SaveService.persist()
	_restore_screen_for_current_state()

	call_deferred("_queue_launch_app_open")


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_APPLICATION_PAUSED:
		last_app_paused_at_unix = int(Time.get_unix_time_from_system())
		SaveService.persist()
	elif what == MainLoop.NOTIFICATION_APPLICATION_RESUMED:
		call_deferred("_handle_application_resume")


func show_home() -> void:
	_show_screen(HOME_SCENE)


func show_run() -> void:
	_show_screen(RUN_SCENE)


func show_combat() -> void:
	_show_screen(COMBAT_SCENE)


func show_relic_choice() -> void:
	_show_screen(RELIC_SCENE)


func show_run_upgrade() -> void:
	_show_screen(RUN_UPGRADE_SCENE)


func show_meta() -> void:
	_show_screen(META_SCENE)


func show_result() -> void:
	if GameState.last_result.is_empty():
		show_home()
		return
	_show_screen(RESULT_SCENE)


func _build_shell() -> void:
	if screen_host != null:
		return

	var background := ColorRect.new()
	background.color = Color(0.03, 0.04, 0.05, 1.0)
	_full_rect(background)
	add_child(background)

	screen_host = Control.new()
	screen_host.name = "ScreenHost"
	_full_rect(screen_host)
	add_child(screen_host)

	transition_overlay = ColorRect.new()
	transition_overlay.color = Color(0.02, 0.03, 0.04, 0.0)
	transition_overlay.visible = false
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full_rect(transition_overlay)
	add_child(transition_overlay)

	app_open_gate_overlay = ColorRect.new()
	app_open_gate_overlay.color = Color(0.02, 0.03, 0.04, 0.92)
	app_open_gate_overlay.visible = false
	app_open_gate_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_full_rect(app_open_gate_overlay)
	add_child(app_open_gate_overlay)

	var gate_center := CenterContainer.new()
	_full_rect(gate_center)
	app_open_gate_overlay.add_child(gate_center)

	var gate_panel := PanelContainer.new()
	gate_panel.custom_minimum_size = Vector2(560, 180)
	gate_center.add_child(gate_panel)

	app_open_gate_label = Label.new()
	app_open_gate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	app_open_gate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	app_open_gate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	app_open_gate_label.text = "Loading command brief..."
	gate_panel.add_child(app_open_gate_label)


func _show_screen(scene: PackedScene) -> void:
	for child in screen_host.get_children():
		child.queue_free()
	var instance = scene.instantiate()
	screen_host.add_child(instance)
	_play_screen_transition()


func _full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _play_screen_transition() -> void:
	if transition_overlay == null:
		return
	transition_overlay.visible = true
	transition_overlay.color = Color(0.02, 0.03, 0.04, 0.9)
	transition_overlay.modulate = Color(1.0, 1.0, 1.0, 0.82)
	var tween := create_tween()
	tween.tween_property(transition_overlay, "modulate:a", 0.0, 0.2)
	tween.finished.connect(_on_transition_finished)


func _on_transition_finished() -> void:
	if transition_overlay != null:
		transition_overlay.visible = false


func _restore_screen_for_current_state() -> void:
	if GameState.has_active_run():
		if GameState.has_pending_combat():
			show_combat()
		elif GameState.has_pending_relic_choice():
			show_relic_choice()
		elif GameState.has_pending_run_upgrade():
			show_run_upgrade()
		else:
			show_run()
	else:
		show_home()


func _queue_launch_app_open() -> void:
	if launch_app_open_attempted:
		return
	launch_app_open_attempted = true
	_queue_app_open("launch")


func _handle_application_resume() -> void:
	var resumed_at := int(Time.get_unix_time_from_system())
	var paused_at := last_app_paused_at_unix
	last_app_paused_at_unix = 0
	if paused_at <= 0:
		return
	var background_seconds := maxi(0, resumed_at - paused_at)
	if background_seconds >= RUN_RESUME_MAX_AGE_SECONDS and GameState.has_active_run():
		SaveService.load_all()
		_restore_screen_for_current_state()
	if background_seconds >= _get_app_open_resume_threshold_seconds():
		_queue_app_open("resume")


func _queue_app_open(context: String) -> void:
	var normalized_context := context.strip_edges().to_lower()
	if normalized_context.is_empty():
		return
	if not active_app_open_context.is_empty():
		return
	queued_app_open_context = normalized_context
	call_deferred("_try_show_queued_app_open")


func _try_show_queued_app_open() -> void:
	if queued_app_open_context.is_empty():
		return
	if not _has_app_open_placement_eligibility():
		_clear_queued_app_open()
		return
	if _should_wait_for_app_open_consent():
		_set_app_open_gate(true, _app_open_gate_message(queued_app_open_context))
		return
	if not AdService.is_app_open_ready():
		_clear_queued_app_open()
		return

	var queued_context := queued_app_open_context
	_set_app_open_gate(true, _app_open_gate_message(queued_context))
	if not AdService.show_app_open():
		_clear_queued_app_open()
		return

	active_app_open_context = queued_context
	queued_app_open_context = ""


func _has_app_open_placement_eligibility() -> bool:
	if not AdService.is_bridge_active():
		return false
	if GameState.has_active_run():
		return false
	var slot_config := AdService.get_slot_config(AdService.DEFAULT_APP_OPEN_SLOT)
	if not bool(slot_config.get("enabled", false)):
		return false

	var ad_history: Dictionary = GameState.profile.get("ad_history", {})
	return int(ad_history.get("sessions_started", 0)) >= 2


func _should_wait_for_app_open_consent() -> bool:
	if not _has_app_open_placement_eligibility():
		return false
	var platform_config := AdService.get_platform_config("android")
	if not bool(platform_config.get("consent_enabled", false)):
		return false
	return ["pending", "unknown"].has(AdService.get_consent_status())


func _get_app_open_resume_threshold_seconds() -> int:
	var platform_config := AdService.get_platform_config("android")
	return maxi(0, int(platform_config.get(
		"app_open_resume_threshold_seconds",
		DEFAULT_APP_OPEN_RESUME_THRESHOLD_SECONDS
	)))


func _app_open_gate_message(context: String) -> String:
	if context == "resume":
		return "Restoring command brief..."
	return "Loading command brief..."


func _clear_queued_app_open() -> void:
	queued_app_open_context = ""
	if active_app_open_context.is_empty():
		_set_app_open_gate(false)


func _on_ad_consent_status_changed(status: String) -> void:
	if ["granted", "not_required"].has(status):
		call_deferred("_try_show_queued_app_open")
		return
	if not ["declined", "error"].has(status):
		return
	_clear_queued_app_open()


func _on_app_open_settled(slot_key: String) -> void:
	if slot_key != AdService.DEFAULT_APP_OPEN_SLOT:
		return
	active_app_open_context = ""
	if queued_app_open_context.is_empty():
		_set_app_open_gate(false)
	call_deferred("_try_show_queued_app_open")


func _on_app_open_failed(slot_key: String, _reason: String) -> void:
	if slot_key != AdService.DEFAULT_APP_OPEN_SLOT:
		return
	active_app_open_context = ""
	if queued_app_open_context.is_empty():
		_set_app_open_gate(false)
	call_deferred("_try_show_queued_app_open")


func _set_app_open_gate(is_visible: bool, message: String = "") -> void:
	if app_open_gate_overlay == null:
		return
	app_open_gate_overlay.visible = is_visible
	if app_open_gate_label != null and not message.is_empty():
		app_open_gate_label.text = message
