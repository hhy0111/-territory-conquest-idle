from __future__ import annotations

import argparse
import shutil
from collections import Counter, defaultdict, deque
from pathlib import Path

from PIL import Image


CHAT = "ChatGPT Image 2026년 3월 18일 오전 "


MAPS = [
    {"target": "assets/tiles/tile_plains.png", "source": f"{CHAT}10_25_11.png"},
    {"target": "assets/tiles/tile_forest.png", "source": f"{CHAT}10_25_13.png"},
    {"target": "assets/tiles/tile_mine.png", "source": f"{CHAT}10_25_15.png"},
    {"target": "assets/tiles/tile_shrine.png", "source": f"{CHAT}10_25_17.png"},
    {"target": "assets/tiles/tile_fortress.png", "source": f"{CHAT}10_25_19.png"},
    {"target": "assets/tiles/tile_market.png", "source": f"{CHAT}10_25_23.png"},
    {"target": "assets/tiles/tile_swamp.png", "source": f"{CHAT}10_25_26.png"},
    {"target": "assets/tiles/tile_vault.png", "source": f"{CHAT}10_25_27.png"},
    {"target": "assets/tiles/tile_portal.png", "source": f"{CHAT}10_25_30.png"},
    {"target": "assets/tiles/tile_boss_gate.png", "source": f"{CHAT}10_25_32.png"},
    {"target": "assets/tiles/tile_hidden_fog.png", "source": f"{CHAT}10_25_36.png", "padding": 0.02},
    {"target": "assets/tiles/tile_overlay_selectable.png", "source": f"{CHAT}10_25_39.png", "padding": 0.04},
    {"target": "assets/tiles/tile_overlay_captured.png", "source": f"{CHAT}10_25_41.png", "padding": 0.04},
    {"target": "assets/tiles/tile_overlay_locked.png", "source": f"{CHAT}10_25_44.png", "padding": 0.04},
    {"target": "assets/tiles/tile_overlay_boss_warning.png", "source": f"{CHAT}10_25_46.png", "padding": 0.04},
    {"target": "assets/tiles/tile_overlay_path_highlight.png", "source": f"{CHAT}10_25_50.png", "padding": 0.06},
    {"target": "assets/characters/hero_conqueror.png", "source": f"{CHAT}10_25_52.png", "padding": 0.10},
    {"target": "assets/characters/enemy_raider.png", "source": f"{CHAT}10_25_54.png", "padding": 0.10},
    {"target": "assets/characters/enemy_archer.png", "source": f"{CHAT}10_25_57.png", "padding": 0.10},
    {"target": "assets/characters/enemy_brute.png", "source": f"{CHAT}10_25_59.png", "padding": 0.08},
    {"target": "assets/characters/enemy_shaman.png", "source": f"{CHAT}10_26_05.png", "padding": 0.08},
    {"target": "assets/characters/enemy_assassin.png", "source": f"{CHAT}10_26_07.png", "padding": 0.10},
    {"target": "assets/characters/enemy_turret.png", "source": f"{CHAT}10_26_09.png", "padding": 0.08},
    {"target": "assets/characters/enemy_guard.png", "source": f"{CHAT}10_26_12.png", "padding": 0.10},
    {"target": "assets/characters/enemy_seed_pod.png", "source": f"{CHAT}10_26_14.png", "padding": 0.10},
    {"target": "assets/characters/enemy_drone.png", "source": f"{CHAT}10_26_24.png", "padding": 0.10},
    {"target": "assets/characters/enemy_void_clone.png", "source": f"{CHAT}10_26_27.png", "padding": 0.08},
    {"target": "assets/bosses/boss_border_warden.png", "source": f"{CHAT}10_26_29.png", "padding": 0.06},
    {"target": "assets/bosses/boss_root_colossus.png", "source": f"{CHAT}10_26_30.png", "padding": 0.06},
    {"target": "assets/bosses/boss_iron_matriarch.png", "source": f"{CHAT}10_26_33.png", "padding": 0.05},
    {"target": "assets/bosses/boss_rift_bishop.png", "source": f"{CHAT}10_26_37.png", "padding": 0.05},
    {"target": "assets/bosses/boss_crownless_king.png", "source": f"{CHAT}10_26_42.png", "padding": 0.05},
    {"target": "assets/ui/ui_panel_primary.png", "source": f"{CHAT}10_26_44.png", "padding": 0.00},
    {"target": "assets/ui/ui_panel_secondary.png", "source": f"{CHAT}10_26_46.png", "padding": 0.00},
    {"target": "assets/ui/ui_button_primary.png", "source": f"{CHAT}10_26_49.png", "padding": 0.06},
    {"target": "assets/ui/ui_button_secondary.png", "source": f"{CHAT}10_26_54.png", "padding": 0.06},
    {"target": "assets/ui/ui_progress_fill.png", "source": f"{CHAT}10_26_56.png", "padding": 0.08},
    {"target": "assets/ui/ui_progress_frame.png", "source": f"{CHAT}10_26_59.png", "padding": 0.06},
    {"target": "assets/ui/ui_reward_card.png", "source": f"{CHAT}10_27_01.png", "padding": 0.05},
    {"target": "assets/ui/ui_popup_frame.png", "source": f"{CHAT}10_27_03.png", "padding": 0.00},
    {"target": "assets/ui/ui_button_primary_pressed.png", "source": f"{CHAT}10_27_07.png", "padding": 0.08},
    {
        "target": "assets/ui/ui_button_secondary_pressed.png",
        "source": f"{CHAT}10_27_15.png",
        "padding": 0.08,
        "placeholder": "Pressed-state placeholder from ornate plaque.",
    },
    {
        "target": "assets/ui/ui_tab_button.png",
        "source": f"{CHAT}10_27_18.png",
        "padding": 0.08,
        "placeholder": "Generic slim tab placeholder.",
    },
    {"target": "assets/ui/ui_toggle_on.png", "source": f"{CHAT}10_27_20.png", "padding": 0.10},
    {"target": "assets/ui/ui_toggle_off.png", "source": f"{CHAT}10_27_22.png", "padding": 0.10},
    {
        "target": "assets/ui/ui_currency_pill.png",
        "source": f"{CHAT}10_27_18.png",
        "padding": 0.08,
        "placeholder": "Reused slim tab art as currency pill.",
    },
    {
        "target": "assets/ui/ui_stat_chip.png",
        "source": f"{CHAT}10_27_15.png",
        "padding": 0.08,
        "placeholder": "Reused plaque art as stat chip.",
    },
    {
        "target": "assets/ui/ui_tile_preview_frame.png",
        "source": f"{CHAT}10_26_44.png",
        "padding": 0.00,
        "placeholder": "Reused primary panel frame as tile preview frame.",
    },
    {"target": "assets/effects/fx_slash.png", "source": f"{CHAT}10_38_03.png", "padding": 0.10},
    {"target": "assets/effects/fx_arrow_trail.png", "source": f"{CHAT}10_38_32.png", "padding": 0.10},
    {"target": "assets/effects/fx_impact_burst.png", "source": f"{CHAT}10_38_35.png", "padding": 0.08},
    {"target": "assets/effects/fx_crit_flash.png", "source": f"{CHAT}10_38_37.png", "padding": 0.08},
    {"target": "assets/effects/fx_heal_ring.png", "source": f"{CHAT}10_38_39.png", "padding": 0.06},
    {"target": "assets/effects/fx_buff_up.png", "source": f"{CHAT}10_43_08.png", "padding": 0.08},
    {"target": "assets/effects/fx_debuff_down.png", "source": f"{CHAT}10_43_49.png", "padding": 0.08},
    {"target": "assets/effects/fx_levelup_burst.png", "source": f"{CHAT}10_43_52.png", "padding": 0.08},
    {"target": "assets/effects/fx_tile_capture_wave.png", "source": f"{CHAT}10_43_55.png", "padding": 0.06},
    {"target": "assets/effects/fx_portal_swirl.png", "source": f"{CHAT}10_43_58.png", "padding": 0.06},
    {"target": "assets/effects/fx_root_spike.png", "source": f"{CHAT}10_47_08.png", "padding": 0.08},
    {"target": "assets/effects/fx_cannon_shell.png", "source": f"{CHAT}10_47_15.png", "padding": 0.10},
    {"target": "assets/effects/fx_void_bolt.png", "source": f"{CHAT}10_47_17.png", "padding": 0.10},
    {"target": "assets/effects/fx_poison_cloud.png", "source": f"{CHAT}10_47_22.png", "padding": 0.08},
    {"target": "assets/effects/fx_shield_pulse.png", "source": f"{CHAT}10_47_27.png", "padding": 0.06},
    {"target": "assets/effects/fx_danger_telegraph_circle.png", "source": f"{CHAT}10_52_04.png", "padding": 0.06},
    {"target": "assets/effects/fx_dash_smear.png", "source": f"{CHAT}10_52_07.png", "padding": 0.08},
    {"target": "assets/effects/fx_death_smoke.png", "source": f"{CHAT}10_52_12.png", "padding": 0.06},
    {"target": "assets/effects/fx_reward_sparkle.png", "source": f"{CHAT}10_52_15.png", "padding": 0.08},
    {"target": "assets/effects/fx_boss_enrage_aura.png", "source": f"{CHAT}10_55_57.png", "padding": 0.04},
    {"target": "assets/icons/icon_hp.png", "source": f"{CHAT}11_01_11.png", "padding": 0.12},
    {"target": "assets/icons/icon_attack.png", "source": f"{CHAT}11_01_19.png", "padding": 0.12},
    {"target": "assets/icons/icon_attack_speed.png", "source": f"{CHAT}11_05_22.png", "padding": 0.12},
    {"target": "assets/icons/icon_armor.png", "source": f"{CHAT}11_05_43.png", "padding": 0.12},
    {"target": "assets/icons/icon_crit.png", "source": f"{CHAT}11_05_45.png", "padding": 0.12},
    {"target": "assets/icons/icon_lifesteal.png", "source": f"{CHAT}11_05_48.png", "padding": 0.12},
    {"target": "assets/icons/icon_luck.png", "source": "Gemini_Generated_Image_ybprtiybprtiybpr.png", "padding": 0.12},
    {"target": "assets/icons/icon_risk.png", "source": "Gemini_Generated_Image_1anfiy1anfiy1anf.png", "padding": 0.12},
    {"target": "assets/icons/icon_gold.png", "source": "Gemini_Generated_Image_xbv7fexbv7fexbv7.png", "padding": 0.12},
    {"target": "assets/icons/icon_essence.png", "source": "Gemini_Generated_Image_l964til964til964.png", "padding": 0.12},
    {"target": "assets/icons/icon_sigil.png", "source": "Gemini_Generated_Image_ei8hd3ei8hd3ei8h.png", "padding": 0.12},
    {"target": "assets/icons/icon_boss.png", "source": "Gemini_Generated_Image_y8calyy8calyy8ca.png", "padding": 0.12},
    {"target": "assets/icons/icon_relic.png", "source": "Gemini_Generated_Image_6soqc56soqc56soq.png", "padding": 0.12},
    {"target": "assets/icons/icon_curse.png", "source": "Gemini_Generated_Image_avbgayavbgayavbg.png", "padding": 0.12},
    {"target": "assets/icons/icon_heal.png", "source": "Gemini_Generated_Image_26aofp26aofp26ao.png", "padding": 0.12},
    {"target": "assets/icons/icon_shop.png", "source": "Gemini_Generated_Image_qhpg1fqhpg1fqhpg.png", "padding": 0.12},
    {"target": "assets/icons/icon_reroll.png", "source": "Gemini_Generated_Image_kxephdkxephdkxep.png", "padding": 0.12},
    {"target": "assets/icons/icon_reveal.png", "source": "Gemini_Generated_Image_ejp5gejp5gejp5ge.png", "padding": 0.12},
    {"target": "assets/icons/icon_revive.png", "source": "Gemini_Generated_Image_v0fo4av0fo4av0fo.png", "padding": 0.12},
    {"target": "assets/icons/icon_chest.png", "source": "Gemini_Generated_Image_rfdcy8rfdcy8rfdc.png", "padding": 0.12},
    {"target": "assets/icons/icon_portal.png", "source": "Gemini_Generated_Image_lmhaomlmhaomlmha.png", "padding": 0.12},
    {"target": "assets/icons/icon_event.png", "source": "fe8a674a-29e6-42f4-b38e-3085e808a8c8.jpg", "padding": 0.12, "threshold": 34},
    {
        "target": "assets/icons/icon_range.png",
        "source": "02fadf37-3998-46d9-a869-1c603ac15895.jpg",
        "padding": 0.12,
        "threshold": 38,
        "placeholder": "Cleaned from JPG source with baked checker background.",
    },
    {"target": "assets/icons/icon_move_speed.png", "source": "f3eb4720-b620-4f17-93e3-3f16032034ea.jpg", "padding": 0.12},
    {"target": "assets/icons/icon_corruption_resist.png", "source": "fa48add1-2b38-4658-a13d-045c3c4d75b2.jpg", "padding": 0.12},
    {
        "target": "assets/icons/icon_territory_power.png",
        "source": "e52686c0-6a49-4bbf-9ca1-c1de60e0117e.jpg",
        "padding": 0.12,
        "threshold": 38,
        "placeholder": "Cleaned from JPG source with baked checker background.",
    },
    {
        "target": "assets/backgrounds/bg_main_menu.png",
        "source": "1ec45e9e-abda-46fe-9ff7-3e9b2339636f.jpg",
        "crop": (0, 0, 960, 960),
        "placeholder": "Dedicated main-menu art missing. Reused mercenary camp background.",
    },
    {"target": "assets/backgrounds/bg_run_board.png", "source": "2b4a4095-8310-45ac-8595-9850ee510579.jpg", "crop": (80, 100, 800, 800)},
    {"target": "assets/backgrounds/bg_boss_arena.png", "source": "4f904de6-8f9d-40eb-a73c-a97cbec52261.jpg", "crop": (0, 0, 960, 960)},
    {"target": "assets/backgrounds/event_bg_blood_shrine.png", "source": "4dbe0c76-735b-47ab-a086-c482678d5c1f.jpg", "crop": (0, 0, 960, 960)},
    {"target": "assets/backgrounds/event_bg_ruined_caravan.png", "source": "357c1d63-ab71-43b4-a042-dc19fe5a4816.jpg", "crop": (60, 100, 820, 820)},
    {
        "target": "assets/backgrounds/event_bg_cursed_banner.png",
        "source": "4f904de6-8f9d-40eb-a73c-a97cbec52261.jpg",
        "crop": (0, 0, 960, 960),
        "placeholder": "Dedicated cursed-banner event scene missing. Reused boss-arena art.",
    },
    {"target": "assets/backgrounds/event_bg_mercenary_camp.png", "source": "1ec45e9e-abda-46fe-9ff7-3e9b2339636f.jpg", "crop": (0, 0, 960, 960)},
    {"target": "assets/backgrounds/event_bg_sealed_vault.png", "source": "2434f87f-0b6b-476a-a481-c8b5ee3357e6.jpg", "crop": (0, 0, 960, 960)},
    {"target": "assets/backgrounds/event_bg_scout_tower.png", "source": "43c7acfe-d2f0-48e1-b902-818651f73a4e.jpg", "crop": (0, 0, 960, 960)},
    {"target": "assets/backgrounds/bg_meta_hall.png", "source": "08de20af-9ce4-4605-9caf-e64a0524ae02.jpg", "crop": (0, 0, 960, 960)},
    {"target": "assets/backgrounds/bg_result_summary.png", "source": "e2b38aac-edb5-489a-838e-d15664efd6b6.jpg", "crop": (40, 80, 740, 740)},
]


