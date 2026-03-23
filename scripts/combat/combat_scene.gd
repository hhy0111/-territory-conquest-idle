extends Control

const UISkin = preload("res://scripts/ui/ui_skin.gd")

var title_label: Label
var summary_label: Label
var status_label: Label

var player_name_label: Label
var enemy_name_label: Label
var player_hp_label: Label
var enemy_hp_label: Label
var player_hp_bar: TextureProgressBar
var enemy_hp_bar: TextureProgressBar
var player_stat_label: Label
var enemy_stat_label: Label
var player_loadout_label: Label
var enemy_loadout_label: Label
var player_status_empty_label: Label
var enemy_status_empty_label: Label
var player_status_flow: HFlowContainer
var enemy_status_flow: HFlowContainer
var player_portrait_holder: CenterContainer
var enemy_portrait_holder: CenterContainer

var log_label: Label
var primary_button: Button
var retreat_button: Button
var step_timer: Timer
var stage_effect_rect: TextureRect
var stage_flash: ColorRect

var pending_combat: Dictionary = {}
var remaining_events: Array = []
var log_lines: Array = []
var final_result: Dictionary = {}
var battle_started := false
var pending_rewarded_revive := false


func _ready() -> void:
	if not GameState.has_pending_combat():
		get_tree().current_scene.show_run()
		return

	_connect_ad_signals()
	UISkin.install_screen_background(self, UISkin.screen_background("combat"), Color(0.03, 0.04, 0.05, 0.72))
	_build_ui()
	_load_pending_combat()


func _build_ui() -> void:
	var root := UISkin.make_screen_margin(22, 24, 22, 22)
	add_child(root)

	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	root.add_child(column)

	var header := PanelContainer.new()
	UISkin.apply_panel_style(header, "popup")
	column.add_child(header)

	var header_content := VBoxContainer.new()
	header_content.add_theme_constant_override("separation", 8)
	header.add_child(header_content)

	title_label = UISkin.section_title("Auto Combat", 34)
	header_content.add_child(title_label)

	summary_label = UISkin.body_label("", UISkin.TEXT_SECONDARY, 18)
	header_content.add_child(summary_label)

	status_label = UISkin.body_label("", UISkin.TEXT_ACCENT, 18)
	header_content.add_child(status_label)

	var stage_panel := PanelContainer.new()
	UISkin.apply_panel_style(stage_panel, "secondary")
	column.add_child(stage_panel)

	var stage_stack := Control.new()
	stage_stack.custom_minimum_size = Vector2(0, 520)
	stage_panel.add_child(stage_stack)

	var actor_row := HBoxContainer.new()
	actor_row.add_theme_constant_override("separation", 14)
	UISkin.full_rect(actor_row)
	stage_stack.add_child(actor_row)

	var player_card := _build_actor_card(true)
	player_name_label = player_card["name_label"]
	player_portrait_holder = player_card["portrait_holder"]
	player_hp_label = player_card["hp_label"]
	player_hp_bar = player_card["hp_bar"]
	player_stat_label = player_card["stat_label"]
	player_loadout_label = player_card["loadout_label"]
	player_status_empty_label = player_card["status_empty_label"]
	player_status_flow = player_card["status_flow"]
	actor_row.add_child(player_card["panel"])

	var enemy_card := _build_actor_card(false)
	enemy_name_label = enemy_card["name_label"]
	enemy_portrait_holder = enemy_card["portrait_holder"]
	enemy_hp_label = enemy_card["hp_label"]
	enemy_hp_bar = enemy_card["hp_bar"]
	enemy_stat_label = enemy_card["stat_label"]
	enemy_loadout_label = enemy_card["loadout_label"]
	enemy_status_empty_label = enemy_card["status_empty_label"]
	enemy_status_flow = enemy_card["status_flow"]
	actor_row.add_child(enemy_card["panel"])

	stage_effect_rect = TextureRect.new()
	stage_effect_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	stage_effect_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stage_effect_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stage_effect_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UISkin.full_rect(stage_effect_rect)
	stage_stack.add_child(stage_effect_rect)

	stage_flash = ColorRect.new()
	stage_flash.color = Color(1.0, 0.42, 0.3, 0.0)
	stage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UISkin.full_rect(stage_flash)
	stage_stack.add_child(stage_flash)

	var log_panel := PanelContainer.new()
	UISkin.apply_panel_style(log_panel, "primary")
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(log_panel)

	var log_content := VBoxContainer.new()
	log_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_content.add_theme_constant_override("separation", 8)
	log_panel.add_child(log_content)
	log_content.add_child(UISkin.section_title("Battle Log", 22))

	var log_scroll := ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_content.add_child(log_scroll)

	log_label = UISkin.body_label("Combat log will appear here.", UISkin.TEXT_SECONDARY, 17)
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.add_child(log_label)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)

	primary_button = Button.new()
	primary_button.text = "Engage Auto Battle"
	primary_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	primary_button.custom_minimum_size = Vector2(0, 78)
	UISkin.apply_button_style(primary_button, "primary")
	primary_button.pressed.connect(_on_primary_pressed)
	actions.add_child(primary_button)

	retreat_button = Button.new()
	retreat_button.text = "Retreat"
	retreat_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retreat_button.custom_minimum_size = Vector2(0, 78)
	UISkin.apply_button_style(retreat_button, "secondary")
	retreat_button.pressed.connect(_on_retreat_pressed)
	actions.add_child(retreat_button)

	step_timer = Timer.new()
	step_timer.wait_time = 0.22
	step_timer.one_shot = false
	step_timer.timeout.connect(_on_step_timer_timeout)
	add_child(step_timer)


