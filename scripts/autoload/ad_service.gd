extends Node

var rewarded_ready: bool = false
var interstitial_ready: bool = false


func is_rewarded_ready() -> bool:
	return rewarded_ready


func show_rewarded(_ad_slot_id: String) -> bool:
	return rewarded_ready


func is_interstitial_ready() -> bool:
	return interstitial_ready


func show_interstitial() -> bool:
	return interstitial_ready