REVIEW_PENDING = {
    "236cb33a-e592-41b7-a946-43467412c299.jpg": "Unused duplicate banner/territory marker concept.",
    f"{CHAT}10_26_19.png": "Unused duplicate enemy guard sprite.",
    f"{CHAT}10_26_39.png": "Unused alternate Crownless King boss sprite.",
    f"{CHAT}11_00_57.png": "Unused alternate death-smoke VFX concept.",
    f"{CHAT}11_01_04.png": "Unused alternate reward-sparkle VFX concept.",
    f"{CHAT}11_01_08.png": "Unused alternate boss-enrage aura VFX concept.",
    "Gemini_Generated_Image_p611dmp611dmp611.png": "Unused medallion-style icon concept.",
}


REGENERATION_TARGETS = [
    ("assets/backgrounds/bg_main_menu.png", "Dedicated main-menu background was missing, so mercenary camp art was reused as a placeholder."),
    ("assets/ui/ui_button_secondary_pressed.png", "Pressed-state art is a reused plaque, not a dedicated button press treatment."),
    ("assets/ui/ui_tab_button.png", "Generic slim panel reused as a tab button placeholder."),
    ("assets/ui/ui_currency_pill.png", "Currency pill reuses the slim tab asset."),
    ("assets/ui/ui_stat_chip.png", "Stat chip reuses the ornate plaque asset."),
    ("assets/ui/ui_tile_preview_frame.png", "Tile preview frame reuses the primary panel frame."),
    ("assets/icons/icon_range.png", "Icon cleaned from a JPG with a baked checker background. A cleaner native PNG would be better."),
    ("assets/icons/icon_territory_power.png", "Icon cleaned from a JPG with a baked checker background. A cleaner native PNG would be better."),
    ("assets/backgrounds/event_bg_cursed_banner.png", "Dedicated cursed-banner event scene was missing, so boss-arena art was reused as a placeholder."),
]