func _load_pending_combat() -> void:
	pending_combat = GameState.get_pending_combat()
	remaining_events = pending_combat.get("battle_result", {}).get("events", []).duplicate(true)
	final_result = {}
	log_lines = []
	battle_started = false

	var enemy: Dictionary = pending_combat.get("enemy", {})
	var player: Dictionary = pending_combat.get("player_snapshot", GameState.active_run.get("player", {}))
	var battle_result: Dictionary = pending_combat.get("battle_result", {})
	var is_boss := bool(pending_combat.get("is_boss", false))
	var enemy_skills: Array = enemy.get("skills", [])
	var phase_list: Array = enemy.get("phases", [])
	var player_skills: Array = player.get("skills", [])
	var player_traits: Array = player.get("traits", [])

	title_label.text = "Boss Battle" if is_boss else "Auto Combat"
	summary_label.text = "Tile: %s | Enemy ATK %s | Enemy Armor %s | Phase Count %s" % [
		String(pending_combat.get("tile_type", "territory")).capitalize(),
		enemy.get("attack", 0),
		enemy.get("armor", 0),
		phase_list.size()
	]
	_set_actor_presentation(
		player_name_label,
		player_portrait_holder,
		player_loadout_label,
		"Commander",
		UISkin.hero_texture(),
		"Skills: %s | Traits: %s" % [_format_skill_list(player_skills), _format_skill_list(player_traits)]
	)
	_set_actor_presentation(
		enemy_name_label,
		enemy_portrait_holder,
		enemy_loadout_label,
		String(enemy.get("display_name", enemy.get("id", "Enemy"))),
		UISkin.boss_texture(String(enemy.get("id", ""))) if is_boss else UISkin.enemy_texture(String(enemy.get("id", ""))),
		"Skills: %s" % _format_skill_list(enemy_skills)
	)
	_update_hp_display(
		int(player.get("current_hp", 0)),
		int(player.get("max_hp", 1)),
		int(enemy.get("current_hp", 0)),
		int(enemy.get("max_hp", 1))
	)
	_update_actor_state_visuals(
		battle_result.get("initial_player_state", _fallback_actor_state(player)),
		battle_result.get("initial_enemy_state", _fallback_actor_state(enemy))
	)

	if is_boss:
		var rally_suffix := ""
		var rally_heal := int(pending_combat.get("pre_boss_rally_heal", 0))
		if rally_heal > 0:
			rally_suffix = "\nFrontline Rally: +%s HP before the clash." % rally_heal
		status_label.text = "%s\n%s\nReward preview: +%s essence, +%s sigils, %s relic pick(s).%s" % [
			String(enemy.get("trait_name", "Boss Trait")),
			String(enemy.get("trait_summary", enemy.get("description", ""))),
			int(pending_combat.get("boss_reward_essence", 0)),
			int(pending_combat.get("boss_reward_sigils", 0)),
			int(pending_combat.get("boss_reward_relics", 0)),
			rally_suffix
		]
	else:
		status_label.text = "Press Engage to resolve the encounter."

	log_label.text = "Combat log will appear here."
	primary_button.text = "Engage Auto Battle"
	primary_button.disabled = false
	retreat_button.disabled = false


