extends Control

const UISkin = preload("res://scripts/ui/ui_skin.gd")

var summary_flow: HFlowContainer
var hint_label: Label
var message_label: Label
var detail_body: VBoxContainer
var tile_grid: GridContainer
var active_event: Dictionary = {}
var selected_coord_key := ""


func _ready() -> void:
	if not GameState.has_active_run():
		GameState.start_new_run()
		SaveService.persist()
	if GameState.has_pending_combat():
		get_tree().current_scene.show_combat()
		return
	if GameState.has_pending_relic_choice():
		get_tree().current_scene.show_relic_choice()
		return
	if GameState.has_pending_run_upgrade():
		get_tree().current_scene.show_run_upgrade()
		return

	UISkin.install_screen_background(self, UISkin.screen_background("run"), Color(0.03, 0.04, 0.06, 0.66))
	_build_ui()
	_refresh_view("Choose a frontier tile to prepare the next action.")


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
	header_content.add_theme_constant_override("separation", 10)
	header.add_child(header_content)

	header_content.add_child(UISkin.section_title("Frontier Run", 34))

	summary_flow = HFlowContainer.new()
	summary_flow.add_theme_constant_override("h_separation", 10)
	summary_flow.add_theme_constant_override("v_separation", 10)
	header_content.add_child(summary_flow)

	hint_label = UISkin.body_label("", UISkin.TEXT_SECONDARY, 17)
	header_content.add_child(hint_label)

	message_label = UISkin.body_label("", UISkin.TEXT_ACCENT, 17)
	header_content.add_child(message_label)

	var detail_panel := PanelContainer.new()
	UISkin.apply_panel_style(detail_panel, "tile_preview")
	column.add_child(detail_panel)

	detail_body = VBoxContainer.new()
	detail_body.add_theme_constant_override("separation", 12)
	detail_panel.add_child(detail_body)

	var board_panel := PanelContainer.new()
	UISkin.apply_panel_style(board_panel, "secondary")
	board_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(board_panel)

	var board_content := VBoxContainer.new()
	board_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_content.add_theme_constant_override("separation", 10)
	board_panel.add_child(board_content)

	board_content.add_child(UISkin.section_title("Territory Board", 24))

	var board_scroll := ScrollContainer.new()
	board_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_content.add_child(board_scroll)

	tile_grid = GridContainer.new()
	tile_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile_grid.add_theme_constant_override("h_separation", 10)
	tile_grid.add_theme_constant_override("v_separation", 10)
	board_scroll.add_child(tile_grid)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)

	var retreat_button := Button.new()
	retreat_button.text = "Retreat"
	retreat_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retreat_button.custom_minimum_size = Vector2(0, 74)
	UISkin.apply_button_style(retreat_button, "secondary")
	retreat_button.pressed.connect(_on_retreat_pressed)
	actions.add_child(retreat_button)

	var home_button := Button.new()
	home_button.text = "Home"
	home_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_button.custom_minimum_size = Vector2(0, 74)
	UISkin.apply_button_style(home_button, "secondary")
	home_button.pressed.connect(_on_home_pressed)
	actions.add_child(home_button)


func _refresh_view(message: String = "") -> void:
	var run: Dictionary = GameState.active_run
	if run.is_empty():
		active_event = {}
		get_tree().current_scene.show_result()
		return

	message_label.text = message
	_refresh_summary(run)

	for child in detail_body.get_children():
		child.queue_free()
	for child in tile_grid.get_children():
		child.queue_free()

	var tiles: Dictionary = run.get("map", {}).get("tiles", {})
	var tile_defs: Dictionary = DataService.get_tile_definitions()
	_ensure_selected_tile(tiles)
	_render_board(run, tile_defs)

	if not active_event.is_empty():
		hint_label.text = "Resolve the event. Choices are final and apply immediately."
		_render_active_event()
		return

	hint_label.text = "Capture %s tiles to clear the route. Select a visible tile to inspect it, then confirm the action." % GameState.get_run_capture_goal()
	_render_selected_tile(tile_defs, tiles)

	if _selectable_coord_keys(tiles).is_empty():
		GameState.finish_run(false)
		SaveService.persist()
		get_tree().current_scene.show_result()


