extends SceneTree
## Headless test runner. Exit code 0 = all checks passed.
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/run_tests.gd

const SUITES: Array[String] = [
	"res://tests/test_gravity.gd",
]


func _initialize() -> void:
	# Nodes added during _initialize are not inside the tree yet (no global
	# transforms), so the suites run on the first frame instead.
	process_frame.connect(_run_all, CONNECT_ONE_SHOT)


func _run_all() -> void:
	var total_checks := 0
	var all_failures := PackedStringArray()
	for path: String in SUITES:
		var suite: TestSuite = (load(path) as GDScript).new()
		suite.tree = self
		var tests := 0
		for method: Dictionary in suite.get_method_list():
			var method_name := String(method["name"])
			if not method_name.begins_with("test_"):
				continue
			tests += 1
			suite.begin(method_name)
			suite.call(method_name)
			suite.cleanup()
		total_checks += suite.checks
		all_failures.append_array(suite.failures)
		print("[Test] %s: %d tests, %d checks, %d failures" % [
			path.get_file(), tests, suite.checks, suite.failures.size()])
	for failure: String in all_failures:
		printerr("[Test] FAIL %s" % failure)
	print("[Test] TOTAL checks=%d failures=%d" % [total_checks, all_failures.size()])
	quit(0 if all_failures.is_empty() else 1)