func _on_primary_pressed() -> void:
	if pending_rewarded_revive:
		return
	if not final_result.is_empty():
		_continue_after_battle()
		return

	if battle_started:
		return

	battle_started = true
	primary_button.disabled = true
	retreat_button.disabled = true
	status_label.text = "Battle in progress..."

	if remaining_events.is_empty():
		_finalize_battle()
		return

	step_timer.start()


func _on_step_timer_timeout() -> void:
	if remaining_events.is_empty():
		step_timer.stop()
		_finalize_battle()
		return

	var event: Dictionary = remaining_events.pop_front()
	_append_log_line(_format_event_line(event))
	_update_hp_display(
		int(event.get("player_hp", 0)),
		int(GameState.active_run.get("player", {}).get("max_hp", 1)),
		int(event.get("enemy_hp", 0)),
		int(pending_combat.get("enemy", {}).get("max_hp", 1))
	)
	_update_actor_state_visuals(event.get("player_state", {}), event.get("enemy_state", {}))
	_play_event_vfx(event)
	log_label.text = _join_lines(log_lines)

	if remaining_events.is_empty():
		step_timer.stop()
		_finalize_battle()


func _finalize_battle() -> void:
	final_result = GameState.complete_pending_combat()
	SaveService.persist()
	_refresh_post_battle_actions()
	var battle_result: Dictionary = pending_combat.get("battle_result", {})
	var final_player_state: Dictionary = battle_result.get("final_player_state", _fallback_actor_state(GameState.active_run.get("player", {})))
	var final_enemy_state: Dictionary = battle_result.get("final_enemy_state", _fallback_actor_state(pending_combat.get("enemy", {})))
	var final_enemy_hp := int(final_enemy_state.get("current_hp", pending_combat.get("enemy", {}).get("current_hp", 0)))
	_update_hp_display(
		int(final_player_state.get("current_hp", GameState.active_run.get("player", {}).get("current_hp", 0))),
		int(final_player_state.get("max_hp", GameState.active_run.get("player", {}).get("max_hp", 1))),
		0 if final_result.get("victory", false) else final_enemy_hp,
		int(final_enemy_state.get("max_hp", pending_combat.get("enemy", {}).get("max_hp", 1)))
	)
	_update_actor_state_visuals(final_player_state, final_enemy_state)
	_play_result_vfx(bool(final_result.get("victory", false)))


func _continue_after_battle() -> void:
	if final_result.is_empty():
		return

	if not final_result.get("victory", false):
		GameState.finish_run(false)
		SaveService.persist()
		get_tree().current_scene.show_result()
		return

	if GameState.has_pending_relic_choice():
		get_tree().current_scene.show_relic_choice()
		return
	if GameState.has_pending_run_upgrade():
		get_tree().current_scene.show_run_upgrade()
		return

	if GameState.is_run_clear_ready():
		GameState.finish_run(true)
		SaveService.persist()
		get_tree().current_scene.show_result()
		return

	get_tree().current_scene.show_run()


func _on_retreat_pressed() -> void:
	if pending_rewarded_revive:
		return
	if not final_result.is_empty() and not final_result.get("victory", false) and _can_offer_rewarded_revive():
		pending_rewarded_revive = true
		primary_button.disabled = true
		retreat_button.disabled = true
		status_label.text = "Opening rewarded revive..."
		if not AdService.show_rewarded("rewarded_revive"):
			pending_rewarded_revive = false
			_refresh_post_battle_actions("Rewarded revive is not ready.")
			return

		return

	GameState.finish_run(false)
	SaveService.persist()
	get_tree().current_scene.show_result()