TEMP_ARTIFACTS = [
    "image_audit.csv",
    "image_contact_sheet.png",
    "image_sheet_001_035.png",
    "image_sheet_036_070.png",
    "image_sheet_071_107.png",
]


def spec_for_target(target: str) -> dict[str, float | int | str]:
    if target.startswith("assets/tiles/"):
        return {"width": 256, "height": 256, "mode": "transparent", "padding": 0.08, "threshold": 40}
    if target.startswith("assets/characters/"):
        return {"width": 192, "height": 192, "mode": "transparent", "padding": 0.10, "threshold": 38}
    if target.startswith("assets/bosses/"):
        return {"width": 384, "height": 384, "mode": "transparent", "padding": 0.06, "threshold": 36}
    if target.startswith("assets/ui/"):
        return {"width": 512, "height": 512, "mode": "transparent", "padding": 0.04, "threshold": 28}
    if target.startswith("assets/effects/"):
        return {"width": 256, "height": 256, "mode": "transparent", "padding": 0.08, "threshold": 34}
    if target.startswith("assets/icons/"):
        return {"width": 128, "height": 128, "mode": "transparent", "padding": 0.12, "threshold": 34}
    if target.startswith("assets/backgrounds/"):
        return {"width": 2048, "height": 2048, "mode": "background", "padding": 0.00, "threshold": 0}
    raise ValueError(f"Unknown target category: {target}")


