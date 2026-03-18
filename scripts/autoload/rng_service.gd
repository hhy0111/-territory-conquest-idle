extends Node

const CHANNELS := ["map", "combat", "event", "reward"]

var _base_seed: int = 0
var _rngs: Dictionary = {}


func seed_channels(seed: int) -> void:
	_base_seed = seed
	_rngs.clear()
	for index in range(CHANNELS.size()):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(seed + ((index + 1) * 100003))
		_rngs[CHANNELS[index]] = rng


func rng_for(channel: String) -> RandomNumberGenerator:
	if not _rngs.has(channel):
		if _base_seed == 0:
			_base_seed = int(Time.get_unix_time_from_system())
		seed_channels(_base_seed)
	return _rngs[channel]


func randi_range(channel: String, min_value: int, max_value: int) -> int:
	return rng_for(channel).randi_range(min_value, max_value)


func randf_range(channel: String, min_value: float, max_value: float) -> float:
	return rng_for(channel).randf_range(min_value, max_value)