func _can_offer_rewarded_revive() -> bool:
	return not final_result.is_empty() and not final_result.get("victory", false) and AdService.is_rewarded_ready() and GameState.can_use_rewarded_revive()


func _refresh_post_battle_actions(message: String = "") -> void:
	primary_button.text = "Continue" if final_result.get("victory", false) else "End Run"
	primary_button.disabled = false
	var revive_available := _can_offer_rewarded_revive()
	retreat_button.text = "Revive (Ad)" if revive_available else "Retreat"
	retreat_button.disabled = not revive_available
	status_label.text = message if not message.is_empty() else String(final_result.get("message", "Combat resolved."))
	if revive_available:
		status_label.text += "\nRewarded revive is available: restore 50% HP and reduce danger by 10."


func _connect_ad_signals() -> void:
	if not AdService.rewarded_completed.is_connected(_on_rewarded_completed):
		AdService.rewarded_completed.connect(_on_rewarded_completed)
	if not AdService.rewarded_failed.is_connected(_on_rewarded_failed):
		AdService.rewarded_failed.connect(_on_rewarded_failed)


func _on_rewarded_completed(slot_key: String) -> void:
	if slot_key != "rewarded_revive" or not pending_rewarded_revive:
		return

	pending_rewarded_revive = false
	var revive_result := GameState.apply_rewarded_revive()
	if not revive_result.get("ok", false):
		_refresh_post_battle_actions(String(revive_result.get("message", "Rewarded revive failed.")))
		return

	SaveService.persist()
	get_tree().current_scene.show_run()


func _on_rewarded_failed(slot_key: String, _reason: String) -> void:
	if slot_key != "rewarded_revive" or not pending_rewarded_revive:
		return

	pending_rewarded_revive = false
	_refresh_post_battle_actions("Rewarded revive could not be completed.")


func _format_event_line(event: Dictionary) -> String:
	if String(event.get("kind", "attack")) == "status_tick":
		var target_side := String(event.get("target_side", "enemy"))
		var target_hp := int(event.get("enemy_hp", 0)) if target_side == "enemy" else int(event.get("player_hp", 0))
		return "[%ss] %s's %s ticks for %s damage. %s HP: %s" % [
			event.get("elapsed", 0.0),
			String(event.get("attacker_name", "Effect")),
			_status_title(String(event.get("status_id", "status"))),
			event.get("damage", 0),
			String(event.get("target_name", "Target")),
			target_hp
		]
	if String(event.get("kind", "attack")) == "phase_change":
		var line := "[%ss] %s enters %s." % [
			event.get("elapsed", 0.0),
			String(event.get("attacker_name", "Boss")),
			String(event.get("phase_name", "New Phase"))
		]
		var description := String(event.get("phase_description", ""))
		if not description.is_empty():
			line += " %s" % description
		var buff_summary := String(event.get("buff_summary", ""))
		if not buff_summary.is_empty():
			line += " | %s" % buff_summary
		var status_text := String(event.get("status_text", ""))
		if not status_text.is_empty():
			line += " | Status: %s" % status_text
		var heal_amount_phase := int(event.get("heal_amount", 0))
		if heal_amount_phase > 0:
			line += " | Heal +%s" % heal_amount_phase
		return line
	if String(event.get("kind", "attack")) == "trait_trigger":
		var trait_line := "[%ss] %s triggers %s." % [
			event.get("elapsed", 0.0),
			String(event.get("attacker_name", "Commander")),
			String(event.get("trait_name", "Trait"))
		]
		var summary := String(event.get("summary", ""))
		if not summary.is_empty():
			trait_line += " %s" % summary
		var trait_statuses := String(event.get("status_text", ""))
		if not trait_statuses.is_empty():
			trait_line += " | Status: %s" % trait_statuses
		var trait_heal := int(event.get("heal_amount", 0))
		if trait_heal > 0:
			trait_line += " | Heal +%s" % trait_heal
		return trait_line

	var attacker := String(event.get("attacker", "player"))
	var actor_name := String(event.get("attacker_name", "Commander"))
	var target_hp := int(event.get("enemy_hp", 0)) if attacker == "player" else int(event.get("player_hp", 0))
	var target_name := String(event.get("target_name", "Target"))
	var line := "[%ss] %s uses %s for %s damage. %s HP: %s" % [
		event.get("elapsed", 0.0),
		actor_name,
		String(event.get("skill_label", "Attack")),
		event.get("damage", 0),
		target_name,
		target_hp
	]
	var status_text := String(event.get("status_text", ""))
	if not status_text.is_empty():
		line += " | Applied: %s" % status_text
	var heal_amount := int(event.get("heal_amount", 0))
	if heal_amount > 0:
		line += " | Heal +%s" % heal_amount
	return line


