extends RefCounted


func run() -> Array:
	var failures: Array = []
	var data_service := _require_autoload("DataService", failures)
	var analytics_service := _require_autoload("AnalyticsService", failures)
	var ad_service := _require_autoload("AdService", failures)
	if not failures.is_empty():
		return failures

	data_service.load_all_data()
	analytics_service.reset_for_tests()
	ad_service.reset_mock_state()
	ad_service.refresh_runtime_config()

	var runtime_config: Dictionary = data_service.get_ad_runtime_config()
	var android_config: Dictionary = runtime_config.get("platforms", {}).get("android", {})
	if String(android_config.get("app_id", "")) != "ca-app-pub-4402708884038037~2144372327":
		failures.append("Expected ad runtime config to expose the Android AdMob app id.")
	if ad_service.get_slot_unit_id("rewarded_revive") != "ca-app-pub-4402708884038037/1017458066":
		failures.append("Expected AdService to resolve rewarded_revive unit id from runtime config.")
	if int(android_config.get("app_open_resume_threshold_seconds", 0)) != 180:
		failures.append("Expected ad runtime config to require a 180 second background gap before resume app-open attempts.")
	if int(android_config.get("min_sdk", 0)) != 23:
		failures.append("Expected ad runtime config to record Android min SDK 23.")
	var dependencies: Array = android_config.get("maven_dependencies", [])
	if not dependencies.has("com.google.android.gms:play-services-ads:24.9.0"):
		failures.append("Expected ad runtime config to record the Google Mobile Ads SDK dependency.")
	if not dependencies.has("com.google.android.ump:user-messaging-platform:4.0.0"):
		failures.append("Expected ad runtime config to record the UMP SDK dependency.")

	ad_service.request_consent_if_needed()
	if ad_service.get_consent_status() != "granted":
		failures.append("Expected editor/default runtime to grant consent through mock fallback.")

	if not ad_service.show_app_open():
		failures.append("Expected app open mock flow to remain available after runtime-config wiring.")
	ad_service.flush_mock_callbacks_for_tests()
	if ad_service.app_open_show_count != 1:
		failures.append("Expected app open mock flow to record one show count after completion.")

	analytics_service.reset_for_tests()
	if not ad_service.show_rewarded("rewarded_revive"):
		failures.append("Expected rewarded mock flow to remain available after runtime-config wiring.")
	if ad_service.has_recent_rewarded_watch():
		failures.append("Expected rewarded mock flow to wait for completion before marking recent watch state.")
	ad_service.flush_mock_callbacks_for_tests()
	if not ad_service.has_recent_rewarded_watch():
		failures.append("Expected rewarded show to update recent rewarded-watch state.")

	var events: Array = analytics_service.get_recorded_events()
	if not _has_event(events, "ad_show_attempt"):
		failures.append("Expected rewarded show to emit ad_show_attempt analytics.")
	if not _has_event(events, "ad_show_completed"):
		failures.append("Expected rewarded show to emit ad_show_completed analytics.")

	analytics_service.reset_for_tests()
	ad_service.mark_consent_result("declined", "QA block")
	if ad_service.show_interstitial():
		failures.append("Expected declined consent to block interstitial display.")
	if not _has_event(analytics_service.get_recorded_events(), "ad_show_failed"):
		failures.append("Expected blocked interstitial to emit ad_show_failed analytics.")

	ad_service.configure_qa_overrides({
		"enabled": true,
		"consent": {
			"status": "declined",
			"detail": "qa_declined"
		}
	})
	ad_service.request_consent_if_needed()
	if ad_service.get_consent_status() != "declined":
		failures.append("Expected QA consent override to replace the runtime consent result.")

	ad_service.clear_qa_overrides()
	ad_service.mark_consent_result("granted", "Reset")
	analytics_service.reset_for_tests()
	if not ad_service.show_interstitial():
		failures.append("Expected mock interstitial to remain available after consent reset.")
	ad_service.flush_mock_callbacks_for_tests()
	if ad_service.interstitial_show_count != 1:
		failures.append("Expected interstitial mock flow to record one show count.")

	ad_service.reset_mock_state()
	ad_service.refresh_runtime_config()
	ad_service.mark_consent_result("granted", "Reset")
	analytics_service.reset_for_tests()
	ad_service.configure_qa_overrides({
		"enabled": true,
		"slot_outcomes": {
			"rewarded_revive": {
				"outcome": "completed",
				"detail": "qa_reward_grant"
			}
		}
	})
	if not ad_service.show_rewarded("rewarded_revive"):
		failures.append("Expected QA rewarded override to start successfully.")
	if ad_service.rewarded_watch_count != 0:
		failures.append("Expected QA rewarded override to wait for callback flush before counting completion.")
	ad_service.flush_mock_callbacks_for_tests()
	if ad_service.rewarded_watch_count != 1:
		failures.append("Expected QA rewarded override to count completion after flush.")
	if not _has_event(analytics_service.get_recorded_events(), "ad_show_completed"):
		failures.append("Expected QA rewarded override to emit ad_show_completed analytics.")
	if not _has_event_with_payload_value(analytics_service.get_recorded_events(), "ad_show_completed", "detail", "qa_reward_grant"):
		failures.append("Expected QA rewarded override to keep the configured completion detail.")
	if not _has_event_with_payload_value(analytics_service.get_recorded_events(), "ad_show_completed", "mode", "qa"):
		failures.append("Expected QA rewarded override analytics to record qa mode.")

	ad_service.reset_mock_state()
	ad_service.refresh_runtime_config()
	ad_service.mark_consent_result("granted", "Reset")
	analytics_service.reset_for_tests()
	ad_service.configure_qa_overrides({
		"enabled": true,
		"slot_outcomes": {
			"app_open_launch": {
				"outcome": "failed",
				"reason": "qa_app_open_timeout"
			}
		}
	})
	if not ad_service.show_app_open():
		failures.append("Expected QA app-open failure override to start successfully.")
	ad_service.flush_mock_callbacks_for_tests()
	if ad_service.app_open_show_count != 0:
		failures.append("Expected failed QA app-open override to avoid incrementing app-open show count.")
	if not _has_event_with_payload_value(analytics_service.get_recorded_events(), "ad_show_failed", "reason", "qa_app_open_timeout"):
		failures.append("Expected QA app-open failure override to emit the configured failure reason.")

	ad_service.reset_mock_state()
	ad_service.refresh_runtime_config()
	ad_service.mark_consent_result("granted", "Reset")
	analytics_service.reset_for_tests()
	ad_service.configure_qa_overrides({
		"enabled": true,
		"slot_outcomes": {
			"interstitial_run_end": {
				"show_returns": false,
				"reason": "qa_rejected"
			}
		}
	})
	if ad_service.show_interstitial():
		failures.append("Expected QA interstitial rejection override to make show_interstitial return false.")
	if ad_service.interstitial_show_count != 0:
		failures.append("Expected QA interstitial rejection override to avoid incrementing show count.")
	if not _has_event_with_payload_value(analytics_service.get_recorded_events(), "ad_show_failed", "reason", "qa_rejected"):
		failures.append("Expected QA interstitial rejection override to emit the configured rejection reason.")

	return failures


func _require_autoload(node_name: String, failures: Array) -> Node:
	var main_loop := Engine.get_main_loop()
	if not (main_loop is SceneTree):
		failures.append("Expected a SceneTree main loop when running AdService tests.")
		return null

	var tree: SceneTree = main_loop
	var node := tree.root.get_node_or_null(node_name)
	if node == null:
		failures.append("Missing required autoload: %s" % node_name)
	return node


func _has_event(events: Array, event_name: String) -> bool:
	for entry_value in events:
		if not (entry_value is Dictionary):
			continue
		if String(entry_value.get("name", "")) == event_name:
			return true
	return false


func _has_event_with_payload_value(events: Array, event_name: String, payload_key: String, expected_value: Variant) -> bool:
	for entry_value in events:
		if not (entry_value is Dictionary):
			continue
		if String(entry_value.get("name", "")) != event_name:
			continue
		var payload: Variant = entry_value.get("payload", {})
		if not (payload is Dictionary):
			continue
		if payload.get(payload_key) == expected_value:
			return true
	return false