def has_transparency(image: Image.Image) -> bool:
    if image.mode != "RGBA":
        return False
    alpha = image.getchannel("A")
    lo, _ = alpha.getextrema()
    return lo < 250


def edge_palette(image: Image.Image) -> list[tuple[int, int, int]]:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    counter: Counter[tuple[int, int, int]] = Counter()

    def add(x: int, y: int) -> None:
        r, g, b, a = pixels[x, y]
        if a < 10:
            return
        key = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3)
        counter[key] += 1

    for x in range(width):
        add(x, 0)
        add(x, height - 1)
    for y in range(1, height - 1):
        add(0, y)
        add(width - 1, y)

    if not counter:
        return [(255, 255, 255)]

    palette: list[tuple[int, int, int]] = []
    for key, _ in counter.most_common(2):
        rq = (key >> 10) & 31
        gq = (key >> 5) & 31
        bq = key & 31
        palette.append(((rq << 3) | 4, (gq << 3) | 4, (bq << 3) | 4))
    return palette


def color_distance_sq(pixel: tuple[int, int, int, int], target: tuple[int, int, int]) -> int:
    r, g, b, _ = pixel
    dr = r - target[0]
    dg = g - target[1]
    db = b - target[2]
    return dr * dr + dg * dg + db * db


def remove_edge_background(image: Image.Image, threshold: int) -> Image.Image:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    palette = edge_palette(rgba)
    threshold_sq = threshold * threshold
    visited: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()

    def is_background(x: int, y: int) -> bool:
        pixel = pixels[x, y]
        if pixel[3] < 10:
            return True
        return any(color_distance_sq(pixel, bg) <= threshold_sq for bg in palette)

    def seed(x: int, y: int) -> None:
        if (x, y) not in visited and is_background(x, y):
            queue.append((x, y))

    for x in range(width):
        seed(x, 0)
        seed(x, height - 1)
    for y in range(1, height - 1):
        seed(0, y)
        seed(width - 1, y)

    while queue:
        x, y = queue.popleft()
        if (x, y) in visited:
            continue
        visited.add((x, y))
        if not is_background(x, y):
            continue

        r, g, b, _ = pixels[x, y]
        pixels[x, y] = (r, g, b, 0)

        if x > 0:
            queue.append((x - 1, y))
        if x < width - 1:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y < height - 1:
            queue.append((x, y + 1))

    return rgba