func _refresh_summary(run: Dictionary) -> void:
	for child in summary_flow.get_children():
		child.queue_free()

	var player: Dictionary = run.get("player", {})
	summary_flow.add_child(UISkin.make_badge("%s/%s HP" % [player.get("current_hp", 0), player.get("max_hp", 0)], UISkin.icon_texture("hp"), "currency"))
	summary_flow.add_child(UISkin.make_badge("Gold %s" % run.get("gold", 0), UISkin.icon_texture("gold"), "currency"))
	summary_flow.add_child(UISkin.make_badge("Level %s" % run.get("level", 1), UISkin.icon_texture("territory_power")))
	summary_flow.add_child(UISkin.make_badge("XP %s" % run.get("xp", 0), UISkin.icon_texture("reveal")))
	summary_flow.add_child(UISkin.make_badge("Captures %s/%s" % [run.get("captured_tiles", 0), GameState.get_run_capture_goal()], UISkin.icon_texture("boss")))
	summary_flow.add_child(UISkin.make_badge("Bosses %s" % run.get("bosses_defeated", 0), UISkin.icon_texture("boss")))
	summary_flow.add_child(UISkin.make_badge("Danger %s" % run.get("danger", 0), UISkin.icon_texture("risk")))
	summary_flow.add_child(UISkin.make_badge("Relics %s" % run.get("relics", []).size(), UISkin.icon_texture("relic")))


func _render_board(run: Dictionary, tile_defs: Dictionary) -> void:
	var map_data: Dictionary = run.get("map", {})
	var tiles: Dictionary = map_data.get("tiles", {})
	var radius := int(map_data.get("radius", 2))
	tile_grid.columns = radius * 2 + 1

	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			var coord_key := "%s,%s" % [x, y]
			var tile: Dictionary = tiles.get(coord_key, {})
			if tile.is_empty():
				tile_grid.add_child(Control.new())
			else:
				tile_grid.add_child(_build_tile_cell(coord_key, tile, tile_defs))


