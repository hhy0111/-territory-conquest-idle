extends Control

const UISkin = preload("res://scripts/ui/ui_skin.gd")


func _ready() -> void:
	UISkin.install_screen_background(self, UISkin.screen_background("result"), Color(0.03, 0.04, 0.05, 0.7))
	_build_ui()


func _build_ui() -> void:
	var root := UISkin.make_screen_margin(24, 26, 24, 24)
	add_child(root)

	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	root.add_child(column)

	column.add_child(_build_header())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	var result: Dictionary = GameState.last_result
	content.add_child(_build_section("Summary", _summary_text(result), UISkin.icon_texture("territory_power")))
	content.add_child(_build_section("Combat Report", _combat_text(result), UISkin.icon_texture("attack")))
	content.add_child(_build_section("Run Activity", _activity_text(result), UISkin.icon_texture("event")))
	content.add_child(_build_section("Economy", _economy_text(result), UISkin.icon_texture("essence")))
	content.add_child(_build_section("Build", _build_text(result), UISkin.icon_texture("relic")))
	content.add_child(_build_section("Territory", _territory_text(result), UISkin.icon_texture("boss")))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)

	var next_button := Button.new()
	next_button.text = "Start Next Run"
	next_button.custom_minimum_size = Vector2(0, 78)
	next_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UISkin.apply_button_style(next_button, "primary")
	next_button.pressed.connect(_on_next_run_pressed)
	actions.add_child(next_button)

	var meta_button := Button.new()
	meta_button.text = "Meta Upgrades"
	meta_button.custom_minimum_size = Vector2(0, 78)
	meta_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UISkin.apply_button_style(meta_button, "secondary")
	meta_button.pressed.connect(_on_meta_pressed)
	actions.add_child(meta_button)

	var home_button := Button.new()
	home_button.text = "Home"
	home_button.custom_minimum_size = Vector2(0, 78)
	home_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UISkin.apply_button_style(home_button, "secondary")
	home_button.pressed.connect(_on_home_pressed)
	actions.add_child(home_button)


func _build_header() -> Control:
	var result: Dictionary = GameState.last_result
	var panel := PanelContainer.new()
	UISkin.apply_panel_style(panel, "popup")

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	var portrait_frame := PanelContainer.new()
	UISkin.apply_panel_style(portrait_frame, "secondary")
	portrait_frame.custom_minimum_size = Vector2(180, 180)
	row.add_child(portrait_frame)
	portrait_frame.add_child(UISkin.make_portrait(UISkin.hero_texture(), Vector2(150, 150)))

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 10)
	row.add_child(copy)

	var title := UISkin.section_title("Run Victory" if result.get("victory", false) else "Run Defeat", 38)
	title.modulate = Color(0.97, 0.9, 0.56, 1.0) if result.get("victory", false) else Color(0.93, 0.56, 0.49, 1.0)
	copy.add_child(title)

	copy.add_child(UISkin.body_label("Seed %s | Duration %s | Level %s | Captures %s" % [
		result.get("seed", 0),
		_format_duration(int(result.get("duration_seconds", 0))),
		result.get("final_level", 1),
		result.get("captures", 0)
	], UISkin.TEXT_SECONDARY, 18))

	var chips := HFlowContainer.new()
	chips.add_theme_constant_override("h_separation", 10)
	chips.add_theme_constant_override("v_separation", 10)
	copy.add_child(chips)
	chips.add_child(UISkin.make_badge("Essence +%s" % result.get("essence_gain", 0), UISkin.icon_texture("essence"), "currency"))
	chips.add_child(UISkin.make_badge("Sigils +%s" % result.get("sigil_gain", 0), UISkin.icon_texture("sigil"), "currency"))
	chips.add_child(UISkin.make_badge("Bosses %s" % result.get("bosses_defeated", 0), UISkin.icon_texture("boss")))

	return panel


func _summary_text(result: Dictionary) -> String:
	var player: Dictionary = result.get("final_player", {})
	var stats: Dictionary = result.get("stats", {})
	var map_stats: Dictionary = stats.get("map", {})
	return "\n".join([
		"Outcome: %s" % ("Victory" if result.get("victory", false) else "Defeat"),
		"Captures: %s" % result.get("captures", 0),
		"Bosses Defeated: %s" % result.get("bosses_defeated", 0),
		"Ending HP: %s / %s" % [player.get("current_hp", 0), player.get("max_hp", 0)],
		"Highest Danger: %s" % map_stats.get("highest_danger", result.get("final_danger", 0)),
		"Final Attack / Armor: %s / %s" % [player.get("attack", 0), player.get("armor", 0)],
		"Final Crit Rate: %s%%" % int(round(float(player.get("crit_rate", 0.0)) * 100.0)),
		"Final Territory Power: %s%%" % int(round(float(player.get("territory_power", 0.0)) * 100.0))
	])


