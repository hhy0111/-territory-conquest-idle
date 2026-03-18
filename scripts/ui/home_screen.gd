extends Control

const UISkin = preload("res://scripts/ui/ui_skin.gd")

var run_summary_label: Label


func _ready() -> void:
	UISkin.install_screen_background(self, UISkin.screen_background("home"))
	_build_ui()


func _build_ui() -> void:
	var root := UISkin.make_screen_margin(28, 34, 28, 26)
	add_child(root)

	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	root.add_child(column)

	column.add_child(_build_header_card())
	column.add_child(_build_profile_card())
	column.add_child(_build_action_card())

	var footer := UISkin.body_label("Short sessions, permanent doctrine growth, and step-by-step auto battles tuned for portrait mobile play.", UISkin.TEXT_MUTED, 16)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(footer)


func _build_header_card() -> Control:
	var panel := PanelContainer.new()
	UISkin.apply_panel_style(panel, "popup")
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 10)
	row.add_child(copy)

	var title := UISkin.section_title("Territory Conquest Idle", 40)
	copy.add_child(title)

	var subtitle := UISkin.body_label("Expand the frontier, survive escalating risk, defeat command bosses, and convert each loss into permanent doctrine strength.", UISkin.TEXT_SECONDARY, 18)
	copy.add_child(subtitle)

	run_summary_label = UISkin.body_label(_active_run_summary(), UISkin.TEXT_ACCENT, 18)
	copy.add_child(run_summary_label)

	var portrait_frame := PanelContainer.new()
	UISkin.apply_panel_style(portrait_frame, "secondary")
	portrait_frame.custom_minimum_size = Vector2(260, 280)
	row.add_child(portrait_frame)

	var portrait := UISkin.make_portrait(UISkin.hero_texture(), Vector2(220, 240))
	portrait_frame.add_child(portrait)

	return panel


func _build_profile_card() -> Control:
	var panel := PanelContainer.new()
	UISkin.apply_panel_style(panel, "primary")

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	content.add_child(UISkin.section_title("Command Ledger", 26))

	var chip_flow := HFlowContainer.new()
	chip_flow.add_theme_constant_override("h_separation", 10)
	chip_flow.add_theme_constant_override("v_separation", 10)
	content.add_child(chip_flow)

	var profile := GameState.profile
	var best_run: Dictionary = profile.get("best_run", {})
	chip_flow.add_child(UISkin.make_badge("Essence %s" % profile.get("essence", 0), UISkin.icon_texture("essence"), "currency"))
	chip_flow.add_child(UISkin.make_badge("Sigils %s" % profile.get("sigils", 0), UISkin.icon_texture("sigil"), "currency"))
	chip_flow.add_child(UISkin.make_badge("Best Captures %s" % best_run.get("captures", 0), UISkin.icon_texture("territory_power")))
	chip_flow.add_child(UISkin.make_badge("Best Bosses %s" % best_run.get("bosses_defeated", 0), UISkin.icon_texture("boss")))
	chip_flow.add_child(UISkin.make_badge("Seed %s" % best_run.get("seed", 0), UISkin.icon_texture("reveal")))

	return panel


func _build_action_card() -> Control:
	var panel := PanelContainer.new()
	UISkin.apply_panel_style(panel, "secondary")

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	content.add_child(UISkin.section_title("Operations", 26))

	var start_button := Button.new()
	start_button.text = "Resume Run" if GameState.has_active_run() else "Start Run"
	start_button.custom_minimum_size = Vector2(0, 86)
	UISkin.apply_button_style(start_button, "primary")
	start_button.pressed.connect(_on_start_pressed)
	content.add_child(start_button)

	var meta_button := Button.new()
	meta_button.text = "Meta Upgrades"
	meta_button.custom_minimum_size = Vector2(0, 82)
	UISkin.apply_button_style(meta_button, "secondary")
	meta_button.pressed.connect(_on_meta_pressed)
	content.add_child(meta_button)

	var disabled_row := HBoxContainer.new()
	disabled_row.add_theme_constant_override("separation", 12)
	content.add_child(disabled_row)

	var compendium_button := Button.new()
	compendium_button.text = "Compendium"
	compendium_button.disabled = true
	compendium_button.custom_minimum_size = Vector2(0, 72)
	compendium_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UISkin.apply_button_style(compendium_button, "secondary")
	disabled_row.add_child(compendium_button)

	var settings_button := Button.new()
	settings_button.text = "Settings"
	settings_button.disabled = true
	settings_button.custom_minimum_size = Vector2(0, 72)
	settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UISkin.apply_button_style(settings_button, "secondary")
	disabled_row.add_child(settings_button)

	return panel


func _active_run_summary() -> String:
	if not GameState.has_active_run():
		return "No active run. Start a new campaign and claim 12 tiles to clear the current prototype route."

	var run: Dictionary = GameState.active_run
	var player: Dictionary = run.get("player", {})
	return "Active Run: %s captures | %s bosses | HP %s/%s | Gold %s | Danger %s" % [
		run.get("captured_tiles", 0),
		run.get("bosses_defeated", 0),
		player.get("current_hp", 0),
		player.get("max_hp", 0),
		run.get("gold", 0),
		run.get("danger", 0)
	]


func _on_start_pressed() -> void:
	if not GameState.has_active_run():
		GameState.start_new_run()
	SaveService.persist()
	get_tree().current_scene.show_run()


func _on_meta_pressed() -> void:
	get_tree().current_scene.show_meta()