func _build_tile_cell(coord_key: String, tile: Dictionary, tile_defs: Dictionary) -> Control:
	var tile_type := String(tile.get("type", "plains"))
	var tile_def: Dictionary = tile_defs.get(tile_type, {})
	var resolver_mode := String(tile_def.get("resolver_mode", "combat"))
	var state := String(tile.get("state", "hidden"))
	var selectable := state == "selectable"
	var visible_tile := state != "hidden"

	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(142, 142)
	button.disabled = not visible_tile
	UISkin.apply_button_style(button, "secondary")
	button.pressed.connect(_on_tile_preview_pressed.bind(coord_key))

	var art := TextureRect.new()
	art.texture = UISkin.tile_texture(tile_type) if visible_tile else UISkin.tile_overlay_texture("hidden")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UISkin.full_rect(art)
	button.add_child(art)

	if visible_tile:
		var tint := ColorRect.new()
		tint.color = Color(0.02, 0.03, 0.05, 0.22 if selectable else 0.38)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UISkin.full_rect(tint)
		button.add_child(tint)

	var overlay_id := "captured" if state == "captured" else "selectable" if selectable else "path"
	if not visible_tile:
		overlay_id = "hidden"
	var overlay_texture := UISkin.tile_overlay_texture(overlay_id)
	if overlay_texture != null:
		var overlay := TextureRect.new()
		overlay.texture = overlay_texture
		overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UISkin.full_rect(overlay)
		button.add_child(overlay)

	var content := MarginContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UISkin.full_rect(content)
	content.add_theme_constant_override("margin_left", 8)
	content.add_theme_constant_override("margin_top", 8)
	content.add_theme_constant_override("margin_right", 8)
	content.add_theme_constant_override("margin_bottom", 8)
	button.add_child(content)

	var content_column := VBoxContainer.new()
	content_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(content_column)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	content_column.add_child(top_row)
	top_row.add_child(UISkin.make_icon(UISkin.tile_mode_icon(tile_type, resolver_mode), 20))

	var ring_label := Label.new()
	ring_label.text = "R%s" % tile.get("ring", 0)
	ring_label.modulate = UISkin.TEXT_PRIMARY
	ring_label.add_theme_font_size_override("font_size", 13)
	top_row.add_child(ring_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_column.add_child(spacer)

	var bottom_row := VBoxContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_column.add_child(bottom_row)

	var tile_label := Label.new()
	tile_label.text = _pretty_id(tile_type)
	tile_label.modulate = UISkin.TEXT_PRIMARY if visible_tile else UISkin.TEXT_MUTED
	tile_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile_label.add_theme_font_size_override("font_size", 14)
	bottom_row.add_child(tile_label)

	var state_label := Label.new()
	state_label.text = "Selected" if coord_key == selected_coord_key else state.capitalize()
	state_label.modulate = UISkin.TEXT_ACCENT if coord_key == selected_coord_key else UISkin.TEXT_SECONDARY
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.add_theme_font_size_override("font_size", 12)
	bottom_row.add_child(state_label)

	return button


func _render_selected_tile(tile_defs: Dictionary, tiles: Dictionary) -> void:
	if selected_coord_key.is_empty() or not tiles.has(selected_coord_key):
		detail_body.add_child(UISkin.body_label("No visible tile selected.", UISkin.TEXT_MUTED, 18))
		return

	var tile: Dictionary = tiles[selected_coord_key]
	var tile_type := String(tile.get("type", "plains"))
	var tile_def: Dictionary = tile_defs.get(tile_type, {})
	var resolver_mode := String(tile_def.get("resolver_mode", "combat"))
	var reward_data: Dictionary = tile_def.get("base_reward", {})
	var gold_range: Array = reward_data.get("gold", [0, 0])
	var xp_range: Array = reward_data.get("xp", [0, 0])

	var preview_row := HBoxContainer.new()
	preview_row.add_theme_constant_override("separation", 14)
	detail_body.add_child(preview_row)

	var portrait_frame := PanelContainer.new()
	UISkin.apply_panel_style(portrait_frame, "secondary")
	portrait_frame.custom_minimum_size = Vector2(170, 170)
	preview_row.add_child(portrait_frame)
	portrait_frame.add_child(UISkin.make_portrait(UISkin.tile_texture(tile_type), Vector2(140, 140)))

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 8)
	preview_row.add_child(copy)

	copy.add_child(UISkin.section_title("%s  %s" % [_pretty_id(tile_type), selected_coord_key], 28))
	copy.add_child(UISkin.body_label(_tile_summary(tile_def, tile), UISkin.TEXT_SECONDARY, 17))

	var reward_row := HFlowContainer.new()
	reward_row.add_theme_constant_override("h_separation", 10)
	reward_row.add_theme_constant_override("v_separation", 10)
	copy.add_child(reward_row)
	reward_row.add_child(UISkin.make_badge("Mode %s" % resolver_mode.capitalize(), UISkin.tile_mode_icon(tile_type, resolver_mode)))
	reward_row.add_child(UISkin.make_badge("Gold %s-%s" % [gold_range[0], gold_range[1]], UISkin.icon_texture("gold")))
	reward_row.add_child(UISkin.make_badge("XP %s-%s" % [xp_range[0], xp_range[1]], UISkin.icon_texture("reveal")))
	reward_row.add_child(UISkin.make_badge("Risk %+d" % int(tile_def.get("risk_delta", 0)), UISkin.icon_texture("risk")))

	var action_button := Button.new()
	action_button.text = _action_button_text(String(tile.get("state", "hidden")), resolver_mode)
	action_button.disabled = String(tile.get("state", "hidden")) != "selectable"
	action_button.custom_minimum_size = Vector2(0, 74)
	UISkin.apply_button_style(action_button, "primary")
	action_button.pressed.connect(_on_selected_tile_resolve_pressed)
	detail_body.add_child(action_button)