func _combat_text(result: Dictionary) -> String:
	var combat_stats: Dictionary = result.get("stats", {}).get("combat", {})
	var resolved_fights := int(combat_stats.get("victories", 0)) + int(combat_stats.get("defeats", 0))
	var retreats := maxi(0, int(combat_stats.get("encounters_started", 0)) - resolved_fights)
	return "\n".join([
		"Encounters Started: %s" % combat_stats.get("encounters_started", 0),
		"Resolved Wins / Losses: %s / %s" % [combat_stats.get("victories", 0), combat_stats.get("defeats", 0)],
		"Retreated / Unresolved: %s" % retreats,
		"Boss Encounters / Boss Kills: %s / %s" % [combat_stats.get("boss_encounters_started", 0), combat_stats.get("boss_victories", 0)],
		"Damage Dealt / Taken: %s / %s" % [combat_stats.get("damage_dealt", 0), combat_stats.get("damage_taken", 0)],
		"Healing Received: %s" % combat_stats.get("healing_received", 0),
		"Enemy Self-Healing: %s" % combat_stats.get("enemy_healing", 0),
		"Highest Single Hit: %s" % combat_stats.get("highest_hit", 0),
		"Boss Phase Changes Seen: %s" % combat_stats.get("phase_changes_seen", 0),
		"Total Battle Time: %s" % _format_seconds(float(combat_stats.get("total_battle_seconds", 0.0))),
		"Longest Battle: %s" % _format_seconds(float(combat_stats.get("longest_battle_seconds", 0.0)))
	])


func _activity_text(result: Dictionary) -> String:
	var stats: Dictionary = result.get("stats", {})
	var map_stats: Dictionary = stats.get("map", {})
	var economy_stats: Dictionary = stats.get("economy", {})
	return "\n".join([
		"Events Resolved: %s" % map_stats.get("events_resolved", 0),
		"Utility Tiles Secured: %s" % map_stats.get("utilities_resolved", 0),
		"Utility Breakdown: %s" % _format_count_map(map_stats.get("utility_by_type", {})),
		"HP Spent on Event Choices: %s" % economy_stats.get("hp_spent_on_events", 0),
		"HP Restored by Utility Tiles: %s" % economy_stats.get("hp_healed_from_utilities", 0),
		"Curses Taken: %s" % _format_list_or_none(_format_id_list(result.get("curses", []), {}))
	])


func _economy_text(result: Dictionary) -> String:
	var economy_stats: Dictionary = result.get("stats", {}).get("economy", {})
	return "\n".join([
		"Gold Collected: %s" % result.get("gold_earned", 0),
		"Gold From Tile Captures: %s" % economy_stats.get("gold_from_tiles", 0),
		"Gold From Events: %s" % economy_stats.get("gold_from_events", 0),
		"Gold From Utilities: %s" % economy_stats.get("gold_from_utilities", 0),
		"Gold From Run Upgrades: %s" % economy_stats.get("gold_from_upgrades", 0),
		"XP From Tile Captures: %s" % economy_stats.get("xp_from_tiles", 0),
		"XP From Events: %s" % economy_stats.get("xp_from_events", 0),
		"XP From Utilities: %s" % economy_stats.get("xp_from_utilities", 0),
		"Essence Gain: %s" % result.get("essence_gain", 0),
		"Essence Bonus Pool: %s" % result.get("bonus_essence", 0),
		"Essence Bonus From Events: %s" % economy_stats.get("essence_bonus_from_events", 0),
		"Essence Bonus From Run Upgrades: %s" % economy_stats.get("essence_bonus_from_upgrades", 0),
		"Sigils Gain: %s" % result.get("sigil_gain", 0),
		"Sigil Bonus Pool: %s" % result.get("bonus_sigils", 0),
		"Sigil Bonus From Events: %s" % economy_stats.get("sigil_bonus_from_events", 0),
		"Sigil Bonus From Run Upgrades: %s" % economy_stats.get("sigil_bonus_from_upgrades", 0)
	])


