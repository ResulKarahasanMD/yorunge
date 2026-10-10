extends TestSuite
## DemoReport maths and the error-counting logger (no game run needed).

const FRAME := 1.0 / 120.0
const SPIKE := 0.05


func test_frame_stats() -> void:
	var frames := PackedFloat32Array()
	for i in 1000:
		frames.append(FRAME)
	var steady := DemoReport._frame_stats(frames)
	check_near(steady["fps_avg"], 120.0, "steady 120 Hz average", 0.11)
	check_near(steady["fps_low"], 120.0, "steady 1% low equals average", 0.11)
	check_near(steady["worst_frame_ms"], FRAME * 1000.0, "worst frame of a steady run", 0.06)
	for i in 20:
		frames[i * 50] = SPIKE
	var spiky := DemoReport._frame_stats(frames)
	check_near(spiky["worst_frame_ms"], SPIKE * 1000.0, "spike shows up as the worst frame", 0.06)
	check_near(spiky["fps_low"], 1.0 / SPIKE, "2% spikes pull the 1% low down to the spike rate", 0.11)
	check(spiky["fps_avg"] < steady["fps_avg"], "spikes lower the average")
	check(DemoReport._frame_stats(PackedFloat32Array())["frames"] == 0, "empty input is safe")


func test_error_counter() -> void:
	var counter := DemoReport.ErrorCounter.new()
	counter._log_error("f", "a.gd", 1, "code", "why", false, Logger.ERROR_TYPE_ERROR, [])
	counter._log_error("f", "a.gd", 2, "code", "why", false, Logger.ERROR_TYPE_SCRIPT, [])
	counter._log_error("f", "a.gd", 3, "code", "why", false, Logger.ERROR_TYPE_WARNING, [])
	check(counter.snapshot() == Vector2i(2, 1), "two errors and one warning counted (got %s)" % counter.snapshot())
	check(counter.messages.size() == 3 and counter.messages[0].begins_with("a.gd:1"), "messages kept with location")
