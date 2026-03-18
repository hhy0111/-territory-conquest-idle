extends RefCounted
class_name UISkin

const TEXT_PRIMARY := Color(0.95, 0.96, 0.98, 1.0)
const TEXT_SECONDARY := Color(0.78, 0.83, 0.9, 1.0)
const TEXT_MUTED := Color(0.64, 0.7, 0.79, 0.95)
const TEXT_ACCENT := Color(0.97, 0.86, 0.54, 1.0)
const PANEL_TINT := Color(0.14, 0.17, 0.22, 0.94)
const PANEL_TINT_ALT := Color(0.11, 0.14, 0.18, 0.9)
const OVERLAY_DARK := Color(0.03, 0.04, 0.06, 0.62)

const SCREEN_BACKGROUNDS := {
	"home": "res://assets/backgrounds/bg_main_menu.png",
	"run": "res://assets/backgrounds/bg_run_board.png",
	"combat": "res://assets/backgrounds/bg_boss_arena.png",
	"meta": "res://assets/backgrounds/bg_meta_hall.png",
	"result": "res://assets/backgrounds/bg_result_summary.png",
	"relic": "res://assets/backgrounds/bg_boss_arena.png",
	"run_upgrade": "res://assets/backgrounds/bg_run_board.png"
}

const HERO_TEXTURE := "res://assets/characters/hero_conqueror.png"

const TILE_TEXTURES := {
	"plains": "res://assets/tiles/tile_plains.png",
	"forest": "res://assets/tiles/tile_forest.png",
	"mine": "res://assets/tiles/tile_mine.png",
	"ruins": "res://assets/tiles/tile_vault.png",
	"shrine": "res://assets/tiles/tile_shrine.png",
	"watchtower": "res://assets/tiles/tile_fortress.png",
	"market": "res://assets/tiles/tile_market.png",
	"quarry": "res://assets/tiles/tile_mine.png",
	"barracks": "res://assets/tiles/tile_fortress.png",
	"fortress": "res://assets/tiles/tile_fortress.png",
	"sanctum": "res://assets/tiles/tile_vault.png"
}

const TILE_OVERLAYS := {
	"hidden": "res://assets/tiles/tile_hidden_fog.png",
	"captured": "res://assets/tiles/tile_overlay_captured.png",
	"selectable": "res://assets/tiles/tile_overlay_selectable.png",
	"locked": "res://assets/tiles/tile_overlay_locked.png",
	"path": "res://assets/tiles/tile_overlay_path_highlight.png",
	"boss": "res://assets/tiles/tile_overlay_boss_warning.png"
}

const EVENT_BACKGROUNDS := {
	"blood_shrine": "res://assets/backgrounds/event_bg_blood_shrine.png",
	"cursed_banner": "res://assets/backgrounds/event_bg_cursed_banner.png",
	"ruined_caravan": "res://assets/backgrounds/event_bg_ruined_caravan.png",
	"sealed_cache": "res://assets/backgrounds/event_bg_sealed_vault.png",
	"frontier_scribes": "res://assets/backgrounds/event_bg_scout_tower.png",
	"oath_stone": "res://assets/backgrounds/event_bg_mercenary_camp.png",
	"rift_tithe": "res://assets/backgrounds/event_bg_sealed_vault.png",
	"survivor_encampment": "res://assets/backgrounds/event_bg_mercenary_camp.png",
	"smuggler_contract": "res://assets/backgrounds/event_bg_ruined_caravan.png"
}

const ENEMY_TEXTURES := {
	"raider": "res://assets/characters/enemy_raider.png",
	"archer": "res://assets/characters/enemy_archer.png",
	"brute": "res://assets/characters/enemy_brute.png",
	"shaman": "res://assets/characters/enemy_shaman.png",
	"pikeman": "res://assets/characters/enemy_guard.png",
	"skirmisher": "res://assets/characters/enemy_assassin.png",
	"fanatic": "res://assets/characters/enemy_void_clone.png",
	"bombardier": "res://assets/characters/enemy_turret.png"
}

const BOSS_TEXTURES := {
	"border_warden": "res://assets/bosses/boss_border_warden.png",
	"root_colossus": "res://assets/bosses/boss_root_colossus.png",
	"iron_matriarch": "res://assets/bosses/boss_iron_matriarch.png",
	"rift_bishop": "res://assets/bosses/boss_rift_bishop.png",
	"crownless_king": "res://assets/bosses/boss_crownless_king.png"
}

