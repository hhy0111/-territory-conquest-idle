extends SceneTree

const TestAdService = preload("res://tests/test_ad_service.gd")


func _init() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	var suite_failures: Array = TestAdService.new().run()
	if suite_failures.is_empty():
		print("AdService tests passed.")
		quit(0)
		return

	for failure in suite_failures:
		push_error("[ad_service] %s" % failure)
	quit(1)