func _build_actor_card(is_player: bool) -> Dictionary:
	var panel := PanelContainer.new()
	UISkin.apply_panel_style(panel, "primary")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	var name_label := UISkin.section_title("Commander" if is_player else "Enemy", 24)
	content.add_child(name_label)

	var portrait_frame := PanelContainer.new()
	UISkin.apply_panel_style(portrait_frame, "secondary")
	portrait_frame.custom_minimum_size = Vector2(0, 210)
	content.add_child(portrait_frame)

	var portrait_holder := CenterContainer.new()
	portrait_frame.add_child(portrait_holder)

	var hp_label := UISkin.body_label("HP 0 / 0", UISkin.TEXT_PRIMARY, 18)
	content.add_child(hp_label)

	var hp_bar := TextureProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 26)
	hp_bar.min_value = 0
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.texture_under = UISkin.texture("res://assets/ui/ui_progress_frame.png")
	hp_bar.texture_progress = UISkin.texture("res://assets/ui/ui_progress_fill.png")
	hp_bar.nine_patch_stretch = true
	content.add_child(hp_bar)

	var stat_label := UISkin.body_label("", UISkin.TEXT_SECONDARY, 16)
	content.add_child(stat_label)

	var loadout_label := UISkin.body_label("", UISkin.TEXT_MUTED, 15)
	content.add_child(loadout_label)

	content.add_child(UISkin.section_title("Active Effects", 18))

	var status_empty_label := UISkin.body_label("No active effects.", UISkin.TEXT_MUTED, 14)
	content.add_child(status_empty_label)

	var status_flow := HFlowContainer.new()
	status_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_flow.add_theme_constant_override("h_separation", 6)
	status_flow.add_theme_constant_override("v_separation", 6)
	content.add_child(status_flow)

	return {
		"panel": panel,
		"name_label": name_label,
		"portrait_holder": portrait_holder,
		"hp_label": hp_label,
		"hp_bar": hp_bar,
		"stat_label": stat_label,
		"loadout_label": loadout_label,
		"status_empty_label": status_empty_label,
		"status_flow": status_flow
	}


func _set_actor_presentation(name_label: Label, portrait_holder: CenterContainer, loadout_label: Label, actor_name: String, portrait_texture: Texture2D, loadout_text: String) -> void:
	name_label.text = actor_name
	loadout_label.text = loadout_text
	for child in portrait_holder.get_children():
		child.queue_free()
	portrait_holder.add_child(UISkin.make_portrait(portrait_texture, Vector2(180, 180)))


func _update_hp_display(player_hp: int, player_max_hp: int, enemy_hp: int, enemy_max_hp: int) -> void:
	player_hp_bar.max_value = maxf(1.0, float(player_max_hp))
	player_hp_bar.value = clampf(float(player_hp), 0.0, float(player_max_hp))
	enemy_hp_bar.max_value = maxf(1.0, float(enemy_max_hp))
	enemy_hp_bar.value = clampf(float(enemy_hp), 0.0, float(enemy_max_hp))
	player_hp_label.text = "HP %s / %s" % [player_hp, player_max_hp]
	enemy_hp_label.text = "HP %s / %s" % [enemy_hp, enemy_max_hp]