const STATUS_ICONS := {
	"burn": "res://assets/icons/icon_risk.png",
	"weaken": "res://assets/icons/icon_attack.png",
	"sunder": "res://assets/icons/icon_armor.png",
	"guard": "res://assets/icons/icon_armor.png",
	"fury": "res://assets/icons/icon_attack.png",
	"fervor": "res://assets/icons/icon_territory_power.png"
}

const EFFECT_TEXTURES := {
	"impact": "res://assets/effects/fx_impact_burst.png",
	"slash": "res://assets/effects/fx_slash.png",
	"arrow": "res://assets/effects/fx_arrow_trail.png",
	"shell": "res://assets/effects/fx_cannon_shell.png",
	"heal": "res://assets/effects/fx_heal_ring.png",
	"buff": "res://assets/effects/fx_buff_up.png",
	"debuff": "res://assets/effects/fx_debuff_down.png",
	"phase": "res://assets/effects/fx_boss_enrage_aura.png",
	"void": "res://assets/effects/fx_void_bolt.png",
	"danger": "res://assets/effects/fx_danger_telegraph_circle.png",
	"levelup": "res://assets/effects/fx_levelup_burst.png",
	"reward": "res://assets/effects/fx_reward_sparkle.png",
	"capture": "res://assets/effects/fx_tile_capture_wave.png",
	"portal": "res://assets/effects/fx_portal_swirl.png"
}

const ICON_TEXTURES := {
	"attack": "res://assets/icons/icon_attack.png",
	"attack_speed": "res://assets/icons/icon_attack_speed.png",
	"armor": "res://assets/icons/icon_armor.png",
	"boss": "res://assets/icons/icon_boss.png",
	"chest": "res://assets/icons/icon_chest.png",
	"crit": "res://assets/icons/icon_crit.png",
	"curse": "res://assets/icons/icon_curse.png",
	"essence": "res://assets/icons/icon_essence.png",
	"event": "res://assets/icons/icon_event.png",
	"gold": "res://assets/icons/icon_gold.png",
	"heal": "res://assets/icons/icon_heal.png",
	"hp": "res://assets/icons/icon_hp.png",
	"lifesteal": "res://assets/icons/icon_lifesteal.png",
	"luck": "res://assets/icons/icon_luck.png",
	"portal": "res://assets/icons/icon_portal.png",
	"range": "res://assets/icons/icon_range.png",
	"relic": "res://assets/icons/icon_relic.png",
	"reroll": "res://assets/icons/icon_reroll.png",
	"reveal": "res://assets/icons/icon_reveal.png",
	"risk": "res://assets/icons/icon_risk.png",
	"shop": "res://assets/icons/icon_shop.png",
	"sigil": "res://assets/icons/icon_sigil.png",
	"territory_power": "res://assets/icons/icon_territory_power.png"
}

static var texture_cache: Dictionary = {}


