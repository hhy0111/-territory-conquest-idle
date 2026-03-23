extends Control

const UISkin = preload("res://scripts/ui/ui_skin.gd")

var status_label: Label
var list_box: VBoxContainer
var pending_home_exit := false


func _ready() -> void:
	_connect_ad_signals()
	UISkin.install_screen_background(self, UISkin.screen_background("meta"))
	_build_ui()
	_refresh_view("Spend permanent resources on long-term doctrine upgrades.")


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

	var header_content := VBoxContainer.new()
	header_content.add_theme_constant_override("separation", 10)
	header.add_child(header_content)
	header_content.add_child(UISkin.section_title("Meta Upgrades", 36))

	status_label = UISkin.body_label("", UISkin.TEXT_SECONDARY, 18)
	header_content.add_child(status_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 16)
	scroll.add_child(list_box)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button.custom_minimum_size = Vector2(0, 74)
	UISkin.apply_button_style(back_button, "secondary")
	back_button.pressed.connect(_on_back_pressed)
	actions.add_child(back_button)

	var run_button := Button.new()
	run_button.text = "Start Run"
	run_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	run_button.custom_minimum_size = Vector2(0, 74)
	UISkin.apply_button_style(run_button, "primary")
	run_button.pressed.connect(_on_run_pressed)
	actions.add_child(run_button)


func _refresh_view(message: String) -> void:
	var profile := GameState.profile
	_set_status_message(message)

	for child in list_box.get_children():
		child.queue_free()

	var definitions: Dictionary = DataService.get_meta_upgrade_definitions()
	var grouped: Dictionary = _group_upgrades_by_tree(definitions)
	var tree_order := ["command", "logistics", "legacy"]

	for tree_id in tree_order:
		var entries: Array = grouped.get(tree_id, [])
		if entries.is_empty():
			continue

		list_box.add_child(_build_tree_section(tree_id, entries, profile))


func _build_tree_section(tree_id: String, entries: Array, profile: Dictionary) -> Control:
	var section := PanelContainer.new()
	UISkin.apply_panel_style(section, "secondary")

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	section.add_child(content)

	content.add_child(UISkin.section_title("%s Doctrine" % _pretty_id(tree_id), 28))

	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value
		content.add_child(_build_upgrade_card(entry, profile))

	return section