func _render_active_event() -> void:
	var event_def: Dictionary = active_event.get("event", {})
	var coord_key := String(active_event.get("coord_key", ""))
	var tile_type := String(active_event.get("tile_type", "event"))

	var banner := PanelContainer.new()
	UISkin.apply_panel_style(banner, "popup")
	detail_body.add_child(banner)

	var banner_stack := MarginContainer.new()
	banner_stack.custom_minimum_size = Vector2(0, 230)
	banner.add_child(banner_stack)

	var background := TextureRect.new()
	background.texture = UISkin.event_background_texture(String(event_def.get("id", "")))
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UISkin.full_rect(background)
	banner_stack.add_child(background)

	var overlay := ColorRect.new()
	overlay.color = Color(0.03, 0.04, 0.05, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UISkin.full_rect(overlay)
	banner_stack.add_child(overlay)

	var text_margin := UISkin.make_screen_margin(18, 18, 18, 18)
	text_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_stack.add_child(text_margin)

	var text_column := VBoxContainer.new()
	text_column.add_theme_constant_override("separation", 8)
	text_margin.add_child(text_column)
	text_column.add_child(UISkin.section_title("%s  (%s)" % [String(event_def.get("title", "Event")), coord_key], 28))
	text_column.add_child(UISkin.body_label(String(event_def.get("description", "Choose one option to resolve this tile.")), UISkin.TEXT_SECONDARY, 18))
	text_column.add_child(UISkin.make_badge("Tile %s" % _pretty_id(tile_type), UISkin.tile_mode_icon(tile_type, "event")))

	for choice_data in event_def.get("choices", []):
		if not (choice_data is Dictionary):
			continue
		var choice: Dictionary = choice_data
		var choice_id := String(choice.get("id", ""))
		if choice_id.is_empty():
			continue

		var card := PanelContainer.new()
		UISkin.apply_panel_style(card, "reward")
		detail_body.add_child(card)

		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 8)
		card.add_child(content)
		content.add_child(UISkin.section_title(String(choice.get("label", "Choose")), 22))
		content.add_child(UISkin.body_label(_describe_event_choice(choice), UISkin.TEXT_SECONDARY, 17))

		var button := Button.new()
		button.text = "Confirm %s" % String(choice.get("label", "Choice"))
		button.custom_minimum_size = Vector2(0, 70)
		UISkin.apply_button_style(button, "primary")
		button.pressed.connect(_on_event_choice_pressed.bind(coord_key, choice_id))
		content.add_child(button)


func _ensure_selected_tile(tiles: Dictionary) -> void:
	if not selected_coord_key.is_empty() and tiles.has(selected_coord_key):
		return

	var map_selected := String(GameState.active_run.get("map", {}).get("selected_tile", ""))
	if not map_selected.is_empty() and tiles.has(map_selected):
		selected_coord_key = map_selected
		return

	var selectable_keys := _selectable_coord_keys(tiles)
	selected_coord_key = String(selectable_keys[0]) if not selectable_keys.is_empty() else ""


func _selectable_coord_keys(tiles: Dictionary) -> Array:
	var selectable_keys: Array = []
	for key in tiles.keys():
		if String(tiles[key].get("state", "")) == "selectable":
			selectable_keys.append(String(key))
	selectable_keys.sort()
	return selectable_keys


func _on_tile_preview_pressed(coord_key: String) -> void:
	if active_event.is_empty():
		selected_coord_key = coord_key
		_refresh_view(message_label.text)


func _on_selected_tile_resolve_pressed() -> void:
	if selected_coord_key.is_empty():
		return

	var result := GameState.resolve_tile(selected_coord_key)
	if not result.get("ok", false):
		_refresh_view(String(result.get("message", "That tile could not be resolved.")))
		return

	match String(result.get("kind", "")):
		"event":
			active_event = result.duplicate(true)
			SaveService.persist()
			_refresh_view(String(result.get("message", "Choose an event option.")))
			return
		"utility":
			active_event = {}
			if GameState.has_pending_run_upgrade():
				SaveService.persist()
				get_tree().current_scene.show_run_upgrade()
				return
			if GameState.is_run_clear_ready():
				GameState.finish_run(true)
				SaveService.persist()
				get_tree().current_scene.show_result()
				return
			SaveService.persist()
			_refresh_view(String(result.get("message", "Utility tile resolved.")))
			return
		"combat":
			active_event = {}
			SaveService.persist()
			get_tree().current_scene.show_combat()
			return
		_:
			SaveService.persist()
			_refresh_view(String(result.get("message", "Action resolved.")))


func _on_event_choice_pressed(coord_key: String, choice_id: String) -> void:
	var result := GameState.choose_event(coord_key, choice_id)
	if not result.get("ok", false):
		_refresh_view(String(result.get("message", "Event choice failed.")))
		return

	active_event = {}
	if GameState.has_pending_run_upgrade():
		SaveService.persist()
		get_tree().current_scene.show_run_upgrade()
		return
	if GameState.is_run_clear_ready():
		GameState.finish_run(true)
		SaveService.persist()
		get_tree().current_scene.show_result()
		return

	SaveService.persist()
	_refresh_view(String(result.get("message", "Event resolved.")))