static func full_rect(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func texture(path: String) -> Texture2D:
	if texture_cache.has(path):
		return texture_cache[path]

	var loaded_texture: Texture2D = null
	if path.get_extension().to_lower() == "png":
		var image := Image.new()
		var error := image.load(ProjectSettings.globalize_path(path))
		if error == OK:
			loaded_texture = ImageTexture.create_from_image(image)
	else:
		var resource: Resource = load(path)
		loaded_texture = resource as Texture2D

	texture_cache[path] = loaded_texture
	return loaded_texture


static func screen_background(screen_id: String) -> Texture2D:
	var path := String(SCREEN_BACKGROUNDS.get(screen_id, SCREEN_BACKGROUNDS["run"]))
	return texture(path)


static func install_screen_background(host: Control, background_texture: Texture2D, overlay_color: Color = OVERLAY_DARK) -> void:
	var background := TextureRect.new()
	background.name = "BackgroundArt"
	background.texture = background_texture
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect(background)
	host.add_child(background)
	host.move_child(background, 0)

	var overlay := ColorRect.new()
	overlay.name = "BackgroundOverlay"
	overlay.color = overlay_color
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect(overlay)
	host.add_child(overlay)
	host.move_child(overlay, 1)


static func make_screen_margin(left: int = 28, top: int = 36, right: int = 28, bottom: int = 28) -> MarginContainer:
	var margin := MarginContainer.new()
	full_rect(margin)
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


static func apply_button_style(button: Button, variant: String = "primary") -> void:
	button.add_theme_stylebox_override("normal", _button_style(variant, false, false))
	button.add_theme_stylebox_override("hover", _button_style(variant, false, true))
	button.add_theme_stylebox_override("pressed", _button_style(variant, true, false))
	button.add_theme_stylebox_override("disabled", _button_style(variant, false, false))
	button.add_theme_stylebox_override("focus", _button_style(variant, false, true))
	button.add_theme_color_override("font_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	button.add_theme_color_override("font_disabled_color", Color(0.6, 0.65, 0.72, 0.8))
	button.add_theme_font_size_override("font_size", 22)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


static func apply_panel_style(panel: PanelContainer, variant: String = "primary") -> void:
	panel.add_theme_stylebox_override("panel", _panel_style(variant))


static func apply_progress_style(bar: ProgressBar) -> void:
	bar.add_theme_stylebox_override("background", _texture_style("res://assets/ui/ui_progress_frame.png", 128))
	bar.add_theme_stylebox_override("fill", _texture_style("res://assets/ui/ui_progress_fill.png", 128))


static func make_icon(texture_or_path: Variant, size: int = 28, tint: Color = Color(1.0, 1.0, 1.0, 1.0)) -> TextureRect:
	var icon := TextureRect.new()
	var icon_texture: Texture2D = texture_or_path as Texture2D
	if icon_texture == null and texture_or_path is String:
		icon_texture = texture(String(texture_or_path))
	icon.texture = icon_texture
	icon.custom_minimum_size = Vector2(size, size)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = tint
	return icon


static func make_badge(text: String, icon_texture: Texture2D = null, variant: String = "stat", font_size: int = 18) -> PanelContainer:
	var panel := PanelContainer.new()
	if variant == "currency":
		panel.add_theme_stylebox_override("panel", _texture_style("res://assets/ui/ui_currency_pill.png", 128))
	else:
		panel.add_theme_stylebox_override("panel", _texture_style("res://assets/ui/ui_stat_chip.png", 128))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	if icon_texture != null:
		row.add_child(make_icon(icon_texture, 24))

	var label := Label.new()
	label.text = text
	label.modulate = TEXT_PRIMARY
	label.add_theme_font_size_override("font_size", font_size)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	return panel


static func make_portrait(texture_or_path: Variant, min_size: Vector2, tint: Color = Color(1.0, 1.0, 1.0, 1.0)) -> TextureRect:
	var portrait := TextureRect.new()
	var portrait_texture: Texture2D = texture_or_path as Texture2D
	if portrait_texture == null and texture_or_path is String:
		portrait_texture = texture(String(texture_or_path))
	portrait.texture = portrait_texture
	portrait.custom_minimum_size = min_size
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.modulate = tint
	return portrait


static func section_title(text: String, size: int = 24) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = TEXT_PRIMARY
	label.add_theme_font_size_override("font_size", size)
	return label


static func body_label(text: String, accent: Color = TEXT_SECONDARY, size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.modulate = accent
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	return label


static func tile_texture(tile_type: String) -> Texture2D:
	var path := String(TILE_TEXTURES.get(tile_type, "res://assets/tiles/tile_plains.png"))
	return texture(path)


static func tile_overlay_texture(overlay_id: String) -> Texture2D:
	var path := String(TILE_OVERLAYS.get(overlay_id, ""))
	if path.is_empty():
		return null
	return texture(path)


static func event_background_texture(event_id: String) -> Texture2D:
	var path := String(EVENT_BACKGROUNDS.get(event_id, SCREEN_BACKGROUNDS["run"]))
	return texture(path)


static func hero_texture() -> Texture2D:
	return texture(HERO_TEXTURE)


static func enemy_texture(enemy_id: String) -> Texture2D:
	var path := String(ENEMY_TEXTURES.get(enemy_id, "res://assets/characters/enemy_guard.png"))
	return texture(path)


static func boss_texture(boss_id: String) -> Texture2D:
	var path := String(BOSS_TEXTURES.get(boss_id, "res://assets/bosses/boss_border_warden.png"))
	return texture(path)


static func icon_texture(icon_id: String) -> Texture2D:
	var path := String(ICON_TEXTURES.get(icon_id, "res://assets/icons/icon_event.png"))
	return texture(path)


static func status_icon_texture(status_id: String) -> Texture2D:
	var path := String(STATUS_ICONS.get(status_id, "res://assets/icons/icon_curse.png"))
	return texture(path)


static func combat_effect_texture(event: Dictionary) -> Texture2D:
	var kind := String(event.get("kind", "attack"))
	if kind == "phase_change":
		return texture(EFFECT_TEXTURES["phase"])
	if kind == "trait_trigger":
		return texture(EFFECT_TEXTURES["buff"])
	if kind == "status_tick":
		match String(event.get("status_id", "")):
			"burn":
				return texture(EFFECT_TEXTURES["debuff"])
			"guard":
				return texture(EFFECT_TEXTURES["buff"])
			_:
				return texture(EFFECT_TEXTURES["debuff"])

	var skill_label := String(event.get("skill_label", "")).to_lower()
	if skill_label.contains("volley"):
		return texture(EFFECT_TEXTURES["arrow"])
	if skill_label.contains("mortar"):
		return texture(EFFECT_TEXTURES["shell"])
	if skill_label.contains("hex") or skill_label.contains("void"):
		return texture(EFFECT_TEXTURES["void"])
	if skill_label.contains("slam") or skill_label.contains("strike") or skill_label.contains("shrapnel"):
		return texture(EFFECT_TEXTURES["slash"])
	return texture(EFFECT_TEXTURES["impact"])


static func tile_mode_icon(tile_type: String, resolver_mode: String) -> Texture2D:
	match resolver_mode:
		"event":
			return icon_texture("event")
		"utility":
			match tile_type:
				"market":
					return icon_texture("shop")
				"watchtower":
					return icon_texture("reveal")
				_:
					return icon_texture("heal")
		_:
			match tile_type:
				"mine", "quarry":
					return icon_texture("gold")
				"fortress", "barracks":
					return icon_texture("armor")
				"shrine", "sanctum":
					return icon_texture("curse")
				_:
					return icon_texture("risk")


static func dominant_effect_icon(effect: Dictionary) -> Texture2D:
	if effect.has("attack_flat") or effect.has("attack_percent"):
		return icon_texture("attack")
	if effect.has("armor_flat"):
		return icon_texture("armor")
	if effect.has("attack_speed"):
		return icon_texture("attack_speed")
	if effect.has("crit_rate"):
		return icon_texture("crit")
	if effect.has("heal_flat") or effect.has("heal_percent") or effect.has("max_hp_flat"):
		return icon_texture("heal")
	if effect.has("gold") or effect.has("gold_flat"):
		return icon_texture("gold")
	if effect.has("essence_on_run_end") or effect.has("essence_on_run_end_flat"):
		return icon_texture("essence")
	if effect.has("sigils_on_run_end") or effect.has("sigils_on_run_end_flat"):
		return icon_texture("sigil")
	if effect.has("territory_power"):
		return icon_texture("territory_power")
	if effect.has("grant_skill"):
		return icon_texture("range")
	if effect.has("grant_trait"):
		return icon_texture("relic")
	return icon_texture("event")


static func rarity_color(rarity: String) -> Color:
	match rarity:
		"rare":
			return Color(0.47, 0.75, 0.98, 1.0)
		"epic":
			return Color(0.88, 0.67, 0.29, 1.0)
		_:
			return TEXT_SECONDARY


static func _button_style(variant: String, pressed: bool, hovered: bool) -> StyleBox:
	var path := "res://assets/ui/ui_button_primary.png"
	if variant == "secondary":
		path = "res://assets/ui/ui_button_secondary.png"
	if pressed:
		path = "res://assets/ui/ui_button_primary_pressed.png" if variant == "primary" else "res://assets/ui/ui_button_secondary_pressed.png"

	var style := _texture_style(path, 160, Color(1.0, 1.0, 1.0, 1.0))
	if style is StyleBoxTexture and hovered:
		var texture_style: StyleBoxTexture = style
		texture_style.modulate_color = Color(1.06, 1.06, 1.06, 1.0)
	return style


static func _panel_style(variant: String) -> StyleBox:
	match variant:
		"secondary":
			return _texture_style("res://assets/ui/ui_panel_secondary.png", 128, PANEL_TINT_ALT)
		"popup":
			return _texture_style("res://assets/ui/ui_popup_frame.png", 128, PANEL_TINT)
		"reward":
			return _texture_style("res://assets/ui/ui_reward_card.png", 128, Color(0.18, 0.2, 0.24, 0.96))
		"tile_preview":
			return _texture_style("res://assets/ui/ui_tile_preview_frame.png", 128, Color(0.14, 0.16, 0.19, 0.95))
		_:
			return _texture_style("res://assets/ui/ui_panel_primary.png", 128, PANEL_TINT)


static func _texture_style(path: String, margin: int, tint: Color = Color(1.0, 1.0, 1.0, 1.0)) -> StyleBox:
	var style := StyleBoxTexture.new()
	style.texture = texture(path)
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.modulate_color = tint
	return style
