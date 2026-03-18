extends RefCounted

const EventResolverScript = preload("res://scripts/map/event_resolver.gd")
const MapGeneratorScript = preload("res://scripts/map/map_generator.gd")


func run() -> Array:
	var failures: Array = []
	var run := {
		"seed": 123,
		"captured_tiles": 0,
		"danger": 0,
		"gold": 0,
		"xp": 0,
		"level": 1,
		"pending_essence_bonus": 0,
		"player": {
			"current_hp": 100,
			"max_hp": 100,
			"attack": 12,
			"territory_power": 0.0
		},
		"curses": [],
		"map": {
			"tiles": {
				"0,0": { "x": 0, "y": 0, "type": "plains", "state": "captured", "ring": 0 },
				"1,0": { "x": 1, "y": 0, "type": "shrine", "state": "selectable", "ring": 1 }
			}
		}
	}
	var tile_defs := {
		"shrine": {
			"id": "shrine",
			"base_reward": { "gold": [8, 14], "xp": [14, 18] },
			"risk_delta": 6
		}
	}
	var event_defs := {
		"blood_shrine": {
			"id": "blood_shrine",
			"title": "Blood Shrine",
			"choices": [
				{
					"id": "offer_blood",
					"label": "Offer Blood",
					"cost": { "current_hp_percent": 0.2 },
					"reward": { "attack_percent": 0.18 },
					"danger_delta": 6
				}
			]
		}
	}
	var tile_def := {
		"event_pool": ["blood_shrine"]
	}

	var event_def := EventResolverScript.event_for_tile(run, MapGeneratorScript.coord_key(1, 0), tile_def, event_defs)
	var result := EventResolverScript.apply_choice(run, MapGeneratorScript.coord_key(1, 0), tile_defs, event_def, "offer_blood")
	if not result.get("ok", false):
		failures.append("Expected event resolution to succeed.")
		return failures

	var next_run: Dictionary = result.get("run", {})
	if int(next_run.get("player", {}).get("attack", 0)) <= 12:
		failures.append("Expected event reward to increase player attack.")
	if int(next_run.get("player", {}).get("current_hp", 0)) >= 100:
		failures.append("Expected event cost to reduce current HP.")
	if int(next_run.get("captured_tiles", 0)) != 1:
		failures.append("Expected event tile to count as captured.")

	return failures
