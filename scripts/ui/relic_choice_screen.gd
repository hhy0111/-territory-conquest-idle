extends Control

const UISkin = preload("res://scripts/ui/ui_skin.gd")

var summary_label: Label
var message_label: Label
var choice_list: VBoxContainer
var reroll_button: Button
var pending_rewarded_reroll := false


func _ready() -> void:
	if not GameState.has_pending_relic_choice():
		if GameState.has_pending_run_upgrade():
			get_tree().current_scene.show_run_upgrade()
			return
		get_tree().current_scene.show_run()
		return

	_connect_ad_signals()
	UISkin.install_screen_background(self, UISkin.screen_background("relic"), Color(0.03, 0.04, 0.06, 0.72))
	_build_ui()
	_refresh_view("Choose a relic reward.")


func _build_ui() -> void:
	var root := UISkin.make_screen_margin(26, 30, 26, 24)
	add_child(root)

	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 14)
	root.add_child(column)

	var header := PanelContainer.new()
	UISkin.apply_panel_style(header, "popup")
	column.add_child(header)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 14)
	header.add_child(header_row)

	var portrait_frame := PanelContainer.new()
	UISkin.apply_panel_style(portrait_frame, "secondary")
	portrait_frame.custom_minimum_size = Vector2(180, 180)
	header_row.add_child(portrait_frame)

	var portrait := UISkin.make_portrait(UISkin.hero_texture(), Vector2(150, 150))
	portrait_frame.add_child(portrait)

	var header_copy := VBoxContainer.new()
	header_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_copy.add_theme_constant_override("separation", 8)
	header_row.add_child(header_copy)

	header_copy.add_child(UISkin.section_title("Relic Selection", 34))

	summary_label = UISkin.body_label("", UISkin.TEXT_SECONDARY, 18)
	header_copy.add_child(summary_label)

	message_label = UISkin.body_label("", UISkin.TEXT_ACCENT, 18)
	header_copy.add_child(message_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	choice_list = VBoxContainer.new()
	choice_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_list.add_theme_constant_override("separation", 14)
	scroll.add_child(choice_list)

	reroll_button = Button.new()
	reroll_button.custom_minimum_size = Vector2(0, 70)
	UISkin.apply_button_style(reroll_button, "secondary")
	reroll_button.pressed.connect(_on_reroll_pressed)
	column.add_child(reroll_button)


func _refresh_view(message: String) -> void:
	var choice_state: Dictionary = GameState.get_pending_relic_choice()
	if choice_state.is_empty():
		get_tree().current_scene.show_run()
		return

	var relic_defs: Dictionary = DataService.get_relic_definitions()
	var relic_ids: Array = choice_state.get("choices", [])
	summary_label.text = "Pick %s relic(s). Current relics: %s | Bosses defeated: %s" % [
		choice_state.get("picks_remaining", 1),
		GameState.active_run.get("relics", []).size(),
		GameState.active_run.get("bosses_defeated", 0)
	]
	message_label.text = message
	_refresh_reroll_button()

	for child in choice_list.get_children():
		child.queue_free()

	for relic_value in relic_ids:
		var relic_id := String(relic_value)
		var relic_def: Dictionary = relic_defs.get(relic_id, {})
		if relic_def.is_empty():
			continue
		choice_list.add_child(_build_relic_card(relic_id, relic_def))


func _build_relic_card(relic_id: String, relic_def: Dictionary) -> Control:
	var card := PanelContainer.new()
	UISkin.apply_panel_style(card, "reward")

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)

	var badge_row := HFlowContainer.new()
	badge_row.add_theme_constant_override("h_separation", 10)
	badge_row.add_theme_constant_override("v_separation", 10)
	content.add_child(badge_row)
	badge_row.add_child(UISkin.make_badge(String(relic_def.get("rarity", "common")).capitalize(), UISkin.icon_texture("relic")))
	badge_row.add_child(UISkin.make_badge("Relic", UISkin.icon_texture("chest")))

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 10)
	content.add_child(title_row)
	title_row.add_child(UISkin.make_icon(UISkin.dominant_effect_icon(relic_def.get("effect", {})), 34, UISkin.rarity_color(String(relic_def.get("rarity", "common")))))

	var title := UISkin.section_title(String(relic_def.get("name", relic_id)), 26)
	title.modulate = UISkin.rarity_color(String(relic_def.get("rarity", "common")))
	title_row.add_child(title)

	content.add_child(UISkin.body_label(_describe_relic_effect(relic_def.get("effect", {})), UISkin.TEXT_SECONDARY, 18))

	var pick_button := Button.new()
	pick_button.text = "Take %s" % String(relic_def.get("name", relic_id))
	pick_button.custom_minimum_size = Vector2(0, 74)
	UISkin.apply_button_style(pick_button, "primary")
	pick_button.pressed.connect(_on_relic_pressed.bind(relic_id))
	content.add_child(pick_button)

	return card