func _on_retreat_pressed() -> void:
	GameState.finish_run(false)
	SaveService.persist()
	get_tree().current_scene.show_result()


func _on_home_pressed() -> void:
	SaveService.persist()
	get_tree().current_scene.show_home()


func _tile_summary(tile_def: Dictionary, tile: Dictionary) -> String:
	return "State: %s | Ring %s | Threat %.2f | Rewards scale with tile type and current run danger." % [
		String(tile.get("state", "hidden")).capitalize(),
		tile.get("ring", 0),
		float(tile_def.get("base_threat", 1.0))
	]


func _action_button_text(state: String, resolver_mode: String) -> String:
	if state != "selectable":
		match state:
			"captured":
				return "Captured"
			"revealed":
				return "Reach Adjacent Tile First"
			_:
				return "Hidden"

	match resolver_mode:
		"event":
			return "Resolve Event"
		"utility":
			return "Secure Utility"
		_:
			return "Engage Combat"


func _describe_event_choice(choice: Dictionary) -> String:
	var segments: Array = []
	var cost: Dictionary = choice.get("cost", {})
	var reward: Dictionary = choice.get("reward", {})

	if cost.has("current_hp_percent"):
		segments.append("Lose %s%% HP" % int(round(float(cost["current_hp_percent"]) * 100.0)))
	if cost.has("gold_flat"):
		segments.append("Pay %s Gold" % int(cost["gold_flat"]))
	if cost.has("curse"):
		segments.append("Gain curse")

	if reward.has("attack_flat"):
		segments.append("+%s ATK" % int(reward["attack_flat"]))
	if reward.has("attack_percent"):
		segments.append("+%s%% ATK" % int(round(float(reward["attack_percent"]) * 100.0)))
	if reward.has("armor_flat"):
		segments.append("+%s Armor" % int(reward["armor_flat"]))
	if reward.has("attack_speed"):
		segments.append("+%s%% Attack Speed" % int(round(float(reward["attack_speed"]) * 100.0)))
	if reward.has("crit_rate"):
		segments.append("+%s%% Crit" % int(round(float(reward["crit_rate"]) * 100.0)))
	if reward.has("territory_power"):
		segments.append("+%s%% Territory Power" % int(round(float(reward["territory_power"]) * 100.0)))
	if reward.has("max_hp_flat"):
		segments.append("+%s Max HP" % int(reward["max_hp_flat"]))
	if reward.has("heal_flat"):
		segments.append("Heal %s" % int(reward["heal_flat"]))
	if reward.has("heal_percent"):
		segments.append("Heal %s%% HP" % int(round(float(reward["heal_percent"]) * 100.0)))
	if reward.has("luck"):
		segments.append("+%s Luck" % int(reward["luck"]))
	if reward.has("gold"):
		segments.append("+%s Gold" % int(reward["gold"]))
	if reward.has("xp"):
		segments.append("+%s XP" % int(reward["xp"]))
	if reward.has("essence_on_run_end"):
		segments.append("+%s Essence on end" % int(reward["essence_on_run_end"]))
	if reward.has("sigils_on_run_end"):
		segments.append("+%s Sigils on end" % int(reward["sigils_on_run_end"]))
	if reward.has("grant_skill"):
		segments.append("Skill: %s" % _format_special_name(reward["grant_skill"]))
	if reward.has("grant_trait"):
		segments.append("Trait: %s" % _format_special_name(reward["grant_trait"]))

	var danger_delta := int(choice.get("danger_delta", 0))
	if danger_delta != 0:
		var sign := "+" if danger_delta > 0 else ""
		segments.append("%s%s Danger" % [sign, danger_delta])

	if segments.is_empty():
		return "Resolve tile"
	return _join_segments(segments)


func _format_special_name(value: Variant) -> String:
	if value is Array:
		var names: Array = []
		for item in value:
			names.append(_pretty_id(String(item)))
		return ", ".join(names)
	return _pretty_id(String(value))


func _pretty_id(value: String) -> String:
	var parts := value.split("_")
	var title_parts: Array = []
	for part in parts:
		title_parts.append(String(part).capitalize())
	return " ".join(title_parts)


func _join_segments(segments: Array) -> String:
	var text := ""
	for index in range(segments.size()):
		if index > 0:
			text += ", "
		text += String(segments[index])
	return text
