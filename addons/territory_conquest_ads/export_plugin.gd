@tool
extends EditorPlugin

const PLUGIN_NAME := "TerritoryConquestAds"

var export_plugin: TerritoryConquestAdsExportPlugin


func _enter_tree() -> void:
	export_plugin = TerritoryConquestAdsExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree() -> void:
	if export_plugin == null:
		return
	remove_export_plugin(export_plugin)
	export_plugin = null


class TerritoryConquestAdsExportPlugin extends EditorExportPlugin:
	const RUNTIME_CONFIG_PATH := "res://data/ad_runtime.json"
	const DEBUG_AAR_RELATIVE_PATHS := [
		"territory_conquest_ads/bin/debug/territory-conquest-ads-debug.aar"
	]
	const RELEASE_AAR_RELATIVE_PATHS := [
		"territory_conquest_ads/bin/release/territory-conquest-ads-release.aar"
	]

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid


	func _get_name() -> String:
		return "TerritoryConquestAds"


	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var candidate_paths := DEBUG_AAR_RELATIVE_PATHS if debug else RELEASE_AAR_RELATIVE_PATHS
		var exported_paths := PackedStringArray()
		for relative_path in candidate_paths:
			var res_path := "res://addons/%s" % relative_path
			if FileAccess.file_exists(res_path):
				exported_paths.append(relative_path)
		return exported_paths


	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var android_config := _get_android_platform_config()
		var dependencies: Array = android_config.get("maven_dependencies", [])
		return _to_packed_string_array(dependencies)


	func _get_android_dependencies_maven_repos(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var android_config := _get_android_platform_config()
		var repositories: Array = android_config.get("maven_repositories", [])
		return _to_packed_string_array(repositories)


	func _get_android_manifest_application_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
		var android_config := _get_android_platform_config()
		var app_id := String(android_config.get("app_id", "")).strip_edges()
		if app_id.is_empty():
			return ""

		return "\n        <meta-data\n            android:name=\"com.google.android.gms.ads.APPLICATION_ID\"\n            android:value=\"%s\" />" % app_id


	func _get_android_manifest_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
		return ""


	func _get_android_manifest_activity_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
		return ""


	func _load_runtime_config() -> Dictionary:
		if not FileAccess.file_exists(RUNTIME_CONFIG_PATH):
			return {}

		var file := FileAccess.open(RUNTIME_CONFIG_PATH, FileAccess.READ)
		if file == null:
			return {}

		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary:
			return parsed
		return {}


	func _get_android_platform_config() -> Dictionary:
		var runtime_config := _load_runtime_config()
		var platforms: Variant = runtime_config.get("platforms", {})
		if not (platforms is Dictionary):
			return {}
		return platforms.get("android", {})


	func _to_packed_string_array(values: Array) -> PackedStringArray:
		var result := PackedStringArray()
		for value in values:
			result.append(String(value))
		return result