func _build_upgrade_card(definition: Dictionary, profile: Dictionary) -> Control:
	var card := PanelContainer.new()
	UISkin.apply_panel_style(card, "reward")

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	card.add_child(content)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	content.add_child(header_row)

	header_row.add_child(UISkin.make_badge(_pretty_id(String(definition.get("tree", "core"))), _tree_icon(String(definition.get("tree", "core"))), "stat"))

	var title := UISkin.section_title(String(definition.get("name", "Upgrade")), 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	var current_rank := int(profile.get("meta_upgrades", {}).get(String(definition.get("id", "")), 0))
	var max_rank := int(definition.get("max_rank", 1))
	header_row.add_child(UISkin.make_badge("Lv %s/%s" % [current_rank, max_rank], UISkin.icon_texture("relic")))

	content.add_child(UISkin.body_label(_build_meta_description(definition), UISkin.TEXT_SECONDARY, 17))

	var cost_row := HFlowContainer.new()
	cost_row.add_theme_constant_override("h_separation", 10)
	cost_row.add_theme_constant_override("v_separation", 10)
	content.add_child(cost_row)

	var next_essence_cost := int(definition.get("cost_essence", 0)) * (current_rank + 1)
	var next_sigil_cost := int(definition.get("cost_sigils", 0))
	if next_essence_cost > 0:
		cost_row.add_child(UISkin.make_badge("%s Essence" % next_essence_cost, UISkin.icon_texture("essence"), "currency"))
	if next_sigil_cost > 0:
		cost_row.add_child(UISkin.make_badge("%s Sigils" % next_sigil_cost, UISkin.icon_texture("sigil"), "currency"))

	var buy_button := Button.new()
	buy_button.text = "Purchased" if current_rank >= max_rank else "Purchase"
	buy_button.disabled = current_rank >= max_rank
	buy_button.custom_minimum_size = Vector2(0, 68)
	UISkin.apply_button_style(buy_button, "primary")
	buy_button.pressed.connect(_on_buy_pressed.bind(String(definition.get("id", ""))))
	content.add_child(buy_button)

	return card


func _profile_summary(profile: Dictionary) -> String:
	return "Essence %s | Sigils %s | Purchased Upgrades %s" % [
		profile.get("essence", 0),
		profile.get("sigils", 0),
		profile.get("meta_upgrades", {}).size()
	]


func _group_upgrades_by_tree(definitions: Dictionary) -> Dictionary:
	var grouped := {}
	var ids: Array = definitions.keys()
	ids.sort()
	for upgrade_value in ids:
		var upgrade_id := String(upgrade_value)
		var definition: Dictionary = definitions[upgrade_id]
		var tree_id := String(definition.get("tree", "core"))
		if not grouped.has(tree_id):
			grouped[tree_id] = []
		var entries: Array = grouped[tree_id]
		entries.append(definition)
		grouped[tree_id] = entries
	return grouped


func _on_buy_pressed(upgrade_id: String) -> void:
	var result: Dictionary = GameState.purchase_meta_upgrade(upgrade_id)
	if result.get("ok", false):
		SaveService.persist()
	_refresh_view(String(result.get("message", "No response.")))


func _on_back_pressed() -> void:
	if pending_home_exit:
		return

	var gate := GameState.begin_run_end_interstitial("home")
	if not gate.get("accepted", false):
		SaveService.persist()
		get_tree().current_scene.show_home()
		return

	pending_home_exit = true
	_set_status_message("Showing interstitial...")
	if not AdService.show_interstitial():
		pending_home_exit = false
		GameState.abandon_run_end_interstitial()
		SaveService.persist()
		get_tree().current_scene.show_home()


func _on_run_pressed() -> void:
	GameState.start_new_run()
	SaveService.persist()
	get_tree().current_scene.show_run()


func _set_status_message(message: String) -> void:
	status_label.text = "%s\n%s" % [_profile_summary(GameState.profile), message]


func _connect_ad_signals() -> void:
	if not AdService.interstitial_closed.is_connected(_on_interstitial_closed):
		AdService.interstitial_closed.connect(_on_interstitial_closed)
	if not AdService.interstitial_failed.is_connected(_on_interstitial_failed):
		AdService.interstitial_failed.connect(_on_interstitial_failed)


func _on_interstitial_closed(slot_key: String) -> void:
	if not pending_home_exit or slot_key != "interstitial_run_end":
		return

	pending_home_exit = false
	GameState.complete_run_end_interstitial()
	SaveService.persist()
	get_tree().current_scene.show_home()


func _on_interstitial_failed(slot_key: String, _reason: String) -> void:
	if not pending_home_exit or slot_key != "interstitial_run_end":
		return

	pending_home_exit = false
	GameState.abandon_run_end_interstitial()
	SaveService.persist()
	get_tree().current_scene.show_home()


func _build_meta_description(definition: Dictionary) -> String:
	var description := String(definition.get("description", ""))
	var effect_summary := _describe_effect(definition.get("effect", {}))
	if description.is_empty():
		return effect_summary
	if effect_summary.is_empty():
		return description
	return "%s | %s" % [description, effect_summary]


func _describe_effect(effect: Dictionary) -> String:
	var segments: Array = []
	if effect.has("base_attack_flat"):
		segments.append("+%s starting ATK" % int(effect["base_attack_flat"]))
	if effect.has("base_hp_flat"):
		segments.append("+%s starting HP" % int(effect["base_hp_flat"]))
	if effect.has("base_armor_flat"):
		segments.append("+%s starting Armor" % int(effect["base_armor_flat"]))
	if effect.has("base_crit_rate_flat"):
		segments.append("+%s%% starting Crit" % int(round(float(effect["base_crit_rate_flat"]) * 100.0)))
	if effect.has("starting_gold_flat"):
		segments.append("+%s starting Gold" % int(effect["starting_gold_flat"]))
	if effect.has("starting_luck_flat"):
		segments.append("+%s starting Luck" % int(effect["starting_luck_flat"]))
	if effect.has("essence_gain_percent"):
		segments.append("+%s%% Essence gain" % int(round(float(effect["essence_gain_percent"]) * 100.0)))
	if effect.has("heal_after_boss_percent"):
		segments.append("Heal %s%% after boss" % int(round(float(effect["heal_after_boss_percent"]) * 100.0)))
	if effect.has("boss_reward_essence_flat"):
		segments.append("+%s boss Essence" % int(effect["boss_reward_essence_flat"]))
	if effect.has("boss_reward_sigil_flat"):
		segments.append("+%s boss Sigil" % int(effect["boss_reward_sigil_flat"]))
	if effect.has("relic_offer_extra_choices"):
		segments.append("+%s relic choice" % int(effect["relic_offer_extra_choices"]))
	if effect.has("run_upgrade_offer_extra_choices"):
		segments.append("+%s run-upgrade choice" % int(effect["run_upgrade_offer_extra_choices"]))
	if effect.has("victory_sigils_flat"):
		segments.append("+%s victory Sigil" % int(effect["victory_sigils_flat"]))
	return ", ".join(segments)


func _pretty_id(value: String) -> String:
	var parts := value.split("_")
	var title_parts: Array = []
	for part in parts:
		title_parts.append(String(part).capitalize())
	return " ".join(title_parts)


func _tree_icon(tree_id: String) -> Texture2D:
	match tree_id:
		"command":
			return UISkin.icon_texture("attack")
		"logistics":
			return UISkin.icon_texture("gold")
		"legacy":
			return UISkin.icon_texture("relic")
		_:
			return UISkin.icon_texture("event")