def opaque_bounds(image: Image.Image, alpha_threshold: int = 12) -> tuple[int, int, int, int]:
    alpha = image.getchannel("A").point(lambda value: 255 if value > alpha_threshold else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        return (0, 0, image.width, image.height)
    return bbox


def contain(image: Image.Image, bounds: tuple[int, int, int, int], width: int, height: int, padding: float) -> Image.Image:
    cropped = image.crop(bounds)
    usable_width = max(1, int(round(width * (1.0 - padding * 2.0))))
    usable_height = max(1, int(round(height * (1.0 - padding * 2.0))))
    scale = min(usable_width / cropped.width, usable_height / cropped.height)
    scaled_size = (
        max(1, int(round(cropped.width * scale))),
        max(1, int(round(cropped.height * scale))),
    )
    scaled = cropped.resize(scaled_size, Image.Resampling.LANCZOS)
    output = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    dx = (width - scaled.width) // 2
    dy = (height - scaled.height) // 2
    output.paste(scaled, (dx, dy), scaled)
    return output


def cover(image: Image.Image, crop: tuple[int, int, int, int], width: int, height: int) -> Image.Image:
    x, y, w, h = crop
    cropped = image.crop((x, y, x + w, y + h))
    return cropped.resize((width, height), Image.Resampling.LANCZOS)


def write_lines(path: Path, lines: list[str]) -> None:
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def process_assets(project_root: Path, source_dir: Path) -> None:
    review_dir = source_dir / "review_pending"
    review_dir.mkdir(parents=True, exist_ok=True)

    used_sources: set[str] = set()
    placeholder_targets: list[tuple[str, str]] = []

    for entry in MAPS:
        target_rel = entry["target"]
        source_name = entry["source"]
        source_path = source_dir / source_name
        if not source_path.exists():
            raise FileNotFoundError(f"Missing source image: {source_name}")

        spec = spec_for_target(target_rel)
        width = int(spec["width"])
        height = int(spec["height"])
        padding = float(entry.get("padding", spec["padding"]))
        threshold = int(entry.get("threshold", spec["threshold"]))
        mode = str(spec["mode"])

        image = Image.open(source_path).convert("RGBA")
        if mode == "background":
            crop = entry.get("crop", (0, 0, image.width, image.height))
            output = cover(image, crop, width, height)
        else:
            if not has_transparency(image):
                image = remove_edge_background(image, threshold)
            output = contain(image, opaque_bounds(image), width, height, padding)

        target_path = project_root / target_rel
        target_path.parent.mkdir(parents=True, exist_ok=True)
        output.save(target_path, "PNG")
        used_sources.add(source_name)

        if "placeholder" in entry:
            placeholder_targets.append((target_rel, str(entry["placeholder"])))

    for source_name in sorted(used_sources):
        if source_name in REVIEW_PENDING:
            continue
        source_path = source_dir / source_name
        if source_path.exists():
            source_path.unlink()

    for source_name, reason in REVIEW_PENDING.items():
        source_path = source_dir / source_name
        if source_path.exists():
            target_path = review_dir / source_name
            if target_path.exists():
                target_path.unlink()
            shutil.move(str(source_path), str(target_path))

    for artifact in TEMP_ARTIFACTS:
        artifact_path = project_root / artifact
        if artifact_path.exists():
            artifact_path.unlink()

    failed_sizes: list[str] = []
    for entry in MAPS:
        target_rel = entry["target"]
        spec = spec_for_target(target_rel)
        width = int(spec["width"])
        height = int(spec["height"])
        target_path = project_root / target_rel
        with Image.open(target_path) as image:
            if image.size != (width, height):
                failed_sizes.append(f"{target_rel}: expected {(width, height)}, got {image.size}")
    if failed_sizes:
        raise RuntimeError("Unexpected output sizes:\n" + "\n".join(failed_sizes))

    duplicates: dict[str, list[str]] = defaultdict(list)
    for entry in MAPS:
        duplicates[entry["source"]].append(entry["target"])

    report_lines = [
        "# Asset Import Report",
        "",
        f"- Processed targets: {len(MAPS)}",
        f"- Unique source files consumed: {len(used_sources)}",
        f"- Review-pending source files: {len(REVIEW_PENDING)}",
        f"- Placeholder targets: {len(placeholder_targets)}",
        "",
        "## Duplicate Source Usage",
        "",
    ]
    for source_name in sorted(name for name, targets in duplicates.items() if len(targets) > 1):
        report_lines.append(f"- `{source_name}`")
        for target in duplicates[source_name]:
            report_lines.append(f"  - {target}")

    report_lines.extend(["", "## Placeholder Targets", ""])
    for target, note in placeholder_targets:
        report_lines.append(f"- `{target}`: {note}")

    report_lines.extend(["", "## Review Pending", ""])
    for source_name, reason in REVIEW_PENDING.items():
        report_lines.append(f"- `image/review_pending/{source_name}`: {reason}")

    report_lines.extend(["", "## Verification", "", "- All processed assets match their target output size."])
    write_lines(project_root / "asset_import_report.md", report_lines)

    regen_lines = [
        "# Asset Regeneration List",
        "",
        "아래 항목은 현재 게임에 배치했지만, 더 좋은 전용 원본으로 다시 요청하는 것이 좋습니다.",
        "",
    ]
    for target, reason in REGENERATION_TARGETS:
        regen_lines.append(f"- `{target}`: {reason}")
    regen_lines.extend(["", "## Review Pending Source Files", ""])
    for source_name, reason in REVIEW_PENDING.items():
        regen_lines.append(f"- `image/review_pending/{source_name}`: {reason}")
    write_lines(project_root / "asset_regeneration_list.md", regen_lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--source-dir", required=True)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    process_assets(Path(args.project_root), Path(args.source_dir))
    print(f"Imported {len(MAPS)} assets into the project.")


if __name__ == "__main__":
    main()