func _update_actor_state_visuals(player_state: Dictionary, enemy_state: Dictionary) -> void:
	_update_single_actor_visuals(player_state, player_stat_label, player_status_empty_label, player_status_flow)
	_update_single_actor_visuals(enemy_state, enemy_stat_label, enemy_status_empty_label, enemy_status_flow)


func _update_single_actor_visuals(state: Dictionary, stat_label: Label, empty_label: Label, status_flow: HFlowContainer) -> void:
	var effective_stats: Dictionary = state.get("effective_stats", {})
	stat_label.text = "ATK %s | ARM %s | TP %s%% | SPD %.2f" % [
		int(effective_stats.get("attack", 0)),
		int(effective_stats.get("armor", 0)),
		int(round(float(effective_stats.get("territory_power", 0.0)) * 100.0)),
		float(effective_stats.get("attack_speed", 1.0))
	]

	for child in status_flow.get_children():
		child.queue_free()

	var statuses: Array = state.get("statuses", [])
	empty_label.visible = statuses.is_empty()
	status_flow.visible = not statuses.is_empty()
	for status_value in statuses:
		if status_value is Dictionary:
			status_flow.add_child(_build_status_chip(status_value))


func _build_status_chip(status: Dictionary) -> Control:
	var status_id := String(status.get("id", "status"))
	var palette := _status_palette(status_id)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(100, 54)
	panel.tooltip_text = _status_tooltip(status)
	panel.add_theme_stylebox_override("panel", _build_chip_style(palette))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	var border_color: Color = palette.get("border", Color(1.0, 1.0, 1.0, 1.0))
	row.add_child(UISkin.make_icon(UISkin.status_icon_texture(status_id), 22, border_color))

	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)

	var code_label := Label.new()
	code_label.text = _status_title(status_id)
	code_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
	code_label.add_theme_font_size_override("font_size", 13)
	copy.add_child(code_label)

	var time_label := Label.new()
	time_label.text = "%.1fs" % maxf(0.0, float(status.get("duration", 0.0)))
	time_label.modulate = Color(0.96, 0.98, 1.0, 0.95)
	time_label.add_theme_font_size_override("font_size", 11)
	copy.add_child(time_label)

	return panel


func _status_tooltip(status: Dictionary) -> String:
	var lines: Array = [_status_title(String(status.get("id", "status")))]
	var effect_lines: Array = []

	var tick_damage := int(status.get("tick_damage", 0))
	if tick_damage > 0:
		effect_lines.append("Deals %s damage every %.1fs." % [tick_damage, float(status.get("tick_interval", 1.0))])

	var attack_multiplier := float(status.get("attack_multiplier", 1.0))
	if absf(attack_multiplier - 1.0) > 0.001:
		var delta_percent := int(round((attack_multiplier - 1.0) * 100.0))
		effect_lines.append("%s Attack." % _signed_percent_text(delta_percent))

	var armor_delta := int(status.get("armor_delta", 0))
	if armor_delta != 0:
		effect_lines.append("%s Armor." % _signed_flat_text(armor_delta))

	var territory_power_delta := float(status.get("territory_power_delta", 0.0))
	if absf(territory_power_delta) > 0.001:
		effect_lines.append("%s Territory Power." % _signed_percent_text(int(round(territory_power_delta * 100.0))))

	var crit_damage_delta := float(status.get("crit_damage_delta", 0.0))
	if absf(crit_damage_delta) > 0.001:
		effect_lines.append("%s Crit Damage." % _signed_percent_text(int(round(crit_damage_delta * 100.0))))

	if effect_lines.is_empty():
		effect_lines.append("Temporary combat effect.")

	for effect_line in effect_lines:
		lines.append(effect_line)
	lines.append("Remaining: %.1fs" % maxf(0.0, float(status.get("duration", 0.0))))

	var source_name := String(status.get("source_name", ""))
	if not source_name.is_empty():
		lines.append("Source: %s" % source_name)

	return "\n".join(lines)


