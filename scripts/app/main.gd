extends Control

const HOME_SCENE = preload("res://scenes/ui/home_screen.tscn")
const RUN_SCENE = preload("res://scenes/map/run_scene.tscn")
const COMBAT_SCENE = preload("res://scenes/combat/combat_scene.tscn")
const META_SCENE = preload("res://scenes/meta/meta_screen.tscn")
const RELIC_SCENE = preload("res://scenes/ui/relic_choice_scene.tscn")
const RUN_UPGRADE_SCENE = preload("res://scenes/ui/run_upgrade_scene.tscn")
const RESULT_SCENE = preload("res://scenes/ui/result_screen.tscn")

var screen_host: Control
var transition_overlay: ColorRect


func _ready() -> void:
	_build_shell()
	SaveService.load_all()
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