func _on_relic_pressed(relic_id: String) -> void:
	var result: Dictionary = GameState.choose_relic(relic_id)
	if not result.get("ok", false):
		_refresh_view(String(result.get("message", "Relic selection failed.")))
		return

	SaveService.persist()
	if result.get("has_more", false):
		_refresh_view(String(result.get("message", "Relic acquired.")))
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


func _on_reroll_pressed() -> void:
	if pending_rewarded_reroll:
		return
	if not AdService.is_rewarded_ready():
		_refresh_view("Rewarded reroll is not ready.")
		return
	pending_rewarded_reroll = true
	_refresh_view("Opening rewarded reroll...")
	if not AdService.show_rewarded("rewarded_bonus_reroll"):
		pending_rewarded_reroll = false
		_refresh_view("Rewarded reroll could not be shown.")
		return


func _describe_relic_effect(effect: Dictionary) -> String:
	var segments: Array = []

	if effect.has("attack_flat"):
		segments.append("+%s ATK" % int(effect["attack_flat"]))
	if effect.has("armor_flat"):
		segments.append("+%s Armor" % int(effect["armor_flat"]))
	if effect.has("attack_speed"):
		segments.append("+%s%% Attack Speed" % int(round(float(effect["attack_speed"]) * 100.0)))
	if effect.has("crit_rate"):
		segments.append("+%s%% Crit" % int(round(float(effect["crit_rate"]) * 100.0)))
	if effect.has("lifesteal"):
		segments.append("+%s%% Lifesteal" % int(round(float(effect["lifesteal"]) * 100.0)))
	if effect.has("territory_power"):
		segments.append("+%s%% Territory Power" % int(round(float(effect["territory_power"]) * 100.0)))
	if effect.has("luck"):
		segments.append("+%s Luck" % int(effect["luck"]))
	if effect.has("grant_skill"):
		segments.append("Skill: %s" % _format_special_name(effect["grant_skill"]))
	if effect.has("grant_trait"):
		segments.append("Trait: %s" % _format_special_name(effect["grant_trait"]))

	return _join_segments(segments)


func _join_segments(segments: Array) -> String:
	var text := ""
	for index in range(segments.size()):
		if index > 0:
			text += ", "
		text += String(segments[index])
	return text


func _format_special_name(value: Variant) -> String:
	if value is Array:
		var names: Array = []
		for item in value:
			names.append(String(item).replace("_", " ").capitalize())
		return ", ".join(names)
	return String(value).replace("_", " ").capitalize()


func _refresh_reroll_button() -> void:
	if reroll_button == null:
		return

	var level := int(GameState.active_run.get("level", 1))
	var ad_state: Dictionary = GameState.active_run.get("ad_state", {})
	var reroll_used := bool(ad_state.get("rewarded_bonus_reroll_used", false))
	var reroll_available := GameState.can_use_rewarded_reroll() and AdService.is_rewarded_ready()

	if pending_rewarded_reroll:
		reroll_button.text = "Rewarded Reroll In Progress"
	elif reroll_used:
		reroll_button.text = "Rewarded Reroll Used"
	elif level < 3:
		reroll_button.text = "Rewarded Reroll Unlocks at Level 3"
	elif not AdService.is_rewarded_ready():
		reroll_button.text = "Rewarded Reroll Unavailable"
	else:
		reroll_button.text = "Watch Ad: Reroll Relics"

	reroll_button.disabled = pending_rewarded_reroll or not reroll_available


func _connect_ad_signals() -> void:
	if not AdService.rewarded_completed.is_connected(_on_rewarded_completed):
		AdService.rewarded_completed.connect(_on_rewarded_completed)
	if not AdService.rewarded_failed.is_connected(_on_rewarded_failed):
		AdService.rewarded_failed.connect(_on_rewarded_failed)


func _on_rewarded_completed(slot_key: String) -> void:
	if not pending_rewarded_reroll or slot_key != "rewarded_bonus_reroll":
		return

	pending_rewarded_reroll = false
	var result := GameState.use_rewarded_reroll()
	if not result.get("ok", false):
		_refresh_view(String(result.get("message", "Rewarded reroll failed.")))
		return

	SaveService.persist()
	_refresh_view(String(result.get("message", "Rerolled relic choices.")))


func _on_rewarded_failed(slot_key: String, _reason: String) -> void:
	if not pending_rewarded_reroll or slot_key != "rewarded_bonus_reroll":
		return

	pending_rewarded_reroll = false
	_refresh_view("Rewarded reroll could not be completed.")