func _status_palette(status_id: String) -> Dictionary:
	match status_id:
		"burn":
			return { "fill": Color(0.78, 0.28, 0.16, 0.94), "border": Color(0.98, 0.7, 0.3, 1.0) }
		"weaken":
			return { "fill": Color(0.35, 0.48, 0.64, 0.94), "border": Color(0.7, 0.84, 0.95, 1.0) }
		"sunder":
			return { "fill": Color(0.47, 0.33, 0.28, 0.94), "border": Color(0.86, 0.7, 0.58, 1.0) }
		"guard":
			return { "fill": Color(0.2, 0.42, 0.72, 0.94), "border": Color(0.66, 0.82, 1.0, 1.0) }
		"fury":
			return { "fill": Color(0.64, 0.16, 0.16, 0.94), "border": Color(0.95, 0.48, 0.36, 1.0) }
		"fervor":
			return { "fill": Color(0.57, 0.46, 0.14, 0.94), "border": Color(0.96, 0.86, 0.44, 1.0) }
		_:
			return { "fill": Color(0.28, 0.31, 0.36, 0.94), "border": Color(0.76, 0.82, 0.9, 1.0) }


func _build_chip_style(palette: Dictionary) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = palette.get("fill", Color(0.28, 0.31, 0.36, 1.0))
	style.border_color = palette.get("border", Color(0.76, 0.82, 0.9, 1.0))
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _status_title(status_id: String) -> String:
	match status_id:
		"burn":
			return "Burn"
		"weaken":
			return "Weaken"
		"sunder":
			return "Sunder"
		"guard":
			return "Guard"
		"fury":
			return "Fury"
		"fervor":
			return "Fervor"
		_:
			return String(status_id).capitalize()


func _signed_percent_text(value: int) -> String:
	return "%s%s%%" % ["+" if value > 0 else "", value]


func _signed_flat_text(value: int) -> String:
	return "%s%s" % ["+" if value > 0 else "", value]


func _fallback_actor_state(stats: Dictionary) -> Dictionary:
	return {
		"current_hp": int(stats.get("current_hp", stats.get("max_hp", 1))),
		"max_hp": int(stats.get("max_hp", 1)),
		"effective_stats": stats.duplicate(true),
		"statuses": []
	}


func _append_log_line(line: String) -> void:
	log_lines.append(line)
	while log_lines.size() > 14:
		log_lines.pop_front()


func _join_lines(lines: Array) -> String:
	var text := ""
	for index in range(lines.size()):
		if index > 0:
			text += "\n"
		text += String(lines[index])
	return text


func _format_skill_list(skills: Array) -> String:
	if skills.is_empty():
		return "Basic Attack"

	var names: Array = []
	for skill_value in skills:
		names.append(String(skill_value).replace("_", " ").capitalize())
	return ", ".join(names)


func _play_event_vfx(event: Dictionary) -> void:
	stage_effect_rect.texture = UISkin.combat_effect_texture(event)
	stage_effect_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	stage_effect_rect.scale = Vector2.ONE * 0.82
	var tween := create_tween()
	tween.tween_property(stage_effect_rect, "modulate:a", 0.92, 0.08)
	tween.parallel().tween_property(stage_effect_rect, "scale", Vector2.ONE, 0.14)
	tween.tween_property(stage_effect_rect, "modulate:a", 0.0, 0.18)

	if String(event.get("kind", "")) == "phase_change":
		stage_flash.color = Color(0.95, 0.34, 0.24, 0.0)
		var flash_tween := create_tween()
		flash_tween.tween_property(stage_flash, "color:a", 0.26, 0.08)
		flash_tween.tween_property(stage_flash, "color:a", 0.0, 0.18)


func _play_result_vfx(victory: bool) -> void:
	stage_effect_rect.texture = UISkin.texture("res://assets/effects/fx_levelup_burst.png") if victory else UISkin.texture("res://assets/effects/fx_death_smoke.png")
	stage_effect_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tween := create_tween()
	tween.tween_property(stage_effect_rect, "modulate:a", 0.96, 0.12)
	tween.tween_property(stage_effect_rect, "modulate:a", 0.0, 0.36)