func _build_text(result: Dictionary) -> String:
	var player: Dictionary = result.get("final_player", {})
	var relic_defs: Dictionary = DataService.get_relic_definitions()
	var run_upgrade_defs: Dictionary = DataService.get_run_upgrade_definitions()
	var build_stats: Dictionary = result.get("stats", {}).get("build", {})
	return "\n".join([
		"Relics Chosen: %s" % _format_list_or_none(_format_id_list(result.get("relic_ids", []), relic_defs, "name")),
		"Relic Pick Order: %s" % _format_list_or_none(_format_id_list(build_stats.get("relic_pick_order", []), relic_defs, "name")),
		"Run Upgrades: %s" % _format_run_upgrades(result.get("run_upgrades", {}), run_upgrade_defs),
		"Upgrade Pick Order: %s" % _format_list_or_none(_format_id_list(build_stats.get("run_upgrade_pick_order", []), run_upgrade_defs, "name")),
		"Skills Active: %s" % _format_list_or_none(_format_pretty_ids(player.get("skills", []))),
		"Traits Active: %s" % _format_list_or_none(_format_pretty_ids(player.get("traits", []))),
		"Skills Gained During Run: %s" % _format_list_or_none(_format_pretty_ids(build_stats.get("skills_gained", []))),
		"Traits Gained During Run: %s" % _format_list_or_none(_format_pretty_ids(build_stats.get("traits_gained", [])))
	])


func _territory_text(result: Dictionary) -> String:
	var map_stats: Dictionary = result.get("stats", {}).get("map", {})
	return "\n".join([
		"Captured Tile Breakdown: %s" % _format_count_map(map_stats.get("captured_by_type", {})),
		"Total Captures: %s" % result.get("captures", 0),
		"Final Danger: %s" % result.get("final_danger", 0)
	])


func _build_section(title: String, body: String, icon_texture: Texture2D) -> Control:
	var panel := PanelContainer.new()
	UISkin.apply_panel_style(panel, "primary")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	content.add_child(title_row)
	title_row.add_child(UISkin.make_icon(icon_texture, 28))
	title_row.add_child(UISkin.section_title(title, 24))

	var label := UISkin.body_label(body, UISkin.TEXT_SECONDARY, 18)
	content.add_child(label)

	return panel


func _format_duration(seconds: int) -> String:
	var total := maxi(0, seconds)
	var minutes := total / 60
	var remaining_seconds := total % 60
	return "%02d:%02d" % [minutes, remaining_seconds]


func _format_seconds(value: float) -> String:
	return "%.1fs" % maxf(0.0, value)


func _format_run_upgrades(run_upgrades: Dictionary, definitions: Dictionary) -> String:
	if run_upgrades.is_empty():
		return "None"

	var keys: Array = run_upgrades.keys()
	keys.sort()
	var entries: Array = []
	for upgrade_id_value in keys:
		var upgrade_id := String(upgrade_id_value)
		var definition: Dictionary = definitions.get(upgrade_id, {})
		var label := String(definition.get("name", _pretty_id(upgrade_id)))
		entries.append("%s x%s" % [label, int(run_upgrades.get(upgrade_id, 0))])
	return ", ".join(entries)


func _format_id_list(ids: Array, definitions: Dictionary, name_key: String = "") -> Array:
	var labels: Array = []
	for id_value in ids:
		var entry_id := String(id_value)
		if not name_key.is_empty():
			var definition: Dictionary = definitions.get(entry_id, {})
			labels.append(String(definition.get(name_key, _pretty_id(entry_id))))
		else:
			labels.append(_pretty_id(entry_id))
	return labels


func _format_pretty_ids(ids: Array) -> Array:
	var labels: Array = []
	for id_value in ids:
		labels.append(_pretty_id(String(id_value)))
	return labels


func _format_list_or_none(items: Array) -> String:
	if items.is_empty():
		return "None"
	return ", ".join(items)


func _format_count_map(count_map: Dictionary) -> String:
	if count_map.is_empty():
		return "None"

	var keys: Array = count_map.keys()
	keys.sort()
	var entries: Array = []
	for key_value in keys:
		var label := _pretty_id(String(key_value))
		entries.append("%s x%s" % [label, int(count_map.get(key_value, 0))])
	return ", ".join(entries)


func _pretty_id(value: String) -> String:
	var parts := value.split("_")
	var title_parts: Array = []
	for part in parts:
		title_parts.append(String(part).capitalize())
	return " ".join(title_parts)


func _on_next_run_pressed() -> void:
	GameState.start_new_run()
	SaveService.persist()
	get_tree().current_scene.show_run()


func _on_meta_pressed() -> void:
	get_tree().current_scene.show_meta()


func _on_home_pressed() -> void:
	get_tree().current_scene.show_home()
